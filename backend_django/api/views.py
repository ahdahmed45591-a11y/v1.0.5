"""Portage 1:1 de backend/api/server_api.js + backend/core/server_core.js.

Les chemins, les codes HTTP et la forme des JSON sont ceux de la v1.0.4 :
l'app Android et l'admin React ne sont pas modifies.
"""

import base64
import binascii
import datetime as dt
import functools
import hashlib
import json
import os
import uuid
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

import bcrypt
import jwt
from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction as db_transaction
from django.db.models import Sum
from django.http import HttpResponse, HttpResponseRedirect
from django.views.static import serve as static_serve
from rest_framework.decorators import api_view, throttle_classes
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle

from . import brvm, jeko
from .models import Message, Ticket, Transaction, User

JWT_SECRET = settings.JWT_SECRET
UPLOAD_DIR = settings.UPLOAD_DIR

# Seules valeurs acceptees pour User.kyc (max_length=20). "verified" est la
# seule qui deverrouille les operations d'argent (voir create_transaction).
KYC_STATUSES = ("pending", "verified", "rejected", "suspended")


class AuthThrottle(AnonRateThrottle):
    """Limite les endpoints ou deviner vaut le coup (login, reinitialisation).
    Le throttle global est a 300/min : largement assez pour brute-forcer un
    mot de passe. Taux dans settings.DEFAULT_THROTTLE_RATES["auth"]."""

    scope = "auth"

ADMIN_STATS = {
    "totalUsers": 0,
    "kycVerified": 0,
    "kycPending": 0,
    "kycUrgent": 0,
    "suspended": 0,
    "marketStatus": "OPEN",
    "marketCloseIn": "3h 15m",
    "brvm": {
        "composite": 214.68,
        "composite_change": 0.85,
        "brvm10": 312.45,
        "brvm10_change": 1.23,
        "volume": 482300000,
        "volume_change": -3.2,
    },
}


def now_iso():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def money(x):
    """Montant FCFA arrondi au centime, en Decimal (voir MONEY dans models.py).
    Decimal(str(x)) et pas Decimal(x) : passer un float directement conserve
    son erreur binaire (Decimal(0.1) -> 0.1000000000000000055511151231257827)."""
    return Decimal(str(x)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


# Frais de courtage 0,5 % + TVA 18 % sur ces frais. En Decimal : multiplier un
# Decimal par un float leve TypeError.
FEE_RATE = Decimal("0.005")
TVA_RATE = Decimal("0.18")


# ── Auth ────────────────────────────────────────────────────────────────


def session_of(request):
    header = request.headers.get("Authorization", "")
    # ?token= en secours : /uploads/... (voir plus bas) est charge via
    # <img src>, qui ne peut pas poser d'en-tete Authorization.
    token = header[7:] if header.startswith("Bearer ") else request.GET.get("token")
    if not token:
        return None
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        return None


def require_auth(admin=False):
    def deco(fn):
        @functools.wraps(fn)
        def wrapper(request, *args, **kwargs):
            if not request.headers.get("Authorization", "").startswith("Bearer "):
                return Response({"error": "Accès refusé. Jeton d'authentification manquant."}, status=401)
            sess = session_of(request)
            if sess is None:
                return Response({"error": "Jeton invalide ou expiré."}, status=401)
            if admin and sess.get("role") != "admin":
                return Response({"error": "Accès réservé aux administrateurs."}, status=403)
            request.session_data = sess
            return fn(request, *args, **kwargs)

        return wrapper

    return deco


def check_password(raw, stored):
    raw = (raw or "").encode()
    if stored and stored.startswith("$2"):
        try:
            return bcrypt.checkpw(raw, stored.encode())
        except ValueError:
            return False
    # Comptes importes en clair (comportement d'origine, conserve pour
    # ne pas verrouiller les comptes existants).
    return raw.decode() == stored


def hash_password(raw):
    return bcrypt.hashpw(raw.encode(), bcrypt.gensalt(10)).decode()


# ── Racine & health ─────────────────────────────────────────────────────


@api_view(["GET"])
def root(request):
    return Response({
        "name": "🐘 Éléphant Bourse REST API Gateway",
        "architecture": "Django 5 + DRF + PostgreSQL 16",
        "version": "1.0.5",
        "status": "running",
        "market": "BRVM — Côte d'Ivoire",
    })


@api_view(["GET"])
def health(request):
    ok = True
    try:
        User.objects.exists()
    except Exception:
        ok = False
    return Response({
        "status": "ok" if ok else "degraded",
        "service": "backend-django",
        "db_connected": ok,
    })


# ── Auth ────────────────────────────────────────────────────────────────


@api_view(["POST"])
@throttle_classes([AuthThrottle])
def login(request):
    email = (request.data.get("email") or "").strip().lower()
    user = User.objects.filter(email__iexact=email).first()
    if not user or not check_password(request.data.get("password"), user.password):
        return Response({"success": False, "message": "Email ou mot de passe incorrect."}, status=401)

    token = jwt.encode(
        {
            "userId": user.id,
            "email": user.email,
            "role": user.role,
            "name": user.name,
            "exp": dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=24),
        },
        JWT_SECRET,
        algorithm="HS256",
    )
    return Response({"success": True, "token": token, "user": user.as_dict()})


def send_welcome_email(user):
    """Email de bienvenue avec lien de confirmation, envoye depuis le compte
    support (EMAIL_HOST_USER). ponytail: si EMAIL_HOST_PASSWORD n'est pas
    configure (mot de passe d'application Gmail), on n'essaie meme pas
    d'ouvrir la connexion SMTP -- une inscription ne doit jamais echouer a
    cause de l'email."""
    if not settings.EMAIL_HOST_PASSWORD:
        return
    verify_token = jwt.encode(
        {
            "userId": user.id,
            "purpose": "verify_email",
            "exp": dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=7),
        },
        JWT_SECRET,
        algorithm="HS256",
    )
    link = f"{settings.BACKEND_PUBLIC_URL}/api/auth/verify-email?token={verify_token}"
    try:
        send_mail(
            subject="Bienvenue sur BAOU Finance — confirmez votre compte",
            message=(
                f"Bonjour {user.name},\n\n"
                "Votre compte BAOU Finance a bien ete cree.\n"
                f"Confirmez votre adresse email en ouvrant ce lien depuis votre telephone :\n{link}\n\n"
                "Le lien ouvre directement l'application BAOU si elle est installee.\n\n"
                "L'equipe BAOU Finance"
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        )
    except Exception:  # noqa: BLE001 - SMTP down/creds invalides : ne bloque pas l'inscription
        pass


def send_password_reset_email(user):
    """Meme mecanique que send_welcome_email, mais le token sert de *code* a
    copier-coller dans l'appli plutot qu'un lien a suivre : pas de parsing de
    deep link cote Flutter a construire pour ce flux (voir verify_email pour
    le cas ou un simple "ouvrir l'app" suffit)."""
    if not settings.EMAIL_HOST_PASSWORD:
        return
    token = jwt.encode(
        {
            "userId": user.id,
            "purpose": "reset_password",
            # ponytail: empreinte du mot de passe actuel -> le code devient
            # caduc des qu'il a servi (le hash change), sans colonne ni table
            # de jetons a stocker. Avant, le meme code marchait autant de fois
            # qu'on voulait pendant 1 h.
            "pw": hashlib.sha256(user.password.encode()).hexdigest()[:16],
            "exp": dt.datetime.now(dt.timezone.utc) + dt.timedelta(hours=1),
        },
        JWT_SECRET,
        algorithm="HS256",
    )
    try:
        send_mail(
            subject="BAOU Finance — Réinitialisation de votre mot de passe",
            message=(
                f"Bonjour {user.name},\n\n"
                "Voici votre code de reinitialisation (valable 1 heure) :\n\n"
                f"{token}\n\n"
                "Ouvrez l'application BAOU, allez sur \"Mot de passe oublie\", "
                "puis collez ce code avec votre nouveau mot de passe.\n\n"
                "Si vous n'etes pas a l'origine de cette demande, ignorez cet email.\n\n"
                "L'equipe BAOU Finance"
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        )
    except Exception:  # noqa: BLE001 - SMTP down/creds invalides : ne bloque jamais l'appel
        pass


@api_view(["POST"])
@throttle_classes([AuthThrottle])
def request_password_reset(request):
    email = (request.data.get("email") or "").strip().lower()
    user = User.objects.filter(email__iexact=email).first()
    if user:
        send_password_reset_email(user)
    # Meme reponse que le compte existe ou non : evite l'enumeration d'emails.
    return Response({
        "success": True,
        "message": "Si un compte existe avec cet email, un code de réinitialisation a été envoyé.",
    })


@api_view(["POST"])
@throttle_classes([AuthThrottle])
def reset_password(request):
    token = request.data.get("token") or ""
    new_password = request.data.get("newPassword") or ""
    if len(new_password) < 6:
        return Response({"error": "Le mot de passe doit contenir au moins 6 caractères."}, status=400)
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        return Response({"error": "Code invalide ou expiré."}, status=400)
    if payload.get("purpose") != "reset_password":
        return Response({"error": "Code invalide."}, status=400)
    user = User.objects.filter(id=payload.get("userId")).first()
    if not user:
        return Response({"error": "Compte introuvable."}, status=404)
    if payload.get("pw") != hashlib.sha256(user.password.encode()).hexdigest()[:16]:
        # Code deja utilise (le mot de passe a change depuis son envoi).
        return Response({"error": "Code déjà utilisé ou expiré."}, status=400)
    user.password = hash_password(new_password)
    user.save()
    return Response({"success": True, "message": "Mot de passe mis à jour."})


@api_view(["POST"])
def register(request):
    d = request.data
    email = (d.get("email") or "").strip().lower()
    name = (d.get("name") or d.get("firstName") or "").strip()
    password = d.get("password") or ""

    if not email or not password or not name:
        return Response({"error": "Email, mot de passe et nom/prénom sont requis."}, status=400)
    if User.objects.filter(email__iexact=email).exists():
        return Response({"error": "Un compte existe déjà avec cet email."}, status=409)

    user = User.objects.create(
        id=f"CLI-{int(dt.datetime.now().timestamp() * 1000)}",
        name=name,
        email=email,
        password=hash_password(password),
        role="client",
        kyc="pending",
        balance=Decimal(0),
        joined_at=now_iso(),
    )
    send_welcome_email(user)
    return Response({"success": True, "user": user.as_dict()}, status=201)


class AppRedirect(HttpResponseRedirect):
    """Redirection vers l'application mobile (scheme baou://).

    HttpResponseRedirect n'autorise que http/https/ftp et leve
    DisallowedRedirect sur tout autre scheme -- que Django transforme en 400.
    Le lien de confirmation envoye par email renvoyait donc "400 Bad Request"
    au lieu d'ouvrir l'app : il n'a jamais fonctionne. On autorise le seul
    scheme dont on a besoin (voir AndroidManifest.xml).
    """

    allowed_schemes = ["http", "https", "baou"]


def verify_email(request):
    """Lien clique depuis l'email de bienvenue : marque l'email verifie puis
    redirige vers l'app mobile (scheme baou://, voir AndroidManifest.xml).
    Pas de @api_view : ce n'est jamais appele en JSON, toujours ouvert dans
    un navigateur/webview depuis l'email."""
    token = request.GET.get("token") or ""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        return AppRedirect("baou://verify-email?ok=0")
    if payload.get("purpose") != "verify_email":
        return AppRedirect("baou://verify-email?ok=0")
    user = User.objects.filter(id=payload.get("userId")).first()
    if not user:
        return AppRedirect("baou://verify-email?ok=0")
    user.email_verified = True
    user.save()
    return AppRedirect("baou://verify-email?ok=1")


@api_view(["POST"])
@require_auth()
def logout(request):
    return Response({"success": True, "message": "Déconnexion réussie."})


@api_view(["PATCH", "POST"])
@require_auth()
def profile(request):
    d = request.data
    user = User.objects.filter(id=request.session_data["userId"]).first()
    if not user:
        return Response({"error": "Utilisateur introuvable."}, status=404)

    first, last = d.get("firstName"), d.get("lastName")
    if first or last:
        user.name = f"{first or ''} {last or ''}".strip()
    # ponytail: kyc/identityDocStatus/proofOfAddressStatus/signatureStatus
    # retires du champ modifiable par le client -- avant ce correctif un
    # simple PATCH /api/auth/profile {"kycStatus":"verified"} suffisait a
    # s'auto-valider et contournait entierement la revue admin (voir aussi
    # le verrou dans create_transaction). Seul admin_user_kyc peut les changer.
    for src, field in (
        ("whatsapp", "whatsapp"),
        ("birthDate", "birth_date"),
        ("profession", "profession"),
        ("residence", "residence"),
    ):
        if d.get(src):
            setattr(user, field, d[src])
    user.save()
    return Response({"success": True, "user": user.as_dict()})


def uploads(request, path):
    """Sert les pieces KYC (CNI, selfie, justificatif...). Route protegee :
    seul le proprietaire (prefixe userId du nom de fichier, voir
    upload_document) ou un admin peut lire. Avant ce correctif /uploads/
    etait public, sans aucune authentification."""
    sess = session_of(request)
    if sess is None:
        return HttpResponse(status=401)
    owner_id = path.split("_", 1)[0]
    if sess.get("role") != "admin" and sess.get("userId") != owner_id:
        return HttpResponse(status=403)
    return static_serve(request, path, document_root=UPLOAD_DIR)


CONTRACT_PATH = os.path.join(os.path.dirname(__file__), "contract_sgi_brvm.txt")


@api_view(["GET"])
@require_auth()
def contract(request):
    # Fichier texte simple, pas de modele/DB : la SGI edite le .txt pour
    # changer le contrat, sans reconstruire ni redeployer l'app mobile.
    try:
        with open(CONTRACT_PATH, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        text = "Contrat indisponible pour le moment."
    return Response({"success": True, "text": text})


def contract_pdf(request):
    """PDF du contrat SGI BRVM + image de la signature du client en bas de
    page. Genere a la demande (pas stocke) : le client peut le telecharger
    depuis son Profil, l'admin depuis le dossier d'un client (?userId=)."""
    sess = session_of(request)
    if sess is None:
        return HttpResponse(status=401)
    target_id = request.GET.get("userId") or sess.get("userId")
    if sess.get("role") != "admin" and sess.get("userId") != target_id:
        return HttpResponse(status=403)
    user = User.objects.filter(id=target_id).first()
    if not user:
        return HttpResponse(status=404)
    if not user.contract_url:
        return HttpResponse("Contrat pas encore signe par ce client.", status=404)

    from fpdf import FPDF

    def latin1_safe(s):
        # ponytail: la police core "Helvetica" de fpdf2 n'accepte que le
        # latin-1 strict -- un tiret cadratin "—" (present dans le .txt du
        # contrat, et que l'admin peut retaper en l'editant) plante tout le
        # rendu (FPDFUnicodeEncodingException, jamais latin-1). On degrade
        # proprement au lieu de planter ; passer a une police unicode
        # (DejaVu, .add_font) si des caracteres non-latins deviennent requis.
        return (s or "").encode("latin-1", errors="replace").decode("latin-1")

    try:
        with open(CONTRACT_PATH, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        text = "Contrat indisponible pour le moment."
    text = latin1_safe(text)

    pdf = FPDF(format="A4", unit="mm")
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 14)
    pdf.multi_cell(0, 8, "CONTRAT D'OUVERTURE DE COMPTE TITRES - SGI BRVM", align="C")
    pdf.ln(4)
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(0, 5.5, text)
    pdf.ln(8)
    pdf.set_font("Helvetica", "B", 10)
    pdf.cell(0, 6, latin1_safe(f"Client : {user.name} ({user.email})"), ln=True)
    if user.whatsapp:
        pdf.cell(0, 6, latin1_safe(f"WhatsApp : {user.whatsapp}"), ln=True)
    pdf.ln(4)
    pdf.set_font("Helvetica", "B", 10)
    pdf.cell(0, 6, "Signature electronique :", ln=True)
    sig_path = os.path.join(UPLOAD_DIR, os.path.basename(user.contract_url))
    if os.path.exists(sig_path):
        try:
            pdf.image(sig_path, w=60)
        except Exception:  # noqa: BLE001 - fichier non-image (ancien format .txt) : on l'omet, pas de 500
            pass
    pdf.set_font("Helvetica", "I", 8)
    pdf.cell(0, 6, latin1_safe(user.signature_status) or "Signe electroniquement.", ln=True)

    resp = HttpResponse(bytes(pdf.output()), content_type="application/pdf")
    resp["Content-Disposition"] = f'attachment; filename="contrat_sgi_brvm_{user.id}.pdf"'
    return resp


DOC_FIELDS = {
    "cni_recto": "cni_recto_url",
    "cniRecto": "cni_recto_url",
    "cni_verso": "cni_verso_url",
    "cniVerso": "cni_verso_url",
    "selfie": "selfie_url",
    "proof_address": "proof_address_url",
    "proofAddress": "proof_address_url",
    "contract": "contract_url",
}


@api_view(["POST"])
@require_auth()
def upload_document(request):
    d = request.data
    doc_type = d.get("docType")
    if not doc_type:
        return Response({"error": "userId et docType sont requis."}, status=400)

    user = User.objects.filter(id=request.session_data["userId"]).first()
    if not user:
        return Response({"error": "Utilisateur introuvable."}, status=404)

    file_name = d.get("fileName") or f"{doc_type}.jpg"
    payload = d.get("fileBase64")
    url = None
    if payload:
        raw = payload.split(",", 1)[-1]  # tolere le prefixe data:image/...;base64,
        try:
            blob = base64.b64decode(raw, validate=True)
        except (binascii.Error, ValueError):
            return Response({"error": "Fichier base64 invalide."}, status=400)
        if len(blob) > 15 * 1024 * 1024:
            return Response({"error": "Fichier trop volumineux (15 Mo maximum)."}, status=413)
        safe = f"{user.id}_{doc_type}_{os.path.basename(file_name)}".replace("/", "_")
        os.makedirs(UPLOAD_DIR, exist_ok=True)
        with open(os.path.join(UPLOAD_DIR, safe), "wb") as fh:
            fh.write(blob)
        url = f"/uploads/{safe}"
        field = DOC_FIELDS.get(doc_type)
        if field:
            setattr(user, field, url)

    docs = dict(user.documents or {})
    docs[doc_type] = {"fileName": file_name, "uploadedAt": now_iso(), "status": "uploaded", "url": url}
    user.documents = docs

    # Statuts lisibles pour l'admin (UserManagementView les affiche deja) :
    # deduits de la presence des URLs, pas d'un champ separe a maintenir.
    # ponytail: colonnes CharField(max_length=30) en Postgres -- un texte
    # plus long declenchait "value too long" (500) a l'ecriture, invisible
    # sur SQLite en local qui n'impose pas la limite. Rester <30 caracteres.
    if user.cni_recto_url and user.cni_verso_url:
        user.identity_doc_status = "Reçu - à vérifier"
    if user.proof_address_url:
        user.proof_of_address_status = "Reçu - à vérifier"
    if user.contract_url:
        user.signature_status = f"Signé le {now_iso()[:10]}"
    # Un dossier rejete qui reenvoie une piece redevient "pending" : sinon
    # le client reste verrouille sans jamais repasser devant l'admin.
    if user.kyc == "suspended":
        user.kyc = "pending"

    user.save()
    return Response({"success": True, "message": f'Document "{doc_type}" reçu avec succès.', "user": user.as_dict()})


# ── Chat & support ──────────────────────────────────────────────────────


def push_message(user, sender, text, user_name=None):
    return Message.objects.create(
        id=f"MSG-{uuid.uuid4().hex[:12]}",
        user=user,
        user_name=user_name or user.name or "Client",
        sender=sender,
        text=(text or "").strip(),
        time=dt.datetime.now().strftime("%H:%M"),
    )


@api_view(["GET", "POST"])
@require_auth()
def my_chat(request):
    user = User.objects.filter(id=request.session_data["userId"]).first()
    if not user:
        return Response({"error": "Utilisateur introuvable."}, status=404)
    if request.method == "GET":
        return Response({"success": True, "data": [m.as_dict() for m in user.messages.all()]})
    msg = push_message(user, "client", request.data.get("text"), request.session_data.get("name"))
    return Response({"success": True, "data": msg.as_dict()}, status=201)


@api_view(["GET", "POST"])
@require_auth(admin=True)
def admin_chat(request, user_id):
    user = User.objects.filter(id=user_id).first()
    if not user:
        return Response({"error": "Utilisateur introuvable."}, status=404)
    if request.method == "GET":
        return Response({"success": True, "data": [m.as_dict() for m in user.messages.all()]})
    msg = push_message(user, request.data.get("sender") or "ADMIN", request.data.get("text"))
    return Response({"success": True, "data": msg.as_dict()}, status=201)


@api_view(["POST"])
@require_auth()
def support(request):
    sess = request.session_data
    ticket = Ticket.objects.create(
        id=f"TKT-{uuid.uuid4().hex[:8]}",
        client_name=sess.get("name") or "",
        client_id=sess.get("email") or "",
        subject=request.data.get("subject") or "Assistance",
        message=request.data.get("message") or "",
        status="OUVERT",
        date_string=dt.datetime.now().strftime("%d/%m/%Y, %H:%M"),
    )
    return Response({"success": True, "data": ticket.as_dict()}, status=201)


@api_view(["GET"])
@require_auth(admin=True)
def admin_support(request):
    rows = [t.as_dict() for t in Ticket.objects.all()]
    return Response({"success": True, "count": len(rows), "data": rows})


# ── Stocks ──────────────────────────────────────────────────────────────


@api_view(["GET"])
def stock_list(request):
    data = brvm.stocks()
    return Response({"success": True, "count": len(data), "data": data})


@api_view(["GET"])
def stock_detail(request, ticker):
    stock = brvm.find(ticker)
    if not stock:
        return Response({"error": "Titre introuvable."}, status=404)
    return Response({"success": True, "data": stock})


# ── Transactions ────────────────────────────────────────────────────────


@api_view(["GET", "POST"])
@require_auth()
def transactions(request):
    sess = request.session_data
    if request.method == "GET":
        qs = Transaction.objects.all()
        if sess.get("role") != "admin":
            qs = qs.filter(user_id=sess["userId"])
        rows = [t.as_dict() for t in qs]
        return Response({"success": True, "count": len(rows), "data": rows})
    return create_transaction(request, sess)


@api_view(["GET"])
@require_auth(admin=True)
def transactions_all(request):
    rows = [t.as_dict() for t in Transaction.objects.all()]
    return Response({"success": True, "count": len(rows), "data": rows})


def _owned_quantity(user, ticker):
    """Titres reellement disponibles a la vente : achats valides moins ventes
    deja validees ou en attente (meme logique que le gel de solde a l'achat,
    cf. create_transaction/BUY : empeche de vendre deux fois les memes titres
    via deux ordres "pending" simultanes)."""
    bought = Transaction.objects.filter(
        user=user, ticker=ticker, type="BUY", status="validated"
    ).aggregate(s=Sum("quantity"))["s"] or 0
    reserved = Transaction.objects.filter(
        user=user, ticker=ticker, type="SELL", status__in=("validated", "pending")
    ).aggregate(s=Sum("quantity"))["s"] or 0
    return bought - reserved


def create_transaction(request, sess):
    d = request.data
    kind = (d.get("type") or "BUY").upper()
    try:
        qty = int(d.get("quantity") or 1)
        price = money(d.get("price") or 0)
    except (TypeError, ValueError, InvalidOperation):
        # InvalidOperation : money() passe par Decimal, qui leve ca (et pas
        # ValueError) sur une chaine non numerique.
        return Response({"error": "Quantité et prix doivent être numériques."}, status=400)
    if qty <= 0 or price < 0:
        return Response({"error": "Quantité et prix doivent être positifs."}, status=400)

    # ponytail: un admin peut creer une operation POUR un client (modale
    # "Nouvelle Operation" du portail). Sans ce champ, sess["userId"] etait
    # toujours l'admin lui-meme : toute operation saisie par l'admin
    # atterrissait sur SON compte, jamais sur celui du client vise.
    # Reserve aux admins : un client ne peut pas cibler un autre compte.
    for_client = sess.get("role") == "admin" and d.get("userId")
    user = User.objects.filter(id=d["userId"] if for_client else sess["userId"]).first()
    if not user:
        return Response({"error": "Utilisateur introuvable."}, status=404)
    if user.kyc != "verified":
        return Response(
            {"error": "Compte verrouille : dossier KYC et contrat SGI a valider avant toute operation."},
            status=403,
        )

    if kind in ("DEPOSIT", "RECHARGE"):
        # Paiement reel via Jeko (voir jeko.py) : plus de credit instantane
        # non verifie. L'appel reseau se fait hors transaction DB (pas de
        # verrou sur `user` pendant la requete HTTP sortante). Le solde n'est
        # credite qu'a la confirmation du paiement (voir jeko_webhook et
        # _credit_deposit, partages avec la validation manuelle admin).
        amount = money(price)
        if amount < 100:
            # ponytail: minimum Jeko = 100 FCFA (amountCents >= 10000, voir
            # jeko.py). En dessous, leur API renvoie un message d'erreur casse
            # ("must be at least undefined") -- autant bloquer ici avec un
            # message clair plutot que de laisser deviner.
            return Response({"error": "Le montant minimum pour un dépôt est de 100 FCFA."}, status=400)
        if for_client:
            # ponytail: recharge saisie par l'admin pour un client (especes,
            # virement recu hors Jeko...). Rien a payer en ligne : on credite
            # directement au lieu de renvoyer un lien Jeko que personne
            # n'ouvrira. Trace par processed_by = l'admin qui l'a saisie.
            with db_transaction.atomic():
                tx = Transaction.objects.create(
                    id=str(uuid.uuid4()),
                    user=user,
                    user_email=user.email,
                    user_name=user.name,
                    ticker="CASH",
                    company="Recharge manuelle (admin)",
                    type="DEPOSIT",
                    quantity=1,
                    price=amount,
                    total=amount,
                    fees=0,
                    tva=0,
                    grand_total=amount,
                    status="validated",
                    payment_ref=f"ADMIN-{uuid.uuid4().hex[:8]}",
                    payment_method=d.get("paymentMethod") or "Recharge manuelle",
                    submitted_at=now_iso(),
                    processed_at=now_iso(),
                    processed_by=sess["userId"],
                )
                _credit_deposit(tx)
            return Response({"success": True, "data": tx.as_dict()}, status=201)
        if not settings.JEKO_API_KEY:
            # ponytail: aucune cle Jeko configuree (dev local sans .env.docker
            # rempli, ou CI -- voir .github/workflows/build.yml) -> repli sur
            # le credit simule d'avant l'integration Jeko, pour que le reste
            # de l'app (achat/vente, tests) reste utilisable sans compte Jeko.
            # Ne se declenche jamais en prod : JEKO_API_KEY y est toujours
            # renseigne (voir .env.docker).
            tx = Transaction.objects.create(
                id=str(uuid.uuid4()),
                user=user,
                user_email=d.get("userEmail") or user.email,
                user_name=d.get("userName") or user.name,
                ticker="CASH",
                company="Dépôt (simulé — Jeko non configuré)",
                type="DEPOSIT",
                quantity=1,
                price=amount,
                total=amount,
                fees=0,
                tva=0,
                grand_total=amount,
                status="validated",
                payment_ref=f"SIM-{uuid.uuid4().hex[:8]}",
                payment_method="Simulé (dev)",
                submitted_at=now_iso(),
                processed_at=now_iso(),
                processed_by="SYSTEM",
            )
            user.balance = money(user.balance + amount)
            user.save()
            return Response({"success": True, "data": tx.as_dict()}, status=201)
        try:
            link = jeko.create_payment_link(f"Depot BAOU - {user.name} - {int(amount)} FCFA", amount)
            payment_ref, payment_url, payment_method = link["id"], link["link"], "Jeko"
        except jeko.JekoError as e:
            # ponytail: print (pas logging) -> visible dans `docker compose
            # logs backend` meme sans LOGGING configure / DEBUG=0. Seule facon
            # de savoir POURQUOI ca retombe sur le lien fixe (403 API pas
            # activee, storeId invalide, timeout reseau, etc.) sans deviner.
            print(f"[jeko] create_payment_link a echoue, repli lien fixe : {e}", flush=True)
            # ponytail: compte Jeko pas encore active pour l'API (403
            # business_not_enabled_for_api_access) -> repli sur le lien fixe
            # du Cockpit (JEKO_FALLBACK_LINK). payment_ref prefixe MANUAL- :
            # jeko_webhook credite quand meme automatiquement, en associant
            # par montant (voir jeko_webhook) au lieu de payment_ref exact --
            # plus besoin de validation admin. A retirer une fois l'API
            # activee cote Jeko : la creation de lien dynamique ci-dessus
            # reprendra automatiquement, avec correlation exacte par lien.
            payment_ref = f"MANUAL-{uuid.uuid4().hex[:8]}"
            payment_url = settings.JEKO_FALLBACK_LINK
            payment_method = "Jeko (lien partagé)"
        tx = Transaction.objects.create(
            id=str(uuid.uuid4()),
            user=user,
            user_email=d.get("userEmail") or user.email,
            user_name=d.get("userName") or user.name,
            ticker="CASH",
            company="Dépôt Jeko",
            type="DEPOSIT",
            quantity=1,
            price=amount,
            total=amount,
            fees=0,
            tva=0,
            grand_total=amount,
            status="pending",
            payment_ref=payment_ref,
            payment_method=payment_method,
            submitted_at=now_iso(),
        )
        return Response({"success": True, "data": tx.as_dict(), "paymentUrl": payment_url}, status=201)

    # select_for_update : deux ordres simultanes ne doivent pas ecraser
    # le meme solde (le store Node en memoire avait ce trou).
    with db_transaction.atomic():
        user = User.objects.select_for_update().filter(id=user.id).first()

        stock = brvm.find(d.get("ticker"))
        if not stock:
            return Response({"error": f"Titre \"{d.get('ticker')}\" introuvable."}, status=404)

        total = qty * price
        fees = total * FEE_RATE
        tva = fees * TVA_RATE
        grand_total = total + fees + tva

        if kind == "BUY" and user.balance < grand_total:
            return Response(
                {"error": f"Solde insuffisant ({user.balance} FCFA dispo, {grand_total:.0f} FCFA requis)."},
                status=400,
            )
        if kind == "SELL":
            owned = _owned_quantity(user, stock["ticker"])
            if qty > owned:
                return Response(
                    {"error": f"Vous ne détenez que {owned} titre(s) {stock['ticker']}."},
                    status=400,
                )
            # Frais preleves a la vente comme a l'achat : le montant credite
            # au solde (a la validation, cf. validate_transaction) est le net.
            net = money(total - fees - tva)
        else:
            net = money(total)

        tx = Transaction.objects.create(
            id=str(uuid.uuid4()),
            user=user,
            user_email=d.get("userEmail") or user.email,
            user_name=d.get("userName") or user.name,
            ticker=stock["ticker"],
            company=stock["company"],
            type=kind,
            quantity=qty,
            price=price,
            total=net,
            fees=money(fees),
            tva=money(tva),
            grand_total=money(grand_total) if kind != "SELL" else net,
            status="pending",
            payment_ref=d.get("paymentRef") or f"AUTO-{uuid.uuid4().hex[:8]}",
            payment_method=d.get("paymentMethod") or "Non spécifié",
            submitted_at=now_iso(),
        )

        if kind == "BUY":
            # Gele le montant des la creation de l'ordre : sinon deux ordres
            # "pending" successifs pouvaient chacun passer le test de solde
            # ci-dessus et depasser ensemble le solde reel avant validation
            # admin. Rembourse en cas de rejet (voir reject_transaction).
            user.balance = money(user.balance - grand_total)
            user.save()
    return Response({"success": True, "data": tx.as_dict()}, status=201)


def _credit_deposit(tx):
    """Credite le solde pour un DEPOSIT/SELL/DIVIDEND valide -- partage entre
    la validation manuelle admin (validate_transaction) et la confirmation
    automatique par webhook Jeko (jeko_webhook). BUY est deja debite/gele a
    la creation (voir create_transaction) : rien a refaire ici. Appeler dans
    un bloc `db_transaction.atomic()` avec `tx` deja verrouille (select_for_update)."""
    if tx.type == "BUY":
        return
    user = User.objects.select_for_update().filter(id=tx.user_id).first()
    if user:
        user.balance = max(Decimal(0), money(user.balance + tx.total))
        user.save()


@api_view(["PATCH"])
@require_auth(admin=True)
def validate_transaction(request, tx_id):
    with db_transaction.atomic():
        tx = Transaction.objects.select_for_update().filter(id=tx_id).first()
        if not tx:
            return Response({"error": "Transaction introuvable."}, status=404)
        if tx.status != "pending":
            return Response({"error": f'Transaction déjà "{tx.status}".'}, status=400)

        tx.status = "validated"
        tx.processed_at = now_iso()
        tx.processed_by = request.session_data.get("userId") or "ADMIN"
        tx.save()
        _credit_deposit(tx)
    return Response({"success": True, "data": tx.as_dict()})


@api_view(["POST"])
def jeko_webhook(request):
    """Webhook JEKO (`transaction.completed`) : credite le depot des que le
    paiement est confirme cote Jeko. Voir
    https://developer.jeko.africa/fr/integration/webhooks/integration

    Pas de @require_auth : appele par les serveurs Jeko (pas de session/JWT),
    authentifie par la signature HMAC (en-tete Jeko-Signature) a la place.
    Repond toujours 200 sauf signature invalide, pour eviter les retries
    Jeko sur des evenements deja traites ou qui ne nous concernent pas."""
    raw = request.body
    # ponytail: log d'entree systematique -- seule facon de distinguer "Jeko
    # n'appelle jamais notre URL" (rien dans les logs = mauvaise config
    # Cockpit) de "Jeko appelle mais on rejette/ne matche pas" (code a
    # corriger).
    print(f"[jeko webhook] recu, {len(raw)} octets", flush=True)
    if not jeko.verify_signature(raw, request.headers.get("Jeko-Signature", "")):
        print("[jeko webhook] signature invalide", flush=True)
        return Response({"error": "Signature invalide."}, status=401)
    try:
        payload = json.loads(raw)
    except ValueError:
        return Response({"error": "JSON invalide."}, status=400)

    # ponytail: la doc prose Jeko dit transactionType == "payment", le schema
    # OpenAPI (source de verite, cf. /partner_api/stores) montre
    # "PaymentRequest" dans les 3 exemples de payload (redirect/soundbox/lien
    # de paiement) -- les deux etaient acceptes ici tant que ca ne credite
    # jamais rien de faux (status doit quand meme etre "success").
    if payload.get("status") != "success" or payload.get("transactionType") not in ("PaymentRequest", "payment"):
        print(f"[jeko] webhook ignore (status={payload.get('status')!r}, "
              f"transactionType={payload.get('transactionType')!r})", flush=True)
        return Response({"success": True})

    link_id = (payload.get("transactionDetails") or {}).get("paymentLinkId")
    # Jeko envoie des centimes (entier). Division en Decimal, pas en float :
    # le montant sert de cle de rapprochement avec un DecimalField
    # (total=amount_xof plus bas), une erreur d'arrondi ne matcherait rien.
    amount_xof = money(Decimal(str((payload.get("amount") or {}).get("amount", 0))) / 100)

    with db_transaction.atomic():
        # status="pending" dans le filtre = idempotence : un webhook rejoue
        # (retry Jeko) ne trouve plus rien a crediter la deuxieme fois.
        tx = None
        if link_id:
            tx = Transaction.objects.select_for_update().filter(
                payment_ref=link_id, type="DEPOSIT", status="pending"
            ).first()
        if not tx and amount_xof:
            # ponytail: lien de secours partage (compte Jeko pas encore
            # active pour l'API, voir create_transaction) -> pas de
            # paymentLinkId par depot. Repli : on associe au plus ancien
            # depot MANUAL- en attente du meme montant, plus d'admin requis.
            # Ceiling : deux depots identiques + simultanes peuvent se
            # confondre. Repasse en correlation exacte par lien des que
            # l'API Jeko est activee (le match payment_ref ci-dessus prend
            # le dessus automatiquement).
            tx = Transaction.objects.select_for_update().filter(
                type="DEPOSIT", status="pending", payment_ref__startswith="MANUAL-", total=amount_xof,
            ).order_by("submitted_at").first()
        if not tx:
            print(f"[jeko webhook] aucun depot en attente ne correspond "
                  f"(link_id={link_id!r}, amount_xof={amount_xof!r})", flush=True)
            return Response({"success": True})
        tx.status = "validated"
        tx.processed_at = now_iso()
        tx.processed_by = "JEKO_WEBHOOK"
        tx.save()
        _credit_deposit(tx)
        print(f"[jeko webhook] depot {tx.id} credite ({tx.total} FCFA)", flush=True)
    return Response({"success": True})


@api_view(["PATCH"])
@require_auth(admin=True)
def reject_transaction(request, tx_id):
    with db_transaction.atomic():
        tx = Transaction.objects.select_for_update().filter(id=tx_id).first()
        if not tx:
            return Response({"error": "Transaction introuvable."}, status=404)
        if tx.status != "pending":
            return Response({"error": f'Transaction déjà "{tx.status}".'}, status=400)

        tx.status = "rejected"
        tx.rejection_reason = request.data.get("reason") or "Rejeté par l'administrateur."
        tx.processed_at = now_iso()
        tx.save()

        if tx.type == "BUY":
            # Rembourse le montant gele a la creation de l'ordre.
            user = User.objects.select_for_update().filter(id=tx.user_id).first()
            if user:
                user.balance = money(user.balance + tx.grand_total)
                user.save()
    return Response({"success": True, "data": tx.as_dict()})


# ── Admin ───────────────────────────────────────────────────────────────


@api_view(["GET"])
@require_auth(admin=True)
def admin_stats(request):
    clients = User.objects.filter(role="client")
    return Response({
        "success": True,
        "data": {
            **ADMIN_STATS,
            "totalUsers": clients.count(),
            "kycVerified": clients.filter(kyc="verified").count(),
            "kycPending": clients.filter(kyc="pending").count(),
            "suspended": clients.filter(kyc="suspended").count(),
        },
    })


@api_view(["GET"])
@require_auth(admin=True)
def admin_users(request):
    rows = [u.as_dict() for u in User.objects.filter(role="client")]
    return Response({"success": True, "count": len(rows), "data": rows})


@api_view(["PATCH"])
@require_auth(admin=True)
def admin_user_suspend(request, user_id):
    """Bascule suspendu / non suspendu. Un compte reactive repasse par
    'pending' : la validation KYC doit etre refaite explicitement."""
    user = User.objects.filter(id=user_id).first()
    if not user:
        return Response({"error": "Utilisateur introuvable."}, status=404)
    user.kyc = "pending" if user.kyc == "suspended" else "suspended"
    user.save()
    return Response({"success": True, "data": {"id": user.id, "name": user.name, "kyc": user.kyc}})


@api_view(["PATCH"])
@require_auth(admin=True)
def admin_ticket_status(request, ticket_id):
    ticket = Ticket.objects.filter(id=ticket_id).first()
    if not ticket:
        return Response({"error": "Ticket introuvable."}, status=404)
    ticket.status = request.data.get("status") or ticket.status
    ticket.save()
    return Response({"success": True, "data": ticket.as_dict()})


@api_view(["PATCH"])
@require_auth(admin=True)
def admin_user_kyc(request, user_id):
    user = User.objects.filter(id=user_id).first()
    if not user:
        return Response({"error": "Utilisateur introuvable."}, status=404)
    status_ = request.data.get("status")
    if status_ not in KYC_STATUSES:
        # ponytail: sans cette garde, n'importe quelle chaine passait. Une
        # faute de frappe ("verifie") verrouillait le client en silence -- le
        # verrou de create_transaction ne s'ouvre que sur "verified" exactement
        # -- et une valeur > 20 caracteres fait planter Postgres (max_length,
        # deja vu sur upload-document, commit 05f739b).
        return Response(
            {"error": f"Statut KYC invalide. Valeurs acceptées : {', '.join(KYC_STATUSES)}."},
            status=400,
        )
    user.kyc = status_
    user.save()
    return Response({"success": True, "data": {"id": user.id, "name": user.name, "kyc": user.kyc}})

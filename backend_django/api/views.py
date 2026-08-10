"""Portage 1:1 de backend/api/server_api.js + backend/core/server_core.js.

Les chemins, les codes HTTP et la forme des JSON sont ceux de la v1.0.4 :
l'app Android et l'admin React ne sont pas modifies.
"""

import base64
import binascii
import datetime as dt
import functools
import os
import uuid

import bcrypt
import jwt
from django.conf import settings
from django.db import transaction as db_transaction
from django.http import HttpResponse
from django.views.static import serve as static_serve
from rest_framework.decorators import api_view
from rest_framework.response import Response

from . import brvm
from .models import Message, Ticket, Transaction, User

JWT_SECRET = settings.JWT_SECRET
UPLOAD_DIR = settings.UPLOAD_DIR

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
    return round(float(x), 2)


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
        balance=0.0,
        joined_at=now_iso(),
    )
    return Response({"success": True, "user": user.as_dict()}, status=201)


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


def create_transaction(request, sess):
    d = request.data
    kind = (d.get("type") or "BUY").upper()
    try:
        qty = int(d.get("quantity") or 1)
        price = float(d.get("price") or 0)
    except (TypeError, ValueError):
        return Response({"error": "Quantité et prix doivent être numériques."}, status=400)
    if qty <= 0 or price < 0:
        return Response({"error": "Quantité et prix doivent être positifs."}, status=400)

    # select_for_update : deux depots simultanes ne doivent pas ecraser
    # le meme solde (le store Node en memoire avait ce trou).
    with db_transaction.atomic():
        user = User.objects.select_for_update().filter(id=sess["userId"]).first()
        if not user:
            return Response({"error": "Utilisateur introuvable."}, status=404)
        if user.kyc != "verified":
            return Response(
                {"error": "Compte verrouille : dossier KYC et contrat SGI a valider avant toute operation."},
                status=403,
            )

        if kind in ("DEPOSIT", "RECHARGE"):
            amount = money(price)
            user.balance = money(user.balance + amount)
            user.save()
            tx = Transaction.objects.create(
                id=str(uuid.uuid4()),
                user=user,
                user_email=d.get("userEmail") or user.email,
                user_name=d.get("userName") or user.name,
                ticker=(d.get("ticker") or "CASH").upper(),
                company=f"Dépôt {d.get('paymentMethod') or 'Wave CI'}",
                type="DEPOSIT",
                quantity=1,
                price=amount,
                total=amount,
                fees=0,
                tva=0,
                grand_total=amount,
                status="validated",
                payment_ref=d.get("paymentRef") or f"REF-{uuid.uuid4().hex[:6].upper()}",
                payment_method=d.get("paymentMethod") or "Wave CI",
                submitted_at=now_iso(),
                processed_at=now_iso(),
                processed_by="SYSTEM",
            )
            return Response({"success": True, "data": tx.as_dict()}, status=201)

        stock = brvm.find(d.get("ticker"))
        if not stock:
            return Response({"error": f"Titre \"{d.get('ticker')}\" introuvable."}, status=404)

        total = qty * price
        fees = total * 0.005
        tva = fees * 0.18
        grand_total = total + fees + tva

        if kind == "BUY" and user.balance < grand_total:
            return Response(
                {"error": f"Solde insuffisant ({user.balance} FCFA dispo, {grand_total:.0f} FCFA requis)."},
                status=400,
            )

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
            total=money(total),
            fees=money(fees),
            tva=money(tva),
            grand_total=money(grand_total),
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

        # BUY : deja debite/gele a la creation (create_transaction), rien a
        # refaire ici. DEPOSIT est deja valide des la creation (jamais
        # "pending"). SELL/DIVIDEND restent credites a la validation.
        if tx.type != "BUY":
            user = User.objects.select_for_update().filter(id=tx.user_id).first()
            if user:
                user.balance = max(0.0, money(user.balance + tx.total))
                user.save()
    return Response({"success": True, "data": tx.as_dict()})


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
    user.kyc = request.data.get("status") or user.kyc
    user.save()
    return Response({"success": True, "data": {"id": user.id, "name": user.name, "kyc": user.kyc}})

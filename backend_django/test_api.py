"""Rejoue le parcours complet contre un backend qui tourne.

    docker compose up -d
    python backend_django/test_api.py           # ou BASE=http://... python ...

Aucune dependance : urllib seulement.
"""

import hashlib
import hmac
import http.client
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit

BASE = os.environ.get("BASE", "http://localhost:3001")
ADMIN = ("admin@elephantbourse.ci", "admin2024")


def _env_docker_value(key):
    """Lit une valeur depuis .env.docker (racine du repo) sans dependance --
    utilise pour simuler un webhook Jeko signe (voir test du depot). Fichier
    absent en CI (gitignore) : renvoie "" plutot que planter, le depot tombe
    alors sur le repli simule cote serveur (voir create_transaction) et cette
    fonction n'est jamais appelee."""
    path = Path(__file__).resolve().parent.parent / ".env.docker"
    if not path.exists():
        return ""
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith(f"{key}="):
            return line.split("=", 1)[1].strip()
    return ""


def call(method, path, body=None, token=None, expect=200):
    req = urllib.request.Request(
        BASE + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={
            "Content-Type": "application/json",
            **({"Authorization": f"Bearer {token}"} if token else {}),
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            status, payload = r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        status, payload = e.code, json.loads(e.read() or b"{}")
    assert status == expect, f"{method} {path} -> {status} (attendu {expect}) : {payload}"
    return payload


def raw_get(path, token=None):
    """GET brut (reponse fichier, pas JSON) -- pour /uploads/... et le PDF."""
    req = urllib.request.Request(
        BASE + path, headers=({"Authorization": f"Bearer {token}"} if token else {}))
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def raw_status(path, token=None):
    return raw_get(path, token=token)[0]


def redirect_target(path):
    """GET sans suivre la redirection -- urllib suit les 302 automatiquement
    et plante sur un scheme custom (baou://), inutilisable ici."""
    u = urlsplit(BASE)
    conn = http.client.HTTPConnection(u.hostname, u.port or 80, timeout=15)
    conn.request("GET", path)
    r = conn.getresponse()
    status, location = r.status, r.getheader("Location")
    r.read()
    conn.close()
    return status, location


def main():
    call("GET", "/health")

    admin_token = call("POST", "/api/auth/login", {"email": ADMIN[0], "password": ADMIN[1]})["token"]
    call("POST", "/api/auth/login", {"email": ADMIN[0], "password": "faux"}, expect=401)

    email = f"test{int(time.time())}@baou.ci"
    user = call("POST", "/api/auth/register",
                {"email": email, "password": "password123", "name": "Test Client"}, expect=201)["user"]
    assert user["balance"] == 0 and user["kyc"] == "pending"
    assert user["emailVerified"] is False, user  # pas encore clique sur le lien recu par email
    call("POST", "/api/auth/register",
         {"email": email, "password": "x", "name": "Doublon"}, expect=409)
    call("POST", "/api/auth/register", {"email": "", "password": "", "name": ""}, expect=400)

    # Lien de confirmation : redirige vers l'app (baou://), jamais un 200 JSON.
    status, location = redirect_target("/api/auth/verify-email?token=nimportequoi")
    assert status == 302 and location == "baou://verify-email?ok=0", (status, location)
    status, location = redirect_target("/api/auth/verify-email")
    assert status == 302 and location == "baou://verify-email?ok=0", (status, location)

    # Mot de passe oublie : meme reponse que le compte existe ou non (anti-enumeration)
    call("POST", "/api/auth/request-password-reset", {"email": email}, expect=200)
    call("POST", "/api/auth/request-password-reset", {"email": "personne@nulle-part.ci"}, expect=200)
    call("POST", "/api/auth/reset-password", {"token": "nimportequoi", "newPassword": "nouveaumdp"}, expect=400)
    call("POST", "/api/auth/reset-password", {"token": "nimportequoi", "newPassword": "abc"}, expect=400)

    token = call("POST", "/api/auth/login", {"email": email, "password": "password123"})["token"]
    call("GET", "/api/admin/users", token=token, expect=403)

    stocks = call("GET", "/api/stocks")["data"]
    # 26 SEED + tickers reels supplementaires lus depuis data/brvm_data/
    # (voir brvm.py) -- pas de nombre fige, le jeu de donnees est mis a jour.
    assert len(stocks) >= 26, len(stocks)
    snts = call("GET", "/api/stocks/SNTS")["data"]
    call("GET", "/api/stocks/ZZZZ", expect=404)

    # ── Verrou KYC : tant que non verifie, aucune operation d'argent ────
    call("POST", "/api/transactions",
         {"type": "DEPOSIT", "price": 1000, "paymentMethod": "Wave CI"},
         token=token, expect=403)
    call("POST", "/api/transactions",
         {"ticker": "SNTS", "type": "BUY", "quantity": 1, "price": snts["price"]},
         token=token, expect=403)

    # Faille corrigee : le client ne peut plus s'auto-valider via son profil.
    call("POST", "/api/auth/update-profile", {"kycStatus": "verified"}, token=token)
    still_pending = call("POST", "/api/auth/profile", {}, token=token)["user"]
    assert still_pending["kyc"] == "pending", still_pending
    call("POST", "/api/transactions",
         {"type": "DEPOSIT", "price": 1000, "paymentMethod": "Wave CI"},
         token=token, expect=403)

    # Documents KYC : upload -> statuts auto-deduits, contrat servi par l'API
    contract_text = call("GET", "/api/contract", token=token)["text"]
    assert "SGI" in contract_text and len(contract_text) > 100
    call("POST", "/api/auth/upload-document",
         {"docType": "cni_recto", "fileName": "recto.jpg", "fileBase64": "aGVsbG8="}, token=token)
    call("POST", "/api/auth/upload-document",
         {"docType": "cni_verso", "fileName": "verso.jpg", "fileBase64": "aGVsbG8="}, token=token)
    call("POST", "/api/auth/upload-document",
         {"docType": "proof_address", "fileName": "facture.jpg", "fileBase64": "aGVsbG8="}, token=token)
    call("POST", "/api/auth/upload-document",
         {"docType": "contract", "fileName": "signature.txt", "fileBase64": "aGVsbG8="}, token=token)
    with_docs = next(u for u in call("GET", "/api/admin/users", token=admin_token)["data"]
                      if u["id"] == user["id"])
    assert with_docs["identityDocStatus"] == "Reçu - à vérifier", with_docs
    assert with_docs["proofOfAddressStatus"] == "Reçu - à vérifier", with_docs
    assert with_docs["signatureStatus"].startswith("Signé le"), with_docs
    assert with_docs["cniRectoUrl"] == f"/uploads/{user['id']}_cni_recto_recto.jpg"

    # PDF du contrat : genere a la demande, telechargeable par le client et par l'admin
    status, body = raw_get("/api/contract/pdf", token=token)
    assert status == 200 and body[:4] == b"%PDF", (status, body[:20])
    status, body = raw_get(f"/api/contract/pdf?userId={user['id']}", token=admin_token)
    assert status == 200 and body[:4] == b"%PDF", (status, body[:20])
    assert raw_status("/api/contract/pdf") == 401  # pas de jeton

    # /uploads/ protege : ni public, ni ouvert a n'importe quel jeton valide
    doc_path = with_docs["cniRectoUrl"]
    assert raw_status(doc_path) == 401, "document KYC lisible sans authentification !"
    assert raw_status(doc_path, token=token) == 200
    assert raw_status(doc_path, token=admin_token) == 200

    # Admin verifie le dossier -> deverrouillage
    verified = call("PATCH", f"/api/admin/users/{user['id']}/kyc", {"status": "verified"}, token=admin_token)["data"]
    assert verified["kyc"] == "verified", verified

    # Depot : deux modes valides selon la config du backend (voir
    # create_transaction) -- "pending" + lien Jeko reel si JEKO_API_KEY est
    # renseigne (.env.docker), "validated" instantane (repli simule) sinon
    # (cas de la CI, qui n'a pas de compte Jeko : voir build.yml).
    dep_res = call("POST", "/api/transactions", {"type": "DEPOSIT", "price": 500000}, token=token, expect=201)
    dep = dep_res["data"]
    if dep["status"] == "pending":
        assert dep_res["paymentUrl"].startswith("https://pay.jeko.africa/"), dep_res

        # Webhook Jeko simule (meme forme que la doc), signe avec le secret de
        # .env.docker -- verifie la signature ET le credit du solde.
        webhook_secret = _env_docker_value("JEKO_WEBHOOK_SECRET")
        assert webhook_secret, "JEKO_WEBHOOK_SECRET absent de .env.docker : impossible de confirmer le depot"
        webhook_body = json.dumps({
            "id": "txn_test", "status": "success", "transactionType": "payment",
            "transactionDetails": {"paymentLinkId": dep["paymentRef"]},
        }).encode()
        signature = hmac.new(webhook_secret.encode(), webhook_body, hashlib.sha256).hexdigest()
        req = urllib.request.Request(
            BASE + "/api/webhooks/jeko", method="POST", data=webhook_body,
            headers={"Content-Type": "application/json", "Jeko-Signature": signature},
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            assert r.status == 200, r.status
        dep = call("GET", "/api/transactions", token=token)["data"][0]
    assert dep["status"] == "validated" and dep["grandTotal"] == 500000, dep

    # Achat sans provision suffisante -> refuse (plus le verrou, le solde)
    call("POST", "/api/transactions",
         {"ticker": "SNTS", "type": "BUY", "quantity": 10_000_000, "price": snts["price"]},
         token=token, expect=400)

    # Achat : frais 0,5 % + TVA 18 % sur les frais, statut pending
    qty, price = 2, 1000.0
    buy = call("POST", "/api/transactions",
               {"ticker": "SNTS", "type": "BUY", "quantity": qty, "price": price},
               token=token, expect=201)["data"]
    assert buy["total"] == 2000.0, buy
    assert buy["fees"] == 10.0, buy
    assert buy["tva"] == 1.8, buy
    assert buy["grandTotal"] == 2011.8, buy
    assert buy["status"] == "pending", buy

    # Validation admin : le solde est debite du grandTotal
    call("PATCH", f"/api/transactions/{buy['id']}/validate", {}, token=admin_token)
    call("PATCH", f"/api/transactions/{buy['id']}/validate", {}, token=admin_token, expect=400)
    me = next(u for u in call("GET", "/api/admin/users", token=admin_token)["data"] if u["id"] == user["id"])
    assert me["balance"] == round(500000 - 2011.8, 2), me["balance"]

    # Rejet
    sell = call("POST", "/api/transactions",
                {"ticker": "SNTS", "type": "SELL", "quantity": 1, "price": price},
                token=token, expect=201)["data"]
    rejected = call("PATCH", f"/api/transactions/{sell['id']}/reject",
                    {"reason": "Test"}, token=admin_token)["data"]
    assert rejected["status"] == "rejected" and rejected["rejectionReason"] == "Test"

    # Vente > titres detenus (2 SNTS valides) -> refuse
    call("POST", "/api/transactions",
         {"ticker": "SNTS", "type": "SELL", "quantity": 999, "price": price},
         token=token, expect=400)

    # Vente valide : frais 0,5 % + TVA 18 % retenus, credit net a la validation
    sell2 = call("POST", "/api/transactions",
                 {"ticker": "SNTS", "type": "SELL", "quantity": qty, "price": price},
                 token=token, expect=201)["data"]
    assert sell2["total"] == round(2000.0 - 10.0 - 1.8, 2), sell2
    call("PATCH", f"/api/transactions/{sell2['id']}/validate", {}, token=admin_token)
    me2 = next(u for u in call("GET", "/api/admin/users", token=admin_token)["data"] if u["id"] == user["id"])
    assert me2["balance"] == round(me["balance"] + 1988.2, 2), me2["balance"]

    # Les titres sont maintenant vendus : impossible de les revendre
    call("POST", "/api/transactions",
         {"ticker": "SNTS", "type": "SELL", "quantity": 1, "price": price},
         token=token, expect=400)

    # Entrees non numeriques : 400, pas 500
    call("POST", "/api/transactions",
         {"ticker": "SNTS", "type": "BUY", "quantity": "beaucoup", "price": 1},
         token=token, expect=400)
    call("POST", "/api/transactions",
         {"ticker": "SNTS", "type": "BUY", "quantity": -5, "price": 1},
         token=token, expect=400)

    # Cloisonnement : le client ne voit que ses transactions
    mine = call("GET", "/api/transactions", token=token)["data"]
    assert {t["userId"] for t in mine} == {user["id"]}, "fuite de transactions entre comptes"

    # Chat bidirectionnel
    call("POST", "/api/auth/chat", {"text": "Bonjour"}, token=token, expect=201)
    call("POST", f"/api/admin/chat/{user['id']}", {"text": "Bonjour, ici l'admin"},
         token=admin_token, expect=201)
    thread = call("GET", "/api/auth/chat", token=token)["data"]
    assert [m["sender"] for m in thread] == ["client", "ADMIN"], thread

    # Support, KYC, profil, upload
    ticket = call("POST", "/api/auth/support", {"subject": "Aide", "message": "Test"},
                  token=token, expect=201)["data"]
    assert any(t["subject"] == "Aide" for t in call("GET", "/api/admin/support", token=admin_token)["data"])
    closed = call("PATCH", f"/api/admin/support/{ticket['id']}/status",
                  {"status": "FERME"}, token=admin_token)["data"]
    assert closed["status"] == "FERME", closed

    # Suspension : bascule, verrouille de nouveau, et la reactivation
    # repasse par "pending" (pas "verified") -- toujours verrouille.
    assert call("PATCH", f"/api/admin/users/{user['id']}/suspend", {},
                token=admin_token)["data"]["kyc"] == "suspended"
    call("POST", "/api/transactions",
         {"type": "DEPOSIT", "price": 1000, "paymentMethod": "Wave CI"},
         token=token, expect=403)
    assert call("PATCH", f"/api/admin/users/{user['id']}/suspend", {},
                token=admin_token)["data"]["kyc"] == "pending"
    call("POST", "/api/transactions",
         {"type": "DEPOSIT", "price": 1000, "paymentMethod": "Wave CI"},
         token=token, expect=403)

    call("PATCH", f"/api/admin/users/{user['id']}/kyc", {"status": "verified"}, token=admin_token)
    call("POST", "/api/auth/update-profile", {"whatsapp": "+2250700000000"}, token=token)
    call("POST", "/api/auth/upload-document",
         {"docType": "selfie", "fileName": "s.png", "fileBase64": "aGVsbG8="}, token=token)
    call("POST", "/api/auth/upload-document",
         {"docType": "selfie", "fileName": "s.png", "fileBase64": "pas du base64 !!"},
         token=token, expect=400)

    updated = next(u for u in call("GET", "/api/admin/users", token=admin_token)["data"]
                   if u["id"] == user["id"])
    assert updated["kyc"] == "verified" and updated["whatsapp"] == "+2250700000000"
    assert updated["identityDocStatus"] == "Reçu - à vérifier", updated["identityDocStatus"]
    assert updated["selfieUrl"] == f"/uploads/{user['id']}_selfie_s.png", updated["selfieUrl"]

    # Jeton absent ou bidon
    call("GET", "/api/transactions", expect=401)
    call("GET", "/api/transactions", token="nimportequoi", expect=401)

    # Statut KYC invalide refuse (avant : n'importe quelle chaine passait, une
    # faute de frappe verrouillait le client en silence et un statut trop long
    # faisait planter Postgres).
    call("PATCH", f"/api/admin/users/{user['id']}/kyc", {"status": "verifie"},
         token=admin_token, expect=400)
    call("PATCH", f"/api/admin/users/{user['id']}/kyc", {"status": "x" * 40},
         token=admin_token, expect=400)
    assert next(u for u in call("GET", "/api/admin/users", token=admin_token)["data"]
                if u["id"] == user["id"])["kyc"] == "verified", "statut KYC ecrase par une valeur invalide"

    # Recharge admin : l'operation doit atterrir sur le compte du CLIENT vise,
    # pas sur celui de l'admin connecte (le champ userId etait ignore).
    before = next(u for u in call("GET", "/api/admin/users", token=admin_token)["data"]
                  if u["id"] == user["id"])["balance"]
    recharge = call("POST", "/api/transactions",
                    {"userId": user["id"], "type": "DEPOSIT", "price": 5000},
                    token=admin_token, expect=201)["data"]
    assert recharge["userId"] == user["id"], recharge
    assert recharge["status"] == "validated", recharge
    after = next(u for u in call("GET", "/api/admin/users", token=admin_token)["data"]
                 if u["id"] == user["id"])["balance"]
    assert after == round(before + 5000, 2), (before, after)

    # ...mais un client ne peut pas se faire passer pour un autre compte.
    usurpe = call("POST", "/api/transactions",
                  {"userId": "CLI-nimportequoi", "type": "BUY", "ticker": "SNTS",
                   "quantity": 1, "price": 100},
                  token=token, expect=201)["data"]
    assert usurpe["userId"] == user["id"], "un client a pu cibler un autre compte !"

    print("OK — parcours complet valide")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print(f"ECHEC : {e}")
        sys.exit(1)

"""Rejoue le parcours complet contre un backend qui tourne.

    docker compose up -d
    python backend_django/test_api.py           # ou BASE=http://... python ...

Aucune dependance : urllib seulement.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = os.environ.get("BASE", "http://localhost:3001")
ADMIN = ("admin@elephantbourse.ci", "admin2024")


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


def main():
    call("GET", "/health")

    admin_token = call("POST", "/api/auth/login", {"email": ADMIN[0], "password": ADMIN[1]})["token"]
    call("POST", "/api/auth/login", {"email": ADMIN[0], "password": "faux"}, expect=401)

    email = f"test{int(time.time())}@baou.ci"
    user = call("POST", "/api/auth/register",
                {"email": email, "password": "password123", "name": "Test Client"}, expect=201)["user"]
    assert user["balance"] == 0 and user["kyc"] == "pending"
    call("POST", "/api/auth/register",
         {"email": email, "password": "x", "name": "Doublon"}, expect=409)
    call("POST", "/api/auth/register", {"email": "", "password": "", "name": ""}, expect=400)

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
    assert with_docs["identityDocStatus"] == "Reçu, en attente de vérification", with_docs
    assert with_docs["proofOfAddressStatus"] == "Reçu, en attente de vérification", with_docs
    assert with_docs["signatureStatus"].startswith("Signé électroniquement"), with_docs
    assert with_docs["cniRectoUrl"] == f"/uploads/{user['id']}_cni_recto_recto.jpg"

    # Admin verifie le dossier -> deverrouillage
    verified = call("PATCH", f"/api/admin/users/{user['id']}/kyc", {"status": "verified"}, token=admin_token)["data"]
    assert verified["kyc"] == "verified", verified

    # Depot : credite immediatement, statut validated
    dep = call("POST", "/api/transactions",
               {"type": "DEPOSIT", "price": 500000, "paymentMethod": "Wave CI"},
               token=token, expect=201)["data"]
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
    assert updated["identityDocStatus"] == "Reçu, en attente de vérification", updated["identityDocStatus"]
    assert updated["selfieUrl"] == f"/uploads/{user['id']}_selfie_s.png", updated["selfieUrl"]

    # Jeton absent ou bidon
    call("GET", "/api/transactions", expect=401)
    call("GET", "/api/transactions", token="nimportequoi", expect=401)

    print("OK — parcours complet valide")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print(f"ECHEC : {e}")
        sys.exit(1)

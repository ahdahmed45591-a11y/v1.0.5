"""Verifie les garde-fous des operations d'argent : idempotence et quota
par compte. Pur Python, ni serveur ni base de donnees.

    python backend_django/test_payment_guards.py

Les deux mecanismes protegent le meme accident : le client tape deux fois,
ou le reseau mobile coupe avant la reponse et l'app rejoue. Sans eux, deux
ordres sont crees et le montant est gele deux fois.

Ce test verifie le CABLAGE (le calcul est delegue a Postgres et a DRF, deja
testes chez eux) : que la contrainte unique existe, que le code sait
repondre a la course perdue, et que le quota compte par compte et pas par IP.
"""

import re
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
VIEWS = (BASE / "api" / "views.py").read_text(encoding="utf-8")
MODELS = (BASE / "api" / "models.py").read_text(encoding="utf-8")
SETTINGS = (BASE / "config" / "settings.py").read_text(encoding="utf-8")
MIGRATIONS = "\n".join(
    p.read_text(encoding="utf-8") for p in (BASE / "api" / "migrations").glob("*.py")
)


def block(src, header):
    """Corps d'une classe / d'un bloc, jusqu'a la prochaine definition de
    premier niveau. Evite les fenetres de N caracteres arbitraires, qui
    coupent au milieu et font echouer le test pour un code correct."""
    start = src.index(header)
    rest = src[start + len(header):]
    end = re.search(r"\n(?:class |def |@)", rest)
    return rest[: end.start()] if end else rest


def test_idempotency_constraint_exists():
    """Le SELECT dans la vue ne suffit pas : deux requetes simultanees le
    passent toutes les deux. Seule la contrainte en base tranche."""
    assert "uniq_tx_idempotency_per_user" in MODELS, \
        "contrainte d'idempotence absente du modele"
    assert "uniq_tx_idempotency_per_user" in MIGRATIONS, \
        "contrainte declaree dans le modele mais jamais migree : elle n'existe pas en base"
    assert "idempotency_key__isnull" in MODELS, (
        "la contrainte doit etre partielle (condition sur NULL) : sinon deux "
        "ordres sans cle du meme client se bloquent entre eux"
    )


def test_integrity_error_is_handled():
    """La course perdue doit renvoyer l'ordre du gagnant, pas une 500."""
    assert "except IntegrityError" in VIEWS, \
        "IntegrityError non rattrape : le perdant de la course recoit une 500"
    body = block(VIEWS, "except IntegrityError")
    assert "replayed" in body, \
        "la reponse de rejeu doit etre identifiable par le client (champ replayed)"


def test_payment_quota_is_per_account():
    """Par IP serait faux : le NAT operateur fait partager une IP a des
    milliers de clients mobiles."""
    assert "class PaymentThrottle" in VIEWS, "PaymentThrottle absent"
    body = block(VIEWS, "class PaymentThrottle")
    assert "session_of(request)" in body, \
        "le quota doit etre calcule par compte (session), pas seulement par IP"
    assert '"payments"' in SETTINGS, \
        "taux 'payments' absent de DEFAULT_THROTTLE_RATES : le scope ne s'applique pas"


def test_read_is_not_throttled_as_payment():
    body = block(VIEWS, "class PaymentThrottle")
    assert 'request.method != "POST"' in body, (
        "la consultation (GET) ne doit pas consommer le quota de paiement, "
        "sinon le rafraichissement d'ecran bloque le client"
    )


def test_payment_view_is_protected():
    m = re.search(r"@throttle_classes\(\[PaymentThrottle\]\)\s*\n@require_auth\(\)\s*\ndef transactions", VIEWS)
    assert m, "la vue transactions() ne porte pas PaymentThrottle"


def main():
    test_idempotency_constraint_exists()
    test_integrity_error_is_handled()
    test_payment_quota_is_per_account()
    test_read_is_not_throttled_as_payment()
    test_payment_view_is_protected()
    print("OK — idempotence garantie en base, quota paiement par compte, lecture non penalisee")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print(f"ECHEC : {e}")
        sys.exit(1)

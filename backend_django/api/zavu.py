"""Client HTTP minimal pour l'API Zavu (notifications WhatsApp/SMS clients).

Doc : https://docs.zavu.dev/quickstart

ponytail: stdlib (urllib), meme pattern que jeko.py -- un POST Bearer ne
justifie pas la dependance au SDK zavudev. Contrairement a jeko.py, send()
ne leve jamais : une notification client ne doit jamais faire echouer
l'operation (validation d'ordre, KYC, depot...) qui la declenche, meme
principe que send_mail dans views.py.
"""

import json
import re
import urllib.error
import urllib.request

from django.conf import settings

API_BASE = "https://api.zavu.dev/v1"


def _to_e164(local_number):
    """Numero local ivoirien ('07 00 00 00 00') -> E.164 ('+2250700000000').
    Meme regle que openWhatsApp() cote Flutter (lib/screens/common.dart)."""
    digits = re.sub(r"[^0-9]", "", local_number or "")
    if digits.startswith("0"):
        digits = digits[1:]
    return f"+225{digits}" if digits else ""


def send(local_number, text):
    if not settings.ZAVU_API_KEY:
        return
    to = _to_e164(local_number)
    if not to:
        return
    req = urllib.request.Request(
        f"{API_BASE}/messages",
        data=json.dumps({"to": to, "text": text}).encode(),
        headers={
            "Authorization": f"Bearer {settings.ZAVU_API_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        urllib.request.urlopen(req, timeout=10)
    except (urllib.error.HTTPError, urllib.error.URLError):
        pass

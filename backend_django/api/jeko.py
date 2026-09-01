"""Client HTTP minimal pour l'API JEKO (paiements en ligne / depots).

Doc : https://developer.jeko.africa/fr/integration/payments/online-payment
      https://developer.jeko.africa/fr/integration/webhooks/integration

ponytail: stdlib (urllib) plutot que `requests` -- une lib externe pour
quelques appels JSON n'aurait ajoute qu'une ligne a requirements.txt et un
rebuild d'image pour rien.
"""

import hashlib
import hmac
import json
import urllib.error
import urllib.request

from django.conf import settings

API_BASE = "https://api.jeko.africa/partner_api"


class JekoError(Exception):
    pass


def _headers():
    return {
        "X-API-KEY": settings.JEKO_API_KEY,
        "X-API-KEY-ID": settings.JEKO_API_KEY_ID,
        "Content-Type": "application/json",
    }


def _request(method, path, payload=None):
    req = urllib.request.Request(
        f"{API_BASE}{path}",
        data=json.dumps(payload).encode() if payload is not None else None,
        headers=_headers(),
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        # ponytail: payload envoye inclus dans l'erreur -- Jeko renvoie parfois
        # des messages vagues ("must be at least undefined"), impossible de
        # savoir si le bug est chez nous ou chez eux sans voir ce qu'on a
        # vraiment envoye.
        raise JekoError(f"{method} {path} {payload!r} -> {e.code}: {detail}") from e
    except urllib.error.URLError as e:
        raise JekoError(f"{method} {path} injoignable : {e.reason}") from e


def create_payment_link(title, amount_xof):
    """Lien de paiement a usage unique (un par depot) : `canReceivePayments`
    passe a false des le premier paiement recu (voir doc), inutilisable pour
    un deuxieme depot -- exactement ce qu'il faut ici."""
    return _request("POST", "/payment_links", {
        "storeId": settings.JEKO_STORE_ID,
        "title": title[:255],
        "amountCents": round(amount_xof * 100),
        "currency": "XOF",
        "allowMultiplePayments": False,
    })


def get_payment_link(link_id):
    """Fallback polling (voir doc) si le webhook n'est pas encore configure
    ou tarde a arriver."""
    return _request("GET", f"/payment_links/{link_id}")


def verify_signature(raw_body: bytes, signature: str) -> bool:
    """HMAC-SHA256 du corps brut avec le secret webhook (Jeko-Signature)."""
    if not signature or not settings.JEKO_WEBHOOK_SECRET:
        return False
    expected = hmac.new(settings.JEKO_WEBHOOK_SECRET.encode(), raw_body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)

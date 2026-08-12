import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "django-dev-key-change-me")
DEBUG = os.environ.get("DEBUG", "0") == "1"
ALLOWED_HOSTS = ["*"]  # ponytail: derriere ngrok/railway, filtrage fait en amont

# Aucune valeur par defaut hors DEBUG : un secret de repli finit toujours par
# devenir le secret de production. Le service refuse de demarrer sans.
JWT_SECRET = os.environ.get("JWT_SECRET") or ("dev-insecure-secret" if DEBUG else "")
if not JWT_SECRET:
    from django.core.exceptions import ImproperlyConfigured

    raise ImproperlyConfigured(
        "JWT_SECRET est absent. Renseignez-le dans .env.docker "
        "(demarrer_local.bat en genere un au premier lancement)."
    )
UPLOAD_DIR = os.environ.get("UPLOAD_DIR", "/data/uploads")

# Email de bienvenue (inscription) : compte Gmail du support. EMAIL_HOST_PASSWORD
# doit etre un "mot de passe d'application" Google (pas le mot de passe du
# compte -- Gmail refuse l'auth SMTP normale), genere sur
# https://myaccount.google.com/apppasswords. Tant qu'il n'est pas renseigne,
# l'envoi est simplement ignore (voir send_welcome_email) : l'inscription ne
# doit jamais echouer a cause d'un email qui ne part pas.
EMAIL_HOST = "smtp.gmail.com"
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = os.environ.get("EMAIL_HOST_USER", "dramancis40@gmail.com")
EMAIL_HOST_PASSWORD = os.environ.get("EMAIL_HOST_PASSWORD", "")
DEFAULT_FROM_EMAIL = f"BAOU Finance <{EMAIL_HOST_USER}>"

# URL publique du backend (ngrok ou domaine reel) utilisee pour construire le
# lien de confirmation dans l'email -- doit etre a jour dans .env.docker,
# sinon le lien pointe vers localhost et ne marche pas depuis le telephone.
BACKEND_PUBLIC_URL = os.environ.get("BACKEND_PUBLIC_URL", "http://localhost:3001")

# Depots mobiles : paiement en ligne Jeko Africa (voir api/jeko.py). Cles +
# storeId depuis https://cockpit.jeko.africa (Parametres > API & Webhooks).
# JEKO_WEBHOOK_SECRET signe les webhooks entrants (HMAC-SHA256) -- meme page,
# section webhook. Tant que ces valeurs sont vides, les depots echouent avec
# un message explicite (voir create_transaction) plutot que de planter.
JEKO_API_KEY = os.environ.get("JEKO_API_KEY", "")
JEKO_API_KEY_ID = os.environ.get("JEKO_API_KEY_ID", "")
JEKO_STORE_ID = os.environ.get("JEKO_STORE_ID", "")
JEKO_WEBHOOK_SECRET = os.environ.get("JEKO_WEBHOOK_SECRET", "")
# Repli tant que le compte Jeko n'a pas l'acces API active (403
# business_not_enabled_for_api_access sur /payment_links, voir views.py) :
# lien fixe cree a la main dans le Cockpit, depot alors valide manuellement
# par l'admin. Retire tout seul une fois l'API activee cote Jeko.
JEKO_FALLBACK_LINK = os.environ.get(
    "JEKO_FALLBACK_LINK", "https://pay.jeko.africa/pl/3b7524f4-5883-44c3-96fc-8e239ae1aa87"
)

INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.auth",
    "rest_framework",
    "api",
]

MIDDLEWARE = [
    "config.settings.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
]

ROOT_URLCONF = "api.urls"
WSGI_APPLICATION = "config.wsgi.application"
APPEND_SLASH = False  # les clients appellent /api/stocks sans slash final

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("POSTGRES_DB", "baou"),
        "USER": os.environ.get("POSTGRES_USER", "baou"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", "baou"),
        "HOST": os.environ.get("POSTGRES_HOST", "db"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
    }
}

REST_FRAMEWORK = {
    # JSON uniquement. L'API navigable de DRF exige des templates et
    # staticfiles, et repondrait du HTML a un navigateur : 500 garanti.
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.AllowAny"],
    "DEFAULT_THROTTLE_CLASSES": ["rest_framework.throttling.AnonRateThrottle"],
    "DEFAULT_THROTTLE_RATES": {"anon": "300/min"},
    "UNAUTHENTICATED_USER": None,
}

DATA_UPLOAD_MAX_MEMORY_SIZE = 15 * 1024 * 1024  # documents KYC en base64
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
USE_TZ = True
LANGUAGE_CODE = "fr-fr"
TIME_ZONE = "UTC"


class CorsMiddleware:
    """Meme politique que la v1.0.4 : tout est autorise en local."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method == "OPTIONS":
            from django.http import HttpResponse

            response = HttpResponse(status=204)
        else:
            response = self.get_response(request)
        response["Access-Control-Allow-Origin"] = request.headers.get("Origin", "*")
        response["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        response["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        response["Access-Control-Max-Age"] = "86400"
        return response

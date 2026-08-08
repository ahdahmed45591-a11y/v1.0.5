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

import os
from pathlib import Path
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

# SECURITY
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("DJANGO_SECRET_KEY environment variable is required in production")

DEBUG = os.environ.get("DJANGO_DEBUG", "False").lower() in ("1", "true", "yes")

# Use a comma-separated list in env (e.g. example.com,api.example.com)
ALLOWED_HOSTS = [h.strip() for h in os.environ.get("DJANGO_ALLOWED_HOSTS", "").split(",") if h.strip()]

# If you're behind a proxy/load-balancer (e.g. nginx, AWS ELB)
# Set this to the header your proxy sets (common value below)
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

# Only enable CSRF_TRUSTED_ORIGINS if you actually need browser-based forms
# For mobile apps using JWT in Authorization header, CSRF is not typically needed
CSRF_TRUSTED_ORIGINS = [u.strip() for u in os.environ.get("DJANGO_CSRF_TRUSTED_ORIGINS", "").split(",") if u.strip()]

# Application definition
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",

    # Third party
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    "corsheaders",

    # Utilities you already used (only include moviepy if needed)
    "django_extensions",

    # Project apps
    "progress_tracking",
    "user",
    "core",
]

# REST Framework and JWT (reasonable secure defaults)
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticated",
    ),
}

from rest_framework_simplejwt.settings import api_settings as jwt_api_settings

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=int(os.environ.get("JWT_ACCESS_MINUTES", 30))),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=int(os.environ.get("JWT_REFRESH_DAYS", 7))),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "ALGORITHM": "HS256",
    "SIGNING_KEY": SECRET_KEY,
    "AUTH_HEADER_TYPES": ("Bearer",),
    "AUTH_TOKEN_CLASSES": ("rest_framework_simplejwt.tokens.AccessToken",),
}

APPEND_SLASH = False

# Middleware - secure and minimal with proper ordering
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    # Optional: whitenoise for static files if serving from Django
    # "whitenoise.middleware.WhiteNoiseMiddleware",

    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",

    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",

    # Project custom middleware (if needed)
    "miloc.block_progress_images_middleware.BlockDirectProgressImageAccessMiddleware",
]

ROOT_URLCONF = "miloc.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# Use ASGI for channels / websocket support if used
WSGI_APPLICATION = "miloc.wsgi.application"

# Database - use PostgreSQL in production. Example uses env vars.
DATABASES = {
    "default": {
        "ENGINE": os.environ.get("DB_ENGINE", "django.db.backends.postgresql"),
        "NAME": os.environ.get("DB_NAME", "miloc"),
        "USER": os.environ.get("DB_USER", "milocuser"),
        "PASSWORD": os.environ.get("DB_PASSWORD", ""),
        "HOST": os.environ.get("DB_HOST", "localhost"),
        "PORT": os.environ.get("DB_PORT", "5432"),
    }
}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",},
]

# Internationalization
LANGUAGE_CODE = "en-us"
TIME_ZONE = os.environ.get("DJANGO_TIME_ZONE", "UTC")
USE_I18N = True
USE_TZ = True

# Static and media
STATIC_URL = "/static/"
# Optionally use whitenoise or a CDN. In production prefer S3/Cloud Storage for MEDIA.
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
AUTH_USER_MODEL = "user.CustomUser"

# CORS - for mobile apps this is usually not needed; restrict to your frontend web origins
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = [u.strip() for u in os.environ.get("CORS_ALLOWED_ORIGINS", "").split(",") if u.strip()]

# SECURITY settings (recommended)
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_SSL_REDIRECT = os.environ.get("SECURE_SSL_REDIRECT", "True").lower() in ("1", "true", "yes")
SECURE_HSTS_SECONDS = int(os.environ.get("SECURE_HSTS_SECONDS", 31536000))  # 1 year default
SECURE_HSTS_INCLUDE_SUBDOMAINS = os.environ.get("SECURE_HSTS_INCLUDE_SUBDOMAINS", "True").lower() in ("1", "true", "yes")
SECURE_HSTS_PRELOAD = os.environ.get("SECURE_HSTS_PRELOAD", "False").lower() in ("1", "true", "yes")
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = "DENY"

# Logging: keep errors visible in production
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {"class": "logging.StreamHandler",},
    },
    "root": {"handlers": ["console"], "level": os.environ.get("DJANGO_LOG_LEVEL", "INFO")},
}



# Additional recommendations:
# - Consider using django-storages + S3 for MEDIA in production.
# - Run migrations as part of deploy and don't keep DEBUG=True.
# CSRF not needed for mobile clients (only relevant for browsers)
CSRF_TRUSTED_ORIGINS = []

# CORS not needed for mobile apps (only relevant for browsers)
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = []

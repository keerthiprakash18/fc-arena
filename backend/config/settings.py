import os
from pathlib import Path
from decouple import config
from datetime import timedelta
import urllib.parse

BASE_DIR = Path(__file__).resolve().parent.parent

for _env_key in ('EXPLABS_API_KEY', 'EXPLABS_BASE_URL', 'EXPLABS_MODEL', 'OCR_PROVIDER'):
    os.environ.setdefault(_env_key, config(_env_key, default=''))

SECRET_KEY = config('SECRET_KEY', default='django-insecure-change-me')
DEBUG = config('DEBUG', default=True, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='*').split(',')

# CORS
CORS_ALLOW_ALL_ORIGINS = config('CORS_ALLOW_ALL_ORIGINS', default=True, cast=bool)
_cors_origins = config('CORS_ALLOWED_ORIGINS', default='')
CORS_ALLOWED_ORIGINS = [o.strip() for o in _cors_origins.split(',') if o.strip()] or \
    ['http://localhost:3000', 'http://localhost:8080', 'http://localhost:5000']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders',
    'accounts',
    'leagues',
    'seasons',
    'tournaments',
    'matches',
    'statistics',
    'ratings',
    'evidence',
    'verification',
    'leaderboards',
    'awards',
    'records',
    'disputes',
    'notifications',
    'auditlog',
    'dashboard',
    'categories',

]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

# Support both DATABASE_URL (Render/Neon) and individual vars (local dev)
_database_url = os.environ.get('DATABASE_URL', '')
if _database_url:
    _db = urllib.parse.urlparse(_database_url)
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': _db.path.lstrip('/').split('?')[0],
            'USER': _db.username,
            'PASSWORD': _db.password,
            'HOST': _db.hostname,
            'PORT': _db.port or '5432',
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': config('DATABASE_NAME', default='fc_arena_db'),
            'USER': config('DATABASE_USER', default='fc_arena_user'),
            'PASSWORD': config('DATABASE_PASSWORD', default='password'),
            'HOST': config('DATABASE_HOST', default='localhost'),
            'PORT': config('DATABASE_PORT', default='5432'),
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

AUTH_USER_MODEL = 'accounts.User'

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Kolkata'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Optional object storage (AWS S3 / Cloudflare R2). Enables durable
# evidence files on hosts without persistent disk. Set USE_S3=True.
if config('USE_S3', default=False, cast=bool):
    storage_backend = 'storages.backends.s3boto3.S3Boto3Storage'
    AWS_ACCESS_KEY_ID = config('S3_ACCESS_KEY_ID', default='')
    AWS_SECRET_ACCESS_KEY = config('S3_SECRET_ACCESS_KEY', default='')
    AWS_STORAGE_BUCKET_NAME = config('S3_BUCKET_NAME', default='')
    AWS_S3_REGION_NAME = config('S3_REGION_NAME', default='auto')
    AWS_S3_ENDPOINT_URL = config('S3_ENDPOINT_URL', default='')
    AWS_S3_OBJECT_PARAMETERS = {'CacheControl': 'max-age=604800'}
    AWS_QUERYSTRING_AUTH = False
    host = AWS_S3_ENDPOINT_URL.replace('https://', '').replace('http://', '').split('/')[0]
    MEDIA_URL = f'https://{AWS_STORAGE_BUCKET_NAME}.{host}/media/'
else:
    storage_backend = 'django.core.files.storage.FileSystemStorage'
    MEDIA_URL = '/media/'

STORAGES = {
    'default': {'BACKEND': storage_backend},
    'staticfiles': {'BACKEND': 'whitenoise.storage.CompressedManifestStaticFilesStorage'},
}
MEDIA_ROOT = BASE_DIR / 'media'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
}

if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SECURE_SSL_REDIRECT = config('SECURE_SSL_REDIRECT', default=True, cast=bool)
    SESSION_COOKIE_SECURE = config('SESSION_COOKIE_SECURE', default=True, cast=bool)
    CSRF_COOKIE_SECURE = config('CSRF_COOKIE_SECURE', default=True, cast=bool)
    SECURE_HSTS_SECONDS = config('SECURE_HSTS_SECONDS', default=31536000, cast=int)
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = 'DENY'
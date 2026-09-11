from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse

API_VERSION = '1.0.0'

# Every app that exposes a router under /api/. Kept here so the API root
# listing and the health probe stay in sync with the mounted routes.
API_SECTIONS = [
    'accounts', 'leagues', 'seasons', 'tournaments', 'evidence', 'matches',
    'statistics', 'ratings', 'verification', 'leaderboards', 'awards',
    'records', 'disputes', 'notifications', 'auditlog', 'dashboard',
    'categories',
]


def api_root(request):
    """Human/health-friendly landing page at /api/ (also used by uptime checks)."""
    return JsonResponse({
        'name': 'FC ARENA API',
        'version': API_VERSION,
        'status': 'ok',
        'sections': [f'/api/{s}/' for s in API_SECTIONS],
        'auth': '/api/auth/login/',
    })


def health(request):
    """Cheap liveness + database probe for load balancers and the mobile app."""
    from django.db import connection
    db_ok = True
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
            cursor.fetchone()
    except Exception:
        db_ok = False
    return JsonResponse(
        {'status': 'ok' if db_ok else 'degraded', 'database': db_ok, 'version': API_VERSION},
        status=200 if db_ok else 503,
    )


urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', api_root),
    path('api/health/', health),
    path('api/', include('accounts.urls')),
    path('api/', include('leagues.urls')),
    path('api/', include('seasons.urls')),
    path('api/', include('tournaments.urls')),
    path('api/', include('evidence.urls')),
    path('api/', include('matches.urls')),
    path('api/', include('statistics.urls')),
    path('api/', include('ratings.urls')),
    path('api/', include('verification.urls')),
    path('api/', include('leaderboards.urls')),
    path('api/', include('awards.urls')),
    path('api/', include('records.urls')),
    path('api/', include('disputes.urls')),
    path('api/', include('notifications.urls')),
    path('api/', include('auditlog.urls')),
    path('api/', include('dashboard.urls')),
    path('api/', include('categories.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
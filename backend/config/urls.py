from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
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
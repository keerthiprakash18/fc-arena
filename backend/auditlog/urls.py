from django.urls import path
from .views import AuditLogListView

urlpatterns = [
    path('audit/',
         AuditLogListView.as_view(), name='audit-log-user'),
    path('leagues/<int:league_id>/audit/',
         AuditLogListView.as_view(), name='audit-log-league'),
]
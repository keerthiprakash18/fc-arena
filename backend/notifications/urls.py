from django.urls import path
from .views import (
    NotificationListView, NotificationDetailView,
    NotificationMarkReadView, NotificationMarkAllReadView,
    NotificationUnreadCountView, NotificationPreferenceView
)

urlpatterns = [
    path('notifications/',
         NotificationListView.as_view(), name='notification-list'),
    path('notifications/<int:notification_id>/',
         NotificationDetailView.as_view(), name='notification-detail'),
    path('notifications/<int:notification_id>/read/',
         NotificationMarkReadView.as_view(), name='notification-mark-read'),
    path('notifications/read-all/',
         NotificationMarkAllReadView.as_view(), name='notification-mark-all-read'),
    path('notifications/unread-count/',
         NotificationUnreadCountView.as_view(), name='notification-unread-count'),
    path('notifications/preferences/',
         NotificationPreferenceView.as_view(), name='notification-preferences'),
]
from django.urls import path
from .views import AwardListView, AwardCreateView, AwardDetailView, AwardAuditLogView

urlpatterns = [
    path('leagues/<int:league_id>/awards/',
         AwardListView.as_view(), name='award-list'),
    path('leagues/<int:league_id>/awards/create/',
         AwardCreateView.as_view(), name='award-create'),
    path('leagues/<int:league_id>/awards/<int:pk>/',
         AwardDetailView.as_view(), name='award-detail'),
    path('leagues/<int:league_id>/awards/<int:award_id>/audit/',
         AwardAuditLogView.as_view(), name='award-audit'),
]
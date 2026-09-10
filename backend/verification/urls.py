from django.urls import path
from .views import (
    TriggerVerificationView, VerificationTaskDetailView,
    AdminReviewView, VerificationResultsView
)

urlpatterns = [
    path('leagues/<int:league_id>/matches/<int:match_id>/verify/',
         TriggerVerificationView.as_view(), name='trigger-verification'),
    path('leagues/<int:league_id>/matches/<int:match_id>/verification/',
         VerificationTaskDetailView.as_view(), name='verification-detail'),
    path('leagues/<int:league_id>/matches/<int:match_id>/verification/review/',
         AdminReviewView.as_view(), name='admin-review'),
    path('leagues/<int:league_id>/matches/<int:match_id>/verification/results/',
         VerificationResultsView.as_view(), name='verification-results'),
]
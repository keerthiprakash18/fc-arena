from django.urls import path
from .views import EvidenceUploadView, EvidenceListView, EvidenceFileView

urlpatterns = [
    path('leagues/<int:league_id>/matches/<int:match_id>/evidence/upload/',
         EvidenceUploadView.as_view(), name='evidence-upload'),
    path('leagues/<int:league_id>/matches/<int:match_id>/evidence/',
         EvidenceListView.as_view(), name='evidence-list'),
    path('leagues/<int:league_id>/matches/<int:match_id>/evidence/<int:evidence_id>/file/',
         EvidenceFileView.as_view(), name='evidence-file'),
]

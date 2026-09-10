from django.urls import path
from .views import (
    DisputeListCreateView, DisputeDetailView,
    DisputeResolveView, DisputeCommentCreateView
)

urlpatterns = [
    path('leagues/<int:league_id>/disputes/',
         DisputeListCreateView.as_view(), name='dispute-list-create'),
    path('leagues/<int:league_id>/disputes/<int:dispute_id>/',
         DisputeDetailView.as_view(), name='dispute-detail'),
    path('leagues/<int:league_id>/disputes/<int:dispute_id>/resolve/',
         DisputeResolveView.as_view(), name='dispute-resolve'),
    path('leagues/<int:league_id>/disputes/<int:dispute_id>/comments/',
         DisputeCommentCreateView.as_view(), name='dispute-comment'),
]
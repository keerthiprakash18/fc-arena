from django.urls import path
from .views import (
    PlayerLeagueRatingListView, PlayerLeagueRatingDetailView,
    RatingHistoryListView
)

urlpatterns = [
    path('leagues/<int:league_id>/ratings/',
         PlayerLeagueRatingListView.as_view(), name='ratings-list'),
    path('leagues/<int:league_id>/ratings/<int:user_id>/',
         PlayerLeagueRatingDetailView.as_view(), name='ratings-detail'),
    path('leagues/<int:league_id>/ratings/history/',
         RatingHistoryListView.as_view(), name='rating-history'),
]
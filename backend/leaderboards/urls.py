from django.urls import path
from .views import LeaderboardListView, LeaderboardTopView, LeaderboardRegenerateView

urlpatterns = [
    path('leagues/<int:league_id>/leaderboards/',
         LeaderboardListView.as_view(), name='leaderboard-list'),
    path('leagues/<int:league_id>/leaderboards/regenerate/',
         LeaderboardRegenerateView.as_view(), name='leaderboard-regenerate'),
    path('leagues/<int:league_id>/leaderboards/<str:category>/top/',
         LeaderboardTopView.as_view(), name='leaderboard-top'),
]
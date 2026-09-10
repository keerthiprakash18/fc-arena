from django.urls import path
from .views import (
    PlayerLeagueStatisticsListView, PlayerLeagueStatisticsDetailView,
    LeagueStandingListView, RebuildStatisticsView
)

urlpatterns = [
    path('leagues/<int:league_id>/statistics/',
         PlayerLeagueStatisticsListView.as_view(), name='statistics-list'),
    path('leagues/<int:league_id>/statistics/<int:user_id>/',
         PlayerLeagueStatisticsDetailView.as_view(), name='statistics-detail'),
    path('leagues/<int:league_id>/standings/',
         LeagueStandingListView.as_view(), name='standings-list'),
    path('leagues/<int:league_id>/statistics/rebuild/',
         RebuildStatisticsView.as_view(), name='statistics-rebuild'),
]
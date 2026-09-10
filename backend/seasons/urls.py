from django.urls import path
from .views import (
    SeasonListCreateView, SeasonDetailView,
    SeasonCurrentView, SeasonJoinView, SeasonMembersView
)

urlpatterns = [
    path('leagues/<int:league_id>/seasons/',
         SeasonListCreateView.as_view(), name='season-list-create'),
    path('leagues/<int:league_id>/seasons/current/',
         SeasonCurrentView.as_view(), name='season-current'),
    path('leagues/<int:league_id>/seasons/<int:season_id>/',
         SeasonDetailView.as_view(), name='season-detail'),
    path('leagues/<int:league_id>/seasons/<int:season_id>/join/',
         SeasonJoinView.as_view(), name='season-join'),
    path('leagues/<int:league_id>/seasons/<int:season_id>/members/',
         SeasonMembersView.as_view(), name='season-members'),
]
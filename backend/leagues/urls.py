from django.urls import path
from .views import (
    LeagueListCreateView, LeagueDetailView,
    LeagueJoinView, LeagueMembersView,
    LeagueMemberManageView,
)

urlpatterns = [
    path('leagues/', LeagueListCreateView.as_view(), name='league-list-create'),
    path('leagues/<int:league_id>/', LeagueDetailView.as_view(), name='league-detail'),
    path('leagues/join/', LeagueJoinView.as_view(), name='league-join'),
    path('leagues/<int:league_id>/members/', LeagueMembersView.as_view(), name='league-members'),
    path('leagues/<int:league_id>/members/<int:user_id>/', LeagueMemberManageView.as_view(), name='league-member-manage'),
]
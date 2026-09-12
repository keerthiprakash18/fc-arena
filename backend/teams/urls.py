from django.urls import path

from .views import (
    TeamBannerView,
    TeamDetailView,
    TeamListCreateView,
    TeamLogoView,
    TeamMemberManageView,
    TeamMembersView,
    TeamStandingsView,
    TeamStatisticsView,
)

urlpatterns = [
    # NOTE: 'standings/' must precede '<int:team_id>/' so it is not swallowed
    # by the integer converter (Django tries patterns in order).
    path('leagues/<int:league_id>/teams/standings/',
         TeamStandingsView.as_view(), name='team-standings'),
    path('leagues/<int:league_id>/teams/',
         TeamListCreateView.as_view(), name='team-list-create'),
    path('leagues/<int:league_id>/teams/<int:team_id>/',
         TeamDetailView.as_view(), name='team-detail'),
    path('leagues/<int:league_id>/teams/<int:team_id>/statistics/',
         TeamStatisticsView.as_view(), name='team-statistics'),
    path('leagues/<int:league_id>/teams/<int:team_id>/members/',
         TeamMembersView.as_view(), name='team-members'),
    path('leagues/<int:league_id>/teams/<int:team_id>/members/<int:member_id>/',
         TeamMemberManageView.as_view(), name='team-member-manage'),
    path('leagues/<int:league_id>/teams/<int:team_id>/logo/',
         TeamLogoView.as_view(), name='team-logo'),
    path('leagues/<int:league_id>/teams/<int:team_id>/banner/',
         TeamBannerView.as_view(), name='team-banner'),
]

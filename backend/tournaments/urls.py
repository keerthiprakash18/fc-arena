from django.urls import path
from .views import (
    TournamentListCreateView, TournamentDetailView,
    TournamentStatusUpdateView, TournamentRegisterView,
    TournamentParticipantsView, TournamentGroupsView,
    TournamentRoundsView, TournamentFixturesView, TournamentTransitionsView
)

urlpatterns = [
    path('leagues/<int:league_id>/tournaments/',
         TournamentListCreateView.as_view(), name='tournament-list-create'),
    path('leagues/<int:league_id>/tournaments/<int:tournament_id>/',
         TournamentDetailView.as_view(), name='tournament-detail'),
    path('leagues/<int:league_id>/tournaments/<int:tournament_id>/status/',
         TournamentStatusUpdateView.as_view(), name='tournament-status'),
    path('leagues/<int:league_id>/tournaments/<int:tournament_id>/register/',
         TournamentRegisterView.as_view(), name='tournament-register'),
    path('leagues/<int:league_id>/tournaments/<int:tournament_id>/participants/',
         TournamentParticipantsView.as_view(), name='tournament-participants'),
    path('leagues/<int:league_id>/tournaments/<int:tournament_id>/groups/',
         TournamentGroupsView.as_view(), name='tournament-groups'),
    path('leagues/<int:league_id>/tournaments/<int:tournament_id>/rounds/',
         TournamentRoundsView.as_view(), name='tournament-rounds'),
    path('leagues/<int:league_id>/tournaments/<int:tournament_id>/fixtures/',
         TournamentFixturesView.as_view(), name='tournament-fixtures'),
    path('leagues/<int:league_id>/tournaments/<int:tournament_id>/transitions/',
         TournamentTransitionsView.as_view(), name='tournament-transitions'),
]
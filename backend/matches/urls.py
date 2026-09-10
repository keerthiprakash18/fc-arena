from django.urls import path
from .views import (
    MatchListCreateView, MatchDetailView,
    MatchStatusUpdateView, MatchSubmitResultView,
    MatchEvidenceListCreateView, MatchStatisticsView,
    MatchVerificationView, MatchTransitionsView
)
from .event_views import MatchEventListCreateView, MatchEventDeleteView

urlpatterns = [
    path('leagues/<int:league_id>/matches/',
         MatchListCreateView.as_view(), name='match-list-create'),
    path('leagues/<int:league_id>/matches/<int:match_id>/',
         MatchDetailView.as_view(), name='match-detail'),
    path('leagues/<int:league_id>/matches/<int:match_id>/status/',
         MatchStatusUpdateView.as_view(), name='match-status'),
    path('leagues/<int:league_id>/matches/<int:match_id>/submit/',
         MatchSubmitResultView.as_view(), name='match-submit'),
    path('leagues/<int:league_id>/matches/<int:match_id>/evidence/',
         MatchEvidenceListCreateView.as_view(), name='match-evidence'),
    path('leagues/<int:league_id>/matches/<int:match_id>/statistics/',
         MatchStatisticsView.as_view(), name='match-statistics'),
    path('leagues/<int:league_id>/matches/<int:match_id>/verification/',
         MatchVerificationView.as_view(), name='match-verification'),
    path('leagues/<int:league_id>/matches/<int:match_id>/transitions/',
         MatchTransitionsView.as_view(), name='match-transitions'),
    path('leagues/<int:league_id>/matches/<int:match_id>/events/',
         MatchEventListCreateView.as_view(), name='match-events'),
    path('leagues/<int:league_id>/matches/<int:match_id>/events/<int:event_id>/',
         MatchEventDeleteView.as_view(), name='match-event-delete'),
]
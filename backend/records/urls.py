from django.urls import path

from .views import LeagueRecordListView, LeagueRecordRecomputeView

urlpatterns = [
    path('leagues/<int:league_id>/records/',
         LeagueRecordListView.as_view(), name='record-list'),
    path('leagues/<int:league_id>/records/recompute/',
         LeagueRecordRecomputeView.as_view(), name='record-recompute'),
]

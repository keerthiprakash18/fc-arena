from django.urls import path
from .views import LeagueRecordListView

urlpatterns = [
    path('leagues/<int:league_id>/records/',
         LeagueRecordListView.as_view(), name='record-list'),
]
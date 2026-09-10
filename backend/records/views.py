from rest_framework import generics, permissions
from .models import LeagueRecord
from .serializers import LeagueRecordSerializer


class LeagueRecordListView(generics.ListAPIView):
    serializer_class = LeagueRecordSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        queryset = LeagueRecord.objects.filter(
            league_id=league_id, is_current=True
        ).select_related('user', 'match')
        record_type = self.request.query_params.get('record_type')
        if record_type:
            queryset = queryset.filter(record_type=record_type)
        return queryset
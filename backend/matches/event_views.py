from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import Match, MatchEvent
from .event_serializers import MatchEventSerializer, MatchEventCreateSerializer


class MatchEventListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return MatchEventCreateSerializer
        return MatchEventSerializer

    def get_queryset(self):
        match_id = self.kwargs['match_id']
        return MatchEvent.objects.filter(match_id=match_id).select_related('player', 'assisted_by')

    def perform_create(self, serializer):
        match = get_object_or_404(Match, id=self.kwargs['match_id'])
        serializer.save(match=match, created_by=self.request.user)


class MatchEventDeleteView(generics.DestroyAPIView):
    serializer_class = MatchEventSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        match_id = self.kwargs['match_id']
        return MatchEvent.objects.filter(match_id=match_id)
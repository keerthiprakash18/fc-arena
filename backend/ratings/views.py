from rest_framework import generics, permissions
from django.shortcuts import get_object_or_404
from .models import PlayerLeagueRating, RatingHistory
from .serializers import PlayerLeagueRatingSerializer, RatingHistorySerializer


class PlayerLeagueRatingListView(generics.ListAPIView):
    serializer_class = PlayerLeagueRatingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        return PlayerLeagueRating.objects.filter(
            league_id=league_id
        ).select_related('user')


class PlayerLeagueRatingDetailView(generics.RetrieveAPIView):
    serializer_class = PlayerLeagueRatingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        league_id = self.kwargs['league_id']
        user_id = self.kwargs['user_id']
        return get_object_or_404(
            PlayerLeagueRating, league_id=league_id, user_id=user_id
        )


class RatingHistoryListView(generics.ListAPIView):
    serializer_class = RatingHistorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        queryset = RatingHistory.objects.filter(
            league_id=league_id
        ).select_related('user', 'match')
        user_id = self.request.query_params.get('user_id')
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        return queryset
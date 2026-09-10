from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from leagues.models import League, LeagueMember
from .models import Leaderboard
from .serializers import LeaderboardSerializer
from .services import calculate_leaderboards


class LeaderboardListView(generics.ListAPIView):
    serializer_class = LeaderboardSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        queryset = Leaderboard.objects.filter(
            league_id=league_id
        ).select_related('user')
        category = self.request.query_params.get('category')
        if category:
            queryset = queryset.filter(category=category)
        season_id = self.request.query_params.get('season_id')
        if season_id:
            queryset = queryset.filter(season_id=season_id)
        else:
            queryset = queryset.filter(season__isnull=True)
        tournament_id = self.request.query_params.get('tournament_id')
        if tournament_id:
            queryset = queryset.filter(tournament_id=tournament_id)
        else:
            queryset = queryset.filter(tournament__isnull=True)
        return queryset.order_by('rank', '-value')


class LeaderboardRegenerateView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        league = get_object_or_404(League, id=league_id)

        is_admin = LeagueMember.objects.filter(
            league_id=league_id,
            user=request.user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            is_active=True
        ).exists()
        if not is_admin:
            return Response(
                {'error': 'Only league admins can regenerate leaderboards.'},
                status=status.HTTP_403_FORBIDDEN
            )

        season_id = request.data.get('season_id')
        tournament_id = request.data.get('tournament_id')
        calculate_leaderboards(league, season_id, tournament_id)

        return Response({'message': 'Leaderboards regenerated successfully.'})


class LeaderboardTopView(generics.ListAPIView):
    serializer_class = LeaderboardSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        category = self.kwargs['category']
        return Leaderboard.objects.filter(
            league_id=league_id,
            category=category,
            season__isnull=True,
            tournament__isnull=True
        ).select_related('user').order_by('rank', '-value')[:10]
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from leagues.models import League, LeagueMember
from .models import PlayerLeagueStatistics, LeagueStanding
from .serializers import PlayerLeagueStatisticsSerializer, LeagueStandingSerializer
from .services import rebuild_league_statistics


class PlayerLeagueStatisticsListView(generics.ListAPIView):
    serializer_class = PlayerLeagueStatisticsSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        queryset = PlayerLeagueStatistics.objects.filter(
            league_id=league_id
        ).select_related('user', 'season')
        season_id = self.request.query_params.get('season_id')
        if season_id:
            queryset = queryset.filter(season_id=season_id)
        return queryset


class PlayerLeagueStatisticsDetailView(generics.RetrieveAPIView):
    serializer_class = PlayerLeagueStatisticsSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        league_id = self.kwargs['league_id']
        user_id = self.kwargs['user_id']
        return get_object_or_404(
            PlayerLeagueStatistics, league_id=league_id, user_id=user_id
        )


class LeagueStandingListView(generics.ListAPIView):
    serializer_class = LeagueStandingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        queryset = LeagueStanding.objects.filter(
            league_id=league_id
        ).select_related('user', 'season')
        season_id = self.request.query_params.get('season_id')
        if season_id:
            queryset = queryset.filter(season_id=season_id)
        return queryset


class RebuildStatisticsView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        league = get_object_or_404(League, id=league_id)

        is_member = LeagueMember.objects.filter(
            league=league, user=request.user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            is_active=True
        ).exists()
        if not is_member:
            return Response(
                {'error': 'Only league admins can rebuild statistics.'},
                status=status.HTTP_403_FORBIDDEN
            )

        season_id = request.data.get('season_id')
        rebuild_league_statistics(league, season_id)

        return Response({'message': 'Statistics rebuilt successfully.'})
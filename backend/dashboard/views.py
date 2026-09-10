from rest_framework.exceptions import PermissionDenied
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404

from leagues.models import League, LeagueMember
from ratings.models import PlayerLeagueRating
from statistics.models import PlayerLeagueStatistics
from . import services


def _is_league_admin(request, league):
    if request.user.is_superuser:
        return True
    return LeagueMember.objects.filter(
        league=league,
        user=request.user,
        role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
        is_active=True,
    ).exists()


def _is_league_member(request, league):
    return LeagueMember.objects.filter(
        league=league, user=request.user, is_active=True
    ).exists()


def _get_admin_league(request, league_id):
    league = get_object_or_404(League, id=league_id)
    if not _is_league_admin(request, league):
        raise PermissionDenied('League admin access required.')
    return league


def _get_member_league(request, league_id):
    league = get_object_or_404(League, id=league_id)
    if not (_is_league_admin(request, league) or _is_league_member(request, league)):
        raise PermissionDenied('You must be an active league member.')
    return league


class LeagueOverviewView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, league_id, *args, **kwargs):
        league = _get_member_league(request, league_id)
        return Response(services.league_overview(league))


class MatchStatusDistributionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, league_id, *args, **kwargs):
        league = _get_admin_league(request, league_id)
        return Response(services.match_status_distribution(league))


class RatingTrendsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, league_id, *args, **kwargs):
        league = _get_admin_league(request, league_id)
        user = None
        user_id = request.query_params.get('user_id')
        if user_id:
            user = get_object_or_404(PlayerLeagueRating, league=league, user_id=user_id).user
        return Response(services.rating_trends(league, user))


class PendingReviewsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, league_id, *args, **kwargs):
        league = _get_admin_league(request, league_id)
        return Response(services.pending_reviews(league))


class RecentActivityView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, league_id, *args, **kwargs):
        league = _get_admin_league(request, league_id)
        limit = int(request.query_params.get('limit', 20))
        limit = min(max(limit, 1), 100)
        return Response(services.recent_activity(league, limit))


class PlayerStandingsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, league_id, *args, **kwargs):
        league = _get_member_league(request, league_id)
        rows = []
        for s in PlayerLeagueStatistics.objects.filter(league=league).select_related('user'):
            points = (s.wins * 3) + s.draws
            rows.append({
                'username': s.user.username,
                'matches_played': s.matches_played,
                'wins': s.wins,
                'draws': s.draws,
                'losses': s.losses,
                'goals_scored': s.goals_scored,
                'goals_conceded': s.goals_conceded,
                'goal_difference': s.goals_scored - s.goals_conceded,
                'points': points,
            })
        rows.sort(key=lambda r: (-r['points'], -r['goal_difference'], -r['goals_scored']))
        return Response({'players': rows})


class PlatformOverviewView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        if not request.user.is_superuser:
            return Response(
                {'error': 'Superuser access required.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return Response(services.platform_overview())
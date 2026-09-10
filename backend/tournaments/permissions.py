from rest_framework import permissions
from leagues.models import LeagueMember


class IsTournamentLeagueMember(permissions.BasePermission):
    def has_permission(self, request, view):
        tournament = getattr(view, '_tournament', None)
        if tournament is None:
            league_id = view.kwargs.get('league_id')
            if not league_id:
                return False
            return LeagueMember.objects.filter(
                league_id=league_id,
                user=request.user,
                is_active=True
            ).exists()
        return LeagueMember.objects.filter(
            league=tournament.league,
            user=request.user,
            is_active=True
        ).exists()


class IsTournamentLeagueAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        tournament = getattr(view, '_tournament', None)
        if tournament is None:
            league_id = view.kwargs.get('league_id')
            if not league_id:
                return False
            return LeagueMember.objects.filter(
                league_id=league_id,
                user=request.user,
                role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
                is_active=True
            ).exists()
        return LeagueMember.objects.filter(
            league=tournament.league,
            user=request.user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            is_active=True
        ).exists()


class IsTournamentCreator(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        return obj.created_by == request.user
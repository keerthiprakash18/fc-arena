from rest_framework import permissions

from leagues.models import LeagueMember


class IsTeamLeagueMember(permissions.BasePermission):
    """Any active member of the league may read team data."""

    message = 'You are not a member of this league.'

    def has_permission(self, request, view):
        league_id = view.kwargs.get('league_id')
        if not league_id:
            return False
        return LeagueMember.objects.filter(
            league_id=league_id, user=request.user, is_active=True
        ).exists()


class IsTeamLeagueAdmin(permissions.BasePermission):
    """Only a league owner/admin may create, edit or delete teams."""

    message = 'Only a league owner or admin can manage teams.'

    def has_permission(self, request, view):
        league_id = view.kwargs.get('league_id')
        if not league_id:
            return False
        return LeagueMember.objects.filter(
            league_id=league_id,
            user=request.user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            is_active=True,
        ).exists()

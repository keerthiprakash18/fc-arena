from rest_framework import permissions
from leagues.models import LeagueMember


class IsEvidenceLeagueMember(permissions.BasePermission):
    def has_permission(self, request, view):
        league_id = view.kwargs.get('league_id')
        if not league_id:
            return False
        return LeagueMember.objects.filter(
            league_id=league_id,
            user=request.user,
            is_active=True
        ).exists()
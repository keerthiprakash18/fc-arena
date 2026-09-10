from rest_framework import generics, permissions
from django.shortcuts import get_object_or_404
from .models import AuditLog
from .serializers import AuditLogSerializer
from leagues.models import LeagueMember


class AuditLogListView(generics.ListAPIView):
    serializer_class = AuditLogSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs.get('league_id')
        if league_id:
            is_admin = LeagueMember.objects.filter(
                league_id=league_id,
                user=self.request.user,
                role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
                is_active=True
            ).exists()
            if not is_admin:
                return AuditLog.objects.none()
            return AuditLog.objects.filter(league_id=league_id)
        return AuditLog.objects.filter(actor=self.request.user)
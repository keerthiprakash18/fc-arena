from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response

from leagues.models import League, LeagueMember

from .models import LeagueRecord
from .serializers import LeagueRecordSerializer
from .services import recompute_league_records


class _LeagueMemberMixin:
    def get_league(self):
        return get_object_or_404(League, id=self.kwargs['league_id'], is_active=True)

    def is_admin(self, league, user):
        return LeagueMember.objects.filter(
            league=league, user=user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'], is_active=True,
        ).exists()

    def is_member(self, league, user):
        return LeagueMember.objects.filter(
            league=league, user=user, is_active=True
        ).exists()


class LeagueRecordListView(_LeagueMemberMixin, generics.ListAPIView):
    serializer_class = LeagueRecordSerializer
    # Records are league-scoped, so they need the same membership check as every
    # other league endpoint rather than a bare authenticated session.
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        queryset = LeagueRecord.objects.filter(
            league_id=league_id, is_current=True
        ).select_related('user', 'team', 'match')
        record_type = self.request.query_params.get('record_type')
        if record_type:
            queryset = queryset.filter(record_type=record_type)
        return queryset

    def list(self, request, *args, **kwargs):
        league = self.get_league()
        if not self.is_member(league, request.user):
            return Response(
                {'error': 'You are not a member of this league.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().list(request, *args, **kwargs)


class LeagueRecordRecomputeView(_LeagueMemberMixin, generics.GenericAPIView):
    """Rebuild the league's records from its verified matches.

    POST because it writes. Restricted to league owners/admins, since it
    rewrites shared league data.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        league = self.get_league()
        if not self.is_admin(league, request.user):
            return Response(
                {'error': 'Only a league owner or admin can recompute records.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        records = recompute_league_records(league)
        return Response({
            'records': LeagueRecordSerializer(records, many=True).data,
            'count': len(records),
        })

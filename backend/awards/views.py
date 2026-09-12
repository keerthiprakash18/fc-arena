from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from leagues.models import League, LeagueMember
from seasons.models import Season
from tournaments.models import Tournament
from .models import Award, AwardAuditLog
from .serializers import AwardSerializer, AwardCreateSerializer, AwardAuditLogSerializer
from .services import compute_awards


class _LeagueScopedMixin:
    """Shared membership checks for every award endpoint."""

    def get_league(self):
        return get_object_or_404(League, id=self.kwargs['league_id'], is_active=True)

    def is_member(self, league, user):
        return LeagueMember.objects.filter(
            league=league, user=user, is_active=True
        ).exists()

    def is_admin(self, league, user):
        return LeagueMember.objects.filter(
            league=league, user=user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'], is_active=True,
        ).exists()


class AwardListView(_LeagueScopedMixin, generics.ListAPIView):
    serializer_class = AwardSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        queryset = Award.objects.filter(
            league_id=league_id
        ).select_related('user', 'team')
        season_id = self.request.query_params.get('season_id')
        if season_id:
            queryset = queryset.filter(season_id=season_id)
        tournament_id = self.request.query_params.get('tournament_id')
        if tournament_id:
            queryset = queryset.filter(tournament_id=tournament_id)
        award_type = self.request.query_params.get('award_type')
        if award_type:
            queryset = queryset.filter(award_type=award_type)
        return queryset

    def list(self, request, *args, **kwargs):
        league = self.get_league()
        if not self.is_member(league, request.user):
            return Response(
                {'error': 'You are not a member of this league.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().list(request, *args, **kwargs)


class AwardComputeView(_LeagueScopedMixin, generics.GenericAPIView):
    """Rebuild the automatic awards for a league, season or tournament.

    POST because it writes. Organizer overrides are preserved: only
    ``source='AUTO'`` awards are replaced.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        league = self.get_league()
        if not self.is_admin(league, request.user):
            return Response(
                {'error': 'Only league admins can compute awards.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        season = None
        season_id = request.data.get('season_id')
        if season_id:
            season = get_object_or_404(Season, id=season_id, league=league)

        tournament = None
        tournament_id = request.data.get('tournament_id')
        if tournament_id:
            tournament = get_object_or_404(Tournament, id=tournament_id, league=league)

        awards = compute_awards(
            league, season=season, tournament=tournament, awarded_by=request.user
        )
        return Response({
            'awards': AwardSerializer(awards, many=True).data,
            'count': len(awards),
        })


class AwardCreateView(_LeagueScopedMixin, generics.CreateAPIView):
    serializer_class = AwardCreateSerializer
    permission_classes = [permissions.IsAuthenticated]

    def create(self, request, *args, **kwargs):
        """Respond with the same shape the list endpoint returns.

        The write serializer's fields are a subset of the read shape, so
        returning it directly would omit `username`/`team_name`/`title` and
        force the client to re-fetch just to display what it created.
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        return Response(
            AwardSerializer(serializer.instance).data,
            status=status.HTTP_201_CREATED,
        )

    def perform_create(self, serializer):
        league_id = self.kwargs['league_id']
        league_member = LeagueMember.objects.filter(
            league_id=league_id,
            user=self.request.user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            is_active=True
        ).first()
        if not league_member:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Only league admins can assign awards.")

        award = serializer.save(league=get_object_or_404(League, id=league_id))

        AwardAuditLog.objects.create(
            award=award,
            action='ASSIGNED',
            changed_by=self.request.user,
            reason='Manual assignment'
        )

        from auditlog.models import AuditLog
        AuditLog.log(
            actor=self.request.user,
            action='AWARD_ASSIGNED',
            entity_type='Award',
            entity_id=award.id,
            league=award.league,
            after={
                'award_type': award.award_type,
                'user': award.user_id,
                'team': award.team_id,
                'title': award.title,
            },
        )


class AwardDetailView(_LeagueScopedMixin, generics.RetrieveDestroyAPIView):
    serializer_class = AwardSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        return Award.objects.filter(league_id=league_id)

    def perform_destroy(self, instance):
        AwardAuditLog.objects.create(
            award=instance,
            action='REMOVED',
            changed_by=self.request.user,
            reason='Award removed'
        )
        instance.delete()


class AwardAuditLogView(generics.ListAPIView):
    serializer_class = AwardAuditLogSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        award_id = self.kwargs['award_id']
        return AwardAuditLog.objects.filter(award_id=award_id)
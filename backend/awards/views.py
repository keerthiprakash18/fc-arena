from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from leagues.models import League, LeagueMember
from .models import Award, AwardAuditLog
from .serializers import AwardSerializer, AwardCreateSerializer, AwardAuditLogSerializer


class AwardListView(generics.ListAPIView):
    serializer_class = AwardSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        queryset = Award.objects.filter(
            league_id=league_id
        ).select_related('user')
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


class AwardCreateView(generics.CreateAPIView):
    serializer_class = AwardCreateSerializer
    permission_classes = [permissions.IsAuthenticated]

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
                'title': award.custom_name or award.get_award_type_display(),
            },
        )


class AwardDetailView(generics.RetrieveDestroyAPIView):
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
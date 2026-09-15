from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.db import transaction
from leagues.models import League, LeagueMember
from .models import Dispute, DisputeComment
from .serializers import (
    DisputeSerializer, DisputeCreateSerializer,
    DisputeResolutionSerializer, DisputeCommentSerializer
)


def _dispute_notify_targets(match, raised_by):
    """Users who should be told a dispute was raised on `match`.

    Handles both match families and never returns None, so the notification FK
    stays valid. For a team match we notify the opposing squad's manager and
    captain — the team equivalent of "the other player".
    """
    candidates = []
    if match.home_user_id or match.away_user_id:
        for uid, u in (('home_user', match.home_user), ('away_user', match.away_user)):
            if u is not None:
                candidates.append(u)
    else:
        for team in (match.home_team, match.away_team):
            if team is None:
                continue
            for person in (team.manager, team.captain):
                if person is not None:
                    candidates.append(person)

    seen = set()
    result = []
    for u in candidates:
        if u.id == raised_by.id or u.id in seen:
            continue
        seen.add(u.id)
        result.append(u)
    return result


class DisputeListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return DisputeCreateSerializer
        return DisputeSerializer

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        return Dispute.objects.filter(
            league_id=league_id
        ).select_related('raised_by', 'resolved_by', 'match')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['league'] = get_object_or_404(League, id=self.kwargs['league_id'])
        context['request'] = self.request
        return context

    def perform_create(self, serializer):
        league = get_object_or_404(League, id=self.kwargs['league_id'])
        dispute = serializer.save(league=league, raised_by=self.request.user)

        from auditlog.models import AuditLog
        AuditLog.log(
            actor=self.request.user,
            action='DISPUTE_CREATED',
            entity_type='Dispute',
            entity_id=dispute.id,
            league=league,
            after={
                'match': dispute.match_id,
                'reason': dispute.reason,
                'status': dispute.status,
            },
        )

        from notifications.services import create_notification
        # Notify the *other* side. A user match has one opponent; a team match
        # has no user FKs at all, so we fall back to the opposing team's
        # manager and captain. Never notify `None` — Notification.user is a
        # non-null FK and would raise an IntegrityError on team matches.
        for target in _dispute_notify_targets(dispute.match, self.request.user):
            create_notification(
                user=target,
                notification_type='DISPUTE_UPDATE',
                title='New Dispute Raised',
                message=f'A dispute was raised on your match with reasoning: {dispute.get_reason_display()}.',
                league=league,
                match=dispute.match,
            )

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        dispute = serializer.instance
        headers = self.get_success_headers(serializer.data)
        out = DisputeSerializer(dispute, context=self.get_serializer_context()).data
        return Response(out, status=status.HTTP_201_CREATED, headers=headers)


class DisputeDetailView(generics.RetrieveAPIView):
    serializer_class = DisputeSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        league_id = self.kwargs['league_id']
        dispute_id = self.kwargs['dispute_id']
        return get_object_or_404(
            Dispute.objects.select_related('raised_by', 'resolved_by', 'match'),
            id=dispute_id, league_id=league_id
        )


class DisputeResolveView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        dispute_id = self.kwargs['dispute_id']

        league_member = LeagueMember.objects.filter(
            league_id=league_id,
            user=request.user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            is_active=True
        ).first()
        if not league_member:
            return Response(
                {'error': 'Only league admins can resolve disputes.'},
                status=status.HTTP_403_FORBIDDEN
            )

        dispute = get_object_or_404(Dispute, id=dispute_id, league_id=league_id)

        if dispute.status != 'OPEN':
            return Response(
                {'error': f'Dispute is not OPEN. Current status: {dispute.status}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = DisputeResolutionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        with transaction.atomic():
            dispute.status = 'RESOLVED'
            dispute.resolution = serializer.validated_data['resolution']
            dispute.resolution_notes = serializer.validated_data.get('resolution_notes', '')
            dispute.resolved_by = request.user
            dispute.save()

            from auditlog.models import AuditLog
            AuditLog.log(
                actor=request.user,
                action='DISPUTE_RESOLVED',
                entity_type='Dispute',
                entity_id=dispute.id,
                league=dispute.league,
                after={
                    'status': dispute.status,
                    'resolution': dispute.resolution,
                    'resolution_notes': dispute.resolution_notes,
                },
                metadata={'league_id': league_id},
            )

        return Response(DisputeSerializer(dispute).data)


class DisputeCommentCreateView(generics.CreateAPIView):
    serializer_class = DisputeCommentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        league_id = self.kwargs['league_id']
        dispute_id = self.kwargs['dispute_id']
        dispute = get_object_or_404(Dispute, id=dispute_id, league_id=league_id)
        serializer.save(user=self.request.user, dispute=dispute)
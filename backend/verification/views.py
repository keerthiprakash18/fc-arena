from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.db import transaction
from matches.models import Match
from leagues.models import LeagueMember
from .models import VerificationTask, ExtractionResult
from .serializers import (
    VerificationTaskSerializer, ExtractionResultSerializer,
    AdminReviewSerializer
)
from .services import create_verification_task, process_verification, admin_review


class TriggerVerificationView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']

        match = get_object_or_404(Match, id=match_id, league_id=league_id)

        if match.status != 'EVIDENCE_SUBMITTED':
            return Response(
                {'error': f'Match not ready for verification. Status: {match.status}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        evidence = match.stored_evidence.filter(is_valid=True).first()
        if not evidence:
            return Response(
                {'error': 'No valid evidence found for this match.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        with transaction.atomic():
            task = create_verification_task(match, evidence)
            task = process_verification(task)

        return Response(VerificationTaskSerializer(task).data)


class VerificationTaskDetailView(generics.RetrieveAPIView):
    serializer_class = VerificationTaskSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']
        return get_object_or_404(
            VerificationTask,
            match_id=match_id,
            match__league_id=league_id
        )


class AdminReviewView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']

        league_member = LeagueMember.objects.filter(
            league_id=league_id,
            user=request.user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            is_active=True
        ).first()
        if not league_member:
            return Response(
                {'error': 'Only league admins can review verifications.'},
                status=status.HTTP_403_FORBIDDEN
            )

        task = get_object_or_404(
            VerificationTask,
            match_id=match_id,
            match__league_id=league_id
        )

        serializer = AdminReviewSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        approved = serializer.validated_data['approved']
        notes = serializer.validated_data.get('notes', '')

        task, message = admin_review(task, approved, request.user, notes)

        from auditlog.models import AuditLog
        AuditLog.log(
            actor=request.user,
            action='VERIFICATION_REVIEWED',
            entity_type='VerificationTask',
            entity_id=task.id,
            league=task.match.league,
            after={
                'status': task.status,
                'approved': approved,
                'notes': notes,
            },
            metadata={'match_id': match_id, 'league_id': league_id},
        )

        return Response(VerificationTaskSerializer(task).data)


class VerificationResultsView(generics.ListAPIView):
    serializer_class = ExtractionResultSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']
        return ExtractionResult.objects.filter(
            verification_task__match_id=match_id,
            verification_task__match__league_id=league_id
        )
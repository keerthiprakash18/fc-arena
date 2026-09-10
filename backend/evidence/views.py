import base64
import os
import re
from django.conf import settings
from django.http import FileResponse, Http404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from matches.models import Match
from .models import EvidenceStorage
from .serializers import EvidenceStorageSerializer, EvidenceUploadSerializer


def _safe_file_name(name):
    name = re.sub(r'[^A-Za-z0-9._-]+', '_', name or 'evidence')
    return name[:120]


class EvidenceUploadView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']

        match = get_object_or_404(Match, id=match_id, league_id=league_id)

        user = request.user
        if user != match.home_user and user != match.away_user:
            return Response(
                {'error': 'You are not a participant of this match.'},
                status=status.HTTP_403_FORBIDDEN
            )

        if match.status not in ['AWAITING_RESULT', 'EVIDENCE_SUBMITTED']:
            return Response(
                {'error': f'Match not accepting evidence. Current status: {match.status}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = EvidenceUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        file_content = base64.b64decode(data['file_content_base64'])
        checksum = EvidenceStorage.compute_checksum(file_content)

        existing = EvidenceStorage.objects.filter(match=match, checksum=checksum).first()
        if existing:
            return Response(
                EvidenceStorageSerializer(existing).data,
                status=status.HTTP_200_OK
            )

        file_reference = f"evidence/{match_id}/{checksum[:16]}_{_safe_file_name(data['file_name'])}"

        evidence = EvidenceStorage.objects.create(
            match=match,
            uploaded_by=user,
            file_name=data['file_name'],
            file_reference=file_reference,
            file_size=data['file_size'],
            file_type=data['file_type'],
            checksum=checksum,
        )
        evidence.validate()

        from django.core.files.base import ContentFile
        from django.core.files.storage import default_storage
        default_storage.save(file_reference, ContentFile(file_content))

        return Response(
            EvidenceStorageSerializer(evidence).data,
            status=status.HTTP_201_CREATED
        )


class EvidenceFileView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        evidence_id = self.kwargs['evidence_id']
        evidence = get_object_or_404(
            EvidenceStorage,
            id=evidence_id,
            match_id=self.kwargs['match_id'],
            match__league_id=league_id,
        )

        participant = (
            request.user == evidence.match.home_user
            or request.user == evidence.match.away_user
            or request.user.is_superuser
        )
        from leagues.models import LeagueMember
        admin = LeagueMember.objects.filter(
            league_id=league_id,
            user=request.user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            is_active=True,
        ).exists()
        if not (participant or admin):
            return Response(
                {'error': 'You are not allowed to view this evidence.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        from django.core.files.storage import default_storage
        if not default_storage.exists(evidence.file_reference):
            raise Http404('Evidence file not found.')

        return FileResponse(
            default_storage.open(evidence.file_reference, 'rb'),
            content_type=evidence.file_type or 'application/octet-stream',
        )


class EvidenceListView(generics.ListAPIView):
    serializer_class = EvidenceStorageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']
        return EvidenceStorage.objects.filter(
            match_id=match_id,
            match__league_id=league_id
        )
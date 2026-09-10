from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.db import transaction
from django.utils import timezone
from leagues.models import League
from .models import (
    Match, MatchEvidence, MatchStatistics,
    MatchVerification, MatchStateTransition
)
from .serializers import (
    MatchSerializer, MatchCreateSerializer,
    MatchEvidenceSerializer, MatchStatisticsSerializer,
    MatchVerificationSerializer, MatchStateTransitionSerializer,
    MatchStatusUpdateSerializer
)
from .permissions import IsMatchLeagueMember, IsMatchLeagueAdmin


class MatchListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return MatchCreateSerializer
        return MatchSerializer

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        queryset = Match.objects.filter(league_id=league_id).select_related(
            'home_user', 'away_user', 'league'
        )
        tournament_id = self.request.query_params.get('tournament_id')
        if tournament_id:
            queryset = queryset.filter(tournament_id=tournament_id)
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        return queryset

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['league'] = get_object_or_404(League, id=self.kwargs['league_id'])
        return context

    def perform_create(self, serializer):
        serializer.save()


class MatchDetailView(generics.RetrieveAPIView):
    serializer_class = MatchSerializer
    permission_classes = [permissions.IsAuthenticated, IsMatchLeagueMember]

    def get_object(self):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']
        return get_object_or_404(
            Match.objects.select_related('home_user', 'away_user', 'league'),
            id=match_id, league_id=league_id
        )


class MatchStatusUpdateView(generics.GenericAPIView):
    serializer_class = MatchStatusUpdateSerializer
    permission_classes = [permissions.IsAuthenticated, IsMatchLeagueAdmin]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']
        match = get_object_or_404(Match, id=match_id, league_id=league_id)

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        new_status = serializer.validated_data['status']

        with transaction.atomic():
            old_status = match.status
            success, message = match.transition_to(new_status)
            if not success:
                return Response({'error': message}, status=status.HTTP_409_CONFLICT)

            from auditlog.models import AuditLog
            AuditLog.log(
                actor=request.user,
                action='MATCH_STATUS_CHANGED',
                entity_type='Match',
                entity_id=match.id,
                league=match.league,
                before={'status': old_status},
                after={'status': new_status},
                metadata={'league_id': league_id},
            )

            MatchStateTransition.objects.create(
                match=match,
                from_status=old_status,
                to_status=new_status,
                created_by=request.user
            )

            if new_status == 'AWAITING_RESULT':
                match.played_at = timezone.now()
                match.save(update_fields=['played_at'])

        return Response(MatchSerializer(match).data)


class MatchSubmitResultView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated, IsMatchLeagueMember]

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

        if match.status != 'AWAITING_RESULT':
            return Response(
                {'error': f'Match is not in AWAITING_RESULT state. Current: {match.status}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        home_score = request.data.get('home_score')
        away_score = request.data.get('away_score')

        if home_score is None or away_score is None:
            return Response(
                {'error': 'home_score and away_score are required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if home_score < 0 or away_score < 0:
            return Response(
                {'error': 'Scores cannot be negative.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        with transaction.atomic():
            match.home_score = home_score
            match.away_score = away_score

            success, message = match.transition_to('EVIDENCE_SUBMITTED')
            if not success:
                return Response({'error': message}, status=status.HTTP_409_CONFLICT)

            MatchStatistics.objects.update_or_create(
                match=match,
                defaults={
                    'home_possession': request.data.get('home_possession'),
                    'away_possession': request.data.get('away_possession'),
                    'home_shots': request.data.get('home_shots'),
                    'away_shots': request.data.get('away_shots'),
                    'home_shots_on_target': request.data.get('home_shots_on_target'),
                    'away_shots_on_target': request.data.get('away_shots_on_target'),
                    'home_pass_accuracy': request.data.get('home_pass_accuracy'),
                    'away_pass_accuracy': request.data.get('away_pass_accuracy'),
                }
            )

        return Response(MatchSerializer(match).data)


class MatchEvidenceListCreateView(generics.ListCreateAPIView):
    serializer_class = MatchEvidenceSerializer
    permission_classes = [permissions.IsAuthenticated, IsMatchLeagueMember]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']
        return MatchEvidence.objects.filter(
            match_id=match_id,
            match__league_id=league_id
        )

    def perform_create(self, serializer):
        match = get_object_or_404(Match, id=self.kwargs['match_id'], league_id=self.kwargs['league_id'])
        serializer.save(match=match, uploaded_by=self.request.user)


class MatchStatisticsView(generics.RetrieveUpdateAPIView):
    serializer_class = MatchStatisticsSerializer
    permission_classes = [permissions.IsAuthenticated, IsMatchLeagueMember]

    def get_object(self):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']
        match = get_object_or_404(Match, id=match_id, league_id=league_id)
        stats, created = MatchStatistics.objects.get_or_create(match=match)
        return stats


class MatchVerificationView(generics.RetrieveAPIView):
    serializer_class = MatchVerificationSerializer
    permission_classes = [permissions.IsAuthenticated, IsMatchLeagueMember]

    def get_object(self):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']
        return get_object_or_404(
            MatchVerification,
            match_id=match_id,
            match__league_id=league_id
        )


class MatchTransitionsView(generics.ListAPIView):
    serializer_class = MatchStateTransitionSerializer
    permission_classes = [permissions.IsAuthenticated, IsMatchLeagueMember]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        match_id = self.kwargs['match_id']
        return MatchStateTransition.objects.filter(
            match_id=match_id,
            match__league_id=league_id
        )
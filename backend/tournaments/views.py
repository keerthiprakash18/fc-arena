from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.db import transaction
from leagues.models import League, LeagueMember
from .models import (
    Tournament, TournamentParticipant, TournamentGroup,
    TournamentRound, TournamentStateTransition
)
from .serializers import (
    TournamentSerializer, TournamentCreateSerializer,
    TournamentStatusUpdateSerializer, TournamentParticipantSerializer,
    TournamentGroupSerializer, TournamentRoundSerializer,
    TournamentStateTransitionSerializer
)
from .permissions import IsTournamentLeagueMember, IsTournamentLeagueAdmin
from .services import generate_fixtures


class TournamentListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return TournamentCreateSerializer
        return TournamentSerializer

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        return Tournament.objects.filter(league_id=league_id)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        league_id = self.kwargs['league_id']
        context['league'] = get_object_or_404(League, id=league_id)
        return context

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class TournamentDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = TournamentSerializer
    permission_classes = [permissions.IsAuthenticated, IsTournamentLeagueMember]

    def get_object(self):
        league_id = self.kwargs['league_id']
        tournament_id = self.kwargs['tournament_id']
        return get_object_or_404(Tournament, id=tournament_id, league_id=league_id)


class TournamentStatusUpdateView(generics.GenericAPIView):
    serializer_class = TournamentStatusUpdateSerializer
    permission_classes = [permissions.IsAuthenticated, IsTournamentLeagueAdmin]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        tournament_id = self.kwargs['tournament_id']
        tournament = get_object_or_404(Tournament, id=tournament_id, league_id=league_id)

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        new_status = serializer.validated_data['status']

        with transaction.atomic():
            old_status = tournament.status
            success, message = tournament.transition_to(new_status)
            if not success:
                return Response(
                    {'error': message},
                    status=status.HTTP_409_CONFLICT
                )

            TournamentStateTransition.objects.create(
                tournament=tournament,
                from_status=old_status,
                to_status=new_status,
                created_by=request.user
            )

        return Response(TournamentSerializer(tournament).data)


class TournamentRegisterView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated, IsTournamentLeagueMember]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        tournament_id = self.kwargs['tournament_id']
        tournament = get_object_or_404(Tournament, id=tournament_id, league_id=league_id)

        if tournament.status != 'REGISTRATION_OPEN':
            return Response(
                {'error': 'Registration is not open for this tournament.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        current_count = tournament.participants.exclude(status='WITHDRAWN').count()
        if current_count >= tournament.max_participants:
            return Response(
                {'error': 'Tournament is full.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        participant, created = TournamentParticipant.objects.get_or_create(
            tournament=tournament,
            user=request.user,
            defaults={'status': 'REGISTERED'}
        )

        if not created:
            return Response(
                {'error': 'You are already registered for this tournament.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        return Response(
            TournamentParticipantSerializer(participant).data,
            status=status.HTTP_201_CREATED
        )


class TournamentParticipantsView(generics.ListAPIView):
    serializer_class = TournamentParticipantSerializer
    permission_classes = [permissions.IsAuthenticated, IsTournamentLeagueMember]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        tournament_id = self.kwargs['tournament_id']
        return TournamentParticipant.objects.filter(
            tournament_id=tournament_id,
            tournament__league_id=league_id
        ).select_related('user')


class TournamentGroupsView(generics.ListCreateAPIView):
    serializer_class = TournamentGroupSerializer
    permission_classes = [permissions.IsAuthenticated, IsTournamentLeagueAdmin]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        tournament_id = self.kwargs['tournament_id']
        return TournamentGroup.objects.filter(
            tournament_id=tournament_id,
            tournament__league_id=league_id
        )

    def perform_create(self, serializer):
        tournament = get_object_or_404(
            Tournament,
            id=self.kwargs['tournament_id'],
            league_id=self.kwargs['league_id']
        )
        serializer.save(tournament=tournament)


class TournamentRoundsView(generics.ListCreateAPIView):
    serializer_class = TournamentRoundSerializer
    permission_classes = [permissions.IsAuthenticated, IsTournamentLeagueAdmin]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        tournament_id = self.kwargs['tournament_id']
        return TournamentRound.objects.filter(
            tournament_id=tournament_id,
            tournament__league_id=league_id
        )

    def perform_create(self, serializer):
        tournament = get_object_or_404(
            Tournament,
            id=self.kwargs['tournament_id'],
            league_id=self.kwargs['league_id']
        )
        serializer.save(tournament=tournament)


class TournamentFixturesView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated, IsTournamentLeagueAdmin]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        tournament_id = self.kwargs['tournament_id']
        tournament = get_object_or_404(Tournament, id=tournament_id, league_id=league_id)

        if tournament.status not in ['REGISTRATION_CLOSED', 'SEEDING', 'FIXTURES_GENERATING']:
            return Response(
                {'error': f'Fixtures can only be generated after registration closes. Current status: {tournament.status}'},
                status=status.HTTP_409_CONFLICT,
            )

        if tournament.participants.exclude(status='WITHDRAWN').count() < 2:
            return Response(
                {'error': 'At least 2 participants are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        count, message = generate_fixtures(tournament)
        return Response({'matches_created': count, 'message': message, 'status': tournament.status})


class TournamentTransitionsView(generics.ListAPIView):
    serializer_class = TournamentStateTransitionSerializer
    permission_classes = [permissions.IsAuthenticated, IsTournamentLeagueMember]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        tournament_id = self.kwargs['tournament_id']
        return TournamentStateTransition.objects.filter(
            tournament_id=tournament_id,
            tournament__league_id=league_id
        )
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from leagues.models import League
from .models import Season, SeasonMember
from .serializers import (
    SeasonSerializer, SeasonCreateSerializer, SeasonMemberSerializer
)
from .permissions import IsSeasonLeagueMember, IsSeasonLeagueAdmin


class SeasonListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return SeasonCreateSerializer
        return SeasonSerializer

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        return Season.objects.filter(league_id=league_id)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        league_id = self.kwargs['league_id']
        context['league'] = get_object_or_404(League, id=league_id)
        return context

    def perform_create(self, serializer):
        league = get_object_or_404(League, id=self.kwargs['league_id'])
        serializer.save(league=league)


class SeasonDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = SeasonSerializer
    permission_classes = [permissions.IsAuthenticated, IsSeasonLeagueMember]

    def get_object(self):
        league_id = self.kwargs['league_id']
        season_id = self.kwargs['season_id']
        return get_object_or_404(Season, id=season_id, league_id=league_id)


class SeasonCurrentView(generics.RetrieveAPIView):
    serializer_class = SeasonSerializer
    permission_classes = [permissions.IsAuthenticated, IsSeasonLeagueMember]

    def get_object(self):
        league_id = self.kwargs['league_id']
        return get_object_or_404(Season, league_id=league_id, is_current=True)


class SeasonJoinView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated, IsSeasonLeagueMember]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        season_id = self.kwargs['season_id']
        season = get_object_or_404(Season, id=season_id, league_id=league_id)

        membership, created = SeasonMember.objects.get_or_create(
            season=season,
            user=request.user,
            defaults={'is_active': True}
        )

        if not created and not membership.is_active:
            membership.is_active = True
            membership.save()

        return Response(
            SeasonMemberSerializer(membership).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
        )


class SeasonMembersView(generics.ListAPIView):
    serializer_class = SeasonMemberSerializer
    permission_classes = [permissions.IsAuthenticated, IsSeasonLeagueMember]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        season_id = self.kwargs['season_id']
        return SeasonMember.objects.filter(
            season_id=season_id,
            season__league_id=league_id,
            is_active=True
        ).select_related('user')
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from leagues.models import League

from .models import Team, TeamMember
from .permissions import IsTeamLeagueAdmin, IsTeamLeagueMember
from .serializers import (
    TeamMemberCreateSerializer,
    TeamMemberSerializer,
    TeamSerializer,
    TeamStatisticsSerializer,
    TeamWriteSerializer,
)
from .services import recompute_team_statistics, team_standings

MAX_IMAGE_BYTES = 5 * 1024 * 1024
ALLOWED_IMAGE_TYPES = {'image/png', 'image/jpeg', 'image/jpg', 'image/webp'}


def _league(league_id):
    return get_object_or_404(League, id=league_id, is_active=True)


def _team(league_id, team_id):
    return get_object_or_404(
        Team.objects.select_related('captain', 'manager', 'league'),
        id=team_id, league_id=league_id,
    )


def _validate_image(uploaded):
    """Return an error string, or None when the upload is acceptable."""
    if uploaded is None:
        return 'No file was uploaded.'
    if uploaded.size > MAX_IMAGE_BYTES:
        return (f'Image is too large ({uploaded.size} bytes). '
                f'Maximum is {MAX_IMAGE_BYTES} bytes (5 MB).')
    content_type = (getattr(uploaded, 'content_type', '') or '').lower()
    if content_type and content_type not in ALLOWED_IMAGE_TYPES:
        return f'Unsupported image type "{content_type}". Use PNG, JPEG or WebP.'
    return None


class TeamListCreateView(generics.ListCreateAPIView):
    """GET: list a league's teams. POST: create a team (league admin only)."""

    def get_serializer_class(self):
        return TeamWriteSerializer if self.request.method == 'POST' else TeamSerializer

    def get_queryset(self):
        qs = Team.objects.filter(league_id=self.kwargs['league_id'], is_active=True)
        params = self.request.query_params
        if params.get('game'):
            qs = qs.filter(game__iexact=params['game'])
        if params.get('search'):
            qs = qs.filter(name__icontains=params['search'])
        return qs.select_related('captain', 'manager').prefetch_related('members__user')

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['league'] = _league(self.kwargs['league_id'])
        return ctx

    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAuthenticated(), IsTeamLeagueAdmin()]
        return [permissions.IsAuthenticated(), IsTeamLeagueMember()]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        team = serializer.save()
        return Response(
            TeamSerializer(team, context=self.get_serializer_context()).data,
            status=status.HTTP_201_CREATED,
        )


class TeamDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET a team profile. PATCH/PUT/DELETE require league admin.

    DELETE is a soft delete (``is_active = False``) so match history survives.
    """

    def get_serializer_class(self):
        if self.request.method in ('PUT', 'PATCH'):
            return TeamWriteSerializer
        return TeamSerializer

    def get_object(self):
        return _team(self.kwargs['league_id'], self.kwargs['team_id'])

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['league'] = _league(self.kwargs['league_id'])
        return ctx

    def get_permissions(self):
        if self.request.method in ('PUT', 'PATCH', 'DELETE'):
            return [permissions.IsAuthenticated(), IsTeamLeagueAdmin()]
        return [permissions.IsAuthenticated(), IsTeamLeagueMember()]

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        team = serializer.save()
        return Response(TeamSerializer(team, context=self.get_serializer_context()).data)

    def destroy(self, request, *args, **kwargs):
        team = self.get_object()
        team.is_active = False
        team.save(update_fields=['is_active', 'updated_at'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class TeamMembersView(generics.ListCreateAPIView):
    """GET the roster. POST adds a player (league admin only)."""

    def get_serializer_class(self):
        return TeamMemberCreateSerializer if self.request.method == 'POST' else TeamMemberSerializer

    def get_queryset(self):
        return TeamMember.objects.filter(
            team_id=self.kwargs['team_id'],
            team__league_id=self.kwargs['league_id'],
            is_active=True,
        ).select_related('user')

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['team'] = _team(self.kwargs['league_id'], self.kwargs['team_id'])
        return ctx

    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAuthenticated(), IsTeamLeagueAdmin()]
        return [permissions.IsAuthenticated(), IsTeamLeagueMember()]

    def create(self, request, *args, **kwargs):
        team = self.get_serializer_context()['team']
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        member = serializer.save(team=team)
        return Response(TeamMemberSerializer(member).data, status=status.HTTP_201_CREATED)


class TeamMemberManageView(generics.RetrieveUpdateDestroyAPIView):
    """PATCH a member's role/number/position. DELETE soft-removes them."""

    serializer_class = TeamMemberSerializer
    permission_classes = [permissions.IsAuthenticated, IsTeamLeagueAdmin]

    def get_object(self):
        return get_object_or_404(
            TeamMember.objects.select_related('user'),
            team_id=self.kwargs['team_id'],
            team__league_id=self.kwargs['league_id'],
            pk=self.kwargs['member_id'],
        )

    def destroy(self, request, *args, **kwargs):
        member = self.get_object()
        member.is_active = False
        member.save(update_fields=['is_active'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class _TeamImageView(generics.GenericAPIView):
    """Shared implementation for the logo and banner upload endpoints."""

    permission_classes = [permissions.IsAuthenticated, IsTeamLeagueAdmin]
    parser_classes = [MultiPartParser, FormParser]
    field_name = 'logo'

    def post(self, request, *args, **kwargs):
        team = _team(self.kwargs['league_id'], self.kwargs['team_id'])
        uploaded = request.FILES.get(self.field_name)
        error = _validate_image(uploaded)
        if error:
            return Response({'error': error}, status=status.HTTP_400_BAD_REQUEST)
        setattr(team, self.field_name, uploaded)
        team.save(update_fields=[self.field_name, 'updated_at'])
        return Response(TeamSerializer(team, context={'request': request}).data)

    def delete(self, request, *args, **kwargs):
        team = _team(self.kwargs['league_id'], self.kwargs['team_id'])
        setattr(team, self.field_name, None)
        team.save(update_fields=[self.field_name, 'updated_at'])
        return Response(TeamSerializer(team, context={'request': request}).data)


class TeamLogoView(_TeamImageView):
    field_name = 'logo'


class TeamBannerView(_TeamImageView):
    field_name = 'banner'


class TeamStandingsView(generics.GenericAPIView):
    """League team table, ranked by points, then goal difference, then goals."""

    permission_classes = [permissions.IsAuthenticated, IsTeamLeagueMember]

    def get(self, request, *args, **kwargs):
        league = _league(self.kwargs['league_id'])
        payload = []
        for row in team_standings(league):
            team = row['team']
            stats = row['statistics']
            payload.append({
                'rank': row['rank'],
                'team_id': team.id,
                'name': team.name,
                'short_name': team.short_name,
                'logo_url': request.build_absolute_uri(team.logo.url) if team.logo else None,
                'statistics': TeamStatisticsSerializer(stats).data if stats else None,
            })
        return Response(payload)


class TeamStatisticsView(generics.GenericAPIView):
    """GET a team's current statistics. POST recomputes them (league admin).

    Recomputing is a POST because it writes — a GET must stay side-effect free.
    """

    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAuthenticated(), IsTeamLeagueAdmin()]
        return [permissions.IsAuthenticated(), IsTeamLeagueMember()]

    def get(self, request, *args, **kwargs):
        team = _team(self.kwargs['league_id'], self.kwargs['team_id'])
        stats = getattr(team, 'statistics', None)
        return Response(TeamStatisticsSerializer(stats).data if stats else None)

    def post(self, request, *args, **kwargs):
        team = _team(self.kwargs['league_id'], self.kwargs['team_id'])
        stats = recompute_team_statistics(team)
        return Response(TeamStatisticsSerializer(stats).data)

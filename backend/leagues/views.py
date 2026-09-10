from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import League, LeagueMember
from .serializers import (
    LeagueSerializer, LeagueCreateSerializer,
    LeagueJoinSerializer, LeagueMemberSerializer
)
from .permissions import IsLeagueMember, IsLeagueAdmin


class LeagueListCreateView(generics.ListCreateAPIView):
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return LeagueCreateSerializer
        return LeagueSerializer

    def get_queryset(self):
        user = self.request.user
        member_league_ids = LeagueMember.objects.filter(
            user=user, is_active=True
        ).values_list('league_id', flat=True)
        return League.objects.filter(id__in=member_league_ids)

    def get_permissions(self):
        if self.request.method == 'POST':
            return [permissions.IsAuthenticated()]
        return [permissions.IsAuthenticated()]


class LeagueDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = LeagueSerializer
    permission_classes = [permissions.IsAuthenticated, IsLeagueMember]

    def get_permissions(self):
        if self.request.method in ['PUT', 'PATCH']:
            return [permissions.IsAuthenticated(), IsLeagueAdmin()]
        return [permissions.IsAuthenticated(), IsLeagueMember()]

    def get_object(self):
        league_id = self.kwargs['league_id']
        return get_object_or_404(League, id=league_id, is_active=True)


class LeagueJoinView(generics.GenericAPIView):
    serializer_class = LeagueJoinSerializer
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        membership = serializer.save()
        return Response(
            LeagueMemberSerializer(membership).data,
            status=status.HTTP_201_CREATED
        )


class LeagueMembersView(generics.ListAPIView):
    serializer_class = LeagueMemberSerializer
    permission_classes = [permissions.IsAuthenticated, IsLeagueMember]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        return LeagueMember.objects.filter(
            league_id=league_id, is_active=True
        ).select_related('user')


class LeagueMemberManageView(generics.RetrieveUpdateDestroyAPIView):
    """
    Admin/owner manages a member: PATCH to change role, DELETE to remove.
    """
    permission_classes = [permissions.IsAuthenticated, IsLeagueAdmin]

    def get_queryset(self):
        return LeagueMember.objects.filter(
            league_id=self.kwargs['league_id'], is_active=True
        ).select_related('user')

    def get_serializer_class(self):
        if self.request.method == 'GET':
            return LeagueMemberSerializer
        return LeagueMemberSerializer

    def get_serializer_context(self):
        context = super().get_serializer_context()
        league = get_object_or_404(League, id=self.kwargs['league_id'], is_active=True)
        context['league'] = league
        return context

    def get_object(self):
        return get_object_or_404(LeagueMember,
                                 league_id=self.kwargs['league_id'],
                                 user_id=self.kwargs['user_id'],
                                 is_active=True)

    def update(self, request, *args, **kwargs):
        member = self.get_object()
        league = League.objects.get(id=self.kwargs['league_id'])

        if member.role == 'LEAGUE_OWNER':
            return Response({'error': 'Owner role cannot be changed.'},
                            status=status.HTTP_403_FORBIDDEN)

        role = request.data.get('role')
        valid_roles = ['LEAGUE_ADMIN', 'TOURNAMENT_ADMIN', 'PLAYER']
        if role not in valid_roles:
            return Response({'error': 'Invalid role.'}, status=status.HTTP_400_BAD_REQUEST)
        if role == 'LEAGUE_ADMIN' and request.user.id != league.owner_id:
            return Response({'error': 'Only the league owner can promote admins.'},
                            status=status.HTTP_403_FORBIDDEN)

        member.role = role
        member.save(update_fields=['role'])
        return Response(LeagueMemberSerializer(member).data)

    def destroy(self, request, *args, **kwargs):
        member = self.get_object()
        if member.role == 'LEAGUE_OWNER':
            return Response({'error': 'Owner cannot be removed.'},
                            status=status.HTTP_403_FORBIDDEN)
        if member.role == 'LEAGUE_ADMIN' and request.user.id != member.league.owner_id:
            return Response({'error': 'Only the owner can remove admins.'},
                            status=status.HTTP_403_FORBIDDEN)
        member.is_active = False
        member.save(update_fields=['is_active'])
        return Response(status=status.HTTP_204_NO_CONTENT)
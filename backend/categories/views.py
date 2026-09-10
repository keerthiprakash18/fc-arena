from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.contrib.auth import get_user_model
from leagues.models import League, LeagueMember
from .models import Category, PlayerCategory
from .serializers import (
    CategorySerializer, CategoryCreateSerializer,
    PlayerCategorySerializer, PlayerCategoryAssignSerializer
)

User = get_user_model()


class CategoryListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return CategoryCreateSerializer
        return CategorySerializer

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        return Category.objects.filter(league_id=league_id)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['league'] = get_object_or_404(League, id=self.kwargs['league_id'])
        return context

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        category = serializer.instance
        headers = self.get_success_headers(serializer.data)
        out = CategorySerializer(category, context=self.get_serializer_context()).data
        return Response(out, status=status.HTTP_201_CREATED, headers=headers)


class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CategorySerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_url_kwarg = 'category_id'

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        return Category.objects.filter(league_id=league_id)


class CategoryAssignPlayerView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        category_id = self.kwargs['category_id']

        league_member = LeagueMember.objects.filter(
            league_id=league_id,
            user=request.user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            is_active=True
        ).first()
        if not league_member:
            return Response({'error': 'Only league admins can assign players.'},
                          status=status.HTTP_403_FORBIDDEN)

        serializer = PlayerCategoryAssignSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        player = get_object_or_404(User, id=serializer.validated_data['player_id'])
        category = get_object_or_404(Category, id=category_id, league_id=league_id)

        if serializer.validated_data.get('is_primary', True):
            PlayerCategory.objects.filter(
                player=player, category__league_id=league_id, is_primary=True
            ).update(is_primary=False)

        pc, created = PlayerCategory.objects.get_or_create(
            player=player,
            category=category,
            defaults={'is_primary': serializer.validated_data.get('is_primary', True)}
        )

        return Response(
            PlayerCategorySerializer(pc).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
        )


class CategoryPlayersView(generics.ListAPIView):
    serializer_class = PlayerCategorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        category_id = self.kwargs['category_id']
        return PlayerCategory.objects.filter(
            category_id=category_id,
            category__league_id=league_id,
        ).select_related('player', 'category')


class CategoryPlayerRemoveView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, *args, **kwargs):
        league_id = self.kwargs['league_id']
        category_id = self.kwargs['category_id']
        player_id = self.kwargs['player_id']

        league_member = LeagueMember.objects.filter(
            league_id=league_id,
            user=request.user,
            role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            is_active=True
        ).first()
        if not league_member:
            return Response({'error': 'Only league admins can remove players.'},
                          status=status.HTTP_403_FORBIDDEN)

        get_object_or_404(Category, id=category_id, league_id=league_id)
        deleted, _ = PlayerCategory.objects.filter(
            player_id=player_id, category_id=category_id
        ).delete()
        if deleted == 0:
            return Response({'error': 'Player is not assigned to this category.'},
                          status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MyCategoriesView(generics.ListAPIView):
    serializer_class = PlayerCategorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        league_id = self.kwargs['league_id']
        return PlayerCategory.objects.filter(
            player=self.request.user,
            category__league_id=league_id,
        ).select_related('player', 'category')

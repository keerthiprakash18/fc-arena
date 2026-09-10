from django.urls import path
from .views import (
    CategoryListCreateView, CategoryDetailView,
    CategoryAssignPlayerView, CategoryPlayersView,
    CategoryPlayerRemoveView, MyCategoriesView
)

urlpatterns = [
    path('leagues/<int:league_id>/categories/',
         CategoryListCreateView.as_view(), name='category-list-create'),
    path('leagues/<int:league_id>/categories/my/',
         MyCategoriesView.as_view(), name='category-my'),
    path('leagues/<int:league_id>/categories/<int:category_id>/',
         CategoryDetailView.as_view(), name='category-detail'),
    path('leagues/<int:league_id>/categories/<int:category_id>/assign/',
         CategoryAssignPlayerView.as_view(), name='category-assign'),
    path('leagues/<int:league_id>/categories/<int:category_id>/players/',
         CategoryPlayersView.as_view(), name='category-players'),
    path('leagues/<int:league_id>/categories/<int:category_id>/players/<int:player_id>/',
         CategoryPlayerRemoveView.as_view(), name='category-player-remove'),
]

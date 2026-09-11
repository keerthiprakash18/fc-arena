from django.contrib import admin
from .models import Category, PlayerCategory


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'league', 'min_rating', 'max_rating', 'is_active', 'created_at']
    list_filter = ['is_active', 'created_at', 'league']
    search_fields = ['name', 'league__name']
    readonly_fields = ['slug', 'created_at', 'updated_at']


@admin.register(PlayerCategory)
class PlayerCategoryAdmin(admin.ModelAdmin):
    list_display = ['player', 'category', 'is_primary', 'assigned_at']
    list_filter = ['is_primary', 'assigned_at', 'category__league']
    search_fields = ['player__username', 'category__name']
    readonly_fields = ['assigned_at']

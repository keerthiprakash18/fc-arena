from django.contrib import admin
from .models import League, LeagueMember


@admin.register(League)
class LeagueAdmin(admin.ModelAdmin):
    list_display = ['name', 'league_code', 'owner', 'is_active', 'created_at']
    search_fields = ['name', 'league_code']
    list_filter = ['is_active', 'created_at']


@admin.register(LeagueMember)
class LeagueMemberAdmin(admin.ModelAdmin):
    list_display = ['user', 'league', 'role', 'is_active', 'joined_at']
    list_filter = ['role', 'is_active']
    search_fields = ['user__username', 'league__name']
from django.contrib import admin

from .models import Team, TeamMember, TeamStatistics


class TeamMemberInline(admin.TabularInline):
    model = TeamMember
    extra = 0
    autocomplete_fields = ['user']


@admin.register(Team)
class TeamAdmin(admin.ModelAdmin):
    list_display = ('name', 'short_name', 'league', 'captain', 'is_active', 'created_at')
    list_filter = ('is_active', 'league')
    search_fields = ('name', 'short_name', 'league__name')
    prepopulated_fields = {'slug': ('name',)}
    inlines = [TeamMemberInline]


@admin.register(TeamMember)
class TeamMemberAdmin(admin.ModelAdmin):
    list_display = ('user', 'team', 'role', 'jersey_number', 'is_active', 'joined_at')
    list_filter = ('role', 'is_active')
    search_fields = ('user__username', 'team__name')


@admin.register(TeamStatistics)
class TeamStatisticsAdmin(admin.ModelAdmin):
    list_display = ('team', 'matches_played', 'wins', 'draws', 'losses', 'points', 'updated_at')
    search_fields = ('team__name',)

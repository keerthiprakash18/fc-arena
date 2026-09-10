from django.contrib import admin
from .models import PlayerLeagueStatistics, LeagueStanding


@admin.register(PlayerLeagueStatistics)
class PlayerLeagueStatisticsAdmin(admin.ModelAdmin):
    list_display = ['user', 'league', 'season', 'matches_played', 'wins', 'goals_scored']
    list_filter = ['league', 'season']
    search_fields = ['user__username', 'league__name']


@admin.register(LeagueStanding)
class LeagueStandingAdmin(admin.ModelAdmin):
    list_display = ['rank', 'user', 'league', 'season', 'points', 'goal_difference']
    list_filter = ['league', 'season']
from django.contrib import admin
from .models import Leaderboard


@admin.register(Leaderboard)
class LeaderboardAdmin(admin.ModelAdmin):
    list_display = ['league', 'category', 'user', 'rank', 'value', 'season', 'tournament']
    list_filter = ['category', 'league']
    search_fields = ['user__username']
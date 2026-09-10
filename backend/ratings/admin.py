from django.contrib import admin
from .models import PlayerLeagueRating, RatingHistory


@admin.register(PlayerLeagueRating)
class PlayerLeagueRatingAdmin(admin.ModelAdmin):
    list_display = ['user', 'league', 'rating', 'peak_rating', 'matches_rated']
    list_filter = ['league']
    search_fields = ['user__username']


@admin.register(RatingHistory)
class RatingHistoryAdmin(admin.ModelAdmin):
    list_display = ['user', 'league', 'match', 'old_rating', 'new_rating', 'rating_change', 'result']
    list_filter = ['league', 'result']
    search_fields = ['user__username']
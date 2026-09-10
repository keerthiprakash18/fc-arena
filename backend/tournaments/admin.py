from django.contrib import admin
from .models import (
    Tournament, TournamentParticipant, TournamentGroup,
    TournamentRound, TournamentStateTransition
)


@admin.register(Tournament)
class TournamentAdmin(admin.ModelAdmin):
    list_display = ['name', 'league', 'format', 'status', 'tournament_code', 'created_at']
    list_filter = ['status', 'format', 'league']
    search_fields = ['name', 'tournament_code']


@admin.register(TournamentParticipant)
class TournamentParticipantAdmin(admin.ModelAdmin):
    list_display = ['user', 'tournament', 'status', 'seed_number', 'registered_at']
    list_filter = ['status', 'tournament']


@admin.register(TournamentGroup)
class TournamentGroupAdmin(admin.ModelAdmin):
    list_display = ['name', 'tournament', 'group_number']


@admin.register(TournamentRound)
class TournamentRoundAdmin(admin.ModelAdmin):
    list_display = ['name', 'tournament', 'round_number', 'is_current']


@admin.register(TournamentStateTransition)
class TournamentStateTransitionAdmin(admin.ModelAdmin):
    list_display = ['tournament', 'from_status', 'to_status', 'created_by', 'created_at']
    list_filter = ['from_status', 'to_status']
from django.contrib import admin
from .models import (
    Match, MatchEvidence, MatchStatistics,
    MatchVerification, MatchStateTransition
)


@admin.register(Match)
class MatchAdmin(admin.ModelAdmin):
    list_display = ['id', 'home_user', 'away_user', 'home_score', 'away_score', 'status', 'league']
    list_filter = ['status', 'league']
    search_fields = ['home_user__username', 'away_user__username']


@admin.register(MatchEvidence)
class MatchEvidenceAdmin(admin.ModelAdmin):
    list_display = ['match', 'uploaded_by', 'source_type', 'is_primary', 'uploaded_at']
    list_filter = ['source_type', 'is_primary']


@admin.register(MatchStatistics)
class MatchStatisticsAdmin(admin.ModelAdmin):
    list_display = ['match', 'ai_confidence']


@admin.register(MatchVerification)
class MatchVerificationAdmin(admin.ModelAdmin):
    list_display = ['match', 'status', 'ai_confidence_score', 'verified_at']
    list_filter = ['status']


@admin.register(MatchStateTransition)
class MatchStateTransitionAdmin(admin.ModelAdmin):
    list_display = ['match', 'from_status', 'to_status', 'created_by', 'created_at']
    list_filter = ['from_status', 'to_status']
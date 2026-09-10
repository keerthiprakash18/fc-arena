from django.contrib import admin
from .models import VerificationTask, ExtractionResult


@admin.register(VerificationTask)
class VerificationTaskAdmin(admin.ModelAdmin):
    list_display = ['match', 'status', 'ai_confidence_score', 'ai_provider', 'verified_at']
    list_filter = ['status', 'ai_provider']
    search_fields = ['match__home_user__username', 'match__away_user__username']


@admin.register(ExtractionResult)
class ExtractionResultAdmin(admin.ModelAdmin):
    list_display = ['verification_task', 'field_name', 'field_value', 'confidence', 'is_reliable']
    list_filter = ['is_reliable', 'field_name']
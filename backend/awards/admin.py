from django.contrib import admin
from .models import Award, AwardAuditLog


@admin.register(Award)
class AwardAdmin(admin.ModelAdmin):
    list_display = ['award_type', 'user', 'league', 'season', 'source', 'awarded_at']
    list_filter = ['award_type', 'source', 'league']
    search_fields = ['user__username', 'custom_name']


@admin.register(AwardAuditLog)
class AwardAuditLogAdmin(admin.ModelAdmin):
    list_display = ['award', 'action', 'changed_by', 'reason', 'created_at']
    list_filter = ['action']
from django.contrib import admin
from .models import AuditLog


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ['timestamp', 'actor', 'action', 'entity_type', 'entity_id', 'league']
    list_filter = ['action', 'entity_type']
    search_fields = ['actor__username', 'action', 'entity_type']
    readonly_fields = ['timestamp']
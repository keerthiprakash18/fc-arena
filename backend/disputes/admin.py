from django.contrib import admin
from .models import Dispute, DisputeComment


@admin.register(Dispute)
class DisputeAdmin(admin.ModelAdmin):
    list_display = ['id', 'league', 'match', 'raised_by', 'reason', 'status', 'resolution', 'created_at']
    list_filter = ['status', 'reason', 'league']
    search_fields = ['raised_by__username', 'description']


@admin.register(DisputeComment)
class DisputeCommentAdmin(admin.ModelAdmin):
    list_display = ['dispute', 'user', 'comment', 'created_at']
    list_filter = ['user']
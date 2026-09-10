from django.contrib import admin
from .models import LeagueRecord


@admin.register(LeagueRecord)
class LeagueRecordAdmin(admin.ModelAdmin):
    list_display = ['league', 'record_type', 'user', 'value', 'is_current', 'achieved_at']
    list_filter = ['record_type', 'league', 'is_current']
    search_fields = ['user__username']
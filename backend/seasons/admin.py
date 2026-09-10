from django.contrib import admin
from .models import Season, SeasonMember


@admin.register(Season)
class SeasonAdmin(admin.ModelAdmin):
    list_display = ['name', 'league', 'status', 'is_current', 'start_date', 'end_date']
    list_filter = ['status', 'is_current', 'league']
    search_fields = ['name', 'league__name']


@admin.register(SeasonMember)
class SeasonMemberAdmin(admin.ModelAdmin):
    list_display = ['user', 'season', 'is_active', 'joined_at']
    list_filter = ['is_active', 'season']
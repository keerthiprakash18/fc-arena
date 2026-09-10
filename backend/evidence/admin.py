from django.contrib import admin
from .models import EvidenceStorage


@admin.register(EvidenceStorage)
class EvidenceStorageAdmin(admin.ModelAdmin):
    list_display = ['file_name', 'match', 'uploaded_by', 'file_type', 'file_size', 'is_valid', 'uploaded_at']
    list_filter = ['is_valid', 'file_type']
    search_fields = ['file_name', 'checksum']
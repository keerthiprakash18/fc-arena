from rest_framework import serializers
from .models import LeagueRecord


class LeagueRecordSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    record_type_display = serializers.CharField(source='get_record_type_display', read_only=True)

    class Meta:
        model = LeagueRecord
        fields = ['id', 'league', 'record_type', 'record_type_display',
                  'user', 'username', 'value', 'match', 'achieved_at',
                  'is_current', 'metadata']
        read_only_fields = ['id', 'achieved_at']
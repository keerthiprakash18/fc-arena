from rest_framework import serializers
from .models import MatchEvent


class MatchEventSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='player.username', read_only=True)
    assisted_by_name = serializers.CharField(source='assisted_by.username', read_only=True, default=None)
    event_type_display = serializers.CharField(source='get_event_type_display', read_only=True)

    class Meta:
        model = MatchEvent
        fields = ['id', 'match', 'event_type', 'event_type_display', 'minute',
                  'player', 'username', 'assisted_by', 'assisted_by_name',
                  'description', 'created_by', 'created_at']
        read_only_fields = ['id', 'created_by', 'created_at']


class MatchEventCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = MatchEvent
        fields = ['event_type', 'minute', 'player', 'assisted_by', 'description']
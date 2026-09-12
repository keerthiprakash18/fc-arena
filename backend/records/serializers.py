from rest_framework import serializers

from .models import LeagueRecord


class LeagueRecordSerializer(serializers.ModelSerializer):
    # `username` is kept for the existing client shape, but now resolves to the
    # team name when the holder is a team rather than a user.
    username = serializers.SerializerMethodField()
    display_name = serializers.SerializerMethodField()
    team_name = serializers.SerializerMethodField()
    record_type_display = serializers.CharField(source='get_record_type_display', read_only=True)

    class Meta:
        model = LeagueRecord
        fields = ['id', 'league', 'record_type', 'record_type_display',
                  'user', 'username', 'team', 'team_name', 'display_name',
                  'value', 'match', 'achieved_at', 'is_current', 'metadata']
        read_only_fields = ['id', 'achieved_at']

    def get_username(self, obj):
        return obj.display_name

    def get_display_name(self, obj):
        return obj.display_name

    def get_team_name(self, obj):
        return obj.team.name if obj.team_id else None

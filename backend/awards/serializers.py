from rest_framework import serializers
from .models import Award, AwardAuditLog


class AwardSerializer(serializers.ModelSerializer):
    # `username` is kept for the existing client shape but now resolves to the
    # team name when the recipient is a team.
    username = serializers.SerializerMethodField()
    display_name = serializers.SerializerMethodField()
    team_name = serializers.SerializerMethodField()
    title = serializers.CharField(read_only=True)
    award_type_display = serializers.CharField(source='get_award_type_display', read_only=True)

    class Meta:
        model = Award
        fields = ['id', 'league', 'season', 'tournament', 'award_type',
                  'award_type_display', 'title', 'custom_name',
                  'user', 'username', 'team', 'team_name', 'display_name',
                  'source', 'description', 'awarded_at', 'awarded_by']
        read_only_fields = ['id', 'awarded_at', 'awarded_by']

    def get_username(self, obj):
        return obj.display_name

    def get_display_name(self, obj):
        return obj.display_name

    def get_team_name(self, obj):
        return obj.team.name if obj.team_id else None


class AwardCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Award
        fields = ['season', 'tournament', 'award_type',
                  'custom_name', 'user', 'team', 'description']

    def validate(self, attrs):
        user = attrs.get('user')
        team = attrs.get('team')
        if user is None and team is None:
            raise serializers.ValidationError(
                'An award needs either a user or a team as its recipient.'
            )
        if user is not None and team is not None:
            raise serializers.ValidationError(
                'An award recipient is either a user or a team, not both.'
            )
        return attrs

    def create(self, validated_data):
        user = self.context['request'].user
        return Award.objects.create(
            source='MANUAL',
            awarded_by=user,
            **validated_data
        )


class AwardAuditLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AwardAuditLog
        fields = ['id', 'award', 'action', 'previous_user', 'new_user',
                  'changed_by', 'reason', 'created_at']
        read_only_fields = ['id', 'created_at']
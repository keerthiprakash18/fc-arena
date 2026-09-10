from rest_framework import serializers
from .models import Award, AwardAuditLog


class AwardSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    award_type_display = serializers.CharField(source='get_award_type_display', read_only=True)

    class Meta:
        model = Award
        fields = ['id', 'league', 'season', 'tournament', 'award_type',
                  'award_type_display', 'custom_name', 'user', 'username',
                  'source', 'description', 'awarded_at', 'awarded_by']
        read_only_fields = ['id', 'awarded_at', 'awarded_by']


class AwardCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Award
        fields = ['season', 'tournament', 'award_type',
                  'custom_name', 'user', 'description']

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
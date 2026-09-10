from rest_framework import serializers
from .models import Notification, NotificationPreference


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'user', 'notification_type', 'title', 'message',
                  'league', 'tournament', 'match', 'is_read', 'action_url',
                  'metadata', 'created_at']
        read_only_fields = ['id', 'created_at']


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationPreference
        fields = ['id', 'tournament_invitations', 'match_results',
                  'dispute_updates', 'awards', 'league_updates',
                  'push_enabled', 'email_enabled']
        read_only_fields = ['id']
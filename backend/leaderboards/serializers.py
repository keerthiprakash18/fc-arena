from rest_framework import serializers
from .models import Leaderboard


class LeaderboardSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)

    class Meta:
        model = Leaderboard
        fields = ['id', 'league', 'season', 'tournament', 'category',
                  'category_display', 'user', 'username', 'value',
                  'rank', 'metadata', 'calculated_at']
        read_only_fields = ['id', 'calculated_at']
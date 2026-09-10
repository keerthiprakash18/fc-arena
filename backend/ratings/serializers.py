from rest_framework import serializers
from .models import PlayerLeagueRating, RatingHistory


class PlayerLeagueRatingSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = PlayerLeagueRating
        fields = ['id', 'league', 'user', 'username', 'rating',
                  'peak_rating', 'matches_rated', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class RatingHistorySerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = RatingHistory
        fields = ['id', 'league', 'user', 'username', 'match',
                  'old_rating', 'new_rating', 'rating_change',
                  'opponent_rating', 'result', 'created_at']
        read_only_fields = ['id', 'created_at']
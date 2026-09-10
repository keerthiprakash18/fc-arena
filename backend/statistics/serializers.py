from rest_framework import serializers
from .models import PlayerLeagueStatistics, LeagueStanding


class PlayerLeagueStatisticsSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    goal_difference = serializers.ReadOnlyField()
    win_rate = serializers.ReadOnlyField()
    points = serializers.ReadOnlyField()

    class Meta:
        model = PlayerLeagueStatistics
        fields = ['id', 'league', 'user', 'username', 'season',
                  'matches_played', 'wins', 'draws', 'losses',
                  'goals_scored', 'goals_conceded', 'clean_sheets',
                  'win_streak', 'current_win_streak', 'best_win_streak',
                  'longest_unbeaten', 'goal_difference', 'win_rate', 'points',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class LeagueStandingSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = LeagueStanding
        fields = ['id', 'league', 'season', 'user', 'username', 'rank',
                  'matches_played', 'wins', 'draws', 'losses',
                  'goals_for', 'goals_against', 'goal_difference', 'points',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
from rest_framework import serializers
from .models import (
    Match, MatchEvidence, MatchStatistics,
    MatchVerification, MatchStateTransition
)


class MatchSerializer(serializers.ModelSerializer):
    home_username = serializers.CharField(source='home_user.username', read_only=True)
    away_username = serializers.CharField(source='away_user.username', read_only=True)
    league_name = serializers.CharField(source='league.name', read_only=True)

    class Meta:
        model = Match
        fields = ['id', 'league', 'league_name', 'tournament', 'round',
                  'home_user', 'home_username', 'away_user', 'away_username',
                  'home_score', 'away_score', 'status', 'scheduled_at',
                  'played_at', 'verified_at', 'verified_by',
                  'is_idempotent_processed', 'created_at', 'updated_at']
        read_only_fields = ['id', 'is_idempotent_processed', 'created_at', 'updated_at']


class MatchCreateSerializer(serializers.ModelSerializer):
    """Create a match, then echo back the same shape as ``MatchSerializer``.

    The client parses the POST response straight into its Match model, so the
    response must carry ``status``/``league``/usernames — otherwise the freshly
    created object arrives with a null league and a defaulted status.
    """

    home_username = serializers.CharField(source='home_user.username', read_only=True)
    away_username = serializers.CharField(source='away_user.username', read_only=True)
    league_name = serializers.CharField(source='league.name', read_only=True)

    class Meta:
        model = Match
        fields = ['id', 'league', 'league_name', 'tournament', 'round',
                  'home_user', 'home_username', 'away_user', 'away_username',
                  'home_score', 'away_score', 'status', 'scheduled_at',
                  'played_at', 'verified_at', 'verified_by',
                  'is_idempotent_processed', 'created_at', 'updated_at']
        read_only_fields = ['id', 'league', 'league_name', 'home_username',
                            'away_username', 'home_score', 'away_score',
                            'status', 'played_at', 'verified_at', 'verified_by',
                            'is_idempotent_processed', 'created_at', 'updated_at']

    def validate(self, attrs):
        attrs['league'] = self.context['league']
        return attrs

    def create(self, validated_data):
        return Match.objects.create(**validated_data)


class MatchEvidenceSerializer(serializers.ModelSerializer):
    uploaded_by_name = serializers.CharField(source='uploaded_by.username', read_only=True)

    class Meta:
        model = MatchEvidence
        fields = ['id', 'match', 'uploaded_by', 'uploaded_by_name',
                  'file_reference', 'file_name', 'file_size', 'checksum',
                  'source_type', 'is_primary', 'uploaded_at']
        read_only_fields = ['id', 'uploaded_by', 'uploaded_at']


class MatchStatisticsSerializer(serializers.ModelSerializer):
    class Meta:
        model = MatchStatistics
        fields = ['id', 'match', 'home_possession', 'away_possession',
                  'home_shots', 'away_shots', 'home_shots_on_target', 'away_shots_on_target',
                  'home_pass_accuracy', 'away_pass_accuracy',
                  'home_tackles', 'away_tackles',
                  'home_corners', 'away_corners',
                  'home_fouls', 'away_fouls',
                  'extra_data', 'ai_confidence', 'ai_raw_output',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'ai_confidence', 'ai_raw_output', 'created_at', 'updated_at']


class MatchVerificationSerializer(serializers.ModelSerializer):
    verified_by_name = serializers.CharField(source='verified_by.username', read_only=True, default=None)

    class Meta:
        model = MatchVerification
        fields = ['id', 'match', 'status', 'ai_extracted_data',
                  'ai_confidence_score', 'admin_notes', 'verified_by',
                  'verified_by_name', 'verified_at', 'created_at', 'updated_at']
        read_only_fields = ['id', 'ai_extracted_data', 'ai_confidence_score',
                           'verified_by', 'verified_at', 'created_at', 'updated_at']


class MatchStateTransitionSerializer(serializers.ModelSerializer):
    class Meta:
        model = MatchStateTransition
        fields = ['id', 'match', 'from_status', 'to_status',
                  'created_by', 'created_at', 'metadata']
        read_only_fields = ['id', 'created_at']


class MatchStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Match.STATUS_CHOICES)
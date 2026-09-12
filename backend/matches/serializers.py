from rest_framework import serializers
from .models import (
    Match, MatchEvidence, MatchStatistics,
    MatchVerification, MatchStateTransition
)

# Every read field below is derived from a nullable relation: a team match has
# no home_user/away_user, and a user match has no home_team/away_team. A plain
# ``source='home_user.username'`` traversal raises when the relation is None, so
# all participant fields are exposed through guarded SerializerMethodFields.
_MATCH_PARTICIPANT_FIELDS = (
    'home_username', 'away_username',
    'home_team_name', 'away_team_name',
    'home_team_short_name', 'away_team_short_name',
    'home_team_logo', 'away_team_logo',
    'home_display', 'away_display',
)


class _MatchParticipantFieldsMixin(serializers.Serializer):
    """Guarded display fields shared by the read and write match serializers."""

    home_username = serializers.SerializerMethodField()
    away_username = serializers.SerializerMethodField()
    home_team_name = serializers.SerializerMethodField()
    away_team_name = serializers.SerializerMethodField()
    home_team_short_name = serializers.SerializerMethodField()
    away_team_short_name = serializers.SerializerMethodField()
    home_team_logo = serializers.SerializerMethodField()
    away_team_logo = serializers.SerializerMethodField()
    home_display = serializers.SerializerMethodField()
    away_display = serializers.SerializerMethodField()
    league_name = serializers.SerializerMethodField()

    def get_home_username(self, obj):
        return obj.home_user.username if obj.home_user_id else None

    def get_away_username(self, obj):
        return obj.away_user.username if obj.away_user_id else None

    def get_home_team_name(self, obj):
        return obj.home_team.name if obj.home_team_id else None

    def get_away_team_name(self, obj):
        return obj.away_team.name if obj.away_team_id else None

    def get_home_team_short_name(self, obj):
        return obj.home_team.short_name if obj.home_team_id else None

    def get_away_team_short_name(self, obj):
        return obj.away_team.short_name if obj.away_team_id else None

    def _logo_url(self, team):
        if not team or not team.logo:
            return None
        request = self.context.get('request')
        url = team.logo.url
        return request.build_absolute_uri(url) if request else url

    def get_home_team_logo(self, obj):
        return self._logo_url(obj.home_team) if obj.home_team_id else None

    def get_away_team_logo(self, obj):
        return self._logo_url(obj.away_team) if obj.away_team_id else None

    def get_home_display(self, obj):
        return obj.home_display

    def get_away_display(self, obj):
        return obj.away_display

    def get_league_name(self, obj):
        return obj.league.name if obj.league_id else None


class MatchSerializer(_MatchParticipantFieldsMixin, serializers.ModelSerializer):
    is_team_match = serializers.BooleanField(read_only=True)

    class Meta:
        model = Match
        fields = ['id', 'league', 'league_name', 'tournament', 'round',
                  'home_user', 'home_username', 'away_user', 'away_username',
                  'home_team', 'home_team_name', 'home_team_short_name',
                  'home_team_logo',
                  'away_team', 'away_team_name', 'away_team_short_name',
                  'away_team_logo',
                  'home_display', 'away_display', 'is_team_match', 'venue',
                  'home_score', 'away_score', 'status', 'scheduled_at',
                  'played_at', 'verified_at', 'verified_by',
                  'is_idempotent_processed', 'created_at', 'updated_at']
        read_only_fields = ['id', 'is_idempotent_processed', 'created_at', 'updated_at']


class MatchCreateSerializer(_MatchParticipantFieldsMixin, serializers.ModelSerializer):
    """Create a match, then echo back the same shape as ``MatchSerializer``.

    The client parses the POST response straight into its Match model, so the
    response must carry ``status``/``league``/participant names — otherwise the
    freshly created object arrives with a null league and a defaulted status.
    """

    is_team_match = serializers.BooleanField(read_only=True)

    class Meta:
        model = Match
        fields = ['id', 'league', 'league_name', 'tournament', 'round',
                  'home_user', 'home_username', 'away_user', 'away_username',
                  'home_team', 'home_team_name', 'home_team_short_name',
                  'home_team_logo',
                  'away_team', 'away_team_name', 'away_team_short_name',
                  'away_team_logo',
                  'home_display', 'away_display', 'is_team_match', 'venue',
                  'home_score', 'away_score', 'status', 'scheduled_at',
                  'played_at', 'verified_at', 'verified_by',
                  'is_idempotent_processed', 'created_at', 'updated_at']
        read_only_fields = ['id', 'league', 'league_name', *_MATCH_PARTICIPANT_FIELDS,
                            'is_team_match', 'home_score', 'away_score',
                            'status', 'played_at', 'verified_at', 'verified_by',
                            'is_idempotent_processed', 'created_at', 'updated_at']

    def validate(self, attrs):
        attrs['league'] = self.context['league']
        home_user = attrs.get('home_user')
        away_user = attrs.get('away_user')
        home_team = attrs.get('home_team')
        away_team = attrs.get('away_team')

        has_users = home_user is not None or away_user is not None
        has_teams = home_team is not None or away_team is not None
        if has_users and has_teams:
            raise serializers.ValidationError(
                'A match is either user-based or team-based, not both.'
            )
        if has_teams and (home_team is None or away_team is None):
            raise serializers.ValidationError(
                'A team match requires both home_team and away_team.'
            )
        if home_team is not None and home_team == away_team:
            raise serializers.ValidationError('A team cannot play itself.')

        # A team from another league must never be scheduled into this league.
        for team in (home_team, away_team):
            if team is not None and team.league_id != attrs['league'].id:
                raise serializers.ValidationError(
                    f'Team "{team.name}" does not belong to this league.'
                )
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
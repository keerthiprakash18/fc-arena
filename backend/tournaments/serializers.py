from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import (
    Tournament, TournamentParticipant, TournamentGroup,
    TournamentRound, TournamentStateTransition
)

User = get_user_model()


class TournamentSerializer(serializers.ModelSerializer):
    league_name = serializers.CharField(source='league.name', read_only=True)
    created_by_name = serializers.CharField(source='created_by.username', read_only=True)
    participant_count = serializers.SerializerMethodField()
    logo_url = serializers.SerializerMethodField()
    banner_url = serializers.SerializerMethodField()

    class Meta:
        model = Tournament
        fields = ['id', 'league', 'league_name', 'season', 'name', 'description',
                  'tournament_code', 'format', 'status',
                  'max_participants', 'min_participants',
                  'entry_fee', 'prize_pool', 'prize_description', 'rules', 'game',
                  'logo_url', 'banner_url', 'is_team_based',
                  'registration_start', 'registration_deadline',
                  'start_date', 'end_date', 'created_by', 'created_by_name',
                  'participant_count', 'created_at', 'updated_at']
        read_only_fields = ['id', 'tournament_code', 'created_by',
                           'created_at', 'updated_at']

    def _absolute(self, file_field):
        if not file_field:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(file_field.url) if request else file_field.url

    def get_logo_url(self, obj):
        return self._absolute(obj.logo)

    def get_banner_url(self, obj):
        return self._absolute(obj.banner)

    def get_participant_count(self, obj):
        return obj.participants.exclude(status='WITHDRAWN').count()


class TournamentCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tournament
        fields = ['id', 'name', 'description', 'format', 'game', 'rules',
                  'max_participants', 'min_participants', 'entry_fee', 'prize_pool',
                  'prize_description', 'is_team_based',
                  'registration_start', 'registration_deadline',
                  'start_date', 'end_date']
        read_only_fields = ['id']

    def validate(self, attrs):
        attrs['league'] = self.context['league']
        minimum = attrs.get('min_participants', 2)
        maximum = attrs.get('max_participants', 16)
        if minimum and maximum and minimum > maximum:
            raise serializers.ValidationError(
                {'min_participants': 'Minimum teams cannot exceed the maximum.'}
            )
        return attrs

    def create(self, validated_data):
        return Tournament.objects.create(**validated_data)


class TournamentStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Tournament.STATUS_CHOICES)


class TournamentParticipantSerializer(serializers.ModelSerializer):
    # A participant is either a user (legacy) or a team (FCFC upgrade),
    # so both name fields are optional.
    username = serializers.SerializerMethodField()
    team_name = serializers.SerializerMethodField()

    class Meta:
        model = TournamentParticipant
        fields = ['id', 'user', 'username', 'team', 'team_name',
                  'tournament', 'status', 'seed_number', 'registered_at']
        read_only_fields = ['id', 'registered_at']

    def get_username(self, obj):
        return obj.user.username if obj.user_id else None

    def get_team_name(self, obj):
        return obj.team.name if obj.team_id else None


class TournamentGroupSerializer(serializers.ModelSerializer):
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = TournamentGroup
        fields = ['id', 'tournament', 'name', 'group_number', 'member_count']
        read_only_fields = ['id']

    def get_member_count(self, obj):
        return obj.members.count()


class TournamentRoundSerializer(serializers.ModelSerializer):
    class Meta:
        model = TournamentRound
        fields = ['id', 'tournament', 'name', 'round_number',
                  'round_type', 'is_current']
        read_only_fields = ['id']


class TournamentStateTransitionSerializer(serializers.ModelSerializer):
    class Meta:
        model = TournamentStateTransition
        fields = ['id', 'tournament', 'from_status', 'to_status',
                  'created_by', 'created_at', 'metadata']
        read_only_fields = ['id', 'created_at']
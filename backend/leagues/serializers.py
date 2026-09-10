from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import League, LeagueMember

User = get_user_model()


class LeagueMemberSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)

    class Meta:
        model = LeagueMember
        fields = ['id', 'user', 'username', 'email', 'role', 'is_active', 'joined_at']
        read_only_fields = ['id', 'joined_at']


class LeagueSerializer(serializers.ModelSerializer):
    owner_name = serializers.CharField(source='owner.username', read_only=True)
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = League
        fields = ['id', 'name', 'slug', 'description', 'league_code',
                  'owner', 'owner_name', 'is_active', 'member_count',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'league_code', 'owner', 'created_at', 'updated_at']

    def get_member_count(self, obj):
        return obj.members.filter(is_active=True).count()


class LeagueCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = League
        fields = ['id', 'name', 'slug', 'description', 'league_code']
        read_only_fields = ['id', 'league_code']

    def create(self, validated_data):
        user = self.context['request'].user
        league = League.objects.create(owner=user, **validated_data)
        LeagueMember.objects.create(league=league, user=user, role='LEAGUE_OWNER')
        return league


class LeagueJoinSerializer(serializers.Serializer):
    league_code = serializers.CharField(max_length=10)

    def validate_league_code(self, value):
        try:
            league = League.objects.get(league_code=value, is_active=True)
        except League.DoesNotExist:
            raise serializers.ValidationError("Invalid league code or league is inactive.")
        return value

    def validate(self, attrs):
        user = self.context['request'].user
        league = League.objects.get(league_code=attrs['league_code'])
        if LeagueMember.objects.filter(league=league, user=user).exists():
            raise serializers.ValidationError("You are already a member of this league.")
        attrs['league'] = league
        return attrs

    def save(self, **kwargs):
        user = self.context['request'].user
        league = self.validated_data['league']
        return LeagueMember.objects.create(league=league, user=user, role='PLAYER')
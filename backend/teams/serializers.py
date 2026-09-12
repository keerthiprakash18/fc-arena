from django.contrib.auth import get_user_model
from django.utils.text import slugify
from rest_framework import serializers

from leagues.models import LeagueMember

from .models import Team, TeamMember, TeamStatistics

User = get_user_model()


def unique_slug_for(league, name, exclude_pk=None):
    """Slugify a team name, appending -2, -3… until it is unique within the league."""
    base = slugify(name)[:130] or 'team'
    slug = base
    counter = 1
    qs = Team.objects.filter(league=league, slug=slug)
    if exclude_pk:
        qs = qs.exclude(pk=exclude_pk)
    while qs.exists():
        counter += 1
        slug = f'{base}-{counter}'
        qs = Team.objects.filter(league=league, slug=slug)
        if exclude_pk:
            qs = qs.exclude(pk=exclude_pk)
    return slug


class TeamMemberSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    display_name = serializers.SerializerMethodField()
    profile_photo = serializers.SerializerMethodField()

    class Meta:
        model = TeamMember
        fields = ['id', 'user', 'username', 'display_name', 'profile_photo',
                  'role', 'jersey_number', 'position', 'is_active', 'joined_at']
        read_only_fields = ['id', 'joined_at']

    def get_display_name(self, obj):
        return getattr(obj.user, 'display_name', obj.user.username)

    def get_profile_photo(self, obj):
        photo = getattr(obj.user, 'profile_photo', None)
        if not photo:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(photo.url) if request else photo.url


class TeamStatisticsSerializer(serializers.ModelSerializer):
    goal_difference = serializers.IntegerField(read_only=True)
    win_rate = serializers.FloatField(read_only=True)
    goals_per_match = serializers.FloatField(read_only=True)

    class Meta:
        model = TeamStatistics
        fields = ['matches_played', 'wins', 'draws', 'losses',
                  'goals_scored', 'goals_conceded', 'goal_difference',
                  'clean_sheets', 'points', 'win_rate', 'goals_per_match',
                  'form', 'current_win_streak', 'best_win_streak', 'updated_at']


class TeamSerializer(serializers.ModelSerializer):
    """Read serializer — a full team profile."""

    logo_url = serializers.SerializerMethodField()
    banner_url = serializers.SerializerMethodField()
    captain_name = serializers.SerializerMethodField()
    manager_name = serializers.SerializerMethodField()
    member_count = serializers.IntegerField(read_only=True)
    statistics = serializers.SerializerMethodField()
    members = TeamMemberSerializer(many=True, read_only=True)

    class Meta:
        model = Team
        fields = ['id', 'league', 'name', 'short_name', 'slug', 'description', 'game',
                  'logo_url', 'banner_url',
                  'captain', 'captain_name', 'manager', 'manager_name',
                  'social_links', 'is_active', 'member_count',
                  'statistics', 'members', 'created_at', 'updated_at']
        read_only_fields = ['id', 'slug', 'created_at', 'updated_at']

    def _absolute(self, file_field):
        if not file_field:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(file_field.url) if request else file_field.url

    def get_logo_url(self, obj):
        return self._absolute(obj.logo)

    def get_banner_url(self, obj):
        return self._absolute(obj.banner)

    def get_captain_name(self, obj):
        return obj.captain.username if obj.captain_id else None

    def get_manager_name(self, obj):
        return obj.manager.username if obj.manager_id else None

    def get_statistics(self, obj):
        # Reverse OneToOne raises RelatedObjectDoesNotExist, which subclasses
        # AttributeError — so getattr with a default is the safe read here.
        stats = getattr(obj, 'statistics', None)
        return TeamStatisticsSerializer(stats).data if stats else None


class TeamWriteSerializer(serializers.ModelSerializer):
    """Create/update serializer. `slug` is derived, never client-supplied."""

    class Meta:
        model = Team
        fields = ['id', 'name', 'short_name', 'description', 'game',
                  'captain', 'manager', 'social_links', 'is_active']
        read_only_fields = ['id']

    def validate_name(self, value):
        name = value.strip()
        if not name:
            raise serializers.ValidationError('Team name cannot be blank.')
        league = self.context['league']
        qs = Team.objects.filter(league=league, name__iexact=name)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError(
                f'A team named "{name}" already exists in this league.'
            )
        return name

    def validate(self, attrs):
        league = self.context['league']
        for key in ('captain', 'manager'):
            user = attrs.get(key, getattr(self.instance, key, None) if self.instance else None)
            if user and not LeagueMember.objects.filter(
                league=league, user=user, is_active=True
            ).exists():
                raise serializers.ValidationError(
                    {key: 'That user is not a member of this league.'}
                )
        return attrs

    def create(self, validated_data):
        league = self.context['league']
        validated_data['slug'] = unique_slug_for(league, validated_data['name'])
        team = Team.objects.create(
            league=league, created_by=self.context['request'].user, **validated_data
        )
        # A captain is implicitly a squad member.
        if team.captain_id:
            TeamMember.objects.get_or_create(
                team=team, user=team.captain, defaults={'role': 'CAPTAIN'}
            )
        return team

    def update(self, instance, validated_data):
        new_name = validated_data.get('name')
        if new_name and new_name != instance.name:
            instance.slug = unique_slug_for(instance.league, new_name, exclude_pk=instance.pk)
        for field, value in validated_data.items():
            setattr(instance, field, value)
        if new_name:
            instance.save(update_fields=[*validated_data.keys(), 'slug', 'updated_at'])
        else:
            instance.save()
        if instance.captain_id:
            TeamMember.objects.get_or_create(
                team=instance, user=instance.captain, defaults={'role': 'CAPTAIN'}
            )
        return instance


class TeamMemberCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = TeamMember
        fields = ['user', 'role', 'jersey_number', 'position']

    def validate_user(self, value):
        team = self.context['team']
        if TeamMember.objects.filter(team=team, user=value).exists():
            raise serializers.ValidationError('That player is already on this team.')
        if not LeagueMember.objects.filter(
            league=team.league, user=value, is_active=True
        ).exists():
            raise serializers.ValidationError('That user is not a member of this league.')
        return value

from rest_framework import serializers
from .models import Season, SeasonMember


class SeasonSerializer(serializers.ModelSerializer):
    league_name = serializers.CharField(source='league.name', read_only=True)
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = Season
        fields = ['id', 'league', 'league_name', 'name', 'slug', 'description',
                  'status', 'start_date', 'end_date', 'is_current',
                  'member_count', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_member_count(self, obj):
        return obj.members.filter(is_active=True).count()


class SeasonCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Season
        fields = ['id', 'name', 'description', 'start_date', 'end_date']
        read_only_fields = ['id']

    def validate(self, attrs):
        league = self.context['league']
        attrs['league'] = league
        return attrs

    def create(self, validated_data):
        return Season.objects.create(**validated_data)


class SeasonMemberSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = SeasonMember
        fields = ['id', 'user', 'username', 'is_active', 'joined_at']
        read_only_fields = ['id', 'joined_at']
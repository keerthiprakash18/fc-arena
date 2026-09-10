from rest_framework import serializers
from .models import Category, PlayerCategory


class CategorySerializer(serializers.ModelSerializer):
    player_count = serializers.SerializerMethodField()

    class Meta:
        model = Category
        fields = ['id', 'name', 'slug', 'description', 'min_rating', 'max_rating',
                  'is_active', 'color', 'league', 'player_count', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_player_count(self, obj):
        return obj.players.count()


class CategoryCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['name', 'description', 'min_rating', 'max_rating', 'is_active', 'color']

    def create(self, validated_data):
        league = self.context['league']
        slug = validated_data['name'].lower().replace(' ', '-')
        return Category.objects.create(league=league, slug=slug, **validated_data)


class PlayerCategorySerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='player.username', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)

    class Meta:
        model = PlayerCategory
        fields = ['id', 'player', 'username', 'category', 'category_name',
                  'is_primary', 'assigned_at']
        read_only_fields = ['id', 'assigned_at']


class PlayerCategoryAssignSerializer(serializers.Serializer):
    player_id = serializers.IntegerField()
    is_primary = serializers.BooleanField(default=True)

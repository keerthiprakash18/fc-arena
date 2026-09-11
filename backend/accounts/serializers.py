from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    isStaff = serializers.BooleanField(source='is_staff', read_only=True)
    isSuperuser = serializers.BooleanField(source='is_superuser', read_only=True)
    dateJoined = serializers.DateTimeField(source='date_joined', read_only=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name',
                  'game_uid', 'game_in_game_name', 'phone_number',
                  'profile_photo', 'date_of_birth',
                  'isStaff', 'isSuperuser', 'dateJoined']
        read_only_fields = ['id', 'isStaff', 'isSuperuser', 'dateJoined']


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'first_name', 'last_name',
                  'game_uid', 'game_in_game_name', 'phone_number']

    def create(self, validated_data):
        user = User.objects.create_user(**validated_data)
        return user
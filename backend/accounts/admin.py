from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth import get_user_model

User = get_user_model()


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ['username', 'email', 'game_uid', 'game_in_game_name']
    fieldsets = UserAdmin.fieldsets + (
        ('Game Info', {'fields': ('game_uid', 'game_in_game_name', 'profile_photo', 'date_of_birth')}),
    )
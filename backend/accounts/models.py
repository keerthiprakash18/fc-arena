from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    game_uid = models.CharField(max_length=100, blank=True, null=True)
    game_in_game_name = models.CharField(max_length=100, blank=True, null=True)
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    profile_photo = models.ImageField(upload_to='profiles/', blank=True, null=True)
    date_of_birth = models.DateField(blank=True, null=True)

    # Player-profile fields (Phase 2 of the FCFC upgrade). Additive and nullable
    # so existing rows are unaffected.
    position = models.CharField(max_length=50, blank=True, default='')
    country = models.CharField(max_length=60, blank=True, default='')
    # {"twitter": "...", "youtube": "...", "discord": "..."} — free-form by design.
    social_links = models.JSONField(blank=True, default=dict)

    class Meta:
        db_table = 'users'

    def __str__(self):
        return self.username

    @property
    def display_name(self):
        """Real name if we have one, otherwise the username."""
        full = f'{self.first_name} {self.last_name}'.strip()
        return full or self.username
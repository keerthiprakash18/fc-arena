from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    game_uid = models.CharField(max_length=100, blank=True, null=True)
    game_in_game_name = models.CharField(max_length=100, blank=True, null=True)
    profile_photo = models.ImageField(upload_to='profiles/', blank=True, null=True)
    date_of_birth = models.DateField(blank=True, null=True)

    class Meta:
        db_table = 'users'

    def __str__(self):
        return self.username
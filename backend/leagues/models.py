import uuid
import string
import random
from django.db import models
from django.conf import settings


def generate_league_code():
    chars = string.ascii_uppercase + string.digits
    while True:
        code = ''.join(random.choices(chars, k=6))
        formatted = f"FC-{code}"
        if not League.objects.filter(league_code=formatted).exists():
            return formatted


class League(models.Model):
    name = models.CharField(max_length=200)
    slug = models.SlugField(unique=True, max_length=200)
    description = models.TextField(blank=True, default='')
    league_code = models.CharField(max_length=10, unique=True, default=generate_league_code)
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='owned_leagues')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'leagues'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} ({self.league_code})"


class LeagueMember(models.Model):
    ROLE_CHOICES = [
        ('LEAGUE_OWNER', 'League Owner'),
        ('LEAGUE_ADMIN', 'League Admin'),
        ('TOURNAMENT_ADMIN', 'Tournament Admin'),
        ('PLAYER', 'Player'),
    ]

    league = models.ForeignKey(League, on_delete=models.CASCADE, related_name='members')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='league_memberships')
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='PLAYER')
    is_active = models.BooleanField(default=True)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'league_members'
        unique_together = ['league', 'user']
        ordering = ['joined_at']

    def __str__(self):
        return f"{self.user.username} in {self.league.name} ({self.role})"
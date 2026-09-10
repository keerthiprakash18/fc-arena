import uuid
from django.db import models
from django.conf import settings


class Category(models.Model):
    name = models.CharField(max_length=100)
    slug = models.SlugField(max_length=100)
    description = models.TextField(blank=True, default='')
    min_rating = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    max_rating = models.DecimalField(max_digits=10, decimal_places=2, default=99999)
    is_active = models.BooleanField(default=True)
    color = models.CharField(max_length=20, default='#e94560')
    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='categories')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'categories'
        unique_together = ['league', 'slug']
        ordering = ['min_rating']

    def __str__(self):
        return f"{self.name} ({self.league.name})"


class PlayerCategory(models.Model):
    player = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='player_categories')
    category = models.ForeignKey(Category, on_delete=models.CASCADE, related_name='players')
    assigned_at = models.DateTimeField(auto_now_add=True)
    is_primary = models.BooleanField(default=True)

    class Meta:
        db_table = 'player_categories'
        unique_together = ['player', 'category']
        ordering = ['-is_primary', 'assigned_at']

    def __str__(self):
        return f"{self.player.username} → {self.category.name}"

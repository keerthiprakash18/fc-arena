from django.db import models
from django.conf import settings


class PlayerLeagueRating(models.Model):
    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='player_ratings')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='league_ratings')
    rating = models.DecimalField(max_digits=7, decimal_places=2, default=1000.00)
    peak_rating = models.DecimalField(max_digits=7, decimal_places=2, default=1000.00)
    matches_rated = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'player_league_ratings'
        unique_together = ['league', 'user']
        ordering = ['-rating']

    def __str__(self):
        return f"{self.user.username} - {self.league.name} ({self.rating})"


class RatingHistory(models.Model):
    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='rating_history')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='rating_history')
    match = models.ForeignKey('matches.Match', on_delete=models.CASCADE, related_name='rating_changes')
    old_rating = models.DecimalField(max_digits=7, decimal_places=2)
    new_rating = models.DecimalField(max_digits=7, decimal_places=2)
    rating_change = models.DecimalField(max_digits=7, decimal_places=2)
    opponent_rating = models.DecimalField(max_digits=7, decimal_places=2, blank=True, null=True)
    result = models.CharField(max_length=10)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'rating_history'
        unique_together = ['league', 'user', 'match']
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username}: {self.old_rating} → {self.new_rating} ({self.result})"
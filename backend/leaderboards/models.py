from django.db import models
from django.conf import settings


class Leaderboard(models.Model):
    CATEGORY_CHOICES = [
        ('RATING', 'Overall Rating'),
        ('WINS', 'Most Wins'),
        ('GOALS', 'Top Scorers'),
        ('WIN_RATE', 'Best Win Rate'),
        ('GOAL_DIFF', 'Best Goal Difference'),
        ('MATCHES', 'Most Matches'),
        ('CLEAN_SHEETS', 'Best Defensive Record'),
    ]

    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='leaderboards')
    season = models.ForeignKey('seasons.Season', on_delete=models.SET_NULL, null=True, blank=True, related_name='leaderboards')
    tournament = models.ForeignKey('tournaments.Tournament', on_delete=models.SET_NULL, null=True, blank=True, related_name='leaderboards')
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='leaderboard_entries')
    value = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    rank = models.PositiveIntegerField(default=0)
    metadata = models.JSONField(blank=True, default=dict)
    calculated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'leaderboards'
        unique_together = ['league', 'season', 'tournament', 'category', 'user']
        ordering = ['category', '-value', 'rank']

    def __str__(self):
        return f"{self.get_category_display()}: #{self.rank} {self.user.username} ({self.value})"
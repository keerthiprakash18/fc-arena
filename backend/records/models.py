from django.db import models
from django.conf import settings


class LeagueRecord(models.Model):
    RECORD_TYPE_CHOICES = [
        ('HIGHEST_RATING', 'Highest Rating'),
        ('MOST_GOALS', 'Most Goals'),
        ('MOST_WINS', 'Most Wins'),
        ('LONGEST_WIN_STREAK', 'Longest Winning Streak'),
        ('MOST_GOALS_IN_MATCH', 'Most Goals in One Match'),
        ('MOST_TOURNAMENT_WINS', 'Most Tournament Wins'),
        ('BEST_WIN_RATE', 'Best Win Rate'),
        ('BIGGEST_WINNING_MARGIN', 'Biggest Winning Margin'),
        ('MOST_CLEAN_SHEETS', 'Most Clean Sheets'),
    ]

    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='records')
    record_type = models.CharField(max_length=25, choices=RECORD_TYPE_CHOICES)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='league_records')
    value = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    match = models.ForeignKey('matches.Match', on_delete=models.SET_NULL, null=True, blank=True, related_name='records_set')
    achieved_at = models.DateTimeField(auto_now_add=True)
    is_current = models.BooleanField(default=True)
    metadata = models.JSONField(blank=True, default=dict)

    class Meta:
        db_table = 'league_records'
        unique_together = ['league', 'record_type', 'is_current']
        ordering = ['-value']

    def __str__(self):
        return f"{self.get_record_type_display()}: {self.user.username} ({self.value})"
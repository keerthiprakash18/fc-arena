from django.db import models
from django.conf import settings


class PlayerLeagueStatistics(models.Model):
    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='player_statistics')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='league_statistics')
    season = models.ForeignKey('seasons.Season', on_delete=models.SET_NULL, null=True, blank=True, related_name='player_statistics')

    matches_played = models.PositiveIntegerField(default=0)
    wins = models.PositiveIntegerField(default=0)
    draws = models.PositiveIntegerField(default=0)
    losses = models.PositiveIntegerField(default=0)
    goals_scored = models.PositiveIntegerField(default=0)
    goals_conceded = models.PositiveIntegerField(default=0)
    clean_sheets = models.PositiveIntegerField(default=0)
    win_streak = models.PositiveIntegerField(default=0)
    current_win_streak = models.PositiveIntegerField(default=0)
    best_win_streak = models.PositiveIntegerField(default=0)
    longest_unbeaten = models.PositiveIntegerField(default=0)
    total_goals_in_match = models.PositiveIntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'player_league_statistics'
        unique_together = ['league', 'user', 'season']
        ordering = ['-wins', '-goals_scored']

    def __str__(self):
        season_str = f" ({self.season.name})" if self.season else ""
        return f"{self.user.username} - {self.league.name}{season_str}"

    @property
    def goal_difference(self):
        return self.goals_scored - self.goals_conceded

    @property
    def win_rate(self):
        if self.matches_played == 0:
            return 0
        return round((self.wins / self.matches_played) * 100, 2)

    @property
    def points(self):
        return (self.wins * 3) + self.draws


class LeagueStanding(models.Model):
    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='standings')
    season = models.ForeignKey('seasons.Season', on_delete=models.SET_NULL, null=True, blank=True, related_name='standings')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='league_standings')

    rank = models.PositiveIntegerField(default=0)
    matches_played = models.PositiveIntegerField(default=0)
    wins = models.PositiveIntegerField(default=0)
    draws = models.PositiveIntegerField(default=0)
    losses = models.PositiveIntegerField(default=0)
    goals_for = models.PositiveIntegerField(default=0)
    goals_against = models.PositiveIntegerField(default=0)
    goal_difference = models.IntegerField(default=0)
    points = models.PositiveIntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'league_standings'
        unique_together = ['league', 'season', 'user']
        ordering = ['-points', '-goal_difference', '-goals_for']

    def __str__(self):
        return f"#{self.rank} {self.user.username} ({self.points} pts)"
from django.db import models
from django.conf import settings


class Award(models.Model):
    AWARD_TYPE_CHOICES = [
        ('PLAYER_OF_SEASON', 'Player of the Season'),
        ('GOLDEN_BOOT', 'Golden Boot'),
        ('GOLDEN_BALL', 'Golden Ball'),
        ('TOURNAMENT_MVP', 'Tournament MVP'),
        ('BEST_DEFENDER', 'Best Defender'),
        ('BEST_PERFORMER', 'Best Performer'),
        ('PLAYER_OF_MONTH', 'Player of the Month'),
        ('FAIR_PLAY', 'Fair Play Award'),
        ('LEAGUE_CHAMPION', 'League Champion'),
        ('TOURNAMENT_CHAMPION', 'Tournament Champion'),
        ('RUNNER_UP', 'Runner-up'),
        ('CUSTOM', 'Custom Award'),
    ]

    SOURCE_CHOICES = [
        ('AUTO', 'Auto Calculated'),
        ('MANUAL', 'Manually Assigned'),
        ('OVERRIDE', 'Manual Override'),
    ]

    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='awards')
    season = models.ForeignKey('seasons.Season', on_delete=models.SET_NULL, null=True, blank=True, related_name='awards')
    tournament = models.ForeignKey('tournaments.Tournament', on_delete=models.SET_NULL, null=True, blank=True, related_name='awards')
    award_type = models.CharField(max_length=25, choices=AWARD_TYPE_CHOICES)
    custom_name = models.CharField(max_length=200, blank=True, default='')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='league_awards')
    source = models.CharField(max_length=10, choices=SOURCE_CHOICES, default='AUTO')
    description = models.TextField(blank=True, default='')
    awarded_at = models.DateTimeField(auto_now_add=True)
    awarded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='awards_given')

    class Meta:
        db_table = 'awards'
        unique_together = ['league', 'season', 'tournament', 'award_type', 'user']
        ordering = ['-awarded_at']

    def __str__(self):
        name = self.custom_name or self.get_award_type_display()
        return f"{name}: {self.user.username} ({self.league.name})"


class AwardAuditLog(models.Model):
    award = models.ForeignKey(Award, on_delete=models.CASCADE, related_name='audit_logs')
    action = models.CharField(max_length=50)
    previous_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='previous_awards')
    new_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='new_awards')
    changed_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='award_changes')
    reason = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'award_audit_logs'
        ordering = ['-created_at']

    def __str__(self):
        return f"Audit: {self.action} - {self.award}"
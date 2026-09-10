from django.db import models
from django.conf import settings


class MatchEvent(models.Model):
    EVENT_TYPES = [
        ('GOAL', 'Goal'),
        ('OWN_GOAL', 'Own Goal'),
        ('YELLOW_CARD', 'Yellow Card'),
        ('RED_CARD', 'Red Card'),
        ('ASSIST', 'Assist'),
        ('SAVE', 'Save'),
        ('PENALTY_SCORED', 'Penalty Scored'),
        ('PENALTY_MISSED', 'Penalty Missed'),
    ]

    match = models.ForeignKey('matches.Match', on_delete=models.CASCADE, related_name='events')
    event_type = models.CharField(max_length=20, choices=EVENT_TYPES)
    minute = models.PositiveIntegerField(default=0)
    player = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='match_events')
    assisted_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='assists')
    description = models.CharField(max_length=200, blank=True, default='')
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='created_events')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'match_events'
        ordering = ['minute', 'created_at']

    def __str__(self):
        return f"{self.get_event_type_display()} - {self.player.username} ({self.minute}')"

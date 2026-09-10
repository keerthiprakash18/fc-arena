from django.db import models
from django.conf import settings


class Notification(models.Model):
    TYPE_CHOICES = [
        ('TOURNAMENT_INVITATION', 'Tournament Invitation'),
        ('TOURNAMENT_REGISTRATION', 'Tournament Registration'),
        ('FIXTURE_ASSIGNED', 'Fixture Assigned'),
        ('MATCH_REMINDER', 'Match Reminder'),
        ('EVIDENCE_UPLOADED', 'Evidence Uploaded'),
        ('AI_VERIFICATION_COMPLETE', 'AI Verification Complete'),
        ('ADMIN_REVIEW_REQUIRED', 'Admin Review Required'),
        ('MATCH_VERIFIED', 'Match Verified'),
        ('MATCH_REJECTED', 'Match Rejected'),
        ('DISPUTE_UPDATE', 'Dispute Update'),
        ('TOURNAMENT_STARTED', 'Tournament Started'),
        ('ROUND_COMPLETED', 'Round Completed'),
        ('TOURNAMENT_COMPLETED', 'Tournament Completed'),
        ('AWARD_RECEIVED', 'Award Received'),
        ('LEAGUE_INVITATION', 'League Invitation'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    notification_type = models.CharField(max_length=25, choices=TYPE_CHOICES)
    title = models.CharField(max_length=200)
    message = models.TextField()
    league = models.ForeignKey('leagues.League', on_delete=models.SET_NULL, null=True, blank=True, related_name='notifications')
    tournament = models.ForeignKey('tournaments.Tournament', on_delete=models.SET_NULL, null=True, blank=True, related_name='notifications')
    match = models.ForeignKey('matches.Match', on_delete=models.SET_NULL, null=True, blank=True, related_name='notifications')
    is_read = models.BooleanField(default=False)
    action_url = models.CharField(max_length=500, blank=True, default='')
    metadata = models.JSONField(blank=True, default=dict)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notifications'
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.notification_type}] {self.title} → {self.user.username}"


class NotificationPreference(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notification_preferences')
    tournament_invitations = models.BooleanField(default=True)
    match_results = models.BooleanField(default=True)
    dispute_updates = models.BooleanField(default=True)
    awards = models.BooleanField(default=True)
    league_updates = models.BooleanField(default=True)
    push_enabled = models.BooleanField(default=False)
    email_enabled = models.BooleanField(default=False)

    class Meta:
        db_table = 'notification_preferences'

    def __str__(self):
        return f"Preferences for {self.user.username}"
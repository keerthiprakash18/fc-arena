from django.db import models
from django.conf import settings


class Dispute(models.Model):
    REASON_CHOICES = [
        ('WRONG_SCORE', 'Wrong Score'),
        ('WRONG_OPPONENT', 'Wrong Opponent'),
        ('INVALID_SCREENSHOT', 'Invalid Screenshot'),
        ('INCORRECT_STATISTICS', 'Incorrect Statistics'),
        ('CHEATING', 'Cheating'),
        ('OTHER', 'Other'),
    ]

    STATUS_CHOICES = [
        ('OPEN', 'Open'),
        ('UNDER_REVIEW', 'Under Review'),
        ('RESOLVED', 'Resolved'),
    ]

    RESOLUTION_CHOICES = [
        ('ACCEPTED', 'Accepted'),
        ('REJECTED', 'Rejected'),
        ('CORRECTED', 'Corrected'),
    ]

    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='disputes')
    match = models.ForeignKey('matches.Match', on_delete=models.CASCADE, related_name='disputes')
    raised_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='raised_disputes')
    reason = models.CharField(max_length=25, choices=REASON_CHOICES)
    description = models.TextField()
    status = models.CharField(max_length=15, choices=STATUS_CHOICES, default='OPEN')
    resolution = models.CharField(max_length=15, choices=RESOLUTION_CHOICES, blank=True, null=True)
    resolved_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='resolved_disputes')
    resolution_notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'disputes'
        ordering = ['-created_at']

    def __str__(self):
        return f"Dispute #{self.id}: {self.get_reason_display()} - Match {self.match_id}"


class DisputeComment(models.Model):
    dispute = models.ForeignKey(Dispute, on_delete=models.CASCADE, related_name='comments')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='dispute_comments')
    comment = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'dispute_comments'
        ordering = ['created_at']

    def __str__(self):
        return f"Comment by {self.user.username} on Dispute #{self.dispute_id}"
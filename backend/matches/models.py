from django.db import models
from django.conf import settings


class Match(models.Model):
    STATUS_CHOICES = [
        ('SCHEDULED', 'Scheduled'),
        ('AWAITING_RESULT', 'Awaiting Result'),
        ('EVIDENCE_SUBMITTED', 'Evidence Submitted'),
        ('AI_PROCESSING', 'AI Processing'),
        ('ADMIN_REVIEW', 'Admin Review'),
        ('DISPUTED', 'Disputed'),
        ('VERIFIED', 'Verified'),
        ('REJECTED', 'Rejected'),
        ('CANCELLED', 'Cancelled'),
    ]

    VALID_TRANSITIONS = {
        'SCHEDULED': ['AWAITING_RESULT', 'CANCELLED'],
        'AWAITING_RESULT': ['EVIDENCE_SUBMITTED', 'CANCELLED'],
        'EVIDENCE_SUBMITTED': ['AI_PROCESSING'],
        'AI_PROCESSING': ['ADMIN_REVIEW', 'VERIFIED'],
        'ADMIN_REVIEW': ['VERIFIED', 'REJECTED', 'DISPUTED'],
        'DISPUTED': ['ADMIN_REVIEW', 'CANCELLED'],
        'VERIFIED': [],
        'REJECTED': ['AWAITING_RESULT'],
        'CANCELLED': [],
    }

    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='matches')
    tournament = models.ForeignKey('tournaments.Tournament', on_delete=models.CASCADE, related_name='matches', null=True, blank=True)
    round = models.ForeignKey('tournaments.TournamentRound', on_delete=models.SET_NULL, null=True, blank=True, related_name='matches')
    home_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='home_matches')
    away_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='away_matches')
    home_score = models.PositiveIntegerField(blank=True, null=True)
    away_score = models.PositiveIntegerField(blank=True, null=True)
    status = models.CharField(max_length=25, choices=STATUS_CHOICES, default='SCHEDULED')
    scheduled_at = models.DateTimeField(blank=True, null=True)
    played_at = models.DateTimeField(blank=True, null=True)
    verified_at = models.DateTimeField(blank=True, null=True)
    verified_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='verified_matches')
    is_idempotent_processed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'matches'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.home_user.username} vs {self.away_user.username} ({self.status})"

    def can_transition_to(self, new_status):
        allowed = self.VALID_TRANSITIONS.get(self.status, [])
        return new_status in allowed

    def transition_to(self, new_status):
        if not self.can_transition_to(new_status):
            return False, f"Cannot transition from {self.status} to {new_status}"
        self.status = new_status
        self.save()
        return True, "Transition successful"


class MatchEvidence(models.Model):
    SOURCE_CHOICES = [
        ('SCREENSHOT', 'Screenshot'),
        ('VIDEO', 'Video'),
        ('MANUAL', 'Manual'),
    ]

    match = models.ForeignKey(Match, on_delete=models.CASCADE, related_name='evidences')
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='match_evidences')
    file_reference = models.CharField(max_length=500)
    file_name = models.CharField(max_length=255)
    file_size = models.PositiveIntegerField(default=0)
    checksum = models.CharField(max_length=64, blank=True, default='')
    source_type = models.CharField(max_length=20, choices=SOURCE_CHOICES, default='SCREENSHOT')
    is_primary = models.BooleanField(default=False)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'match_evidences'
        ordering = ['-uploaded_at']

    def __str__(self):
        return f"Evidence for Match {self.match_id} by {self.uploaded_by.username}"


class MatchStatistics(models.Model):
    match = models.OneToOneField(Match, on_delete=models.CASCADE, related_name='statistics')
    home_possession = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    away_possession = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    home_shots = models.PositiveIntegerField(blank=True, null=True)
    away_shots = models.PositiveIntegerField(blank=True, null=True)
    home_shots_on_target = models.PositiveIntegerField(blank=True, null=True)
    away_shots_on_target = models.PositiveIntegerField(blank=True, null=True)
    home_pass_accuracy = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    away_pass_accuracy = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    home_tackles = models.PositiveIntegerField(blank=True, null=True)
    away_tackles = models.PositiveIntegerField(blank=True, null=True)
    home_corners = models.PositiveIntegerField(blank=True, null=True)
    away_corners = models.PositiveIntegerField(blank=True, null=True)
    home_fouls = models.PositiveIntegerField(blank=True, null=True)
    away_fouls = models.PositiveIntegerField(blank=True, null=True)
    extra_data = models.JSONField(blank=True, default=dict)
    ai_confidence = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    ai_raw_output = models.JSONField(blank=True, default=dict)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'match_statistics'

    def __str__(self):
        return f"Stats for Match {self.match_id}"


class MatchVerification(models.Model):
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('AI_PROCESSING', 'AI Processing'),
        ('AI_VERIFIED', 'AI Verified'),
        ('ADMIN_REVIEW', 'Admin Review'),
        ('DISPUTED', 'Disputed'),
        ('REJECTED', 'Rejected'),
        ('VERIFIED', 'Verified'),
    ]

    match = models.OneToOneField(Match, on_delete=models.CASCADE, related_name='verification')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    ai_extracted_data = models.JSONField(blank=True, default=dict)
    ai_confidence_score = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    admin_notes = models.TextField(blank=True, default='')
    verified_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    verified_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'match_verifications'

    def __str__(self):
        return f"Verification for Match {self.match_id} ({self.status})"


class MatchStateTransition(models.Model):
    match = models.ForeignKey(Match, on_delete=models.CASCADE, related_name='state_transitions')
    from_status = models.CharField(max_length=25)
    to_status = models.CharField(max_length=25)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    metadata = models.JSONField(blank=True, default=dict)

    class Meta:
        db_table = 'match_state_transitions'
        ordering = ['-created_at']

    def __str__(self):
        return f"Match {self.match_id}: {self.from_status} → {self.to_status}"


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

    match = models.ForeignKey(Match, on_delete=models.CASCADE, related_name='events')
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
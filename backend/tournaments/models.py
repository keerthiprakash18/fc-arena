import string
import random
from django.db import models
from django.conf import settings


def generate_tournament_code():
    chars = string.ascii_uppercase + string.digits
    while True:
        code = ''.join(random.choices(chars, k=6))
        formatted = f"TRN-{code}"
        if not Tournament.objects.filter(tournament_code=formatted).exists():
            return formatted


class Tournament(models.Model):
    STATUS_CHOICES = [
        ('DRAFT', 'Draft'),
        ('REGISTRATION_OPEN', 'Registration Open'),
        ('REGISTRATION_CLOSED', 'Registration Closed'),
        ('SEEDING', 'Seeding'),
        ('FIXTURES_GENERATING', 'Fixtures Generating'),
        ('READY', 'Ready'),
        ('IN_PROGRESS', 'In Progress'),
        ('SUSPENDED', 'Suspended'),
        ('COMPLETED', 'Completed'),
        ('ARCHIVED', 'Archived'),
        ('CANCELLED', 'Cancelled'),
    ]

    FORMAT_CHOICES = [
        ('LEAGUE', 'League'),
        ('KNOCKOUT', 'Knockout'),
        ('GROUP_KNOCKOUT', 'Group + Knockout'),
        ('CUSTOM', 'Custom'),
    ]

    VALID_TRANSITIONS = {
        'DRAFT': ['REGISTRATION_OPEN', 'CANCELLED'],
        'REGISTRATION_OPEN': ['REGISTRATION_CLOSED', 'CANCELLED'],
        'REGISTRATION_CLOSED': ['SEEDING', 'REGISTRATION_OPEN'],
        'SEEDING': ['FIXTURES_GENERATING', 'REGISTRATION_CLOSED'],
        'FIXTURES_GENERATING': ['READY', 'SEEDING'],
        'READY': ['IN_PROGRESS', 'CANCELLED'],
        'IN_PROGRESS': ['COMPLETED', 'SUSPENDED'],
        'SUSPENDED': ['IN_PROGRESS', 'CANCELLED'],
        'COMPLETED': ['ARCHIVED'],
        'ARCHIVED': [],
        'CANCELLED': [],
    }

    league = models.ForeignKey('leagues.League', on_delete=models.CASCADE, related_name='tournaments')
    season = models.ForeignKey('seasons.Season', on_delete=models.SET_NULL, null=True, blank=True, related_name='tournaments')
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True, default='')
    tournament_code = models.CharField(max_length=10, unique=True, default=generate_tournament_code)
    format = models.CharField(max_length=20, choices=FORMAT_CHOICES, default='KNOCKOUT')
    status = models.CharField(max_length=25, choices=STATUS_CHOICES, default='DRAFT')
    max_participants = models.PositiveIntegerField(default=16)
    entry_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    prize_pool = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    registration_deadline = models.DateTimeField(blank=True, null=True)
    start_date = models.DateTimeField(blank=True, null=True)
    end_date = models.DateTimeField(blank=True, null=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='created_tournaments')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'tournaments'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} ({self.tournament_code})"

    def can_transition_to(self, new_status):
        allowed = self.VALID_TRANSITIONS.get(self.status, [])
        return new_status in allowed

    def transition_to(self, new_status):
        if not self.can_transition_to(new_status):
            return False, f"Cannot transition from {self.status} to {new_status}"
        self.status = new_status
        self.save(update_fields=['status', 'updated_at'])
        return True, "Transition successful"


class TournamentParticipant(models.Model):
    STATUS_CHOICES = [
        ('REGISTERED', 'Registered'),
        ('CONFIRMED', 'Confirmed'),
        ('ACTIVE', 'Active'),
        ('ELIMINATED', 'Eliminated'),
        ('WITHDRAWN', 'Withdrawn'),
    ]

    tournament = models.ForeignKey(Tournament, on_delete=models.CASCADE, related_name='participants')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='tournament_participations')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='REGISTERED')
    seed_number = models.PositiveIntegerField(blank=True, null=True)
    registered_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'tournament_participants'
        unique_together = ['tournament', 'user']
        ordering = ['seed_number', 'registered_at']

    def __str__(self):
        return f"{self.user.username} in {self.tournament.name}"


class TournamentGroup(models.Model):
    tournament = models.ForeignKey(Tournament, on_delete=models.CASCADE, related_name='groups')
    name = models.CharField(max_length=50)
    group_number = models.PositiveIntegerField()

    class Meta:
        db_table = 'tournament_groups'
        unique_together = ['tournament', 'group_number']
        ordering = ['group_number']

    def __str__(self):
        return f"{self.tournament.name} - Group {self.name}"


class TournamentGroupMember(models.Model):
    group = models.ForeignKey(TournamentGroup, on_delete=models.CASCADE, related_name='members')
    participant = models.ForeignKey(TournamentParticipant, on_delete=models.CASCADE, related_name='group_memberships')
    position = models.PositiveIntegerField(default=0)

    class Meta:
        db_table = 'tournament_group_members'
        unique_together = ['group', 'participant']
        ordering = ['position']

    def __str__(self):
        return f"{self.participant.user.username} in {self.group.name}"


class TournamentRound(models.Model):
    tournament = models.ForeignKey(Tournament, on_delete=models.CASCADE, related_name='rounds')
    name = models.CharField(max_length=100)
    round_number = models.PositiveIntegerField()
    round_type = models.CharField(max_length=50, default='KNOCKOUT')
    is_current = models.BooleanField(default=False)

    class Meta:
        db_table = 'tournament_rounds'
        unique_together = ['tournament', 'round_number']
        ordering = ['round_number']

    def __str__(self):
        return f"{self.tournament.name} - {self.name}"


class TournamentStateTransition(models.Model):
    tournament = models.ForeignKey(Tournament, on_delete=models.CASCADE, related_name='state_transitions')
    from_status = models.CharField(max_length=25)
    to_status = models.CharField(max_length=25)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    metadata = models.JSONField(blank=True, default=dict)

    class Meta:
        db_table = 'tournament_state_transitions'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.tournament.name}: {self.from_status} → {self.to_status}"
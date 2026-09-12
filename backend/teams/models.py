"""Teams — a squad layer that sits *alongside* the existing user-based system.

DESIGN NOTE (important): this app is strictly ADDITIVE.

The platform originally modelled competition as User vs User
(``Match.home_user`` / ``Match.away_user``), and every statistics model
(``PlayerLeagueStatistics``, ``LeagueStanding``, ``PlayerLeagueRating``,
``RatingHistory``, ``Leaderboard``, ``LeagueRecord``, ``Award``) is keyed on
``user``. That pipeline is untouched and keeps working exactly as before.

Teams are a second, parallel way to compete, reached through the nullable
``Match.home_team`` / ``Match.away_team`` FKs. A match is either user-based
(legacy) or team-based (new) — never both. This avoids a risky migration of
existing data while giving organisers the team-centric workflow they asked for.
"""

from django.conf import settings
from django.db import models


class Team(models.Model):
    """A squad competing in a league."""

    league = models.ForeignKey(
        'leagues.League', on_delete=models.CASCADE, related_name='teams'
    )
    name = models.CharField(max_length=120)
    short_name = models.CharField(max_length=20, blank=True, default='')
    slug = models.SlugField(max_length=140)
    logo = models.ImageField(upload_to='teams/logos/', null=True, blank=True)
    banner = models.ImageField(upload_to='teams/banners/', null=True, blank=True)
    description = models.TextField(blank=True, default='')
    game = models.CharField(max_length=100, blank=True, default='')

    captain = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='captained_teams',
    )
    manager = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='managed_teams',
    )

    # {"twitter": "...", "youtube": "...", "discord": "..."} — free-form by design.
    social_links = models.JSONField(blank=True, default=dict)

    is_active = models.BooleanField(default=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='created_teams',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'teams'
        unique_together = ['league', 'slug']
        ordering = ['name']
        indexes = [models.Index(fields=['league', 'is_active'])]

    def __str__(self):
        return f'{self.name} ({self.league.name})'

    @property
    def member_count(self):
        return self.members.filter(is_active=True).count()


class TeamMember(models.Model):
    """Membership of a user in a team, with a squad role."""

    ROLE_CHOICES = [
        ('CAPTAIN', 'Captain'),
        ('PLAYER', 'Player'),
        ('SUBSTITUTE', 'Substitute'),
        ('COACH', 'Coach'),
    ]

    team = models.ForeignKey(Team, on_delete=models.CASCADE, related_name='members')
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='team_memberships'
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='PLAYER')
    jersey_number = models.PositiveIntegerField(null=True, blank=True)
    position = models.CharField(max_length=50, blank=True, default='')
    is_active = models.BooleanField(default=True)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'team_members'
        unique_together = ['team', 'user']
        ordering = ['role', 'joined_at']

    def __str__(self):
        return f'{self.user.username} @ {self.team.name} ({self.role})'


class TeamStatistics(models.Model):
    """Aggregated team record, derived from VERIFIED matches.

    Mirrors the shape of ``statistics.PlayerLeagueStatistics`` so the two
    pipelines read alike. Never edited by hand — see ``teams.services``.
    """

    team = models.OneToOneField(Team, on_delete=models.CASCADE, related_name='statistics')

    matches_played = models.PositiveIntegerField(default=0)
    wins = models.PositiveIntegerField(default=0)
    draws = models.PositiveIntegerField(default=0)
    losses = models.PositiveIntegerField(default=0)

    goals_scored = models.PositiveIntegerField(default=0)
    goals_conceded = models.PositiveIntegerField(default=0)
    clean_sheets = models.PositiveIntegerField(default=0)
    points = models.PositiveIntegerField(default=0)

    # Most-recent-first list of 'W' | 'D' | 'L', capped by teams.services.FORM_LENGTH.
    form = models.JSONField(blank=True, default=list)
    current_win_streak = models.PositiveIntegerField(default=0)
    best_win_streak = models.PositiveIntegerField(default=0)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'team_statistics'
        verbose_name_plural = 'team statistics'

    def __str__(self):
        return f'Statistics for {self.team.name}'

    @property
    def goal_difference(self):
        return self.goals_scored - self.goals_conceded

    @property
    def win_rate(self):
        if not self.matches_played:
            return 0.0
        return round(self.wins * 100.0 / self.matches_played, 1)

    @property
    def goals_per_match(self):
        if not self.matches_played:
            return 0.0
        return round(self.goals_scored / self.matches_played, 2)

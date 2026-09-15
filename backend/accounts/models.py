from django.conf import settings
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils import timezone


class User(AbstractUser):
    game_uid = models.CharField(max_length=100, blank=True, null=True)
    game_in_game_name = models.CharField(max_length=100, blank=True, null=True)
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    profile_photo = models.ImageField(upload_to='profiles/', blank=True, null=True)
    date_of_birth = models.DateField(blank=True, null=True)

    # Player-profile fields (Phase 2 of the FCFC upgrade). Additive and nullable
    # so existing rows are unaffected.
    position = models.CharField(max_length=50, blank=True, default='')
    country = models.CharField(max_length=60, blank=True, default='')
    # {"twitter": "...", "youtube": "...", "discord": "..."} — free-form by design.
    social_links = models.JSONField(blank=True, default=dict)

    class Meta:
        db_table = 'users'

    def __str__(self):
        return self.username

    @property
    def display_name(self):
        """Real name if we have one, otherwise the username."""
        full = f'{self.first_name} {self.last_name}'.strip()
        return full or self.username


class OTPCode(models.Model):
    """A single-use, time-boxed verification code.

    One row per issued code, scoped to a user *and* a purpose, so a password
    reset code can never be replayed as an account-verification code. Issuing a
    new code retires any previous unused one for the same purpose, which keeps
    exactly one live code per (user, purpose) at any moment.
    """

    class Purpose(models.TextChoices):
        EMAIL_VERIFY = 'EMAIL_VERIFY', 'Email verification'
        PASSWORD_RESET = 'PASSWORD_RESET', 'Password reset'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='otp_codes',
    )
    code = models.CharField(max_length=6)
    purpose = models.CharField(max_length=20, choices=Purpose.choices)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    attempts = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'otp_codes'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'purpose', 'is_used']),
        ]

    def __str__(self):
        return f'{self.user_id}:{self.purpose}:{self.code}'

    @property
    def is_expired(self):
        return timezone.now() >= self.expires_at

    @property
    def is_valid(self):
        return not self.is_used and not self.is_expired
"""Issuing and verifying one-time codes for sign-up and password reset.

Delivery is pluggable. This deployment has no SMTP account configured, so the
default transport is the console backend: the message is written to the server
log, and — only while ``DEBUG`` is on — the code is also echoed back through the
API (``dev_otp``) so the register → verify → login and forgot → reset flows can
be completed end to end without a mail server. Set ``EMAIL_HOST`` (with the
usual ``EMAIL_*`` variables) to switch to real delivery, after which the code is
never returned in a response.
"""

import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.core.mail import send_mail
from django.utils import timezone

from .models import OTPCode

logger = logging.getLogger(__name__)

OTP_LENGTH = 6


def _ttl_minutes():
    return int(getattr(settings, 'OTP_TTL_MINUTES', 10))


def _max_attempts():
    return int(getattr(settings, 'OTP_MAX_ATTEMPTS', 5))


def _mail_transport_available():
    """True only when a real SMTP transport has actually been configured.

    The console backend is a development affordance, not a way to reach a user,
    so it deliberately does not count as delivery.
    """
    backend = (getattr(settings, 'EMAIL_BACKEND', '') or '').lower()
    if 'smtp' not in backend:
        return False
    return bool(getattr(settings, 'EMAIL_HOST', ''))


def generate_otp(user, purpose):
    """Issue a fresh code, retiring any previous unused code for ``purpose``."""
    OTPCode.objects.filter(user=user, purpose=purpose, is_used=False).update(
        is_used=True
    )
    code = f'{secrets.randbelow(10 ** OTP_LENGTH):0{OTP_LENGTH}d}'
    return OTPCode.objects.create(
        user=user,
        code=code,
        purpose=purpose,
        expires_at=timezone.now() + timedelta(minutes=_ttl_minutes()),
    )


def verify_otp(user, code, purpose):
    """Check ``code`` against the user's live code. Returns ``(ok, message)``.

    The code is consumed on success, and burned after too many wrong guesses so
    a six-digit code cannot be brute-forced within its lifetime.
    """
    code = (code or '').strip()
    otp = (
        OTPCode.objects
        .filter(user=user, purpose=purpose, is_used=False)
        .order_by('-created_at')
        .first()
    )
    if otp is None:
        return False, 'No pending code for this account. Please request a new one.'

    if otp.is_expired:
        otp.is_used = True
        otp.save(update_fields=['is_used'])
        return False, 'That code has expired. Please request a new one.'

    if otp.attempts >= _max_attempts():
        otp.is_used = True
        otp.save(update_fields=['is_used'])
        return False, 'Too many incorrect attempts. Please request a new code.'

    if not secrets.compare_digest(otp.code, code):
        otp.attempts += 1
        if otp.attempts >= _max_attempts():
            otp.is_used = True
            otp.save(update_fields=['attempts', 'is_used'])
            return False, 'Too many incorrect attempts. Please request a new code.'
        otp.save(update_fields=['attempts'])
        remaining = _max_attempts() - otp.attempts
        plural = '' if remaining == 1 else 's'
        return False, f'Incorrect code. {remaining} attempt{plural} remaining.'

    otp.is_used = True
    otp.save(update_fields=['is_used'])
    return True, 'Verified.'


def deliver_otp(user, otp):
    """Send ``otp`` to the user. Returns the code when the caller may see it."""
    subject = 'Your FC Harina verification code'
    body = (
        f'Your FC Harina verification code is {otp.code}.\n\n'
        f'It expires in {_ttl_minutes()} minutes. If you did not request this, '
        'you can safely ignore this message.'
    )

    if _mail_transport_available() and user.email:
        try:
            send_mail(
                subject,
                body,
                getattr(settings, 'DEFAULT_FROM_EMAIL', 'no-reply@fcharina.app'),
                [user.email],
                fail_silently=False,
            )
        except Exception:  # pragma: no cover - depends on the mail server
            logger.exception('OTP email delivery failed for user %s', user.pk)

    # Always log: with no SMTP transport this is the operator's only view of the
    # code, and it doubles as an audit trail of every code issued.
    logger.warning('OTP %s for %s: %s', otp.purpose, user.username, otp.code)

    if getattr(settings, 'OTP_EXPOSE_IN_RESPONSE', settings.DEBUG):
        return otp.code
    return None

"""Registration verification (OTP) and password reset."""

from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import override_settings
from django.utils import timezone
from datetime import timedelta

from tests.base import ApiTestCase, PASSWORD
from accounts.models import OTPCode
from accounts.services import generate_otp, verify_otp

User = get_user_model()


@override_settings(REQUIRE_OTP_VERIFICATION=True, OTP_EXPOSE_IN_RESPONSE=True)
class RegistrationOTPTests(ApiTestCase):
    def _register(self, username='fresh', email='fresh@example.com', password='strongpass123'):
        return self.client.post('/api/auth/register/', {
            'username': username, 'email': email, 'password': password,
        }, format='json')

    def test_register_creates_inactive_user_and_issues_code(self):
        response = self._register()
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(response.data['otp_required'])
        self.assertIn('dev_otp', response.data)

        user = User.objects.get(username='fresh')
        self.assertFalse(user.is_active)
        self.assertEqual(
            OTPCode.objects.filter(user=user, purpose=OTPCode.Purpose.EMAIL_VERIFY).count(), 1
        )

    def test_inactive_user_cannot_log_in(self):
        self._register()
        response = self.client.post('/api/auth/login/', {
            'username': 'fresh', 'password': 'strongpass123',
        }, format='json')
        self.assertEqual(response.status_code, 401)

    def test_unverified_login_says_why(self):
        """The client routes on this wording, so it is part of the contract."""
        self._register()
        response = self.client.post('/api/auth/login/', {
            'username': 'fresh', 'password': 'strongpass123',
        }, format='json')
        self.assertIn('not been verified', response.data['detail'].lower())

    def test_wrong_password_on_an_unverified_account_still_looks_generic(self):
        """An unverified account must not be a username oracle: the real reason
        is only revealed when the password is correct."""
        self._register()
        response = self.client.post('/api/auth/login/', {
            'username': 'fresh', 'password': 'definitely-wrong',
        }, format='json')
        self.assertEqual(response.status_code, 401)
        self.assertNotIn('not been verified', response.data['detail'].lower())

    def test_verify_otp_activates_account(self):
        code = self._register().data['dev_otp']
        response = self.client.post('/api/auth/verify-otp/', {
            'username': 'fresh', 'code': code,
        }, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(User.objects.get(username='fresh').is_active)

    def test_verified_user_can_log_in(self):
        code = self._register().data['dev_otp']
        self.client.post('/api/auth/verify-otp/', {'username': 'fresh', 'code': code}, format='json')
        response = self.client.post('/api/auth/login/', {
            'username': 'fresh', 'password': 'strongpass123',
        }, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.data)

    def test_verify_otp_rejects_wrong_code(self):
        self._register()
        response = self.client.post('/api/auth/verify-otp/', {
            'username': 'fresh', 'code': '000000',
        }, format='json')
        self.assertEqual(response.status_code, 400)
        self.assertFalse(User.objects.get(username='fresh').is_active)

    def test_code_is_single_use(self):
        code = self._register().data['dev_otp']
        self.client.post('/api/auth/verify-otp/', {'username': 'fresh', 'code': code}, format='json')
        response = self.client.post('/api/auth/verify-otp/', {
            'username': 'fresh', 'code': code,
        }, format='json')
        self.assertEqual(response.status_code, 400)

    def test_expired_code_is_rejected(self):
        self._register()
        OTPCode.objects.update(expires_at=timezone.now() - timedelta(minutes=1))
        user = User.objects.get(username='fresh')
        code = OTPCode.objects.get(user=user).code
        response = self.client.post('/api/auth/verify-otp/', {
            'username': 'fresh', 'code': code,
        }, format='json')
        self.assertEqual(response.status_code, 400)
        self.assertFalse(User.objects.get(username='fresh').is_active)

    def test_code_is_burned_after_too_many_wrong_attempts(self):
        code = self._register().data['dev_otp']
        for _ in range(settings.OTP_MAX_ATTEMPTS):
            self.client.post('/api/auth/verify-otp/', {
                'username': 'fresh', 'code': '000000',
            }, format='json')
        # The real code no longer works once the attempt budget is spent.
        response = self.client.post('/api/auth/verify-otp/', {
            'username': 'fresh', 'code': code,
        }, format='json')
        self.assertEqual(response.status_code, 400)
        self.assertFalse(User.objects.get(username='fresh').is_active)

    def test_resend_issues_a_new_code_and_retires_the_old_one(self):
        first = self._register().data['dev_otp']
        response = self.client.post('/api/auth/resend-otp/', {'username': 'fresh'}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        second = response.data['dev_otp']
        self.assertNotEqual(first, second)

        stale = self.client.post('/api/auth/verify-otp/', {'username': 'fresh', 'code': first}, format='json')
        self.assertEqual(stale.status_code, 400)
        fresh = self.client.post('/api/auth/verify-otp/', {'username': 'fresh', 'code': second}, format='json')
        self.assertEqual(fresh.status_code, 200)

    def test_verify_otp_for_unknown_user_is_rejected(self):
        response = self.client.post('/api/auth/verify-otp/', {
            'username': 'nobody', 'code': '123456',
        }, format='json')
        self.assertEqual(response.status_code, 400)


class RegistrationWithoutOTPTests(ApiTestCase):
    """The flag can be turned off for a deployment that cannot deliver a code."""

    @override_settings(REQUIRE_OTP_VERIFICATION=False)
    def test_register_creates_active_user(self):
        response = self.client.post('/api/auth/register/', {
            'username': 'direct', 'email': 'direct@example.com', 'password': 'strongpass123',
        }, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertFalse(response.data['otp_required'])
        self.assertTrue(User.objects.get(username='direct').is_active)

        login = self.client.post('/api/auth/login/', {
            'username': 'direct', 'password': 'strongpass123',
        }, format='json')
        self.assertEqual(login.status_code, 200)


@override_settings(OTP_EXPOSE_IN_RESPONSE=True)
class PasswordResetTests(ApiTestCase):
    def test_forgot_password_issues_a_reset_code(self):
        response = self.client.post('/api/auth/forgot-password/', {'identifier': 'alice'}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertIn('dev_otp', response.data)
        self.assertTrue(OTPCode.objects.filter(
            user=self.alice, purpose=OTPCode.Purpose.PASSWORD_RESET
        ).exists())

    def test_forgot_password_does_not_leak_unknown_accounts(self):
        response = self.client.post('/api/auth/forgot-password/', {'identifier': 'ghost'}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertNotIn('dev_otp', response.data)

    def test_reset_password_changes_the_password(self):
        code = self.client.post('/api/auth/forgot-password/', {'identifier': 'alice'}, format='json').data['dev_otp']
        response = self.client.post('/api/auth/reset-password/', {
            'identifier': 'alice', 'code': code, 'new_password': 'brandnewpass1',
        }, format='json')
        self.assertEqual(response.status_code, 200, response.data)

        login = self.client.post('/api/auth/login/', {
            'username': 'alice', 'password': 'brandnewpass1',
        }, format='json')
        self.assertEqual(login.status_code, 200)
        self.alice.refresh_from_db()
        self.assertTrue(self.alice.check_password('brandnewpass1'))

    def test_reset_password_rejects_wrong_code(self):
        self.client.post('/api/auth/forgot-password/', {'identifier': 'alice'}, format='json')
        response = self.client.post('/api/auth/reset-password/', {
            'identifier': 'alice', 'code': '000000', 'new_password': 'brandnewpass1',
        }, format='json')
        self.assertEqual(response.status_code, 400)
        self.alice.refresh_from_db()
        self.assertTrue(self.alice.check_password(PASSWORD))

    def test_reset_code_cannot_be_reused(self):
        code = self.client.post('/api/auth/forgot-password/', {'identifier': 'alice'}, format='json').data['dev_otp']
        self.client.post('/api/auth/reset-password/', {
            'identifier': 'alice', 'code': code, 'new_password': 'brandnewpass1',
        }, format='json')
        response = self.client.post('/api/auth/reset-password/', {
            'identifier': 'alice', 'code': code, 'new_password': 'anotherpass1',
        }, format='json')
        self.assertEqual(response.status_code, 400)

    def test_reset_password_rejects_short_password(self):
        code = self.client.post('/api/auth/forgot-password/', {'identifier': 'alice'}, format='json').data['dev_otp']
        response = self.client.post('/api/auth/reset-password/', {
            'identifier': 'alice', 'code': code, 'new_password': 'short',
        }, format='json')
        self.assertEqual(response.status_code, 400)

    def test_verify_code_cannot_be_used_as_a_reset_code(self):
        """Purpose scoping: a registration code must not authorise a reset."""
        otp = generate_otp(self.alice, OTPCode.Purpose.EMAIL_VERIFY)
        response = self.client.post('/api/auth/reset-password/', {
            'identifier': 'alice', 'code': otp.code, 'new_password': 'brandnewpass1',
        }, format='json')
        self.assertEqual(response.status_code, 400)


class OTPServiceTests(ApiTestCase):
    def test_generate_retires_previous_unused_code(self):
        first = generate_otp(self.alice, OTPCode.Purpose.EMAIL_VERIFY)
        second = generate_otp(self.alice, OTPCode.Purpose.EMAIL_VERIFY)
        first.refresh_from_db()
        self.assertTrue(first.is_used)
        self.assertTrue(second.is_valid)
        self.assertEqual(
            OTPCode.objects.filter(
                user=self.alice, purpose=OTPCode.Purpose.EMAIL_VERIFY, is_used=False
            ).count(),
            1,
        )

    def test_verify_consumes_the_code(self):
        otp = generate_otp(self.alice, OTPCode.Purpose.EMAIL_VERIFY)
        ok, _ = verify_otp(self.alice, otp.code, OTPCode.Purpose.EMAIL_VERIFY)
        self.assertTrue(ok)
        ok_again, _ = verify_otp(self.alice, otp.code, OTPCode.Purpose.EMAIL_VERIFY)
        self.assertFalse(ok_again)

    def test_codes_are_six_digits(self):
        otp = generate_otp(self.alice, OTPCode.Purpose.EMAIL_VERIFY)
        self.assertEqual(len(otp.code), 6)
        self.assertTrue(otp.code.isdigit())

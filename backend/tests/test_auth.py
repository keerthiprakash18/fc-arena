"""Authentication: registration, login, token refresh, profile."""

from django.contrib.auth import get_user_model
from tests.base import ApiTestCase, PASSWORD

User = get_user_model()


class RegistrationTests(ApiTestCase):
    def test_register_creates_user(self):
        response = self.client.post('/api/auth/register/', {
            'username': 'newplayer',
            'email': 'new@example.com',
            'password': 'strongpass123',
            'game_in_game_name': 'New Player',
        }, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(User.objects.filter(username='newplayer').exists())

    def test_register_rejects_short_password(self):
        response = self.client.post('/api/auth/register/', {
            'username': 'shorty', 'email': 's@example.com', 'password': 'abc',
        }, format='json')
        self.assertEqual(response.status_code, 400)
        self.assertFalse(User.objects.filter(username='shorty').exists())

    def test_register_rejects_duplicate_username(self):
        response = self.client.post('/api/auth/register/', {
            'username': 'alice', 'email': 'other@example.com', 'password': 'strongpass123',
        }, format='json')
        self.assertEqual(response.status_code, 400)

    def test_password_is_hashed_not_stored_plain(self):
        self.client.post('/api/auth/register/', {
            'username': 'hashme', 'email': 'h@example.com', 'password': 'strongpass123',
        }, format='json')
        user = User.objects.get(username='hashme')
        self.assertNotEqual(user.password, 'strongpass123')
        self.assertTrue(user.check_password('strongpass123'))


class LoginTests(ApiTestCase):
    def test_login_returns_access_and_refresh(self):
        response = self.client.post('/api/auth/login/', {
            'username': 'alice', 'password': PASSWORD,
        }, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)

    def test_login_with_wrong_password_is_rejected(self):
        response = self.client.post('/api/auth/login/', {
            'username': 'alice', 'password': 'wrong-password',
        }, format='json')
        self.assertEqual(response.status_code, 401)

    def test_login_with_unknown_user_is_rejected(self):
        response = self.client.post('/api/auth/login/', {
            'username': 'ghost', 'password': PASSWORD,
        }, format='json')
        self.assertEqual(response.status_code, 401)

    def test_refresh_issues_new_access_token(self):
        login = self.client.post('/api/auth/login/', {
            'username': 'alice', 'password': PASSWORD,
        }, format='json')
        response = self.client.post('/api/auth/refresh/', {
            'refresh': login.data['refresh'],
        }, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.data)

    def test_refresh_rejects_garbage_token(self):
        response = self.client.post('/api/auth/refresh/', {
            'refresh': 'not-a-real-token',
        }, format='json')
        self.assertEqual(response.status_code, 401)


class ProfileTests(ApiTestCase):
    def test_profile_requires_authentication(self):
        self.assertEqual(self.client.get('/api/auth/profile/').status_code, 401)

    def test_profile_returns_current_user(self):
        self.authenticate(self.alice)
        response = self.client.get('/api/auth/profile/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['username'], 'alice')

    def test_profile_exposes_staff_flags(self):
        self.authenticate(self.alice)
        response = self.client.get('/api/auth/profile/')
        self.assertIn('isStaff', response.data)
        self.assertIn('isSuperuser', response.data)
        self.assertFalse(response.data['isStaff'])

    def test_profile_rejects_invalid_token(self):
        self.client.credentials(HTTP_AUTHORIZATION='Bearer garbage.token.here')
        self.assertEqual(self.client.get('/api/auth/profile/').status_code, 401)

    def test_staff_flags_are_read_only(self):
        """A user must not be able to promote themselves via the profile endpoint."""
        self.authenticate(self.alice)
        self.client.patch('/api/auth/profile/', {'is_staff': True}, format='json')
        self.alice.refresh_from_db()
        self.assertFalse(self.alice.is_staff)

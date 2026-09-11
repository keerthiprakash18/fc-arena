"""Shared fixtures and helpers for the FC ARENA API tests."""

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

User = get_user_model()

PASSWORD = 'testpass123'


class ApiTestCase(APITestCase):
    """Base class with three users, JWT helpers and league/match factories.

    Tests authenticate through the *real* login endpoint rather than forcing
    ``client.force_authenticate``, so a broken auth pipeline fails the suite.
    """

    def setUp(self):
        super().setUp()
        self.alice = User.objects.create_user('alice', 'alice@example.com', PASSWORD)
        self.bob = User.objects.create_user('bob', 'bob@example.com', PASSWORD)
        self.carol = User.objects.create_user('carol', 'carol@example.com', PASSWORD)

    # ── auth ────────────────────────────────────────────────────────────────
    def authenticate(self, user):
        """Log in over HTTP and attach the resulting bearer token."""
        response = self.client.post(
            '/api/auth/login/',
            {'username': user.username, 'password': PASSWORD},
            format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        token = response.data['access']
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        return token

    def logout(self):
        self.client.credentials()

    # ── factories ───────────────────────────────────────────────────────────
    def create_league(self, owner=None, name='Test League', slug='test-league'):
        """Create a league as ``owner`` (default alice) and return its payload."""
        self.authenticate(owner or self.alice)
        response = self.client.post(
            '/api/leagues/',
            {'name': name, 'slug': slug, 'description': ''},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)
        return response.data

    def join_league(self, user, league_code):
        self.authenticate(user)
        return self.client.post(
            '/api/leagues/join/', {'league_code': league_code}, format='json'
        )

    def create_match(self, league, home_user, away_user, actor=None):
        """Create a match inside ``league``; defaults to acting as alice."""
        self.authenticate(actor or self.alice)
        response = self.client.post(
            f"/api/leagues/{league['id']}/matches/",
            {'home_user': home_user.id, 'away_user': away_user.id},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)
        return response.data

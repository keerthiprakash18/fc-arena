"""Tournaments: creation, registration, fixtures and rounds."""

from tests.base import ApiTestCase


class TournamentTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.league = self.create_league()
        self.join_league(self.bob, self.league['league_code'])

    def _create_tournament(self, name='Cup', fmt='KNOCKOUT'):
        self.authenticate(self.alice)
        return self.client.post(
            f"/api/leagues/{self.league['id']}/tournaments/",
            {'name': name, 'format': fmt, 'description': ''},
            format='json',
        )

    def test_create_tournament(self):
        response = self._create_tournament()
        self.assertEqual(response.status_code, 201, response.data)

    def test_list_tournaments(self):
        self._create_tournament()
        self.authenticate(self.alice)
        response = self.client.get(f"/api/leagues/{self.league['id']}/tournaments/")
        self.assertEqual(response.status_code, 200)

    def test_detail_returns_200(self):
        tournament = self._create_tournament().data
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/tournaments/{tournament['id']}/"
        )
        self.assertEqual(response.status_code, 200)

    def test_registration_closed_until_tournament_opens(self):
        """A DRAFT tournament must not accept sign-ups yet."""
        tournament = self._create_tournament().data
        self.authenticate(self.bob)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/tournaments/{tournament['id']}/register/",
            {}, format='json',
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn('not open', response.data['error'].lower())

    def test_participants_endpoint(self):
        tournament = self._create_tournament().data
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/tournaments/{tournament['id']}/participants/"
        )
        self.assertEqual(response.status_code, 200)

    def test_rounds_endpoint(self):
        tournament = self._create_tournament().data
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/tournaments/{tournament['id']}/rounds/"
        )
        self.assertEqual(response.status_code, 200)

    def test_fixtures_blocked_while_still_draft(self):
        """Fixtures must not be generated before registration closes."""
        tournament = self._create_tournament().data
        self.authenticate(self.alice)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/tournaments/{tournament['id']}/fixtures/",
            {}, format='json',
        )
        self.assertEqual(response.status_code, 409)
        self.assertIn('registration', response.data['error'].lower())

    def test_tournaments_require_authentication(self):
        self.logout()
        response = self.client.get(f"/api/leagues/{self.league['id']}/tournaments/")
        self.assertEqual(response.status_code, 401)

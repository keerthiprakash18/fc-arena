"""Dashboard aggregates and leaderboards."""

from tests.base import ApiTestCase


class DashboardTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.league = self.create_league()
        self.join_league(self.bob, self.league['league_code'])

    def test_overview_returns_200(self):
        self.authenticate(self.alice)
        response = self.client.get(f"/api/leagues/{self.league['id']}/dashboard/overview/")
        self.assertEqual(response.status_code, 200)

    def test_pending_reviews_returns_200(self):
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/dashboard/pending-reviews/"
        )
        self.assertEqual(response.status_code, 200)

    def test_match_status_distribution_returns_200(self):
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/dashboard/match-status/"
        )
        self.assertEqual(response.status_code, 200)

    def test_overview_requires_authentication(self):
        self.logout()
        response = self.client.get(f"/api/leagues/{self.league['id']}/dashboard/overview/")
        self.assertEqual(response.status_code, 401)

    def test_non_member_cannot_read_overview(self):
        self.authenticate(self.carol)
        response = self.client.get(f"/api/leagues/{self.league['id']}/dashboard/overview/")
        self.assertIn(response.status_code, (403, 404))


class LeaderboardTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.league = self.create_league()
        self.join_league(self.bob, self.league['league_code'])

    def test_list_returns_200(self):
        self.authenticate(self.alice)
        response = self.client.get(f"/api/leagues/{self.league['id']}/leaderboards/")
        self.assertEqual(response.status_code, 200)

    def test_regenerate_returns_200(self):
        self.authenticate(self.alice)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/leaderboards/regenerate/", {}, format='json'
        )
        self.assertIn(response.status_code, (200, 201, 202), response.data)

    def test_top_by_metric_returns_200(self):
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/leaderboards/rating/top/"
        )
        self.assertEqual(response.status_code, 200)

    def test_leaderboards_require_authentication(self):
        self.logout()
        response = self.client.get(f"/api/leagues/{self.league['id']}/leaderboards/")
        self.assertEqual(response.status_code, 401)

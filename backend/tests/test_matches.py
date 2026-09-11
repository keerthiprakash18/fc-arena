"""Matches: creation, listing, and the status-transition state machine."""

from matches.models import Match
from tests.base import ApiTestCase


class MatchTransitionModelTests(ApiTestCase):
    """The transition table is core business logic — test it without HTTP."""

    def setUp(self):
        super().setUp()
        self.league = self.create_league()
        self.match = Match.objects.create(
            league_id=self.league['id'],
            home_user=self.alice,
            away_user=self.bob,
            status='SCHEDULED',
        )

    def test_new_match_starts_scheduled(self):
        self.assertEqual(self.match.status, 'SCHEDULED')

    def test_happy_path_to_verified(self):
        for next_status in ['AWAITING_RESULT', 'EVIDENCE_SUBMITTED',
                            'AI_PROCESSING', 'ADMIN_REVIEW', 'VERIFIED']:
            ok, message = self.match.transition_to(next_status)
            self.assertTrue(ok, f'{next_status}: {message}')
        self.assertEqual(self.match.status, 'VERIFIED')

    def test_cannot_skip_steps(self):
        ok, message = self.match.transition_to('VERIFIED')
        self.assertFalse(ok)
        self.assertIn('Cannot transition', message)
        self.match.refresh_from_db()
        self.assertEqual(self.match.status, 'SCHEDULED')

    def test_verified_is_terminal(self):
        self.match.status = 'VERIFIED'
        self.match.save()
        ok, _ = self.match.transition_to('AWAITING_RESULT')
        self.assertFalse(ok)

    def test_rejected_can_return_to_awaiting_result(self):
        self.match.status = 'REJECTED'
        self.match.save()
        ok, _ = self.match.transition_to('AWAITING_RESULT')
        self.assertTrue(ok)

    def test_scheduled_can_be_cancelled(self):
        ok, _ = self.match.transition_to('CANCELLED')
        self.assertTrue(ok)

    def test_can_transition_to_reports_allowed_targets(self):
        self.assertTrue(self.match.can_transition_to('AWAITING_RESULT'))
        self.assertFalse(self.match.can_transition_to('ADMIN_REVIEW'))


class MatchApiTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.league = self.create_league()

    def test_create_match(self):
        match = self.create_match(self.league, self.alice, self.bob)
        self.assertEqual(match['home_username'], 'alice')
        self.assertEqual(match['away_username'], 'bob')

    def test_create_response_carries_full_match_shape(self):
        """The client parses the POST response straight into its Match model,
        so it must include league, status and usernames."""
        match = self.create_match(self.league, self.alice, self.bob)
        self.assertEqual(match['status'], 'SCHEDULED')
        self.assertEqual(match['league'], self.league['id'])
        self.assertEqual(match['league_name'], self.league['name'])

    def test_created_match_is_scheduled(self):
        match = self.create_match(self.league, self.alice, self.bob)
        self.assertEqual(Match.objects.get(id=match['id']).status, 'SCHEDULED')

    def test_list_matches(self):
        self.create_match(self.league, self.alice, self.bob)
        self.authenticate(self.alice)
        response = self.client.get(f"/api/leagues/{self.league['id']}/matches/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['count'], 1)

    def test_filter_matches_by_status(self):
        self.create_match(self.league, self.alice, self.bob)
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/matches/?status=CANCELLED"
        )
        self.assertEqual(response.data['count'], 0)

    def test_match_detail(self):
        match = self.create_match(self.league, self.alice, self.bob)
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/matches/{match['id']}/"
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['id'], match['id'])

    def test_status_update_follows_transition_rules(self):
        match = self.create_match(self.league, self.alice, self.bob)
        self.authenticate(self.alice)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/matches/{match['id']}/status/",
            {'status': 'AWAITING_RESULT'}, format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['status'], 'AWAITING_RESULT')

    def test_illegal_status_jump_returns_409(self):
        match = self.create_match(self.league, self.alice, self.bob)
        self.authenticate(self.alice)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/matches/{match['id']}/status/",
            {'status': 'VERIFIED'}, format='json',
        )
        self.assertEqual(response.status_code, 409)

    def test_status_update_records_audit_trail(self):
        from matches.models import MatchStateTransition
        match = self.create_match(self.league, self.alice, self.bob)
        self.authenticate(self.alice)
        self.client.post(
            f"/api/leagues/{self.league['id']}/matches/{match['id']}/status/",
            {'status': 'AWAITING_RESULT'}, format='json',
        )
        self.assertEqual(MatchStateTransition.objects.filter(match_id=match['id']).count(), 1)

    def test_transitions_endpoint_lists_valid_next_states(self):
        match = self.create_match(self.league, self.alice, self.bob)
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/matches/{match['id']}/transitions/"
        )
        self.assertEqual(response.status_code, 200)

    def test_non_member_cannot_read_match(self):
        match = self.create_match(self.league, self.alice, self.bob)
        self.authenticate(self.carol)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/matches/{match['id']}/"
        )
        self.assertIn(response.status_code, (403, 404))

    def test_matches_require_authentication(self):
        self.logout()
        response = self.client.get(f"/api/leagues/{self.league['id']}/matches/")
        self.assertEqual(response.status_code, 401)

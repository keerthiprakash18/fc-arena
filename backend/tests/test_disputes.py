"""Disputes: raising, listing, commenting and resolving.

The disputes app had no test coverage at all before this file, which is how a
defect this broad survived: `DisputeCreateSerializer` compared the caller
against `home_user`/`away_user` only, and both are None on a team match — so
*every* team fixture rejected disputes with "Only participants of the match can
raise a dispute." Nothing exercised it, so nothing failed.
"""

from django.contrib.auth import get_user_model

from disputes.models import Dispute, DisputeComment
from leagues.models import League
from matches.models import Match
from notifications.models import Notification
from teams.models import Team, TeamMember

from .base import ApiTestCase

User = get_user_model()


class DisputeTestCase(ApiTestCase):
    """Shared fixtures: alice owns the league; bob and carol are members."""

    def setUp(self):
        super().setUp()
        self.league = self.create_league()
        self.league_id = self.league['id']
        self.league_obj = League.objects.get(pk=self.league_id)
        self.join_league(self.bob, self.league['league_code'])
        self.join_league(self.carol, self.league['league_code'])

    # ── helpers ─────────────────────────────────────────────────────────────
    def raise_dispute(self, match_id, actor, reason='WRONG_SCORE', description='Score is wrong'):
        self.authenticate(actor)
        return self.client.post(
            f'/api/leagues/{self.league_id}/disputes/',
            {'match': match_id, 'reason': reason, 'description': description},
            format='json',
        )

    def make_team(self, name, members=(), manager=None, captain=None):
        self.authenticate(self.alice)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/teams/',
            {'name': name, 'short_name': name[:3], 'description': '', 'game': 'FC Mobile'},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)
        team = Team.objects.get(pk=response.data['id'])
        for user in members:
            TeamMember.objects.create(team=team, user=user, role='PLAYER')
        if manager is not None or captain is not None:
            team.manager = manager
            team.captain = captain
            team.save(update_fields=['manager', 'captain'])
        return team

    def make_team_match(self, home, away):
        return Match.objects.create(
            league=self.league_obj, home_team=home, away_team=away, status='VERIFIED',
        )


class RaiseDisputeTests(DisputeTestCase):
    def test_participant_can_raise_a_dispute(self):
        match = self.create_match(self.league, self.alice, self.bob)
        response = self.raise_dispute(match['id'], self.alice)

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['status'], 'OPEN')
        self.assertEqual(response.data['raised_by_name'], 'alice')
        self.assertEqual(response.data['reason'], 'WRONG_SCORE')

    def test_either_side_can_raise_a_dispute(self):
        match = self.create_match(self.league, self.alice, self.bob)
        response = self.raise_dispute(match['id'], self.bob)
        self.assertEqual(response.status_code, 201, response.data)

    def test_non_participant_cannot_raise_a_dispute(self):
        match = self.create_match(self.league, self.alice, self.bob)
        response = self.raise_dispute(match['id'], self.carol)
        self.assertEqual(response.status_code, 400)

    def test_second_open_dispute_for_the_same_match_is_rejected(self):
        match = self.create_match(self.league, self.alice, self.bob)
        self.assertEqual(self.raise_dispute(match['id'], self.alice).status_code, 201)

        response = self.raise_dispute(match['id'], self.bob)
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Dispute.objects.filter(match_id=match['id']).count(), 1)

    def test_a_match_from_another_league_is_rejected(self):
        other = self.create_league(owner=self.carol, name='Other League', slug='other-league')
        self.authenticate(self.carol)
        created = self.client.post(
            f"/api/leagues/{other['id']}/matches/",
            {'home_user': self.carol.id, 'away_user': self.bob.id},
            format='json',
        )
        self.assertEqual(created.status_code, 201, created.data)

        response = self.raise_dispute(created.data['id'], self.carol)
        self.assertEqual(response.status_code, 400)

    def test_raising_a_dispute_requires_authentication(self):
        match = self.create_match(self.league, self.alice, self.bob)
        self.logout()
        response = self.client.post(
            f'/api/leagues/{self.league_id}/disputes/',
            {'match': match['id'], 'reason': 'WRONG_SCORE', 'description': 'x'},
            format='json',
        )
        self.assertEqual(response.status_code, 401)


class TeamMatchDisputeTests(DisputeTestCase):
    """The regression this file exists for: team matches are disputable."""

    def test_team_member_can_raise_a_dispute(self):
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo', members=[self.carol])
        match = self.make_team_match(alpha, bravo)

        response = self.raise_dispute(match.id, self.bob)

        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(Dispute.objects.filter(match=match, raised_by=self.bob).exists())

    def test_outsider_cannot_raise_a_dispute_on_a_team_match(self):
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo', members=[self.carol])
        match = self.make_team_match(alpha, bravo)

        response = self.raise_dispute(match.id, self.alice)
        self.assertEqual(response.status_code, 400)

    def test_team_match_dispute_notifies_the_opposing_squad(self):
        """Notification.user is a non-null FK, so a team match must resolve to
        a real recipient rather than None (which used to raise on save).

        The team equivalent of "the other player" is the opposing side's manager
        and captain, not the whole squad.
        """
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo', members=[self.carol], manager=self.carol)
        match = self.make_team_match(alpha, bravo)

        response = self.raise_dispute(match.id, self.bob)
        self.assertEqual(response.status_code, 201, response.data)

        self.assertTrue(
            Notification.objects.filter(
                user=self.carol, notification_type='DISPUTE_UPDATE'
            ).exists(),
            "the opposing team's manager should be told about the dispute",
        )
        self.assertFalse(
            Notification.objects.filter(user=self.bob).exists(),
            'the raiser should not be notified about their own dispute',
        )

    def test_team_match_dispute_does_not_notify_the_raising_teams_manager(self):
        """If the raiser is themselves the opposing manager, they must not get
        their own notification."""
        alpha = self.make_team('Alpha', members=[self.bob], manager=self.bob)
        bravo = self.make_team('Bravo', members=[self.carol], manager=self.carol)
        match = self.make_team_match(alpha, bravo)

        response = self.raise_dispute(match.id, self.bob)
        self.assertEqual(response.status_code, 201, response.data)

        self.assertFalse(Notification.objects.filter(user=self.bob).exists())
        self.assertTrue(Notification.objects.filter(user=self.carol).exists())

    def test_a_plain_squad_member_is_not_notified(self):
        """Only the opposing manager/captain is told — not every squad member,
        which would be noise."""
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo', members=[self.carol])  # no manager/captain
        match = self.make_team_match(alpha, bravo)

        response = self.raise_dispute(match.id, self.bob)

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(
            Notification.objects.filter(notification_type='DISPUTE_UPDATE').count(),
            0,
        )

    def test_user_match_dispute_notifies_the_opponent(self):
        match = self.create_match(self.league, self.alice, self.bob)
        self.assertEqual(self.raise_dispute(match['id'], self.alice).status_code, 201)

        self.assertTrue(
            Notification.objects.filter(
                user=self.bob, notification_type='DISPUTE_UPDATE'
            ).exists()
        )


class DisputeResolutionTests(DisputeTestCase):
    def setUp(self):
        super().setUp()
        self.match = self.create_match(self.league, self.alice, self.bob)
        response = self.raise_dispute(self.match['id'], self.bob)
        self.assertEqual(response.status_code, 201, response.data)
        self.dispute_id = response.data['id']

    def resolve(self, actor, resolution='ACCEPTED', notes=''):
        self.authenticate(actor)
        return self.client.post(
            f'/api/leagues/{self.league_id}/disputes/{self.dispute_id}/resolve/',
            {'resolution': resolution, 'resolution_notes': notes},
            format='json',
        )

    def test_league_owner_can_resolve(self):
        response = self.resolve(self.alice, 'ACCEPTED', 'Re-examined the screenshot.')

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['status'], 'RESOLVED')
        self.assertEqual(response.data['resolution'], 'ACCEPTED')
        self.assertEqual(response.data['resolution_notes'], 'Re-examined the screenshot.')
        self.assertEqual(response.data['resolved_by_name'], 'alice')

    def test_plain_member_cannot_resolve(self):
        response = self.resolve(self.bob)
        self.assertEqual(response.status_code, 403)
        self.assertEqual(Dispute.objects.get(pk=self.dispute_id).status, 'OPEN')

    def test_the_person_who_raised_it_cannot_resolve_it(self):
        """bob raised it and is only a member — the raiser is not a judge."""
        response = self.resolve(self.bob)
        self.assertEqual(response.status_code, 403)

    def test_an_already_resolved_dispute_cannot_be_resolved_again(self):
        self.assertEqual(self.resolve(self.alice).status_code, 200)

        response = self.resolve(self.alice, 'REJECTED')
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Dispute.objects.get(pk=self.dispute_id).resolution, 'ACCEPTED')

    def test_an_unknown_resolution_is_rejected(self):
        response = self.resolve(self.alice, 'MAYBE')
        self.assertEqual(response.status_code, 400)
        self.assertEqual(Dispute.objects.get(pk=self.dispute_id).status, 'OPEN')

    def test_all_documented_resolutions_are_accepted(self):
        for resolution in ('ACCEPTED', 'REJECTED', 'CORRECTED'):
            with self.subTest(resolution=resolution):
                match = self.create_match(self.league, self.alice, self.carol)
                created = self.raise_dispute(match['id'], self.carol)
                self.assertEqual(created.status_code, 201, created.data)

                self.authenticate(self.alice)
                response = self.client.post(
                    f"/api/leagues/{self.league_id}/disputes/{created.data['id']}/resolve/",
                    {'resolution': resolution, 'resolution_notes': ''},
                    format='json',
                )
                self.assertEqual(response.status_code, 200, response.data)
                self.assertEqual(response.data['resolution'], resolution)

    def test_resolving_a_missing_dispute_is_404(self):
        self.authenticate(self.alice)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/disputes/999999/resolve/',
            {'resolution': 'ACCEPTED'},
            format='json',
        )
        self.assertEqual(response.status_code, 404)


class DisputeReadTests(DisputeTestCase):
    def setUp(self):
        super().setUp()
        self.match = self.create_match(self.league, self.alice, self.bob)
        self.dispute_id = self.raise_dispute(self.match['id'], self.bob).data['id']

    def test_list_returns_the_dispute(self):
        self.authenticate(self.alice)
        response = self.client.get(f'/api/leagues/{self.league_id}/disputes/')

        self.assertEqual(response.status_code, 200, response.data)
        ids = [d['id'] for d in response.data['results']]
        self.assertIn(self.dispute_id, ids)

    def test_detail_returns_the_dispute(self):
        self.authenticate(self.alice)
        response = self.client.get(
            f'/api/leagues/{self.league_id}/disputes/{self.dispute_id}/'
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['id'], self.dispute_id)
        self.assertEqual(response.data['comments'], [])

    def test_detail_of_another_league_is_404(self):
        other = self.create_league(owner=self.carol, name='Other League', slug='other-league')
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{other['id']}/disputes/{self.dispute_id}/"
        )
        self.assertEqual(response.status_code, 404)

    def test_participant_can_comment_and_it_appears_in_the_thread(self):
        self.authenticate(self.bob)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/disputes/{self.dispute_id}/comments/',
            {'comment': 'Here is the screenshot again.'},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['username'], 'bob')

        self.assertTrue(
            DisputeComment.objects.filter(
                dispute_id=self.dispute_id, user=self.bob
            ).exists()
        )

        detail = self.client.get(
            f'/api/leagues/{self.league_id}/disputes/{self.dispute_id}/'
        )
        self.assertEqual(len(detail.data['comments']), 1)
        self.assertEqual(detail.data['comments'][0]['comment'], 'Here is the screenshot again.')

    def test_commenting_requires_authentication(self):
        self.logout()
        response = self.client.post(
            f'/api/leagues/{self.league_id}/disputes/{self.dispute_id}/comments/',
            {'comment': 'anonymous'},
            format='json',
        )
        self.assertEqual(response.status_code, 401)

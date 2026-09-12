"""Regression tests for team-based match results.

These lock in three defects found by live end-to-end testing of the team
endpoints, all of which passed the suite silently before:

1. ``MatchSerializer`` used ``source='home_user.username'``, which raises on the
   null ``home_user`` of a team match — so the match list 500'd (or, worse,
   returned ``None`` for every participant).
2. ``MatchSubmitResultView`` compared ``user`` against ``home_user``/``away_user``
   — both None on a team match — so every result submission returned 403.
3. The verification pipeline formatted its notification message from
   ``match.home_user.username`` and notified ``[home_user, away_user]``, so a
   team match could never reach VERIFIED without crashing.
"""

from django.contrib.auth import get_user_model
from django.utils import timezone

from evidence.models import EvidenceStorage
from leagues.models import League, LeagueMember
from matches.models import Match
from notifications.models import Notification
from statistics.models import PlayerLeagueStatistics
from teams.models import Team, TeamMember, TeamStatistics
from tournaments.models import Tournament, TournamentParticipant, TournamentRound
from tournaments.services import generate_team_fixtures
from verification.models import VerificationTask
from verification.services import admin_review

from .base import ApiTestCase

User = get_user_model()


class TeamMatchResultTests(ApiTestCase):
    """Team matches: serialization, result submission, verification, knockout."""

    def setUp(self):
        super().setUp()
        self.league = self.create_league()                 # alice owns it
        self.league_id = self.league['id']
        self.league_obj = League.objects.get(pk=self.league_id)
        self.join_league(self.bob, self.league['league_code'])
        self.join_league(self.carol, self.league['league_code'])

    # ── helpers ─────────────────────────────────────────────────────────────
    def make_team(self, name, members=()):
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
        return team

    def make_tournament(self, fmt='ROUND_ROBIN', **extra):
        extra.setdefault('status', 'REGISTRATION_CLOSED')
        return Tournament.objects.create(
            league=self.league_obj, name='Test Cup', format=fmt,
            is_team_based=True,
            created_by=self.alice, **extra,
        )

    def make_team_match(self, home, away, tournament=None, status='SCHEDULED', **extra):
        return Match.objects.create(
            league=self.league_obj, tournament=tournament,
            home_team=home, away_team=away, status=status, **extra,
        )

    def set_status(self, match, new_status):
        self.authenticate(self.alice)          # alice is the league owner
        response = self.client.post(
            f'/api/leagues/{self.league_id}/matches/{match.id}/status/',
            {'status': new_status}, format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        match.refresh_from_db()
        return response

    def submit(self, match, actor, home_score, away_score):
        self.authenticate(actor)
        return self.client.post(
            f'/api/leagues/{self.league_id}/matches/{match.id}/submit/',
            {'home_score': home_score, 'away_score': away_score}, format='json',
        )

    # ── serialization ───────────────────────────────────────────────────────
    def test_team_match_serializes_team_names_and_venue(self):
        alpha = self.make_team('Alpha')
        bravo = self.make_team('Bravo')
        match = self.make_team_match(alpha, bravo, venue='Room A')

        self.authenticate(self.alice)
        response = self.client.get(f'/api/leagues/{self.league_id}/matches/')

        self.assertEqual(response.status_code, 200, response.data)
        row = next(m for m in response.data['results'] if m['id'] == match.id)
        self.assertEqual(row['home_team_name'], 'Alpha')
        self.assertEqual(row['away_team_name'], 'Bravo')
        self.assertEqual(row['home_display'], 'Alpha')
        self.assertEqual(row['away_display'], 'Bravo')
        self.assertEqual(row['venue'], 'Room A')
        self.assertTrue(row['is_team_match'])
        # The null user relations must serialise as null, not explode.
        self.assertIsNone(row['home_username'])
        self.assertIsNone(row['away_username'])

    def test_user_match_still_serializes_usernames(self):
        """The team fields must not break the original user-based shape."""
        self.authenticate(self.alice)
        created = self.client.post(
            f'/api/leagues/{self.league_id}/matches/',
            {'home_user': self.bob.id, 'away_user': self.carol.id}, format='json',
        )
        self.assertEqual(created.status_code, 201, created.data)

        response = self.client.get(f'/api/leagues/{self.league_id}/matches/')
        row = next(m for m in response.data['results'] if m['id'] == created.data['id'])
        self.assertEqual(row['home_username'], 'bob')
        self.assertEqual(row['away_username'], 'carol')
        self.assertEqual(row['home_display'], 'bob')
        self.assertIsNone(row['home_team_name'])
        self.assertFalse(row['is_team_match'])

    # ── result submission ───────────────────────────────────────────────────
    def test_team_member_can_submit_result(self):
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo', members=[self.carol])
        match = self.make_team_match(alpha, bravo)
        self.set_status(match, 'AWAITING_RESULT')

        response = self.submit(match, self.bob, 3, 1)

        self.assertEqual(response.status_code, 200, response.data)
        match.refresh_from_db()
        self.assertEqual((match.home_score, match.away_score), (3, 1))
        self.assertEqual(match.status, 'EVIDENCE_SUBMITTED')

    def test_league_admin_can_submit_result_for_team_match(self):
        alpha = self.make_team('Alpha')      # no roster at all
        bravo = self.make_team('Bravo')
        match = self.make_team_match(alpha, bravo)
        self.set_status(match, 'AWAITING_RESULT')

        response = self.submit(match, self.alice, 2, 2)

        self.assertEqual(response.status_code, 200, response.data)

    def test_unrelated_league_member_cannot_submit_team_result(self):
        """carol is in the league but on neither team and is not an admin."""
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo')
        match = self.make_team_match(alpha, bravo)
        self.set_status(match, 'AWAITING_RESULT')

        response = self.submit(match, self.carol, 1, 0)

        self.assertEqual(response.status_code, 403)

    def test_user_match_submission_still_requires_a_participant(self):
        """The team branch must not have loosened the legacy rule."""
        self.authenticate(self.alice)
        created = self.client.post(
            f'/api/leagues/{self.league_id}/matches/',
            {'home_user': self.bob.id, 'away_user': self.alice.id}, format='json',
        )
        match = Match.objects.get(pk=created.data['id'])
        self.set_status(match, 'AWAITING_RESULT')

        response = self.submit(match, self.carol, 1, 0)

        self.assertEqual(response.status_code, 403)

    def test_submit_rejects_invalid_scores(self):
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo')
        match = self.make_team_match(alpha, bravo)
        self.set_status(match, 'AWAITING_RESULT')

        self.assertEqual(self.submit(match, self.bob, -1, 0).status_code, 400)
        self.assertEqual(self.submit(match, self.bob, 'x', 0).status_code, 400)
        self.assertEqual(self.submit(match, self.bob, None, 0).status_code, 400)

    # ── verification pipeline ───────────────────────────────────────────────
    def _verify_team_match(self, match, approved=True):
        """Drive a team match to VERIFIED through the real review service."""
        evidence = EvidenceStorage.objects.create(
            match=match, uploaded_by=self.alice, file_name='shot.png',
            file_reference='evidence/shot.png', file_size=1024,
            file_type='image/png', checksum='x' * 64, is_valid=True,
        )
        task = VerificationTask.objects.create(
            match=match, evidence=evidence, status='ADMIN_REVIEW',
            ai_extracted_data={'home_score': match.home_score,
                               'away_score': match.away_score},
        )
        return admin_review(task, approved, self.alice, notes='looks right')

    def test_verifying_a_team_match_updates_team_statistics(self):
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo', members=[self.carol])
        match = self.make_team_match(alpha, bravo, home_score=3, away_score=1)

        self._verify_team_match(match)

        match.refresh_from_db()
        self.assertEqual(match.status, 'VERIFIED')
        self.assertIsNotNone(match.verified_at)

        # Team layer updated...
        alpha_stats = TeamStatistics.objects.get(team=alpha)
        self.assertEqual((alpha_stats.wins, alpha_stats.points), (1, 3))
        self.assertEqual(alpha_stats.goals_scored, 3)
        bravo_stats = TeamStatistics.objects.get(team=bravo)
        self.assertEqual(bravo_stats.losses, 1)
        # ...and the user-keyed pipeline was bypassed entirely.
        self.assertEqual(PlayerLeagueStatistics.objects.count(), 0)

    def test_verifying_a_team_match_notifies_the_roster(self):
        """The crash site: the old code read match.home_user.username."""
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo', members=[self.carol])
        match = self.make_team_match(alpha, bravo, home_score=1, away_score=0)

        self._verify_team_match(match)

        recipients = set(
            Notification.objects.filter(notification_type='MATCH_VERIFIED')
            .values_list('user__username', flat=True)
        )
        self.assertEqual(recipients, {'bob', 'carol'})
        note = Notification.objects.filter(
            notification_type='MATCH_VERIFIED', user=self.bob
        ).first()
        # The message names the teams, not "None".
        self.assertIn('Alpha', note.message)
        self.assertIn('Bravo', note.message)
        self.assertNotIn('None', note.message)

    def test_rejecting_a_team_match_notifies_the_roster(self):
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo', members=[self.carol])
        match = self.make_team_match(alpha, bravo, home_score=1, away_score=0)

        self._verify_team_match(match, approved=False)

        match.refresh_from_db()
        self.assertEqual(match.status, 'REJECTED')
        recipients = set(
            Notification.objects.filter(notification_type='MATCH_REJECTED')
            .values_list('user__username', flat=True)
        )
        self.assertEqual(recipients, {'bob', 'carol'})

    # ── knockout advancement ────────────────────────────────────────────────
    def test_team_knockout_advances_winners_to_the_next_round(self):
        alpha = self.make_team('Alpha', members=[self.bob])
        bravo = self.make_team('Bravo')
        charlie = self.make_team('Charlie')
        delta = self.make_team('Delta')

        tournament = self.make_tournament('KNOCKOUT', status='IN_PROGRESS')
        for team in (alpha, bravo, charlie, delta):
            TournamentParticipant.objects.create(tournament=tournament, team=team)

        generate_team_fixtures(tournament)
        first_round = TournamentRound.objects.get(tournament=tournament, round_number=1)
        self.assertEqual(
            Match.objects.filter(tournament=tournament, round=first_round).count(), 2
        )

        # Verify both semi-finals, home side winning each.
        for match in Match.objects.filter(tournament=tournament, round=first_round):
            match.home_score, match.away_score = 2, 0
            match.save(update_fields=['home_score', 'away_score'])
            self._verify_team_match(match)

        second_round = TournamentRound.objects.filter(
            tournament=tournament, round_number=2
        ).first()
        self.assertIsNotNone(second_round, 'the final was never generated')
        final = Match.objects.filter(tournament=tournament, round=second_round)
        self.assertEqual(final.count(), 1)
        # The final must be a *team* fixture between the two home winners.
        self.assertTrue(final.first().is_team_match)
        self.assertIsNone(final.first().home_user)

    # ── create-serializer validation ────────────────────────────────────────
    def test_cannot_schedule_a_team_from_another_league(self):
        outsider = self.make_team('Alpha')
        other_league = League.objects.create(
            name='Other', slug='other-league', owner=self.alice
        )
        foreign = Team.objects.create(league=other_league, name='Foreign',
                                      short_name='FOR', created_by=self.alice)

        self.authenticate(self.alice)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/matches/',
            {'home_team': outsider.id, 'away_team': foreign.id}, format='json',
        )

        self.assertEqual(response.status_code, 400, response.data)

    def test_team_match_requires_both_sides(self):
        alpha = self.make_team('Alpha')
        self.authenticate(self.alice)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/matches/',
            {'home_team': alpha.id}, format='json',
        )
        self.assertEqual(response.status_code, 400, response.data)

    def test_a_team_cannot_play_itself(self):
        alpha = self.make_team('Alpha')
        self.authenticate(self.alice)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/matches/',
            {'home_team': alpha.id, 'away_team': alpha.id}, format='json',
        )
        self.assertEqual(response.status_code, 400, response.data)

"""Automatic award computation.

Awards had an ``AUTO`` source in the model but no service behind it, so every
award was manual. These tests cover the derived honours and, importantly, that
an organizer's manual award is never clobbered by a recompute.
"""

from django.contrib.auth import get_user_model

from awards.models import Award
from awards.services import compute_awards
from leagues.models import League
from matches.models import Match
from statistics.models import PlayerLeagueStatistics
from teams.models import Team, TeamStatistics
from tournaments.models import Tournament, TournamentRound

from .base import ApiTestCase

User = get_user_model()


class AwardServiceTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.league = self.create_league()
        self.league_obj = League.objects.get(pk=self.league['id'])

    def _stats(self, user, **kwargs):
        defaults = dict(matches_played=0, wins=0, draws=0, losses=0,
                        goals_scored=0, goals_conceded=0, clean_sheets=0)
        defaults.update(kwargs)
        return PlayerLeagueStatistics.objects.create(
            league=self.league_obj, user=user, **defaults
        )

    # ── user-based ──────────────────────────────────────────────────────────
    def test_golden_boot_goes_to_the_top_scorer(self):
        self._stats(self.bob, goals_scored=14, matches_played=8)
        self._stats(self.carol, goals_scored=6, matches_played=8)

        compute_awards(self.league_obj)

        award = Award.objects.get(league=self.league_obj, award_type='GOLDEN_BOOT')
        self.assertEqual(award.user, self.bob)
        self.assertEqual(award.source, 'AUTO')
        self.assertIn('14', award.description)

    def test_no_awards_without_data(self):
        compute_awards(self.league_obj)
        self.assertEqual(Award.objects.count(), 0)

    def test_champion_is_the_points_leader(self):
        self._stats(self.bob, wins=5, matches_played=8, goals_scored=10)
        self._stats(self.carol, wins=3, matches_played=8, goals_scored=14)

        compute_awards(self.league_obj)

        champion = Award.objects.get(league=self.league_obj, award_type='LEAGUE_CHAMPION')
        self.assertEqual(champion.user, self.bob)      # 15 pts beats 9

    def test_recompute_does_not_duplicate(self):
        self._stats(self.bob, goals_scored=9, matches_played=6)
        compute_awards(self.league_obj)
        compute_awards(self.league_obj)

        self.assertEqual(
            Award.objects.filter(league=self.league_obj, award_type='GOLDEN_BOOT').count(), 1
        )

    def test_a_manual_award_survives_a_recompute(self):
        """An organizer's decision must not be silently overwritten."""
        self._stats(self.bob, goals_scored=9, matches_played=6)
        self._stats(self.carol, goals_scored=2, matches_played=6)

        Award.objects.create(
            league=self.league_obj, award_type='GOLDEN_BOOT',
            user=self.carol, source='MANUAL', awarded_by=self.alice,
            description='coach’s pick',
        )

        compute_awards(self.league_obj)

        awards = Award.objects.filter(league=self.league_obj, award_type='GOLDEN_BOOT')
        self.assertEqual(awards.count(), 1)
        self.assertEqual(awards.first().user, self.carol)
        self.assertEqual(awards.first().source, 'MANUAL')

    def test_recompute_replaces_its_own_previous_pick(self):
        self._stats(self.bob, goals_scored=9, matches_played=6)
        compute_awards(self.league_obj)

        PlayerLeagueStatistics.objects.filter(
            league=self.league_obj, user=self.bob
        ).update(goals_scored=1)
        self._stats(self.carol, goals_scored=12, matches_played=6)
        compute_awards(self.league_obj)

        award = Award.objects.get(league=self.league_obj, award_type='GOLDEN_BOOT')
        self.assertEqual(award.user, self.carol)

    # ── team-based ──────────────────────────────────────────────────────────
    def test_team_league_awards_are_attributed_to_teams(self):
        alpha = Team.objects.create(league=self.league_obj, name='Alpha',
                                    short_name='ALP', slug='alpha', created_by=self.alice)
        bravo = Team.objects.create(league=self.league_obj, name='Bravo',
                                    short_name='BRA', slug='bravo', created_by=self.alice)
        TeamStatistics.objects.create(team=alpha, matches_played=6, wins=5,
                                      goals_scored=18, clean_sheets=4, points=15)
        TeamStatistics.objects.create(team=bravo, matches_played=6, wins=1,
                                      goals_scored=5, clean_sheets=0, points=3)

        compute_awards(self.league_obj)

        boot = Award.objects.get(league=self.league_obj, award_type='GOLDEN_BOOT')
        self.assertEqual(boot.team, alpha)
        self.assertIsNone(boot.user)
        self.assertEqual(boot.display_name, 'Alpha')

        champion = Award.objects.get(league=self.league_obj, award_type='LEAGUE_CHAMPION')
        self.assertEqual(champion.team, alpha)

    # ── tournament ──────────────────────────────────────────────────────────
    def test_tournament_champion_comes_from_the_verified_final(self):
        tournament = Tournament.objects.create(
            league=self.league_obj, name='Cup', format='KNOCKOUT',
            status='IN_PROGRESS', created_by=self.alice,
        )
        round_row = TournamentRound.objects.create(
            tournament=tournament, round_number=1, name='Final', round_type='KNOCKOUT'
        )
        Match.objects.create(
            league=self.league_obj, tournament=tournament, round=round_row,
            home_user=self.bob, away_user=self.carol,
            home_score=3, away_score=1, status='VERIFIED',
        )

        compute_awards(self.league_obj, tournament=tournament)

        champion = Award.objects.get(
            league=self.league_obj, award_type='TOURNAMENT_CHAMPION'
        )
        self.assertEqual(champion.user, self.bob)
        self.assertEqual(champion.tournament, tournament)

        runner_up = Award.objects.get(league=self.league_obj, award_type='RUNNER_UP')
        self.assertEqual(runner_up.user, self.carol)

    def test_no_champion_while_the_final_is_unverified(self):
        tournament = Tournament.objects.create(
            league=self.league_obj, name='Cup', format='KNOCKOUT',
            status='IN_PROGRESS', created_by=self.alice,
        )
        round_row = TournamentRound.objects.create(
            tournament=tournament, round_number=1, name='Final', round_type='KNOCKOUT'
        )
        Match.objects.create(
            league=self.league_obj, tournament=tournament, round=round_row,
            home_user=self.bob, away_user=self.carol,
            home_score=3, away_score=1, status='SCHEDULED',
        )

        compute_awards(self.league_obj, tournament=tournament)

        self.assertFalse(Award.objects.filter(
            league=self.league_obj, award_type='TOURNAMENT_CHAMPION'
        ).exists())

    def test_a_drawn_final_crowns_nobody(self):
        tournament = Tournament.objects.create(
            league=self.league_obj, name='Cup', format='KNOCKOUT',
            status='IN_PROGRESS', created_by=self.alice,
        )
        round_row = TournamentRound.objects.create(
            tournament=tournament, round_number=1, name='Final', round_type='KNOCKOUT'
        )
        Match.objects.create(
            league=self.league_obj, tournament=tournament, round=round_row,
            home_user=self.bob, away_user=self.carol,
            home_score=2, away_score=2, status='VERIFIED',
        )

        compute_awards(self.league_obj, tournament=tournament)

        self.assertFalse(Award.objects.filter(
            league=self.league_obj, award_type='TOURNAMENT_CHAMPION'
        ).exists())

    # ── endpoints ───────────────────────────────────────────────────────────
    def test_compute_endpoint_requires_admin(self):
        self.join_league(self.bob, self.league['league_code'])
        self.authenticate(self.bob)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/awards/compute/", {}, format='json'
        )
        self.assertEqual(response.status_code, 403)

    def test_compute_endpoint_returns_the_awards(self):
        self._stats(self.bob, goals_scored=11, matches_played=6)
        self.authenticate(self.alice)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/awards/compute/", {}, format='json'
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertGreaterEqual(response.data['count'], 1)
        types = {a['award_type'] for a in response.data['awards']}
        self.assertIn('GOLDEN_BOOT', types)

    def test_award_list_requires_membership(self):
        outsider = User.objects.create_user('outsider', 'o@example.com', 'testpass123')
        self.authenticate(outsider)
        response = self.client.get(f"/api/leagues/{self.league['id']}/awards/")
        self.assertEqual(response.status_code, 403)

    def test_manual_award_needs_a_recipient(self):
        self.authenticate(self.alice)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/awards/create/",
            {'award_type': 'CUSTOM', 'custom_name': 'Best Hair'}, format='json',
        )
        self.assertEqual(response.status_code, 400)

    def test_manual_award_cannot_have_two_recipients(self):
        alpha = Team.objects.create(league=self.league_obj, name='Alpha',
                                    short_name='ALP', slug='alpha', created_by=self.alice)
        self.authenticate(self.alice)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/awards/create/",
            {'award_type': 'CUSTOM', 'custom_name': 'Best Hair',
             'user': self.bob.id, 'team': alpha.id},
            format='json',
        )
        self.assertEqual(response.status_code, 400)

    def test_manual_team_award_is_accepted(self):
        alpha = Team.objects.create(league=self.league_obj, name='Alpha',
                                    short_name='ALP', slug='alpha', created_by=self.alice)
        self.authenticate(self.alice)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/awards/create/",
            {'award_type': 'CUSTOM', 'custom_name': 'Best Kit', 'team': alpha.id},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['username'], 'Alpha')

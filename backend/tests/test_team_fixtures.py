"""Tests for team fixture generation, scheduling and team statistics.

Covers the Phase 3 additions: the team fixture generator (round-robin and
knockout), the scheduling helper, and the team statistics service — including
the branch that keeps team matches out of the user-keyed pipeline.
"""

from datetime import date

from django.contrib.auth import get_user_model
from django.utils import timezone

from leagues.models import League
from matches.models import Match
from statistics.models import PlayerLeagueStatistics
from statistics.services import process_verified_match
from teams.models import Team, TeamStatistics
from teams.services import recompute_team_statistics, team_standings
from tournaments.models import Tournament, TournamentParticipant
from tournaments.services import FixtureScheduler, _parse_start, generate_team_fixtures

from .base import ApiTestCase

User = get_user_model()


class TeamFixtureTests(ApiTestCase):
    """Fixture generation for team-based tournaments."""

    def setUp(self):
        super().setUp()
        self.league = self.create_league()          # alice owns it
        self.league_id = self.league['id']
        self.league_obj = League.objects.get(pk=self.league_id)
        self.join_league(self.bob, self.league['league_code'])

    # ── helpers ─────────────────────────────────────────────────────────────
    def make_team(self, name):
        self.authenticate(self.alice)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/teams/',
            {'name': name, 'short_name': name[:3], 'description': '', 'game': 'FC Mobile'},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)
        return Team.objects.get(pk=response.data['id'])

    def make_tournament(self, fmt='ROUND_ROBIN', **extra):
        return Tournament.objects.create(
            league=self.league_obj, name='Test Cup', format=fmt,
            is_team_based=True, status='REGISTRATION_CLOSED',
            created_by=self.alice, **extra,
        )

    def register(self, tournament, teams):
        for team in teams:
            TournamentParticipant.objects.create(tournament=tournament, team=team)

    # ── generation ──────────────────────────────────────────────────────────
    def test_round_robin_generates_every_pair_once(self):
        teams = [self.make_team(n) for n in ('Alpha', 'Bravo', 'Charlie', 'Delta')]
        tournament = self.make_tournament('ROUND_ROBIN')
        self.register(tournament, teams)

        created, _ = generate_team_fixtures(tournament)

        self.assertEqual(created, 6)                       # C(4,2) = 6
        matches = Match.objects.filter(tournament=tournament)
        self.assertEqual(matches.count(), 6)
        # Every fixture is team-based and leaves the user FKs empty.
        self.assertTrue(all(m.is_team_match for m in matches))
        self.assertTrue(all(m.home_user is None and m.away_user is None for m in matches))

    def test_double_round_doubles_the_fixture_count(self):
        teams = [self.make_team(n) for n in ('Alpha', 'Bravo', 'Charlie')]
        tournament = self.make_tournament('ROUND_ROBIN')
        self.register(tournament, teams)

        created, _ = generate_team_fixtures(tournament, {'double_round': True})

        self.assertEqual(created, 6)                       # 3 pairs, home and away

    def test_knockout_generates_only_the_first_round(self):
        teams = [self.make_team(n) for n in ('Alpha', 'Bravo', 'Charlie', 'Delta')]
        tournament = self.make_tournament('KNOCKOUT')
        self.register(tournament, teams)

        created, _ = generate_team_fixtures(tournament)

        self.assertEqual(created, 2)
        self.assertEqual(Match.objects.filter(tournament=tournament).count(), 2)

    def test_generation_is_idempotent(self):
        teams = [self.make_team(n) for n in ('Alpha', 'Bravo')]
        tournament = self.make_tournament('ROUND_ROBIN')
        self.register(tournament, teams)

        generate_team_fixtures(tournament)
        count, message = generate_team_fixtures(tournament)

        self.assertEqual(count, 1)
        self.assertIn('already generated', message)
        self.assertEqual(Match.objects.filter(tournament=tournament).count(), 1)

    def test_needs_at_least_two_teams(self):
        tournament = self.make_tournament('ROUND_ROBIN')
        self.register(tournament, [self.make_team('Lonely')])

        created, message = generate_team_fixtures(tournament)

        self.assertEqual(created, 0)
        self.assertIn('at least 2 teams', message)

    # ── scheduling ──────────────────────────────────────────────────────────
    def test_scheduling_options_are_applied(self):
        teams = [self.make_team(n) for n in ('Alpha', 'Bravo', 'Charlie')]
        tournament = self.make_tournament('ROUND_ROBIN')
        self.register(tournament, teams)

        generate_team_fixtures(tournament, {
            'start_date': '2026-10-05',
            'start_time': '18:30',
            'interval_minutes': 45,
            'per_day': 2,
            'venue': 'Room A',
        })

        slots = list(
            Match.objects.filter(tournament=tournament)
            .order_by('scheduled_at')
            .values_list('scheduled_at', 'venue')
        )
        # The DB stores UTC; compare in the project's local timezone, which is
        # the wall-clock time the organiser actually typed.
        local = [timezone.localtime(slot).strftime('%Y-%m-%d %H:%M') for slot, _ in slots]
        self.assertEqual(local[0], '2026-10-05 18:30')
        self.assertEqual(local[1], '2026-10-05 19:15')
        # per_day=2 means the third fixture rolls over to the next day.
        self.assertEqual(local[2], '2026-10-06 18:30')
        self.assertTrue(all(venue == 'Room A' for _, venue in slots))

    def test_without_a_start_date_fixtures_stay_unscheduled(self):
        teams = [self.make_team(n) for n in ('Alpha', 'Bravo')]
        tournament = self.make_tournament('ROUND_ROBIN')
        self.register(tournament, teams)

        generate_team_fixtures(tournament, {'venue': 'Room B'})

        match = Match.objects.get(tournament=tournament)
        self.assertIsNone(match.scheduled_at)      # no invented kickoff time
        self.assertEqual(match.venue, 'Room B')

    def test_match_days_are_respected(self):
        start = _parse_start('2026-10-05', '10:00')
        scheduler = FixtureScheduler(start, interval_minutes=60,
                                     match_days=[5, 6], per_day=1)

        slots = [scheduler.next() for _ in range(4)]

        self.assertTrue(all(slot.weekday() in (5, 6) for slot in slots))
        self.assertTrue(all(slot >= start for slot in slots))

    # ── statistics ──────────────────────────────────────────────────────────
    def test_statistics_are_computed_from_verified_matches(self):
        alpha = self.make_team('Alpha')
        bravo = self.make_team('Bravo')
        tournament = self.make_tournament('ROUND_ROBIN')

        Match.objects.create(league=self.league_obj, tournament=tournament,
                             home_team=alpha, away_team=bravo,
                             home_score=3, away_score=1, status='VERIFIED')
        Match.objects.create(league=self.league_obj, tournament=tournament,
                             home_team=bravo, away_team=alpha,
                             home_score=2, away_score=2, status='VERIFIED')

        stats = recompute_team_statistics(alpha)

        self.assertEqual(stats.matches_played, 2)
        self.assertEqual((stats.wins, stats.draws, stats.losses), (1, 1, 0))
        self.assertEqual(stats.goals_scored, 5)
        self.assertEqual(stats.goals_conceded, 3)
        self.assertEqual(stats.goal_difference, 2)
        self.assertEqual(stats.points, 4)
        self.assertEqual(stats.win_rate, 50.0)
        self.assertEqual(stats.form, ['D', 'W'])      # most recent first

    def test_unverified_and_scoreless_matches_are_ignored(self):
        alpha = self.make_team('Alpha')
        bravo = self.make_team('Bravo')
        tournament = self.make_tournament('ROUND_ROBIN')

        Match.objects.create(league=self.league_obj, tournament=tournament,
                             home_team=alpha, away_team=bravo, status='SCHEDULED')
        Match.objects.create(league=self.league_obj, tournament=tournament,
                             home_team=alpha, away_team=bravo, status='VERIFIED')

        stats = recompute_team_statistics(alpha)

        self.assertEqual(stats.matches_played, 0)

    def test_recompute_is_idempotent(self):
        alpha = self.make_team('Alpha')
        bravo = self.make_team('Bravo')
        tournament = self.make_tournament('ROUND_ROBIN')
        Match.objects.create(league=self.league_obj, tournament=tournament,
                             home_team=alpha, away_team=bravo,
                             home_score=1, away_score=0, status='VERIFIED')

        first = recompute_team_statistics(alpha)
        second = recompute_team_statistics(alpha)

        self.assertEqual(first.points, second.points)
        self.assertEqual(second.matches_played, 1)     # not double-counted

    def test_standings_order_by_points_then_goal_difference(self):
        alpha = self.make_team('Alpha')
        bravo = self.make_team('Bravo')
        charlie = self.make_team('Charlie')
        tournament = self.make_tournament('ROUND_ROBIN')

        Match.objects.create(league=self.league_obj, tournament=tournament,
                             home_team=alpha, away_team=bravo,
                             home_score=1, away_score=0, status='VERIFIED')
        Match.objects.create(league=self.league_obj, tournament=tournament,
                             home_team=charlie, away_team=bravo,
                             home_score=5, away_score=0, status='VERIFIED')
        for team in (alpha, bravo, charlie):
            recompute_team_statistics(team)

        rows = team_standings(self.league_obj)

        # Charlie +4 GD, Alpha +1 GD, Bravo -5 GD.
        self.assertEqual([r['team'].name for r in rows], ['Charlie', 'Alpha', 'Bravo'])
        self.assertEqual([r['rank'] for r in rows], [1, 2, 3])

    # ── pipeline integration ────────────────────────────────────────────────
    def test_verification_feeds_team_stats_not_user_stats(self):
        alpha = self.make_team('Alpha')
        bravo = self.make_team('Bravo')
        tournament = self.make_tournament('ROUND_ROBIN')

        match = Match.objects.create(
            league=self.league_obj, tournament=tournament,
            home_team=alpha, away_team=bravo,
            home_score=2, away_score=0, status='VERIFIED',
        )

        process_verified_match(match)

        # The user-keyed pipeline must be bypassed entirely...
        self.assertEqual(PlayerLeagueStatistics.objects.count(), 0)
        # ...and the team layer updated instead.
        alpha_stats = TeamStatistics.objects.get(team=alpha)
        self.assertEqual(alpha_stats.wins, 1)
        self.assertEqual(alpha_stats.points, 3)
        self.assertEqual(alpha_stats.clean_sheets, 1)
        bravo_stats = TeamStatistics.objects.get(team=bravo)
        self.assertEqual(bravo_stats.losses, 1)
        self.assertEqual(bravo_stats.points, 0)

        match.refresh_from_db()
        self.assertTrue(match.is_idempotent_processed)

    def test_standings_endpoint_requires_league_membership(self):
        self.make_team('Alpha')
        outsider = User.objects.create_user('outsider', 'o@example.com', 'testpass123')
        self.authenticate(outsider)
        response = self.client.get(f'/api/leagues/{self.league_id}/teams/standings/')
        self.assertEqual(response.status_code, 403)

    def test_standings_endpoint_returns_ranked_rows(self):
        alpha = self.make_team('Alpha')
        bravo = self.make_team('Bravo')
        tournament = self.make_tournament('ROUND_ROBIN')
        Match.objects.create(league=self.league_obj, tournament=tournament,
                             home_team=alpha, away_team=bravo,
                             home_score=3, away_score=0, status='VERIFIED')
        recompute_team_statistics(alpha)
        recompute_team_statistics(bravo)

        self.authenticate(self.alice)
        response = self.client.get(f'/api/leagues/{self.league_id}/teams/standings/')

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data[0]['name'], 'Alpha')
        self.assertEqual(response.data[0]['rank'], 1)
        self.assertEqual(response.data[0]['statistics']['points'], 3)

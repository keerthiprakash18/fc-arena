"""Global search across a league's teams, tournaments, players and fixtures."""

from leagues.models import League
from matches.models import Match
from teams.models import Team
from tournaments.models import Tournament
from tests.base import ApiTestCase


class LeagueSearchTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.league = self.create_league()
        self.league_id = self.league['id']
        self.league_obj = League.objects.get(pk=self.league_id)
        self.join_league(self.bob, self.league['league_code'])

    def _team(self, name):
        self.authenticate(self.alice)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/teams/',
            {'name': name, 'short_name': name[:3], 'description': '', 'game': 'FC Mobile'},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)
        return Team.objects.get(pk=response.data['id'])

    def _search(self, query, **params):
        self.authenticate(self.alice)
        url = f'/api/leagues/{self.league_id}/search/?q={query}'
        for key, value in params.items():
            url += f'&{key}={value}'
        return self.client.get(url)

    # ── shape ───────────────────────────────────────────────────────────────
    def test_an_empty_query_returns_empty_buckets(self):
        """A stray keystroke must not dump the whole league into the UI."""
        self._team('Nova Stars')

        response = self._search('')

        self.assertEqual(response.status_code, 200, response.data)
        for bucket in ('teams', 'tournaments', 'players', 'matches'):
            self.assertEqual(response.data[bucket], [], bucket)

    def test_whitespace_only_query_is_treated_as_empty(self):
        self._team('Nova Stars')
        response = self._search('   ')
        self.assertEqual(response.data['teams'], [])

    def test_response_always_carries_every_bucket(self):
        response = self._search('nothing-matches-this')
        self.assertEqual(response.status_code, 200, response.data)
        for bucket in ('teams', 'tournaments', 'players', 'matches'):
            self.assertIn(bucket, response.data)
            self.assertEqual(response.data[bucket], [], bucket)

    # ── each entity ─────────────────────────────────────────────────────────
    def test_finds_a_team_by_partial_name(self):
        self._team('Nova Stars')
        self._team('Thunder FC')

        response = self._search('nova')

        names = [t['name'] for t in response.data['teams']]
        self.assertEqual(names, ['Nova Stars'])

    def test_team_search_is_case_insensitive(self):
        self._team('Nova Stars')
        self.assertEqual(len(self._search('NOVA').data['teams']), 1)

    def test_finds_a_tournament_by_name_and_by_code(self):
        tournament = Tournament.objects.create(
            league=self.league_obj, name='Winter Cup', format='KNOCKOUT',
            is_team_based=True, status='DRAFT', created_by=self.alice,
        )

        by_name = self._search('winter')
        self.assertEqual([t['name'] for t in by_name.data['tournaments']], ['Winter Cup'])

        by_code = self._search(tournament.tournament_code)
        self.assertEqual([t['id'] for t in by_code.data['tournaments']], [tournament.id])

    def test_finds_a_player_by_username(self):
        response = self._search('bob')
        usernames = [p['username'] for p in response.data['players']]
        self.assertIn('bob', usernames)

    def test_finds_a_fixture_by_team_name(self):
        alpha = self._team('Alpha United')
        bravo = self._team('Bravo City')
        Match.objects.create(
            league=self.league_obj, home_team=alpha, away_team=bravo,
            status='SCHEDULED',
        )

        response = self._search('bravo')

        self.assertEqual(len(response.data['matches']), 1)
        fixture = response.data['matches'][0]
        self.assertEqual(fixture['home_display'], 'Alpha United')
        self.assertEqual(fixture['away_display'], 'Bravo City')

    def test_a_query_can_match_several_buckets_at_once(self):
        self._team('Falcon FC')
        Tournament.objects.create(
            league=self.league_obj, name='Falcon League', format='LEAGUE',
            is_team_based=True, status='DRAFT', created_by=self.alice,
        )

        response = self._search('falcon')

        self.assertEqual(len(response.data['teams']), 1)
        self.assertEqual(len(response.data['tournaments']), 1)

    # ── scoping and permissions ─────────────────────────────────────────────
    def test_search_does_not_leak_another_leagues_teams(self):
        """A member of one league must not enumerate another league's teams."""
        # Built directly rather than via create_league(), which always makes a
        # league with the same name and so collides on the second call.
        other = League.objects.create(
            name='Other League', slug='other-league', owner=self.alice,
        )
        Team.objects.create(
            league=other, name='Secret Squad',
            slug='secret-squad', created_by=self.alice,
        )

        response = self._search('secret')

        self.assertEqual(response.data['teams'], [])

    def test_search_requires_authentication(self):
        self.logout()
        response = self.client.get(f'/api/leagues/{self.league_id}/search/?q=nova')
        self.assertEqual(response.status_code, 401)

    def test_a_non_member_cannot_search(self):
        self.authenticate(self.carol)
        response = self.client.get(f'/api/leagues/{self.league_id}/search/?q=nova')
        self.assertIn(response.status_code, (403, 404))

    # ── limit ───────────────────────────────────────────────────────────────
    def test_limit_caps_each_bucket(self):
        for i in range(5):
            self._team(f'Gamma {i}')

        response = self._search('gamma', limit=2)
        self.assertEqual(len(response.data['teams']), 2)

    def test_a_nonsense_limit_falls_back_instead_of_erroring(self):
        self._team('Gamma FC')

        for bad in ('abc', '-4', '0'):
            response = self._search('gamma', limit=bad)
            self.assertEqual(response.status_code, 200, (bad, response.data))
            self.assertGreaterEqual(len(response.data['teams']), 1)

    def test_an_oversized_limit_is_clamped(self):
        self._team('Gamma FC')
        response = self._search('gamma', limit=9999)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(len(response.data['teams']), 1)

    def test_query_is_echoed_back(self):
        response = self._search('nova')
        self.assertEqual(response.data['query'], 'nova')

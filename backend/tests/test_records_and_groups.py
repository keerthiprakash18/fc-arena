"""League records and group-stage tournaments.

Both of these were dead ends before this change: `records/services.py` was an
empty file so no record was ever written, and the group models had no endpoints
at all, so a GROUP_STAGE tournament could not be run.
"""

from django.contrib.auth import get_user_model

from leagues.models import League
from matches.models import Match
from records.models import LeagueRecord
from records.services import recompute_league_records
from statistics.models import PlayerLeagueStatistics
from teams.models import Team, TeamMember, TeamStatistics
from tournaments.models import (
    Tournament, TournamentGroup, TournamentParticipant, TournamentRound,
)
from tournaments.services import (
    advance_group_winners,
    create_groups,
    generate_group_fixtures,
    group_standings,
)

from .base import ApiTestCase

User = get_user_model()


class RecordServiceTests(ApiTestCase):
    """Records must come from verified data only, and never be invented."""

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

    def _verified_match(self, home, away, home_score, away_score):
        return Match.objects.create(
            league=self.league_obj, home_user=home, away_user=away,
            home_score=home_score, away_score=away_score, status='VERIFIED',
        )

    def test_no_records_when_there_is_no_data(self):
        records = recompute_league_records(self.league_obj)
        self.assertEqual(len(records), 0)

    def test_most_goals_goes_to_the_top_scorer(self):
        self._stats(self.bob, goals_scored=12, matches_played=6)
        self._stats(self.carol, goals_scored=7, matches_played=6)

        recompute_league_records(self.league_obj)

        record = LeagueRecord.objects.get(
            league=self.league_obj, record_type='MOST_GOALS', is_current=True
        )
        self.assertEqual(record.user, self.bob)
        self.assertEqual(record.value, 12)

    def test_win_rate_needs_a_real_sample(self):
        """A 1-from-1 player must not outrank a 6-from-10 player."""
        self._stats(self.bob, wins=1, matches_played=1)
        self._stats(self.carol, wins=6, matches_played=10)

        recompute_league_records(self.league_obj)

        record = LeagueRecord.objects.get(
            league=self.league_obj, record_type='BEST_WIN_RATE', is_current=True
        )
        self.assertEqual(record.user, self.carol)

    def test_win_rate_absent_when_nobody_qualifies(self):
        self._stats(self.bob, wins=1, matches_played=1)
        recompute_league_records(self.league_obj)
        self.assertFalse(LeagueRecord.objects.filter(
            league=self.league_obj, record_type='BEST_WIN_RATE'
        ).exists())

    def test_biggest_margin_comes_from_a_verified_match(self):
        self._verified_match(self.bob, self.carol, 7, 0)
        self._verified_match(self.bob, self.carol, 3, 1)

        recompute_league_records(self.league_obj)

        record = LeagueRecord.objects.get(
            league=self.league_obj, record_type='BIGGEST_WINNING_MARGIN', is_current=True
        )
        self.assertEqual(record.value, 7)
        self.assertEqual(record.user, self.bob)          # the winner, not the loser
        self.assertIsNotNone(record.match)

    def test_unverified_matches_do_not_set_records(self):
        Match.objects.create(
            league=self.league_obj, home_user=self.bob, away_user=self.carol,
            home_score=9, away_score=0, status='SCHEDULED',
        )
        recompute_league_records(self.league_obj)
        self.assertFalse(LeagueRecord.objects.filter(
            league=self.league_obj, record_type='BIGGEST_WINNING_MARGIN'
        ).exists())

    def test_recompute_is_idempotent(self):
        self._stats(self.bob, goals_scored=5, matches_played=3)
        recompute_league_records(self.league_obj)
        recompute_league_records(self.league_obj)

        self.assertEqual(LeagueRecord.objects.filter(
            league=self.league_obj, record_type='MOST_GOALS', is_current=True
        ).count(), 1)

    def test_a_broken_record_supersedes_the_previous_holder(self):
        """History must be preserved, which the old constraint made impossible."""
        self._stats(self.bob, goals_scored=5, matches_played=3)
        recompute_league_records(self.league_obj)

        PlayerLeagueStatistics.objects.filter(
            league=self.league_obj, user=self.bob
        ).update(goals_scored=9)
        recompute_league_records(self.league_obj)

        self.assertEqual(LeagueRecord.objects.filter(
            league=self.league_obj, record_type='MOST_GOALS', is_current=True
        ).count(), 1)
        self.assertEqual(LeagueRecord.objects.filter(
            league=self.league_obj, record_type='MOST_GOALS', is_current=False
        ).count(), 1)
        current = LeagueRecord.objects.get(
            league=self.league_obj, record_type='MOST_GOALS', is_current=True
        )
        self.assertEqual(current.value, 9)

    def test_a_vanished_record_holder_is_retired(self):
        self._stats(self.bob, goals_scored=5, matches_played=3)
        recompute_league_records(self.league_obj)

        PlayerLeagueStatistics.objects.filter(
            league=self.league_obj, user=self.bob
        ).update(goals_scored=0)
        recompute_league_records(self.league_obj)

        self.assertFalse(LeagueRecord.objects.filter(
            league=self.league_obj, record_type='MOST_GOALS', is_current=True
        ).exists())

    def test_team_records_are_attributed_to_the_team(self):
        # slug is required and unique per league, so direct creates must set it.
        alpha = Team.objects.create(league=self.league_obj, name='Alpha',
                                    short_name='ALP', slug='alpha', created_by=self.alice)
        bravo = Team.objects.create(league=self.league_obj, name='Bravo',
                                    short_name='BRA', slug='bravo', created_by=self.alice)
        TeamStatistics.objects.create(team=alpha, matches_played=4, wins=3,
                                      goals_scored=11, points=9)
        TeamStatistics.objects.create(team=bravo, matches_played=4, wins=1,
                                      goals_scored=4, points=3)

        recompute_league_records(self.league_obj)

        record = LeagueRecord.objects.get(
            league=self.league_obj, record_type='MOST_GOALS', is_current=True
        )
        self.assertEqual(record.team, alpha)
        self.assertIsNone(record.user)

    def test_records_endpoint_returns_the_holder_name(self):
        self._stats(self.bob, goals_scored=8, matches_played=4)
        recompute_league_records(self.league_obj)

        self.authenticate(self.alice)
        response = self.client.get(f"/api/leagues/{self.league['id']}/records/")

        self.assertEqual(response.status_code, 200, response.data)
        rows = response.data['results']
        row = next(r for r in rows if r['record_type'] == 'MOST_GOALS')
        self.assertEqual(row['username'], 'bob')
        self.assertEqual(row['display_name'], 'bob')

    def test_records_endpoint_requires_membership(self):
        outsider = User.objects.create_user('outsider', 'o@example.com', 'testpass123')
        self.authenticate(outsider)
        response = self.client.get(f"/api/leagues/{self.league['id']}/records/")
        self.assertEqual(response.status_code, 403)

    def test_recompute_endpoint_requires_admin(self):
        self.join_league(self.bob, self.league['league_code'])
        self.authenticate(self.bob)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/records/recompute/", {}, format='json'
        )
        self.assertEqual(response.status_code, 403)

    def test_recompute_endpoint_works_for_the_owner(self):
        self._stats(self.bob, goals_scored=8, matches_played=4)
        self.authenticate(self.alice)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/records/recompute/", {}, format='json'
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertGreaterEqual(response.data['count'], 1)


class GroupStageTests(ApiTestCase):
    """Group draw, intra-group fixtures, tables and knockout advancement."""

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

    def _tournament(self, fmt='GROUP_STAGE', teams=8, status='REGISTRATION_CLOSED'):
        tournament = Tournament.objects.create(
            league=self.league_obj, name='Groups Cup', format=fmt,
            is_team_based=True, status=status, created_by=self.alice,
        )
        created = []
        for i in range(teams):
            team = self._team(f'Team {chr(ord("A") + i)}')
            TournamentParticipant.objects.create(tournament=tournament, team=team)
            created.append(team)
        return tournament, created

    # ── draw ────────────────────────────────────────────────────────────────
    def test_draw_splits_participants_evenly(self):
        tournament, _ = self._tournament(teams=8)

        groups, message = create_groups(tournament, 2)

        self.assertEqual(len(groups), 2)
        self.assertEqual(TournamentGroup.objects.filter(tournament=tournament).count(), 2)
        sizes = sorted(g.members.count() for g in groups)
        self.assertEqual(sizes, [4, 4])

    def test_draw_uses_snake_seeding(self):
        """The top two seeds must not land in the same group."""
        tournament, teams = self._tournament(teams=4)
        for i, team in enumerate(teams):
            TournamentParticipant.objects.filter(
                tournament=tournament, team=team
            ).update(seed_number=i + 1)

        groups, _ = create_groups(tournament, 2)

        first = groups[0].members.get(position=0).participant.team
        second = groups[1].members.get(position=1).participant.team
        self.assertEqual(first, teams[0])
        self.assertEqual(second, teams[1])

    def test_draw_replaces_previous_groups(self):
        tournament, _ = self._tournament(teams=4)
        create_groups(tournament, 2)
        create_groups(tournament, 2)
        self.assertEqual(TournamentGroup.objects.filter(tournament=tournament).count(), 2)

    def test_draw_needs_two_participants(self):
        tournament = Tournament.objects.create(
            league=self.league_obj, name='Tiny', format='GROUP_STAGE',
            is_team_based=True, status='REGISTRATION_CLOSED', created_by=self.alice,
        )
        groups, message = create_groups(tournament, 2)
        self.assertEqual(groups, [])
        self.assertIn('at least 2', message.lower())

    def test_draw_endpoint_requires_admin(self):
        tournament, _ = self._tournament(teams=4)
        self.authenticate(self.bob)               # plain member
        response = self.client.post(
            f'/api/leagues/{self.league_id}/tournaments/{tournament.id}/groups/draw/',
            {'group_count': 2}, format='json',
        )
        self.assertEqual(response.status_code, 403)

    def test_draw_endpoint_creates_groups(self):
        tournament, _ = self._tournament(teams=6)
        self.authenticate(self.alice)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/tournaments/{tournament.id}/groups/draw/',
            {'group_count': 3}, format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(len(response.data['groups']), 3)

    # ── fixtures ────────────────────────────────────────────────────────────
    def test_group_fixtures_are_round_robin_inside_each_group(self):
        tournament, _ = self._tournament(teams=8)
        create_groups(tournament, 2)

        created, message = generate_group_fixtures(tournament)

        # 4 per group -> C(4,2) = 6 per group, 12 total.
        self.assertEqual(created, 12)
        self.assertEqual(
            Match.objects.filter(tournament=tournament, round__round_type='GROUP').count(), 12
        )
        # Every fixture stays inside one group.
        for group in tournament.groups.all():
            member_ids = {
                m.participant.team_id
                for m in group.members.select_related('participant')
            }
            matches = Match.objects.filter(tournament=tournament, round__round_number=group.group_number)
            for match in matches:
                self.assertIn(match.home_team_id, member_ids)
                self.assertIn(match.away_team_id, member_ids)

    def test_group_fixtures_are_idempotent(self):
        tournament, _ = self._tournament(teams=4)
        create_groups(tournament, 2)
        generate_group_fixtures(tournament)
        created, message = generate_group_fixtures(tournament)
        self.assertEqual(created, 0)
        self.assertIn('already generated', message)

    def test_group_fixtures_need_groups_first(self):
        tournament, _ = self._tournament(teams=4)
        created, message = generate_group_fixtures(tournament)
        self.assertEqual(created, 0)
        self.assertIn('Create groups', message)

    def test_fixtures_endpoint_routes_group_formats_to_the_group_generator(self):
        tournament, _ = self._tournament(teams=4, fmt='GROUP_KNOCKOUT')
        create_groups(tournament, 2)

        self.authenticate(self.alice)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/tournaments/{tournament.id}/fixtures/',
            {}, format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['matches_created'], 2)   # C(2,2) per group

    # ── standings ───────────────────────────────────────────────────────────
    def _play_group_match(self, tournament, group, home, away, hs, as_):
        # The group round is normally created by generate_group_fixtures; these
        # tests build tables directly, so create it on demand.
        round_row, _ = TournamentRound.objects.get_or_create(
            tournament=tournament,
            round_number=group.group_number,
            defaults={'name': f'Group {group.name}', 'round_type': 'GROUP'},
        )
        Match.objects.create(
            league=self.league_obj, tournament=tournament,
            round=round_row,
            home_team=home, away_team=away,
            home_score=hs, away_score=as_, status='VERIFIED',
        )

    def test_group_table_orders_by_points_then_goal_difference(self):
        tournament, teams = self._tournament(teams=4)
        groups, _ = create_groups(tournament, 2)
        group = groups[0]
        members = [m.participant.team for m in group.members.select_related('participant')]
        a, b = members[0], members[1]

        # a beats b 1-0, then b loses heavily to the third team.
        self._play_group_match(tournament, group, a, b, 1, 0)

        standings = group_standings(tournament)
        rows = standings[group]

        self.assertEqual(rows[0]['participant'].team, a)
        self.assertEqual(rows[0]['points'], 3)
        self.assertEqual(rows[0]['rank'], 1)
        self.assertEqual(rows[1]['points'], 0)

    def test_group_table_ignores_unverified_matches(self):
        tournament, teams = self._tournament(teams=4)
        groups, _ = create_groups(tournament, 2)
        group = groups[0]
        members = [m.participant.team for m in group.members.select_related('participant')]

        round_row, _ = TournamentRound.objects.get_or_create(
            tournament=tournament,
            round_number=group.group_number,
            defaults={'name': f'Group {group.name}', 'round_type': 'GROUP'},
        )
        Match.objects.create(
            league=self.league_obj, tournament=tournament,
            round=round_row,
            home_team=members[0], away_team=members[1],
            home_score=5, away_score=0, status='SCHEDULED',
        )

        rows = group_standings(tournament)[group]
        self.assertTrue(all(r['played'] == 0 for r in rows))
        self.assertTrue(all(r['points'] == 0 for r in rows))

    def test_standings_endpoint_returns_every_group(self):
        tournament, _ = self._tournament(teams=8)
        create_groups(tournament, 2)

        self.authenticate(self.alice)
        response = self.client.get(
            f'/api/leagues/{self.league_id}/tournaments/{tournament.id}/groups/standings/'
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['count'], 2)
        self.assertEqual(len(response.data['groups'][0]['standings']), 4)

    # ── advancement ─────────────────────────────────────────────────────────
    def test_advance_creates_a_cross_group_knockout_round(self):
        tournament, _ = self._tournament(teams=4)
        groups, _ = create_groups(tournament, 2)
        group_a, group_b = groups
        a_teams = [m.participant.team for m in group_a.members.select_related('participant')]
        b_teams = [m.participant.team for m in group_b.members.select_related('participant')]

        # Make the seeding explicit so the qualifiers are deterministic.
        self._play_group_match(tournament, group_a, a_teams[0], a_teams[1], 3, 0)
        self._play_group_match(tournament, group_b, b_teams[0], b_teams[1], 2, 0)

        created, message = advance_group_winners(tournament, per_group=1)

        self.assertEqual(created, 1)
        knockout = TournamentRound.objects.get(tournament=tournament, round_type='KNOCKOUT')
        final = Match.objects.get(tournament=tournament, round=knockout)
        # Group winners meet, and the fixture is a team fixture.
        self.assertEqual({final.home_team, final.away_team}, {a_teams[0], b_teams[0]})
        self.assertTrue(final.is_team_match)

    def test_advance_eliminates_non_qualifiers(self):
        tournament, _ = self._tournament(teams=4)
        groups, _ = create_groups(tournament, 2)
        group_a, group_b = groups
        a_teams = [m.participant.team for m in group_a.members.select_related('participant')]
        b_teams = [m.participant.team for m in group_b.members.select_related('participant')]
        self._play_group_match(tournament, group_a, a_teams[0], a_teams[1], 3, 0)
        self._play_group_match(tournament, group_b, b_teams[0], b_teams[1], 2, 0)

        advance_group_winners(tournament, per_group=1)

        eliminated = set(
            TournamentParticipant.objects.filter(
                tournament=tournament, status='ELIMINATED'
            ).values_list('team_id', flat=True)
        )
        self.assertEqual(eliminated, {a_teams[1].id, b_teams[1].id})

    def test_advance_refuses_when_a_group_is_too_small(self):
        tournament, _ = self._tournament(teams=2)
        create_groups(tournament, 2)          # one participant per group
        created, message = advance_group_winners(tournament, per_group=2)
        self.assertEqual(created, 0)
        self.assertIn('needed per group', message)

    def test_advance_endpoint_requires_admin(self):
        tournament, _ = self._tournament(teams=4)
        create_groups(tournament, 2)
        self.authenticate(self.bob)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/tournaments/{tournament.id}/groups/advance/',
            {'per_group': 1}, format='json',
        )
        self.assertEqual(response.status_code, 403)

    def test_advance_endpoint_creates_the_next_round(self):
        tournament, _ = self._tournament(teams=4)
        groups, _ = create_groups(tournament, 2)
        group_a, group_b = groups
        a_teams = [m.participant.team for m in group_a.members.select_related('participant')]
        b_teams = [m.participant.team for m in group_b.members.select_related('participant')]
        self._play_group_match(tournament, group_a, a_teams[0], a_teams[1], 3, 0)
        self._play_group_match(tournament, group_b, b_teams[0], b_teams[1], 2, 0)

        self.authenticate(self.alice)
        response = self.client.post(
            f'/api/leagues/{self.league_id}/tournaments/{tournament.id}/groups/advance/',
            {'per_group': 1}, format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['matches_created'], 1)
        self.assertEqual(response.data['status'], 'IN_PROGRESS')

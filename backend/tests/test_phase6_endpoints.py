"""Tests for Phase 6 endpoints: global search and tournament dashboard."""

from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase
from rest_framework import status

from leagues.models import League, LeagueMember
from tournaments.models import Tournament, TournamentParticipant
from matches.models import Match, MatchEvent
from teams.models import Team

User = get_user_model()


class GlobalSearchTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='searcher', password='pass', email='s@example.com'
        )
        self.league = League.objects.create(
            name='Search League', slug='search-league', owner=self.user
        )
        LeagueMember.objects.create(league=self.league, user=self.user, role='PLAYER')
        self.client.force_authenticate(user=self.user)

    def test_empty_query_returns_empty_buckets(self):
        response = self.client.get('/api/search/?q=')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(data['query'], '')
        self.assertEqual(data['leagues'], [])
        self.assertEqual(data['teams'], [])

    def test_global_search_finds_team(self):
        Team.objects.create(
            league=self.league, name='Alpha FC', slug='alpha-fc',
            short_name='ALP', game='FIFA', is_active=True
        )
        response = self.client.get('/api/search/?q=alpha')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(len(data['teams']), 1)
        self.assertEqual(data['teams'][0]['name'], 'Alpha FC')
        self.assertEqual(data['teams'][0]['league_id'], self.league.id)

    def test_global_search_finds_tournament(self):
        Tournament.objects.create(
            league=self.league, name='Winter Cup',
            created_by=self.user, status='DRAFT',
        )
        response = self.client.get('/api/search/?q=winter')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(len(data['tournaments']), 1)
        self.assertEqual(data['tournaments'][0]['name'], 'Winter Cup')

    def test_global_search_finds_player(self):
        other = User.objects.create_user(
            username='teammate', password='pass', email='t@example.com'
        )
        LeagueMember.objects.create(league=self.league, user=other, role='PLAYER')
        response = self.client.get('/api/search/?q=team')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        usernames = [p['username'] for p in data['players']]
        self.assertIn('teammate', usernames)

    def test_global_search_finds_match(self):
        other = User.objects.create_user(
            username='rival', password='pass', email='r@example.com'
        )
        LeagueMember.objects.create(league=self.league, user=other, role='PLAYER')
        Match.objects.create(
            league=self.league, home_user=self.user, away_user=other,
            status='SCHEDULED',
        )
        response = self.client.get('/api/search/?q=rival')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(len(data['matches']), 1)
        self.assertEqual(data['matches'][0]['away_display'], 'rival')

    def test_global_search_excludes_non_member_leagues(self):
        other_league = League.objects.create(
            name='Private', slug='private', owner=self.user
        )
        # self.user is NOT a member of other_league
        Team.objects.create(
            league=other_league, name='Secret', slug='secret',
            is_active=True,
        )
        response = self.client.get('/api/search/?q=secret')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(data['teams'], [])

    def test_global_search_limit_respected(self):
        for i in range(5):
            Tournament.objects.create(
                league=self.league, name=f'Tourn {i}',
                created_by=self.user, status='DRAFT',
            )
        response = self.client.get('/api/search/?q=tourn&limit=3')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertLessEqual(len(data['tournaments']), 3)


class TournamentDashboardTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='dash', password='pass', email='d@example.com'
        )
        self.league = League.objects.create(
            name='Dash League', slug='dash-league', owner=self.user
        )
        LeagueMember.objects.create(league=self.league, user=self.user, role='PLAYER')
        self.tournament = Tournament.objects.create(
            league=self.league, name='Test Cup',
            created_by=self.user, status='IN_PROGRESS',
            is_team_based=False,
        )
        self.client.force_authenticate(user=self.user)

    def test_dashboard_returns_structure(self):
        response = self.client.get(
            f'/api/leagues/{self.league.id}/tournaments/{self.tournament.id}/dashboard/'
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertIn('tournament', data)
        self.assertIn('participants', data)
        self.assertIn('matches', data)
        self.assertIn('performance', data)
        self.assertIn('leaders', data)
        self.assertIn('recent_matches', data)

    def test_dashboard_participant_counts(self):
        TournamentParticipant.objects.create(
            tournament=self.tournament, user=self.user, status='REGISTERED'
        )
        response = self.client.get(
            f'/api/leagues/{self.league.id}/tournaments/{self.tournament.id}/dashboard/'
        )
        data = response.json()
        self.assertEqual(data['participants']['total'], 1)
        self.assertEqual(data['participants']['registered'], 1)

    def test_dashboard_match_counts(self):
        Match.objects.create(
            league=self.league, tournament=self.tournament,
            home_user=self.user, away_user=self.user,
            status='VERIFIED', home_score=2, away_score=1,
        )
        response = self.client.get(
            f'/api/leagues/{self.league.id}/tournaments/{self.tournament.id}/dashboard/'
        )
        data = response.json()
        self.assertEqual(data['matches']['total'], 1)
        self.assertEqual(data['matches']['verified'], 1)
        self.assertEqual(data['performance']['total_goals'], 3)
        self.assertEqual(data['performance']['progress_percent'], 100.0)

    def test_dashboard_goals_from_events(self):
        other = User.objects.create_user(
            username='scorer', password='pass', email='sc@example.com'
        )
        LeagueMember.objects.create(league=self.league, user=other, role='PLAYER')
        match = Match.objects.create(
            league=self.league, tournament=self.tournament,
            home_user=self.user, away_user=other,
            status='VERIFIED', home_score=1, away_score=0,
        )
        MatchEvent.objects.create(
            match=match, event_type='GOAL', minute=12,
            player=other, created_by=self.user,
        )
        response = self.client.get(
            f'/api/leagues/{self.league.id}/tournaments/{self.tournament.id}/dashboard/'
        )
        data = response.json()
        self.assertIsNotNone(data['leaders']['top_scorer'])
        self.assertEqual(data['leaders']['top_scorer']['username'], 'scorer')
        self.assertEqual(data['leaders']['top_scorer']['goals'], 1)

    def test_dashboard_non_member_blocked(self):
        outsider = User.objects.create_user(
            username='outsider', password='pass', email='o@example.com'
        )
        self.client.force_authenticate(user=outsider)
        response = self.client.get(
            f'/api/leagues/{self.league.id}/tournaments/{self.tournament.id}/dashboard/'
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

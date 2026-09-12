"""Tests for the teams app — the additive team layer.

These exercise the real HTTP API (login → JWT → request), so a broken
permission or serializer path fails the suite rather than passing silently.
"""

from io import BytesIO

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image

from .base import ApiTestCase, PASSWORD

User = get_user_model()


def _png(name='logo.png'):
    """A tiny but genuinely valid PNG, so ImageField validation is exercised."""
    buf = BytesIO()
    Image.new('RGB', (12, 12), (46, 204, 113)).save(buf, format='PNG')
    buf.seek(0)
    return SimpleUploadedFile(name, buf.read(), content_type='image/png')


def results(response):
    """Unwrap DRF's global pagination envelope: {count, next, previous, results}."""
    data = response.data
    if isinstance(data, dict) and 'results' in data:
        return data['results']
    return data


class TeamApiTests(ApiTestCase):
    """CRUD, roster management, permissions and image upload for teams."""

    def setUp(self):
        super().setUp()
        self.league = self.create_league()              # alice is LEAGUE_OWNER
        self.league_id = self.league['id']
        self.join_league(self.bob, self.league['league_code'])
        self.join_league(self.carol, self.league['league_code'])
        # dave deliberately never joins the league.
        self.dave = User.objects.create_user('dave', 'dave@example.com', PASSWORD)

    # ── helpers ─────────────────────────────────────────────────────────────
    def create_team(self, name='Red Squad', actor=None, **extra):
        self.authenticate(actor or self.alice)
        payload = {'name': name, 'short_name': 'RED', 'description': '', 'game': 'FC Mobile'}
        payload.update(extra)
        return self.client.post(
            f'/api/leagues/{self.league_id}/teams/', payload, format='json'
        )

    def team_url(self, team_id, suffix=''):
        return f'/api/leagues/{self.league_id}/teams/{team_id}/{suffix}'

    # ── create ──────────────────────────────────────────────────────────────
    def test_admin_can_create_team(self):
        response = self.create_team()
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['name'], 'Red Squad')
        self.assertEqual(response.data['slug'], 'red-squad')
        self.assertEqual(response.data['member_count'], 0)
        # No fabricated numbers — statistics are absent until matches are verified.
        self.assertIsNone(response.data['statistics'])

    def test_plain_player_cannot_create_team(self):
        response = self.create_team(actor=self.bob)
        self.assertEqual(response.status_code, 403)

    def test_duplicate_team_name_is_rejected(self):
        self.create_team('Red Squad')
        response = self.create_team('red squad')      # case-insensitive clash
        self.assertEqual(response.status_code, 400)

    def test_same_name_allowed_in_a_different_league(self):
        self.create_team('Red Squad')
        other = self.create_league(self.bob, name='Other League', slug='other-league')
        self.authenticate(self.bob)
        response = self.client.post(
            f"/api/leagues/{other['id']}/teams/",
            {'name': 'Red Squad', 'short_name': 'RED', 'description': '', 'game': ''},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)

    def test_captain_must_be_a_league_member(self):
        response = self.create_team(captain=self.dave.id)
        self.assertEqual(response.status_code, 400)

    def test_captain_is_added_to_the_roster_automatically(self):
        response = self.create_team(captain=self.bob.id)
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['member_count'], 1)
        roles = [(m['username'], m['role']) for m in response.data['members']]
        self.assertEqual(roles, [('bob', 'CAPTAIN')])

    # ── read / permissions ──────────────────────────────────────────────────
    def test_member_can_list_and_read_teams(self):
        team = self.create_team().data
        self.authenticate(self.carol)                 # plain player
        listing = self.client.get(f'/api/leagues/{self.league_id}/teams/')
        self.assertEqual(listing.status_code, 200)
        self.assertEqual(len(results(listing)), 1)
        detail = self.client.get(self.team_url(team['id']))
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(detail.data['name'], 'Red Squad')

    def test_non_member_cannot_list_teams(self):
        self.create_team()
        self.authenticate(self.dave)
        response = self.client.get(f'/api/leagues/{self.league_id}/teams/')
        self.assertEqual(response.status_code, 403)

    def test_anonymous_cannot_list_teams(self):
        self.logout()
        response = self.client.get(f'/api/leagues/{self.league_id}/teams/')
        self.assertEqual(response.status_code, 401)

    def test_search_filters_by_name(self):
        self.create_team('Red Squad')
        self.create_team('Blue Crew')
        self.authenticate(self.alice)
        response = self.client.get(f'/api/leagues/{self.league_id}/teams/?search=blue')
        self.assertEqual(response.status_code, 200)
        self.assertEqual([t['name'] for t in results(response)], ['Blue Crew'])

    # ── update / delete ─────────────────────────────────────────────────────
    def test_admin_can_rename_team_and_slug_follows(self):
        team = self.create_team().data
        self.authenticate(self.alice)
        response = self.client.patch(
            self.team_url(team['id']), {'name': 'Crimson Squad'}, format='json'
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['slug'], 'crimson-squad')

    def test_player_cannot_update_team(self):
        team = self.create_team().data
        self.authenticate(self.bob)
        response = self.client.patch(
            self.team_url(team['id']), {'name': 'Hacked'}, format='json'
        )
        self.assertEqual(response.status_code, 403)

    def test_delete_is_a_soft_delete(self):
        team = self.create_team().data
        self.authenticate(self.alice)
        response = self.client.delete(self.team_url(team['id']))
        self.assertEqual(response.status_code, 204)
        listing = self.client.get(f'/api/leagues/{self.league_id}/teams/')
        self.assertEqual(len(results(listing)), 0)
        # The row survives so historical matches keep their opponent.
        from teams.models import Team
        self.assertTrue(Team.objects.filter(pk=team['id']).exists())

    # ── roster ──────────────────────────────────────────────────────────────
    def test_admin_can_add_player(self):
        team = self.create_team().data
        self.authenticate(self.alice)
        response = self.client.post(
            self.team_url(team['id'], 'members/'),
            {'user': self.bob.id, 'role': 'PLAYER', 'jersey_number': 10, 'position': 'ST'},
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['username'], 'bob')
        self.assertEqual(response.data['jersey_number'], 10)

    def test_duplicate_player_is_rejected(self):
        team = self.create_team().data
        self.authenticate(self.alice)
        url = self.team_url(team['id'], 'members/')
        payload = {'user': self.bob.id, 'role': 'PLAYER'}
        self.assertEqual(self.client.post(url, payload, format='json').status_code, 201)
        self.assertEqual(self.client.post(url, payload, format='json').status_code, 400)

    def test_cannot_add_a_non_league_member(self):
        team = self.create_team().data
        self.authenticate(self.alice)
        response = self.client.post(
            self.team_url(team['id'], 'members/'),
            {'user': self.dave.id, 'role': 'PLAYER'},
            format='json',
        )
        self.assertEqual(response.status_code, 400)

    def test_player_cannot_add_players(self):
        team = self.create_team().data
        self.authenticate(self.bob)
        response = self.client.post(
            self.team_url(team['id'], 'members/'),
            {'user': self.carol.id, 'role': 'PLAYER'},
            format='json',
        )
        self.assertEqual(response.status_code, 403)

    def test_remove_member_is_a_soft_delete(self):
        team = self.create_team(captain=self.bob.id).data
        member_id = team['members'][0]['id']
        self.authenticate(self.alice)
        response = self.client.delete(self.team_url(team['id'], f'members/{member_id}/'))
        self.assertEqual(response.status_code, 204)
        roster = self.client.get(self.team_url(team['id'], 'members/'))
        self.assertEqual(len(results(roster)), 0)

    # ── images ──────────────────────────────────────────────────────────────
    def test_admin_can_upload_logo(self):
        team = self.create_team().data
        self.authenticate(self.alice)
        response = self.client.post(
            self.team_url(team['id'], 'logo/'), {'logo': _png()}, format='multipart'
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertIn('teams/logos/', response.data['logo_url'])

    def test_logo_upload_rejects_non_image(self):
        team = self.create_team().data
        self.authenticate(self.alice)
        bad = SimpleUploadedFile('evil.txt', b'definitely not an image', content_type='text/plain')
        response = self.client.post(
            self.team_url(team['id'], 'logo/'), {'logo': bad}, format='multipart'
        )
        self.assertEqual(response.status_code, 400)

    def test_logo_upload_requires_admin(self):
        team = self.create_team().data
        self.authenticate(self.bob)
        response = self.client.post(
            self.team_url(team['id'], 'logo/'), {'logo': _png()}, format='multipart'
        )
        self.assertEqual(response.status_code, 403)

    def test_banner_upload_and_clear(self):
        team = self.create_team().data
        self.authenticate(self.alice)
        url = self.team_url(team['id'], 'banner/')
        upload = self.client.post(url, {'banner': _png('b.png')}, format='multipart')
        self.assertEqual(upload.status_code, 200, upload.data)
        self.assertIn('teams/banners/', upload.data['banner_url'])
        cleared = self.client.delete(url)
        self.assertEqual(cleared.status_code, 200)
        self.assertIsNone(cleared.data['banner_url'])

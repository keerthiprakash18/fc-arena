"""Leagues: creation, invite codes, membership and role management."""

from leagues.models import LeagueMember
from tests.base import ApiTestCase


class LeagueCreationTests(ApiTestCase):
    def test_create_league_returns_201(self):
        league = self.create_league()
        self.assertEqual(league['name'], 'Test League')

    def test_creator_becomes_owner_member(self):
        league = self.create_league()
        membership = LeagueMember.objects.get(league_id=league['id'], user=self.alice)
        self.assertEqual(membership.role, 'LEAGUE_OWNER')

    def test_invite_code_has_fc_prefix(self):
        league = self.create_league()
        self.assertTrue(league['league_code'].startswith('FC-'))
        self.assertEqual(len(league['league_code']), 9)  # 'FC-' + 6 chars

    def test_invite_codes_are_unique(self):
        codes = {self.create_league(slug=f'league-{i}')['league_code'] for i in range(5)}
        self.assertEqual(len(codes), 5)

    def test_create_requires_authentication(self):
        self.assertEqual(
            self.client.post('/api/leagues/', {'name': 'X', 'slug': 'x'}, format='json').status_code,
            401,
        )


class LeagueListingTests(ApiTestCase):
    def test_list_returns_only_joined_leagues(self):
        self.create_league(name='Mine', slug='mine')
        # create_league already enrols bob as the owner of his own league.
        self.create_league(owner=self.bob, name='Theirs', slug='theirs')

        self.authenticate(self.alice)
        response = self.client.get('/api/leagues/')
        self.assertEqual(response.status_code, 200)
        names = [row['name'] for row in response.data['results']]
        self.assertEqual(names, ['Mine'])

    def test_member_count_is_reported(self):
        league = self.create_league()
        self.join_league(self.bob, league['league_code'])
        self.authenticate(self.alice)
        response = self.client.get(f"/api/leagues/{league['id']}/")
        self.assertEqual(response.data['member_count'], 2)


class LeagueJoinTests(ApiTestCase):
    def test_join_with_valid_code_adds_member(self):
        league = self.create_league()
        response = self.join_league(self.bob, league['league_code'])
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(
            LeagueMember.objects.filter(league_id=league['id'], user=self.bob).exists()
        )

    def test_join_with_invalid_code_fails(self):
        response = self.join_league(self.bob, 'FC-NOPE1')
        self.assertEqual(response.status_code, 400)

    def test_joining_twice_fails(self):
        league = self.create_league()
        self.join_league(self.bob, league['league_code'])
        response = self.join_league(self.bob, league['league_code'])
        self.assertEqual(response.status_code, 400)


class LeagueAccessControlTests(ApiTestCase):
    def test_non_member_cannot_view_league(self):
        league = self.create_league()
        self.authenticate(self.carol)
        self.assertEqual(self.client.get(f"/api/leagues/{league['id']}/").status_code, 403)

    def test_non_member_cannot_list_members(self):
        league = self.create_league()
        self.authenticate(self.carol)
        self.assertEqual(
            self.client.get(f"/api/leagues/{league['id']}/members/").status_code, 403
        )

    def test_member_can_list_members(self):
        league = self.create_league()
        self.join_league(self.bob, league['league_code'])
        self.authenticate(self.alice)
        response = self.client.get(f"/api/leagues/{league['id']}/members/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['count'], 2)


class LeagueRoleManagementTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.league = self.create_league()
        self.join_league(self.bob, self.league['league_code'])

    def test_owner_can_promote_member_to_admin(self):
        self.authenticate(self.alice)
        response = self.client.patch(
            f"/api/leagues/{self.league['id']}/members/{self.bob.id}/",
            {'role': 'LEAGUE_ADMIN'}, format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        member = LeagueMember.objects.get(league_id=self.league['id'], user=self.bob)
        self.assertEqual(member.role, 'LEAGUE_ADMIN')

    def test_owner_role_cannot_be_changed(self):
        self.authenticate(self.alice)
        response = self.client.patch(
            f"/api/leagues/{self.league['id']}/members/{self.alice.id}/",
            {'role': 'PLAYER'}, format='json',
        )
        self.assertEqual(response.status_code, 403)

    def test_owner_cannot_be_removed(self):
        self.authenticate(self.alice)
        response = self.client.delete(
            f"/api/leagues/{self.league['id']}/members/{self.alice.id}/"
        )
        self.assertEqual(response.status_code, 403)

    def test_invalid_role_is_rejected(self):
        self.authenticate(self.alice)
        response = self.client.patch(
            f"/api/leagues/{self.league['id']}/members/{self.bob.id}/",
            {'role': 'SUPERUSER'}, format='json',
        )
        self.assertEqual(response.status_code, 400)

    def test_owner_can_remove_member(self):
        self.authenticate(self.alice)
        response = self.client.delete(
            f"/api/leagues/{self.league['id']}/members/{self.bob.id}/"
        )
        self.assertEqual(response.status_code, 204)
        member = LeagueMember.objects.get(league_id=self.league['id'], user=self.bob)
        self.assertFalse(member.is_active)

    def test_removed_member_loses_access(self):
        self.authenticate(self.alice)
        self.client.delete(f"/api/leagues/{self.league['id']}/members/{self.bob.id}/")
        self.authenticate(self.bob)
        self.assertEqual(
            self.client.get(f"/api/leagues/{self.league['id']}/").status_code, 403
        )

    def test_plain_member_cannot_manage_roles(self):
        self.authenticate(self.bob)
        response = self.client.patch(
            f"/api/leagues/{self.league['id']}/members/{self.carol.id}/",
            {'role': 'PLAYER'}, format='json',
        )
        self.assertIn(response.status_code, (403, 404))

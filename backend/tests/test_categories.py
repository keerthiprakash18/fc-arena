"""Rating-band categories and player assignment."""

from categories.models import Category, PlayerCategory
from tests.base import ApiTestCase


class CategoryTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.league = self.create_league()
        self.join_league(self.bob, self.league['league_code'])

    def _create_category(self, name='Gold', slug='gold'):
        self.authenticate(self.alice)
        return self.client.post(
            f"/api/leagues/{self.league['id']}/categories/",
            {'name': name, 'slug': slug, 'min_rating': 1500, 'max_rating': 2000},
            format='json',
        )

    def test_create_category(self):
        response = self._create_category()
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(
            Category.objects.filter(league_id=self.league['id'], slug='gold').exists()
        )

    def test_list_categories(self):
        self._create_category()
        self.authenticate(self.alice)
        response = self.client.get(f"/api/leagues/{self.league['id']}/categories/")
        self.assertEqual(response.status_code, 200)

    def test_assign_player_to_category(self):
        category = self._create_category().data
        self.authenticate(self.alice)
        response = self.client.post(
            f"/api/leagues/{self.league['id']}/categories/{category['id']}/assign/",
            {'player_id': self.bob.id}, format='json',
        )
        self.assertIn(response.status_code, (200, 201), response.data)

    def test_category_players_endpoint(self):
        category = self._create_category().data
        self.authenticate(self.alice)
        response = self.client.get(
            f"/api/leagues/{self.league['id']}/categories/{category['id']}/players/"
        )
        self.assertEqual(response.status_code, 200)

    def test_categories_require_authentication(self):
        self.logout()
        response = self.client.get(f"/api/leagues/{self.league['id']}/categories/")
        self.assertEqual(response.status_code, 401)

    def test_slug_is_derived_from_name(self):
        self._create_category(name='Gold Cup', slug='ignored')
        category = Category.objects.get(league_id=self.league['id'])
        self.assertEqual(category.slug, 'gold-cup')

    def test_duplicate_category_name_is_rejected_cleanly(self):
        """A second category with the same name must fail with 400, not a 500
        IntegrityError from the unique (league, slug) constraint."""
        self._create_category(name='Gold', slug='gold')
        response = self._create_category(name='Gold', slug='gold')
        self.assertEqual(response.status_code, 400, response.data)


class CategoryModelTests(ApiTestCase):
    def test_category_str_includes_league(self):
        league = self.create_league()
        category = Category.objects.create(
            league_id=league['id'], name='Silver', slug='silver'
        )
        self.assertIn('Silver', str(category))
        self.assertIn('Test League', str(category))

    def test_player_category_unique_per_player(self):
        league = self.create_league()
        category = Category.objects.create(
            league_id=league['id'], name='Bronze', slug='bronze'
        )
        PlayerCategory.objects.create(player=self.bob, category=category)
        self.assertEqual(PlayerCategory.objects.filter(player=self.bob).count(), 1)

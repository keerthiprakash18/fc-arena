"""Service-level endpoints: API root and the health probe."""

from django.test import TestCase
from django.urls import reverse


class ApiRootTests(TestCase):
    def test_api_root_lists_sections(self):
        response = self.client.get('/api/')
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['name'], 'FC ARENA API')
        self.assertEqual(payload['status'], 'ok')
        self.assertIn('/api/leagues/', payload['sections'])
        self.assertIn('/api/matches/', payload['sections'])

    def test_api_root_is_public(self):
        """Uptime checks must not need credentials."""
        self.assertEqual(self.client.get('/api/').status_code, 200)


class HealthTests(TestCase):
    def test_health_reports_ok_and_database_up(self):
        response = self.client.get('/api/health/')
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['status'], 'ok')
        self.assertTrue(payload['database'])
        self.assertIn('version', payload)

    def test_health_is_public(self):
        self.assertEqual(self.client.get('/api/health/').status_code, 200)

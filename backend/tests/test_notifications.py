"""Notifications: listing, unread count, mark-read, preferences."""

from django.contrib.auth import get_user_model
from tests.base import ApiTestCase

User = get_user_model()


class NotificationTests(ApiTestCase):
    def setUp(self):
        super().setUp()
        self.authenticate(self.alice)

    def test_list_returns_200(self):
        self.assertEqual(self.client.get('/api/notifications/').status_code, 200)

    def test_unread_count_returns_200(self):
        response = self.client.get('/api/notifications/unread-count/')
        self.assertEqual(response.status_code, 200)

    def test_mark_all_read_returns_200(self):
        response = self.client.post('/api/notifications/read-all/', {}, format='json')
        self.assertIn(response.status_code, (200, 202, 204))

    def test_preferences_endpoint_returns_200(self):
        response = self.client.get('/api/notifications/preferences/')
        self.assertEqual(response.status_code, 200)

    def test_list_requires_authentication(self):
        self.logout()
        self.assertEqual(self.client.get('/api/notifications/').status_code, 401)

    def test_unread_count_requires_authentication(self):
        self.logout()
        self.assertEqual(
            self.client.get('/api/notifications/unread-count/').status_code, 401
        )

    def test_notifications_are_scoped_to_the_user(self):
        """Alice must never see Bob's notifications."""
        from notifications.models import Notification

        if not hasattr(Notification, 'recipient') and not hasattr(Notification, 'user'):
            self.skipTest('Notification recipient field has a different name')

        field = 'recipient' if hasattr(Notification, 'recipient') else 'user'
        Notification.objects.create(**{
            field: self.bob,
            'title': 'Bob only',
            'message': 'private',
        })

        self.authenticate(self.alice)
        response = self.client.get('/api/notifications/')
        self.assertEqual(response.status_code, 200)
        titles = [n['title'] for n in response.data.get('results', [])]
        self.assertNotIn('Bob only', titles)

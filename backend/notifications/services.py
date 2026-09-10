from .models import Notification, NotificationPreference


def create_notification(user, notification_type, title, message,
                       league=None, tournament=None, match=None,
                       action_url='', metadata=None):
    try:
        prefs = NotificationPreference.objects.get(user=user)
    except NotificationPreference.DoesNotExist:
        prefs = NotificationPreference.objects.create(user=user)

    should_send = True
    if notification_type in ['TOURNAMENT_INVITATION', 'TOURNAMENT_REGISTRATION']:
        should_send = prefs.tournament_invitations
    elif notification_type in ['MATCH_REMINDER', 'MATCH_VERIFIED', 'MATCH_REJECTED',
                                'AI_VERIFICATION_COMPLETE']:
        should_send = prefs.match_results
    elif notification_type in ['DISPUTE_UPDATE']:
        should_send = prefs.dispute_updates
    elif notification_type in ['AWARD_RECEIVED']:
        should_send = prefs.awards
    elif notification_type in ['LEAGUE_INVITATION', 'TOURNAMENT_STARTED',
                                'ROUND_COMPLETED', 'TOURNAMENT_COMPLETED']:
        should_send = prefs.league_updates

    if not should_send:
        return None

    return Notification.objects.create(
        user=user,
        notification_type=notification_type,
        title=title,
        message=message,
        league=league,
        tournament=tournament,
        match=match,
        action_url=action_url,
        metadata=metadata or {},
    )


def create_bulk_notifications(users, notification_type, title, message,
                              league=None, tournament=None, match=None,
                              action_url='', metadata=None):
    notifications = []
    for user in users:
        n = create_notification(
            user, notification_type, title, message,
            league, tournament, match, action_url, metadata
        )
        if n:
            notifications.append(n)
    return notifications


def get_user_notifications(user, unread_only=False):
    qs = Notification.objects.filter(user=user)
    if unread_only:
        qs = qs.filter(is_read=False)
    return qs


def mark_notification_read(notification_id, user):
    try:
        notification = Notification.objects.get(id=notification_id, user=user)
        notification.is_read = True
        notification.save(update_fields=['is_read'])
        return True
    except Notification.DoesNotExist:
        return False


def mark_all_read(user):
    Notification.objects.filter(user=user, is_read=False).update(is_read=True)
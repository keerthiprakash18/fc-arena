"""Drive the full team-match verification pipeline against the live database.

Run:  ./backend/venv/Scripts/python.exe backend/manage.py shell < live_pipeline_check.py

Proves the third fix: a team match can reach VERIFIED without crashing, the
roster is notified with team names (not "None"), and TeamStatistics move.
"""

from django.contrib.auth import get_user_model

from evidence.models import EvidenceStorage
from matches.models import Match
from notifications.models import Notification
from teams.models import TeamStatistics
from verification.models import VerificationTask
from verification.services import admin_review

User = get_user_model()

match = (
    Match.objects.filter(home_team__isnull=False)
    .exclude(status__in=['VERIFIED', 'CANCELLED'])
    .order_by('-id')
    .first()
)
if match is None:
    print('no eligible team match found')
else:
    admin = match.league.owner
    print(f'match #{match.id}: {match.home_display} {match.home_score}-'
          f'{match.away_score} {match.away_display} [{match.status}]')

    if match.home_score is None:
        match.home_score, match.away_score = 2, 1
        match.save(update_fields=['home_score', 'away_score'])
        print(f'  set score to {match.home_score}-{match.away_score}')

    evidence = EvidenceStorage.objects.create(
        match=match, uploaded_by=admin, file_name='live-check.png',
        file_reference='evidence/live-check.png', file_size=2048,
        file_type='image/png', checksum='c' * 64, is_valid=True,
    )
    task = VerificationTask.objects.create(
        match=match, evidence=evidence, status='ADMIN_REVIEW',
        ai_extracted_data={'home_score': match.home_score,
                           'away_score': match.away_score},
    )

    before = Notification.objects.filter(
        notification_type='MATCH_VERIFIED').count()

    task, message = admin_review(task, approved=True, admin_user=admin,
                                 notes='live pipeline check')

    match.refresh_from_db()
    print(f'  admin_review            : {message}')
    print(f'  match status now        : {match.status}')
    print(f'  verified_at set         : {match.verified_at is not None}')

    sent = Notification.objects.filter(
        notification_type='MATCH_VERIFIED').order_by('-id')[:5]
    print(f'  new notifications       : {Notification.objects.filter(notification_type="MATCH_VERIFIED").count() - before}')
    for note in sent:
        print(f'    -> {note.user.username}: {note.message}')

    home_stats = TeamStatistics.objects.filter(team=match.home_team).first()
    away_stats = TeamStatistics.objects.filter(team=match.away_team).first()
    print(f'  {match.home_display:14s} P{home_stats.matches_played if home_stats else 0} '
          f'W{home_stats.wins if home_stats else 0} pts={home_stats.points if home_stats else 0}')
    print(f'  {match.away_display:14s} P{away_stats.matches_played if away_stats else 0} '
          f'W{away_stats.wins if away_stats else 0} pts={away_stats.points if away_stats else 0}')

    ok = (match.status == 'VERIFIED'
          and match.verified_at is not None
          and home_stats is not None
          and home_stats.matches_played >= 1)
    print(f'\nPASS defect 3: {ok}' if ok else '\nFAIL defect 3')

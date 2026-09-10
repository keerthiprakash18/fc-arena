from decimal import Decimal
from django.db import transaction
from django.utils import timezone
from matches.models import Match, MatchStatistics, MatchVerification
from evidence.models import EvidenceStorage
from .models import VerificationTask, ExtractionResult
from .ocr_providers import get_ocr_provider


AUTO_VERIFY_THRESHOLD = Decimal('0.8500')


def create_verification_task(match, evidence):
    task, created = VerificationTask.objects.get_or_create(
        match=match,
        evidence=evidence,
        defaults={'status': 'PENDING'}
    )
    return task


def process_verification(task):
    if task.status not in ['PENDING', 'AI_PROCESSING']:
        return task

    task.status = 'AI_PROCESSING'
    task.save(update_fields=['status', 'updated_at'])

    provider = get_ocr_provider()
    task.ai_provider = provider.get_provider_name()

    from django.conf import settings
    evidence_disk_path = settings.MEDIA_ROOT / task.evidence.file_reference
    extracted_fields = provider.extract(evidence_disk_path)
    task.ai_extracted_data = extracted_fields

    ExtractionResult.objects.filter(verification_task=task).delete()
    total_confidence = Decimal('0')
    count = 0

    for field_data in extracted_fields:
        conf = Decimal(str(field_data.get('confidence', 0)))
        total_confidence += conf
        count += 1

        ExtractionResult.objects.create(
            verification_task=task,
            field_name=field_data['field'],
            field_value=field_data.get('value'),
            confidence=conf,
            source_region=field_data.get('source_region', ''),
            is_reliable=conf >= AUTO_VERIFY_THRESHOLD,
        )

    avg_confidence = total_confidence / count if count > 0 else Decimal('0')
    task.ai_confidence_score = avg_confidence

    extracted_by_field = {
        f.get('field'): f.get('value') for f in extracted_fields
    }
    ocr_home = extracted_by_field.get('home_score')
    ocr_away = extracted_by_field.get('away_score')

    scores_match = False
    match = task.match
    if ocr_home is not None and ocr_away is not None:
        try:
            scores_match = (
                int(ocr_home) == match.home_score
                and int(ocr_away) == match.away_score
            )
        except (TypeError, ValueError):
            scores_match = False

    if scores_match and avg_confidence >= AUTO_VERIFY_THRESHOLD:
        task.status = 'AI_VERIFIED'
        task.verified_by = None
        task.verified_at = None
    elif scores_match:
        task.status = 'ADMIN_REVIEW'
    else:
        task.status = 'ADMIN_REVIEW'
        if count > 0:
            note = "AI extracted scores do not match the submitted result"
            if ocr_home is not None and ocr_away is not None:
                note = (f'AI extracted {ocr_home}-{ocr_away} but '
                        f'submitted result is {match.home_score}-{match.away_score}')
            task.admin_notes = note

    task.save(update_fields=[
        'ai_extracted_data', 'ai_confidence_score', 'ai_provider',
        'status', 'updated_at'
    ])

    _sync_match_verification(task)

    if task.status == 'ADMIN_REVIEW':
        from django.contrib.auth import get_user_model
        from notifications.services import create_notification
        User = get_user_model()
        admins = User.objects.filter(
            league_memberships__league=task.match.league,
            league_memberships__role__in=['LEAGUE_OWNER', 'LEAGUE_ADMIN'],
            league_memberships__is_active=True
        )
        for admin in admins:
            create_notification(
                user=admin,
                notification_type='ADMIN_REVIEW_REQUIRED',
                title='Verification Requires Review',
                message=f'Match #{task.match_id} evidence needs manual review (confidence {task.ai_confidence_score}).',
                league=task.match.league,
                match=task.match,
            )

    return task


def _sync_match_verification(task):
    match_verification, _ = MatchVerification.objects.get_or_create(
        match=task.match,
        defaults={'status': 'PENDING'}
    )

    match_verification.status = task.status
    match_verification.ai_extracted_data = task.ai_extracted_data
    match_verification.ai_confidence_score = task.ai_confidence_score
    match_verification.admin_notes = task.admin_notes
    match_verification.verified_by = task.verified_by
    match_verification.verified_at = task.verified_at
    match_verification.save()

    match = task.match
    if task.status in ('AI_VERIFIED', 'VERIFIED'):
        new_match_status = 'VERIFIED'
    elif task.status == 'ADMIN_REVIEW':
        new_match_status = 'ADMIN_REVIEW'
    elif task.status == 'REJECTED':
        new_match_status = 'REJECTED'
    elif task.status == 'DISPUTED':
        new_match_status = 'DISPUTED'
    else:
        return

    _walk_match_to_status(match, new_match_status)
    if new_match_status == 'VERIFIED':
        match.verified_at = timezone.now()
        match.verified_by = task.verified_by
        match.save(update_fields=['verified_at', 'verified_by'])
        from statistics.services import process_verified_match
        process_verified_match(match)
        from leaderboards.services import calculate_leaderboards
        season = match.tournament.season if match.tournament and hasattr(match.tournament, 'season') else None
        calculate_leaderboards(match.league, season, match.tournament)

        from tournaments.services import advance_tournament_after_verification
        next_round_name = advance_tournament_after_verification(match)
        if next_round_name:
            from notifications.services import create_bulk_notifications
            next_matches = list(match.tournament.matches.filter(round__round_number=match.round.round_number + 1))
            next_participants = []
            for nm in next_matches:
                if nm.home_user_id:
                    next_participants.append(nm.home_user)
                if nm.away_user_id:
                    next_participants.append(nm.away_user)
            if next_participants:
                create_bulk_notifications(
                    users=next_participants,
                    notification_type='TOURNAMENT_UPDATE',
                    title=f'Next Round: {next_round_name}',
                    message=f'Your next match in {match.tournament.name} is set. Check the bracket!',
                    league=match.league,
                    tournament=match.tournament,
                    match=next_matches[0] if next_matches else None,
                )

        from notifications.services import create_bulk_notifications
        create_bulk_notifications(
            users=[match.home_user, match.away_user],
            notification_type='MATCH_VERIFIED',
            title='Match Result Verified',
            message=f'Match verified: {match.home_user.username} {match.home_score} - {match.away_score} {match.away_user.username}',
            league=match.league,
            tournament=match.tournament,
            match=match,
        )
    elif new_match_status in ('REJECTED', 'DISPUTED'):
        from notifications.services import create_bulk_notifications
        create_bulk_notifications(
            users=[match.home_user, match.away_user],
            notification_type='MATCH_REJECTED' if new_match_status == 'REJECTED' else 'DISPUTE_UPDATE',
            title='Match Result Rejected' if new_match_status == 'REJECTED' else 'Match Result Disputed',
            message=f'The submitted result for your match was {new_match_status}.',
            league=match.league,
            tournament=match.tournament,
            match=match,
        )


def _walk_match_to_status(match, target_status):
    """
    Walk the match through the state machine until it reaches target_status.
    Handles paths like EVIDENCE_SUBMITTED -> AI_PROCESSING -> ADMIN_REVIEW -> VERIFIED.
    """
    if match.status == target_status:
        return

    visited = set()
    path = []
    if _find_path(match, match.status, target_status, visited, path):
        for next_status in path:
            match.transition_to(next_status)


def _find_path(match, current, target, visited, path):
    if current == target:
        return True
    if current in visited:
        return False
    visited.add(current)

    allowed = match.VALID_TRANSITIONS.get(current, [])
    for nxt in allowed:
        path.append(nxt)
        if _find_path(match, nxt, target, visited, path):
            return True
        path.pop()
    return False


def admin_review(task, approved, admin_user, notes=''):
    if task.status != 'ADMIN_REVIEW':
        return task, "Task is not in ADMIN_REVIEW status"

    task.admin_notes = notes
    task.verified_by = admin_user
    task.verified_at = timezone.now()

    if approved:
        task.status = 'VERIFIED'
    else:
        task.status = 'REJECTED'

    task.save(update_fields=[
        'admin_notes', 'verified_by', 'verified_at',
        'status', 'updated_at'
    ])

    _sync_match_verification(task)
    return task, "Review submitted"
from django.db.models import Count, Sum, Q, Avg
from django.utils import timezone
from django.contrib.auth import get_user_model
from datetime import timedelta

from accounts.models import User
from leagues.models import League, LeagueMember
from matches.models import Match
from tournaments.models import Tournament, TournamentParticipant
from statistics.models import PlayerLeagueStatistics, LeagueStanding
from ratings.models import PlayerLeagueRating, RatingHistory
from verification.models import VerificationTask
from disputes.models import Dispute
from leaderboards.models import Leaderboard
from auditlog.models import AuditLog
from notifications.models import Notification
from awards.models import Award


def _match_qs(league, **filters):
    return Match.objects.filter(league=league, **filters)


def league_overview(league):
    matches = _match_qs(league)
    total = matches.count()
    verified = matches.filter(status='VERIFIED').count()
    pending_reviews = VerificationTask.objects.filter(
        match__league=league, status='ADMIN_REVIEW'
    ).count()
    open_disputes = Dispute.objects.filter(league=league).exclude(status='RESOLVED').count()

    scored = matches.filter(status='VERIFIED').exclude(home_score=None, away_score=None)
    total_goals = (scored.aggregate(
        total=Sum('home_score') + Sum('away_score')
    )['total'] or 0)

    stats_qs = PlayerLeagueStatistics.objects.filter(league=league)
    top_scorer = stats_qs.order_by('-goals_scored').select_related('user').first()
    leader = LeagueStanding.objects.filter(league=league).order_by('rank').select_related('user').first()

    last_7d = timezone.now() - timedelta(days=7)
    new_last_7d = matches.filter(created_at__gte=last_7d).count()
    verified_last_7d = matches.filter(verified_at__gte=last_7d).count()

    top_goal_league = stats_qs.aggregate(g=Sum('goals_scored'))['g'] or 0

    return {
        'league': {
            'id': league.id,
            'name': league.name,
            'code': league.league_code,
        },
        'counts': {
            'members': LeagueMember.objects.filter(league=league, is_active=True).count(),
            'tournaments': Tournament.objects.filter(league=league).count(),
            'active_tournaments': Tournament.objects.filter(
                league=league, status__in=['REGISTRATION', 'IN_PROGRESS']
            ).count(),
            'tournament_participants': TournamentParticipant.objects.filter(
                tournament__league=league
            ).count(),
            'matches_total': total,
            'matches_verified': verified,
            'matches_scheduled': matches.filter(status='SCHEDULED').count(),
            'matches_in_progress': matches.filter(
                status__in=['AWAITING_RESULT', 'EVIDENCE_SUBMITTED']
            ).count(),
            'pending_verification_reviews': pending_reviews,
            'open_disputes': open_disputes,
            'verified_last_7d': verified_last_7d,
            'new_matches_last_7d': new_last_7d,
        },
        'performance': {
            'total_goals': total_goals,
            'avg_goals_per_verified_match': round(total_goals / verified, 2) if verified else 0,
            'leaderboard_entries': Leaderboard.objects.filter(league=league).count(),
            'total_member_goals': top_goal_league,
            'awards_given': Award.objects.filter(league=league).count(),
        },
        'leaders': {
            'standings_leader': {
                'username': leader.user.username if leader else None,
                'rank': leader.rank if leader else None,
                'points': leader.points if leader else 0,
            } if leader else None,
            'top_scorer': {
                'username': top_scorer.user.username if top_scorer else None,
                'goals': top_scorer.goals_scored if top_scorer else 0,
            } if top_scorer else None,
        },
    }


def match_status_distribution(league):
    rows = _match_qs(league).values('status').annotate(count=Count('id')).order_by('status')
    by_status = {r['status']: r['count'] for r in rows}

    verification_rows = VerificationTask.objects.filter(match__league=league)
    verification_breakdown = verification_rows.values('status').annotate(count=Count('id'))

    dispute_rows = Dispute.objects.filter(league=league)
    dispute_breakdown = dispute_rows.values('status').annotate(count=Count('id'))

    labels = [
        'SCHEDULED', 'AWAITING_RESULT', 'EVIDENCE_SUBMITTED',
        'AI_PROCESSING', 'ADMIN_REVIEW', 'VERIFIED', 'REJECTED', 'DISPUTED',
    ]
    return {
        'match_status': {s: by_status.get(s, 0) for s in labels},
        'verification_status': {
            r['status']: r['count'] for r in verification_breakdown
        },
        'dispute_status': {
            r['status']: r['count'] for r in dispute_breakdown
        },
    }


def rating_trends(league, user=None):
    qs = RatingHistory.objects.filter(league=league).select_related('user').order_by('created_at')
    series = {}
    for h in qs:
        name = h.user.username
        series.setdefault(name, []).append({
            'date': h.created_at.isoformat(),
            'rating': float(h.new_rating),
            'result': h.result,
        })
    result = [{'user': name, 'points': points} for name, points in series.items()]

    if user is not None:
        entries = RatingHistory.objects.filter(league=league, user=user).order_by('created_at')
        return {
            'user': user.username,
            'current': float(
                PlayerLeagueRating.objects.filter(league=league, user=user).first().rating
            ) if PlayerLeagueRating.objects.filter(league=league, user=user).exists() else 1000.0,
            'points': [{
                'date': h.created_at.isoformat(),
                'rating': float(h.new_rating),
                'result': h.result,
            } for h in entries],
            'series': result,
        }
    return {'series': result}


def pending_reviews(league):
    tasks = VerificationTask.objects.filter(
        match__league=league, status='ADMIN_REVIEW'
    ).select_related('match', 'match__home_user', 'match__away_user').order_by('-created_at')

    open_disputes = Dispute.objects.filter(
        league=league
    ).exclude(status='RESOLVED').select_related('match', 'match__home_user', 'match__away_user', 'raised_by')

    return {
        'verification_reviews': [{
            'task_id': t.id,
            'match_id': t.match_id,
            'home_user': t.match.home_user.username,
            'away_user': t.match.away_user.username,
            'confidence': float(t.ai_confidence_score) if t.ai_confidence_score is not None else None,
            'status': t.status,
            'created_at': t.created_at.isoformat(),
        } for t in tasks],
        'open_disputes': [{
            'dispute_id': d.id,
            'match_id': d.match_id,
            'reason': d.reason,
            'raised_by': d.raised_by.username,
            'created_at': d.created_at.isoformat(),
        } for d in open_disputes],
    }


def recent_activity(league, limit=15):
    logs = list(AuditLog.objects.filter(league=league).select_related('actor')
                .order_by('-timestamp')[:limit])
    events = [{
        'type': 'audit',
        'action': l.action,
        'entity_type': l.entity_type,
        'entity_id': l.entity_id,
        'actor': l.actor.username,
        'timestamp': l.timestamp.isoformat(),
        'metadata': l.metadata,
    } for l in logs]

    matches = list(Match.objects.filter(league=league)
                   .select_related('home_user', 'away_user')
                   .order_by('-updated_at')[:limit])
    for m in matches:
        events.append({
            'type': 'match',
            'action': 'MATCH_UPDATED',
            'entity_type': 'Match',
            'entity_id': m.id,
            'actor': None,
            'timestamp': m.updated_at.isoformat(),
            'metadata': {
                'home': m.home_user.username,
                'away': m.away_user.username,
                'status': m.status,
                'score': f"{m.home_score}-{m.away_score}" if m.home_score is not None else None,
            },
        })

    events.sort(key=lambda e: e['timestamp'], reverse=True)
    return events[:limit]


def platform_overview():
    now = timezone.now()
    last_30d = now - timedelta(days=30)
    return {
        'users_total': User.objects.count(),
        'users_last_30d': User.objects.filter(date_joined__gte=last_30d).count(),
        'leagues_total': League.objects.count(),
        'matches_total': Match.objects.count(),
        'matches_verified': Match.objects.filter(status='VERIFIED').count(),
        'matches_last_30d': Match.objects.filter(created_at__gte=last_30d).count(),
        'pending_verification_reviews': VerificationTask.objects.filter(status='ADMIN_REVIEW').count(),
        'open_disputes': Dispute.objects.exclude(status='RESOLVED').count(),
        'active_tournaments': Tournament.objects.filter(status__in=['REGISTRATION', 'IN_PROGRESS']).count(),
        'audit_events': AuditLog.objects.count(),
        'notifications_sent': Notification.objects.count(),
    }
import math
from django.db import transaction
from django.utils import timezone
from .models import Tournament, TournamentRound, TournamentParticipant
from matches.models import Match


def _round_name_for_match_count(count):
    if count == 1:
        return 'Final'
    if count == 2:
        return 'Semi-Finals'
    if count == 4:
        return 'Quarter-Finals'
    if count == 8:
        return 'Round of 16'
    if count == 16:
        return 'Round of 32'
    if count == 32:
        return 'Round of 64'
    return f'Round of {count * 2}'


def _ordered_participants(tournament):
    return list(
        tournament.participants
        .exclude(status='WITHDRAWN')
        .select_related('user')
        .order_by('seed_number', 'registered_at')
    )


def _ensure_rounds(tournament, round_count):
    """Create TournamentRound rows 1..round_count if missing."""
    first_round = None
    for r in range(1, round_count + 1):
        matches_in_round = max(1, 2 ** (round_count - r))
        tr, _ = TournamentRound.objects.get_or_create(
            tournament=tournament, round_number=r,
            defaults={'name': _round_name_for_match_count(matches_in_round), 'round_type': 'KNOCKOUT'},
        )
        if r == 1:
            first_round = tr
    if first_round and not first_round.is_current:
        first_round.is_current = True
        first_round.save(update_fields=['is_current'])
    return first_round


def _promote_byes(tournament):
    """Participants with no match yet in a KO tournament get an automatic win (bye)."""
    match_participant_ids = set()
    from django.db.models import Q
    for m in Match.objects.filter(tournament=tournament).exclude(status='CANCELLED'):
        if m.home_user_id:
            match_participant_ids.add(m.home_user_id)
        if m.away_user_id:
            match_participant_ids.add(m.away_user_id)
    byes = _ordered_participants(tournament)
    advanced = []
    for p in byes:
        if p.user_id not in match_participant_ids:
            p.status = 'ACTIVE'
            p.save(update_fields=['status'])
            advanced.append(p.user)
    return advanced


def generate_knockout_fixtures(tournament):
    participants = _ordered_participants(tournament)
    if not participants:
        return 0, 'No participants to generate fixtures for.'

    n = len(participants)
    rounds = max(1, math.ceil(math.log2(n)))
    pool = participants[:]

    created = 0
    with transaction.atomic():
        first_round = _ensure_rounds(tournament, rounds)

        if Match.objects.filter(tournament=tournament).exists():
            return Match.objects.filter(tournament=tournament).count(), 'Fixtures already generated.'

        # Odd number: the last-seeded participant gets a bye (auto-advances).
        if n % 2 == 1:
            bye = pool.pop()
            bye.status = 'ACTIVE'
            bye.save(update_fields=['status'])

        for i in range(0, len(pool), 2):
            home = pool[i].user if i < len(pool) else None
            away = pool[i + 1].user if i + 1 < len(pool) else None
            Match.objects.create(
                league=tournament.league,
                tournament=tournament,
                round=first_round,
                home_user=home,
                away_user=away,
                status='SCHEDULED',
            )
            created += 1

    tournament.status = 'READY'
    tournament.save(update_fields=['status', 'updated_at'])
    return created, f'Generated {created} round-1 matches across {rounds} round(s).'


def generate_league_fixtures(tournament):
    participants = _ordered_participants(tournament)
    if len(participants) < 2:
        return 0, 'Need at least 2 participants.'

    tr, _ = TournamentRound.objects.get_or_create(
        tournament=tournament, round_number=1,
        defaults={'name': 'League Round', 'round_type': 'LEAGUE'},
    )
    with transaction.atomic():
        if Match.objects.filter(tournament=tournament).exists():
            return Match.objects.filter(tournament=tournament).count(), 'Fixtures already generated.'
        created = 0
        for i in range(len(participants)):
            for j in range(i + 1, len(participants)):
                Match.objects.create(
                    league=tournament.league,
                    tournament=tournament,
                    round=tr,
                    home_user=participants[i].user,
                    away_user=participants[j].user,
                    status='SCHEDULED',
                )
                created += 1

    tournament.status = 'READY'
    tournament.save(update_fields=['status', 'updated_at'])
    return created, f'Generated {created} round-robin matches.'


def generate_fixtures(tournament):
    if tournament.format == 'LEAGUE':
        return generate_league_fixtures(tournament)
    return generate_knockout_fixtures(tournament)


def advance_tournament_after_verification(match):
    """When a match in a knockout tournament is VERIFIED, check whether the
    round completed and, if so, generate the next round from winners."""
    tournament = match.tournament
    if not tournament or tournament.format != 'KNOCKOUT':
        return None
    if tournament.status != 'IN_PROGRESS' and tournament.status != 'READY':
        tournament.status = 'IN_PROGRESS'
        tournament.save(update_fields=['status', 'updated_at'])

    current_round = match.round
    if not current_round:
        return None

    round_matches = list(
        Match.objects.filter(tournament=tournament, round=current_round).exclude(status='CANCELLED')
    )
    if not round_matches:
        return None
    if any(m.status != 'VERIFIED' for m in round_matches):
        return None

    next_round_no = current_round.round_number + 1
    next_round = TournamentRound.objects.filter(tournament=tournament, round_number=next_round_no).first()
    if not next_round:
        tournament.status = 'COMPLETED'
        tournament.save(update_fields=['status', 'updated_at'])
        return 'COMPLETED'

    winners = []
    for m in round_matches:
        losers = []
        if m.home_score is not None and m.away_score is not None and m.away_score > m.home_score:
            winner, loser = m.away_user, m.home_user
        else:
            winner, loser = m.home_user, m.away_user
        winners.append(winner)
        if loser:
            TournamentParticipant.objects.filter(tournament=tournament, user=loser) \
                .exclude(status='ELIMINATED').update(status='ELIMINATED')

    # plus any byes promoted earlier
    byes = list(TournamentParticipant.objects.filter(
        tournament=tournament, status='ACTIVE'
    ).exclude(user__in=winners))
    for b in byes:
        if not Match.objects.filter(tournament=tournament).filter(
            home_user=b.user
        ).exclude(status='CANCELLED').exists() and not Match.objects.filter(
            tournament=tournament, away_user=b.user
        ).exclude(status='CANCELLED').exists():
            winners.append(b.user)

    from django.db.models import Count
    winners = list(dict.fromkeys(winners))
    if len(winners) < 2:
        return None

    winner_ids = {u.id for u in winners}
    TournamentParticipant.objects.filter(tournament=tournament, user_id__in=winner_ids) \
        .update(status='ACTIVE')

    created = 0
    with transaction.atomic():
        for i in range(0, len(winners), 2):
            home = winners[i] if i < len(winners) else None
            away = winners[i + 1] if i + 1 < len(winners) else None
            Match.objects.create(
                league=tournament.league,
                tournament=tournament,
                round=next_round,
                home_user=home,
                away_user=away,
                status='SCHEDULED',
            )
            created += 1

    next_round.is_current = True
    next_round.save(update_fields=['is_current'])
    TournamentRound.objects.filter(tournament=tournament, is_current=True) \
        .exclude(id=next_round.id).update(is_current=False)
    tournament.status = 'IN_PROGRESS'
    tournament.save(update_fields=['status', 'updated_at'])
    return next_round.name
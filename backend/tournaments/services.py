import math
from datetime import datetime, time as dtime, timedelta

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


def generate_fixtures(tournament, options=None):
    """Dispatch to the right generator.

    Team-based tournaments (``is_team_based``) use the team generator, which
    also honours scheduling options. Everything else keeps the original
    user-based behaviour, so existing tournaments are completely unaffected.
    """
    if tournament.is_team_based:
        return generate_team_fixtures(tournament, options)
    if tournament.format in ('LEAGUE', 'ROUND_ROBIN'):
        return generate_league_fixtures(tournament)
    return generate_knockout_fixtures(tournament)


def advance_tournament_after_verification(match):
    """When a match in a knockout tournament is VERIFIED, check whether the
    round completed and, if so, generate the next round from winners.

    Works for both user-based and team-based knockouts: the participant key
    (``user`` vs ``team``) is chosen from ``tournament.is_team_based`` so a team
    bracket advances exactly like a player bracket.
    """
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

    if tournament.is_team_based:
        winners = _team_round_winners(tournament, round_matches)
        return _build_next_round(tournament, next_round, winners, 'team')

    winners = _user_round_winners(tournament, round_matches)
    return _build_next_round(tournament, next_round, winners, 'user')


def _user_round_winners(tournament, round_matches):
    """Winners (User objects) of a completed user-based knockout round."""
    winners = []
    for m in round_matches:
        if m.home_score is not None and m.away_score is not None and m.away_score > m.home_score:
            winner, loser = m.away_user, m.home_user
        else:
            winner, loser = m.home_user, m.away_user
        if winner:
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

    return list(dict.fromkeys(winners))


def _team_round_winners(tournament, round_matches):
    """Winners (Team objects) of a completed team-based knockout round.

    A drawn knockout tie has no defined winner yet, so the home side advances
    (mirroring the user-based rule, which also defaults to home on a draw).
    """
    winners = []
    for m in round_matches:
        if m.home_score is not None and m.away_score is not None and m.away_score > m.home_score:
            winner, loser = m.away_team, m.home_team
        else:
            winner, loser = m.home_team, m.away_team
        if winner:
            winners.append(winner)
        if loser:
            TournamentParticipant.objects.filter(tournament=tournament, team=loser) \
                .exclude(status='ELIMINATED').update(status='ELIMINATED')

    byes = list(TournamentParticipant.objects.filter(
        tournament=tournament, status='ACTIVE', team__isnull=False
    ).exclude(team__in=winners))
    for b in byes:
        if not Match.objects.filter(
            tournament=tournament, home_team=b.team
        ).exclude(status='CANCELLED').exists() and not Match.objects.filter(
            tournament=tournament, away_team=b.team
        ).exclude(status='CANCELLED').exists():
            winners.append(b.team)

    return list(dict.fromkeys(winners))


def _build_next_round(tournament, next_round, winners, key):
    """Create the next knockout round by pairing ``winners`` two at a time.

    ``key`` is ``'user'`` or ``'team'``; it selects which FK pair the fixtures
    are written to, so one implementation serves both tournament kinds.
    """
    if len(winners) < 2:
        return None

    winner_ids = {w.id for w in winners}
    TournamentParticipant.objects.filter(
        tournament=tournament, **{f'{key}_id__in': winner_ids}
    ).update(status='ACTIVE')

    with transaction.atomic():
        for i in range(0, len(winners), 2):
            home = winners[i]
            away = winners[i + 1] if i + 1 < len(winners) else None
            Match.objects.create(
                league=tournament.league,
                tournament=tournament,
                round=next_round,
                status='SCHEDULED',
                **{f'home_{key}': home, f'away_{key}': away},
            )

    next_round.is_current = True
    next_round.save(update_fields=['is_current'])
    TournamentRound.objects.filter(tournament=tournament, is_current=True) \
        .exclude(id=next_round.id).update(is_current=False)
    tournament.status = 'IN_PROGRESS'
    tournament.save(update_fields=['status', 'updated_at'])
    return next_round.name


# ── Team fixtures (FCFC upgrade) ─────────────────────────────────────────────
#
# The generators above pair Users (home_user / away_user). The ones below pair
# Teams instead and add real scheduling: a start date/time, a per-day cap, an
# interval between matches, and an optional set of match days.
# ``generate_fixtures`` picks between the two families via ``is_team_based``.

DEFAULT_PER_DAY = 4
DEFAULT_INTERVAL_MINUTES = 60


class FixtureScheduler:
    """Allocates kickoff datetimes for generated fixtures.

    Walks forward one day at a time, skipping days not in ``match_days``
    (0 = Monday), emitting ``per_day`` slots per day spaced by
    ``interval_minutes``.

    When no start date is supplied it yields ``None`` for every slot, leaving
    fixtures genuinely unscheduled rather than inventing a time.
    """

    def __init__(self, start, interval_minutes=DEFAULT_INTERVAL_MINUTES,
                 match_days=None, per_day=DEFAULT_PER_DAY):
        self.start = start
        self.interval_minutes = max(1, int(interval_minutes or DEFAULT_INTERVAL_MINUTES))
        self.match_days = sorted({int(d) for d in match_days}) if match_days else None
        self.per_day = max(1, int(per_day or DEFAULT_PER_DAY))
        self.day = start
        self.slot = 0

    def _skip_disallowed_days(self):
        while self.match_days and self.day.weekday() not in self.match_days:
            self.day = self.day + timedelta(days=1)

    def next(self):
        if self.start is None:
            return None
        self._skip_disallowed_days()
        if self.slot >= self.per_day:
            self.day = (self.day + timedelta(days=1)).replace(
                hour=self.start.hour, minute=self.start.minute,
                second=0, microsecond=0,
            )
            self.slot = 0
            self._skip_disallowed_days()
        when = self.day + timedelta(minutes=self.interval_minutes * self.slot)
        self.slot += 1
        return when


def _parse_start(start_date, start_time):
    """Combine 'YYYY-MM-DD' + 'HH:MM' into an aware datetime, or None."""
    if not start_date:
        return None
    if isinstance(start_date, str):
        start_date = datetime.strptime(start_date.strip(), '%Y-%m-%d').date()
    if isinstance(start_time, str) and start_time.strip():
        hh, _, mm = start_time.strip().partition(':')
        start_time = dtime(int(hh), int(mm or 0))
    elif not isinstance(start_time, dtime):
        start_time = dtime(18, 0)
    naive = datetime.combine(start_date, start_time)
    if timezone.is_naive(naive):
        naive = timezone.make_aware(naive, timezone.get_current_timezone())
    return naive


def _ordered_team_participants(tournament):
    """Participants that represent a team, in seeding order."""
    return list(
        tournament.participants
        .exclude(status='WITHDRAWN')
        .filter(team__isnull=False)
        .select_related('team')
        .order_by('seed_number', 'registered_at')
    )


def generate_team_fixtures(tournament, options=None):
    """Generate team-vs-team fixtures.

    ``options`` keys (all optional): ``start_date``, ``start_time``,
    ``interval_minutes``, ``match_days``, ``per_day``, ``venue``,
    ``double_round``.
    """
    options = options or {}
    participants = _ordered_team_participants(tournament)
    if len(participants) < 2:
        return 0, 'Need at least 2 teams to generate fixtures.'

    if Match.objects.filter(tournament=tournament).exists():
        return Match.objects.filter(tournament=tournament).count(), 'Fixtures already generated.'

    scheduler = FixtureScheduler(
        _parse_start(options.get('start_date'), options.get('start_time')),
        interval_minutes=options.get('interval_minutes', DEFAULT_INTERVAL_MINUTES),
        match_days=options.get('match_days'),
        per_day=options.get('per_day', DEFAULT_PER_DAY),
    )
    venue = (options.get('venue') or '')[:120]
    created = 0

    with transaction.atomic():
        if tournament.format in ('LEAGUE', 'ROUND_ROBIN', 'GROUP_STAGE'):
            tr, _ = TournamentRound.objects.get_or_create(
                tournament=tournament, round_number=1,
                defaults={'name': 'League Round', 'round_type': 'LEAGUE'},
            )
            pairs = [
                (participants[i], participants[j])
                for i in range(len(participants))
                for j in range(i + 1, len(participants))
            ]
            if options.get('double_round'):
                pairs += [(away, home) for home, away in pairs]
            for home, away in pairs:
                Match.objects.create(
                    league=tournament.league, tournament=tournament, round=tr,
                    home_team=home.team, away_team=away.team,
                    scheduled_at=scheduler.next(), venue=venue, status='SCHEDULED',
                )
                created += 1
        else:
            n = len(participants)
            rounds = max(1, math.ceil(math.log2(n)))
            first_round = _ensure_rounds(tournament, rounds)
            pool = participants[:]
            if n % 2 == 1:
                # Odd count: the last seed gets a bye and auto-advances.
                bye = pool.pop()
                bye.status = 'ACTIVE'
                bye.save(update_fields=['status'])
            for i in range(0, len(pool), 2):
                home = pool[i].team
                away = pool[i + 1].team if i + 1 < len(pool) else None
                Match.objects.create(
                    league=tournament.league, tournament=tournament, round=first_round,
                    home_team=home, away_team=away,
                    scheduled_at=scheduler.next(), venue=venue, status='SCHEDULED',
                )
                created += 1

    tournament.status = 'READY'
    tournament.save(update_fields=['status', 'updated_at'])
    return created, f'Generated {created} team fixtures.'
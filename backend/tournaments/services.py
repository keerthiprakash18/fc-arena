import math
from datetime import datetime, time as dtime, timedelta

from django.db import transaction
from django.utils import timezone

from .models import (
    Tournament, TournamentRound, TournamentParticipant,
    TournamentGroup, TournamentGroupMember,
)
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
    also honours scheduling options. Group formats play a round-robin inside
    each group instead. Everything else keeps the original user-based behaviour,
    so existing tournaments are completely unaffected.
    """
    if tournament.format in ('GROUP_STAGE', 'GROUP_KNOCKOUT'):
        return generate_group_fixtures(tournament, options)
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
        if tournament.format in ('LEAGUE', 'ROUND_ROBIN'):
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

# ── Group stage (FCFC upgrade) ───────────────────────────────────────────────
#
# A group-stage tournament plays a round-robin inside each group, then the top
# finishers cross over into a knockout bracket. Each group gets its own
# TournamentRound (round_type='GROUP'), which is what lets a verified match be
# attributed back to the group it belongs to without a new FK on Match.

GROUP_ROUND_TYPE = 'GROUP'
DEFAULT_PER_GROUP_QUALIFIERS = 2


def _participant_field(tournament):
    """Which participant FK pair a fixture for this tournament writes to."""
    return 'team' if tournament.is_team_based else 'user'


def _side(field, prefix, participant):
    """``{'home_user': user}`` or ``{'home_team': team}``, or None for an empty slot."""
    if participant is None:
        return {f'{prefix}_{field}': None}
    return {f'{prefix}_{field}': getattr(participant, field)}


def _group_participants(tournament):
    return list(
        tournament.participants
        .exclude(status='WITHDRAWN')
        .select_related('user', 'team')
        .order_by('seed_number', 'registered_at')
    )


def create_groups(tournament, group_count=None):
    """Distribute registered participants across groups, snake-seeded.

    Snake order (A,B,C,C,B,A,…) keeps the strongest seeds apart, so group A
    does not collect every top seed. Any existing groups are replaced.
    """
    participants = _group_participants(tournament)
    if len(participants) < 2:
        return [], 'At least 2 participants are required to form groups.'

    if not group_count:
        # Aim for 3-4 per group, clamped to what the field can support.
        group_count = max(2, min(4, len(participants) // 3))
    group_count = max(1, min(int(group_count), len(participants)))

    with transaction.atomic():
        TournamentGroup.objects.filter(tournament=tournament).delete()

        groups = [
            TournamentGroup.objects.create(
                tournament=tournament,
                group_number=i + 1,
                name=chr(ord('A') + i),
            )
            for i in range(group_count)
        ]

        for index, participant in enumerate(participants):
            cycle, offset = divmod(index, group_count)
            slot = offset if cycle % 2 == 0 else group_count - 1 - offset
            TournamentGroupMember.objects.create(
                group=groups[slot], participant=participant, position=index,
            )

    return groups, f'Created {len(groups)} groups from {len(participants)} participants.'


def generate_group_fixtures(tournament, options=None):
    """Round-robin fixtures inside every group, honouring scheduling options."""
    options = options or {}
    groups = list(tournament.groups.all())
    if not groups:
        return 0, 'Create groups before generating group fixtures.'

    if Match.objects.filter(tournament=tournament, round__round_type=GROUP_ROUND_TYPE).exists():
        return 0, 'Group fixtures already generated.'

    field = _participant_field(tournament)
    scheduler = FixtureScheduler(
        _parse_start(options.get('start_date'), options.get('start_time')),
        interval_minutes=options.get('interval_minutes', DEFAULT_INTERVAL_MINUTES),
        match_days=options.get('match_days'),
        per_day=options.get('per_day', DEFAULT_PER_DAY),
    )
    venue = (options.get('venue') or '')[:120]
    double_round = bool(options.get('double_round'))
    created = 0

    with transaction.atomic():
        for group in groups:
            # One round per group keeps group membership recoverable from the
            # match's round, with no schema change.
            round_row, _ = TournamentRound.objects.get_or_create(
                tournament=tournament,
                round_number=group.group_number,
                defaults={'name': f'Group {group.name}', 'round_type': GROUP_ROUND_TYPE},
            )

            members = [
                m.participant
                for m in group.members.select_related('participant__user', 'participant__team')
            ]
            pairs = [
                (members[i], members[j])
                for i in range(len(members))
                for j in range(i + 1, len(members))
            ]
            if double_round:
                pairs += [(away, home) for home, away in pairs]

            for home, away in pairs:
                Match.objects.create(
                    league=tournament.league,
                    tournament=tournament,
                    round=round_row,
                    scheduled_at=scheduler.next(),
                    venue=venue,
                    status='SCHEDULED',
                    **_side(field, 'home', home),
                    **_side(field, 'away', away),
                )
                created += 1

    tournament.status = 'READY'
    tournament.save(update_fields=['status', 'updated_at'])
    return created, f'Generated {created} group fixtures across {len(groups)} groups.'


def _group_table_rows(tournament, group, field):
    """Standings rows for one group, from that group's VERIFIED matches."""
    members = list(
        group.members.select_related('participant__user', 'participant__team')
    )
    rows = {}
    for member in members:
        participant = member.participant
        obj = getattr(participant, field)
        if obj is None:
            continue
        rows[obj.id] = {
            'participant': participant,
            'played': 0, 'wins': 0, 'draws': 0, 'losses': 0,
            'goals_for': 0, 'goals_against': 0,
        }

    matches = Match.objects.filter(
        tournament=tournament,
        round__round_type=GROUP_ROUND_TYPE,
        # Group rounds are numbered after their group, so the round number is
        # the group number. That keeps group membership on the existing schema.
        round__round_number=group.group_number,
        status='VERIFIED',
        home_score__isnull=False,
        away_score__isnull=False,
    )

    for match in matches:
        home = getattr(match, f'home_{field}')
        away = getattr(match, f'away_{field}')
        if home is None or away is None:
            continue
        if home.id not in rows or away.id not in rows:
            continue

        home_row, away_row = rows[home.id], rows[away.id]
        home_row['played'] += 1
        away_row['played'] += 1
        home_row['goals_for'] += match.home_score
        home_row['goals_against'] += match.away_score
        away_row['goals_for'] += match.away_score
        away_row['goals_against'] += match.home_score

        if match.home_score > match.away_score:
            home_row['wins'] += 1
            away_row['losses'] += 1
        elif match.away_score > match.home_score:
            away_row['wins'] += 1
            home_row['losses'] += 1
        else:
            home_row['draws'] += 1
            away_row['draws'] += 1

    ordered = []
    for row in rows.values():
        row['goal_difference'] = row['goals_for'] - row['goals_against']
        row['points'] = row['wins'] * 3 + row['draws']
        ordered.append(row)

    # Points, then goal difference, then goals scored — the standard tiebreak.
    ordered.sort(key=lambda r: (-r['points'], -r['goal_difference'], -r['goals_for']))
    for index, row in enumerate(ordered):
        row['rank'] = index + 1
    return ordered


def group_standings(tournament):
    """Ordered ``{group: [row, ...]}`` for every group in the tournament."""
    field = _participant_field(tournament)
    return {
        group: _group_table_rows(tournament, group, field)
        for group in tournament.groups.all()
    }


def advance_group_winners(tournament, per_group=DEFAULT_PER_GROUP_QUALIFIERS):
    """Promote the top ``per_group`` finishers of each group into a knockout round.

    Qualifiers cross over between neighbouring groups (A1 vs B2, B1 vs A2, …) so
    teams that already met in the group stage do not meet again immediately.
    """
    groups = list(tournament.groups.order_by('group_number'))
    if len(groups) < 2:
        return 0, 'At least 2 groups are required to advance into a knockout.'

    standings = group_standings(tournament)
    field = _participant_field(tournament)

    qualifiers = []
    for group in groups:
        rows = standings.get(group, [])
        if len(rows) < per_group:
            return 0, (
                f'Group {group.name} has only {len(rows)} participant(s); '
                f'{per_group} are needed per group to advance.'
            )
        qualifiers.append([row['participant'] for row in rows[:per_group]])

    # Cross-over pairing between adjacent groups.
    pairing = []
    for i in range(0, len(groups) - 1, 2):
        left, right = qualifiers[i], qualifiers[i + 1]
        for k in range(per_group):
            pairing.append((left[k], right[per_group - 1 - k]))
    if len(groups) % 2 == 1:
        # An unpaired final group: its qualifiers meet each other.
        rest = qualifiers[-1]
        for k in range(0, len(rest) - 1, 2):
            pairing.append((rest[k], rest[k + 1]))

    if not pairing:
        return 0, 'No qualifiers to pair.'

    next_number = (
        TournamentRound.objects.filter(tournament=tournament)
        .order_by('-round_number')
        .values_list('round_number', flat=True)
        .first() or 0
    ) + 1

    with transaction.atomic():
        round_row = TournamentRound.objects.create(
            tournament=tournament,
            round_number=next_number,
            name=_round_name_for_match_count(len(pairing)),
            round_type='KNOCKOUT',
            is_current=True,
        )
        TournamentRound.objects.filter(tournament=tournament, is_current=True) \
            .exclude(id=round_row.id).update(is_current=False)

        for home, away in pairing:
            Match.objects.create(
                league=tournament.league,
                tournament=tournament,
                round=round_row,
                status='SCHEDULED',
                **_side(field, 'home', home),
                **_side(field, 'away', away),
            )

        # Everyone who qualified is still live; everyone else is out.
        qualified_ids = {p.id for pair in pairing for p in pair}
        tournament.participants.exclude(id__in=qualified_ids) \
            .exclude(status='WITHDRAWN').update(status='ELIMINATED')
        tournament.participants.filter(id__in=qualified_ids).update(status='ACTIVE')

    tournament.status = 'IN_PROGRESS'
    tournament.save(update_fields=['status', 'updated_at'])
    return len(pairing), f'Advanced {len(pairing) * 2} qualifiers into {round_row.name}.'


# ── Dashboard aggregates ────────────────────────────────────────────────────

def tournament_dashboard(tournament):
    """Aggregate counts and leaders for a single tournament.

    All numbers come from the database; empty tournaments return zeros and
    nulls rather than fabricated defaults.
    """
    from django.db.models import Count, Sum, Q
    from statistics.models import PlayerLeagueStatistics
    from matches.models import MatchEvent

    participants = tournament.participants.all()
    participant_counts = {
        'total': participants.count(),
        'registered': participants.filter(status='REGISTERED').count(),
        'confirmed': participants.filter(status='CONFIRMED').count(),
        'active': participants.filter(status='ACTIVE').count(),
        'eliminated': participants.filter(status='ELIMINATED').count(),
        'withdrawn': participants.filter(status='WITHDRAWN').count(),
    }

    matches = tournament.matches.all()
    total_matches = matches.count()
    verified_matches = matches.filter(status='VERIFIED').count()

    status_breakdown = {
        s: matches.filter(status=s).count()
        for s in [
            'SCHEDULED', 'AWAITING_RESULT', 'EVIDENCE_SUBMITTED',
            'AI_PROCESSING', 'ADMIN_REVIEW', 'VERIFIED', 'REJECTED',
            'DISPUTED', 'CANCELLED',
        ]
    }

    scored = matches.filter(status='VERIFIED').exclude(home_score=None, away_score=None)
    total_goals = scored.aggregate(
        total=Sum('home_score') + Sum('away_score')
    )['total'] or 0
    avg_goals = round(total_goals / verified_matches, 2) if verified_matches else 0.0

    # Top scorer from match events (goals only)
    top_event_scorer = None
    goal_events = MatchEvent.objects.filter(
        match__tournament=tournament, event_type='GOAL'
    ).values('player').annotate(goals=Count('id')).order_by('-goals').first()
    if goal_events:
        from django.contrib.auth import get_user_model
        User = get_user_model()
        player = User.objects.filter(id=goal_events['player']).first()
        if player:
            top_event_scorer = {
                'id': player.id,
                'username': player.username,
                'goals': goal_events['goals'],
            }

    # Fallback top scorer from league statistics (less precise but works
    # when match events have not been populated).
    top_stats_scorer = None
    stats_qs = PlayerLeagueStatistics.objects.filter(
        league=tournament.league
    ).select_related('user').order_by('-goals_scored').first()
    if stats_qs:
        top_stats_scorer = {
            'id': stats_qs.user.id,
            'username': stats_qs.user.username,
            'goals': stats_qs.goals_scored,
        }

    recent_matches = list(
        matches.select_related('home_user', 'away_user', 'home_team', 'away_team', 'round')
        .order_by('-updated_at')[:6]
    )

    return {
        'tournament': {
            'id': tournament.id,
            'name': tournament.name,
            'status': tournament.status,
            'format': tournament.format,
            'is_team_based': tournament.is_team_based,
        },
        'participants': participant_counts,
        'matches': {
            'total': total_matches,
            'verified': verified_matches,
            'remaining': total_matches - verified_matches,
            'status_breakdown': status_breakdown,
        },
        'performance': {
            'total_goals': total_goals,
            'avg_goals_per_match': avg_goals,
            'progress_percent': round(verified_matches * 100.0 / total_matches, 1)
                if total_matches else 0.0,
        },
        'leaders': {
            'top_scorer': top_event_scorer or top_stats_scorer,
        },
        'recent_matches': [
            {
                'id': m.id,
                'home_display': m.home_display,
                'away_display': m.away_display,
                'home_score': m.home_score,
                'away_score': m.away_score,
                'status': m.status,
                'round_name': m.round.name if m.round_id else None,
                'scheduled_at': m.scheduled_at.isoformat() if m.scheduled_at else None,
            }
            for m in recent_matches
        ],
    }

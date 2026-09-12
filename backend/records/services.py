"""League records, computed from verified matches.

A record is only ever set by data that survived verification: verified matches
and the statistics derived from them. Nothing here invents a value — when a
league has no qualifying data for a record type, no row is written at all, so
the Records screen shows an empty state rather than a zero placeholder.

Participant kind
----------------
A record holder is either a user or a team. A league is treated as team-based
when it has any team statistics, and user-based otherwise. A league running
both concurrently is out of scope: the single-current-holder constraint means
only one of the two could be represented per record type anyway.
"""

from decimal import Decimal

from django.db import transaction

from matches.models import Match
from ratings.models import PlayerLeagueRating
from statistics.models import PlayerLeagueStatistics
from teams.models import TeamStatistics

from .models import LeagueRecord

# A win rate is meaningless over a handful of games, so require a real sample.
MIN_MATCHES_FOR_WIN_RATE = 5


class _Candidate:
    """A record value that may or may not beat the incumbent."""

    __slots__ = ('record_type', 'value', 'user', 'team', 'match', 'metadata')

    def __init__(self, record_type, value, user=None, team=None, match=None, metadata=None):
        self.record_type = record_type
        self.value = Decimal(str(value))
        self.user = user
        self.team = team
        self.match = match
        self.metadata = metadata or {}


def league_is_team_based(league):
    """True when this league's records should be attributed to teams."""
    return TeamStatistics.objects.filter(team__league=league).exists()


def recompute_league_records(league):
    """Rebuild every current record for ``league``.

    Idempotent: running it twice leaves the same single current holder per type.
    Superseded holders are kept with ``is_current = False`` so the history of a
    record is preserved.
    """
    team_based = league_is_team_based(league)
    candidates = _collect_candidates(league, team_based)

    with transaction.atomic():
        for candidate in candidates:
            _apply(league, candidate)

        # A record type that no longer has any qualifying data must not keep a
        # stale holder — otherwise a withdrawn team would still hold a title.
        live_types = {c.record_type for c in candidates}
        LeagueRecord.objects.filter(
            league=league, is_current=True
        ).exclude(record_type__in=live_types).update(is_current=False)

    return LeagueRecord.objects.filter(league=league, is_current=True).select_related(
        'user', 'team', 'match'
    )


def _collect_candidates(league, team_based):
    if team_based:
        return _team_candidates(league)
    return _user_candidates(league)


# ── team-based records ───────────────────────────────────────────────────────

def _team_candidates(league):
    stats = list(TeamStatistics.objects.filter(team__league=league, team__is_active=True))
    candidates = []

    if stats:
        best = max(stats, key=lambda s: s.goals_scored)
        if best.goals_scored > 0:
            candidates.append(_Candidate(
                'MOST_GOALS', best.goals_scored, team=best.team,
                metadata={'matches_played': best.matches_played},
            ))

        best = max(stats, key=lambda s: s.wins)
        if best.wins > 0:
            candidates.append(_Candidate(
                'MOST_WINS', best.wins, team=best.team,
                metadata={'matches_played': best.matches_played},
            ))

        qualified = [s for s in stats if s.matches_played >= MIN_MATCHES_FOR_WIN_RATE]
        if qualified:
            best = max(qualified, key=lambda s: s.win_rate)
            candidates.append(_Candidate(
                'BEST_WIN_RATE', best.win_rate, team=best.team,
                metadata={'matches_played': best.matches_played, 'wins': best.wins},
            ))

        best = max(stats, key=lambda s: s.clean_sheets)
        if best.clean_sheets > 0:
            candidates.append(_Candidate(
                'MOST_CLEAN_SHEETS', best.clean_sheets, team=best.team,
            ))

        best = max(stats, key=lambda s: s.best_win_streak)
        if best.best_win_streak > 0:
            candidates.append(_Candidate(
                'LONGEST_WIN_STREAK', best.best_win_streak, team=best.team,
            ))

    candidates.extend(_match_candidates(league, team_based=True))
    return candidates


# ── user-based records ───────────────────────────────────────────────────────

def _user_candidates(league):
    stats = list(PlayerLeagueStatistics.objects.filter(league=league))
    candidates = []

    if stats:
        best = max(stats, key=lambda s: s.goals_scored)
        if best.goals_scored > 0:
            candidates.append(_Candidate(
                'MOST_GOALS', best.goals_scored, user=best.user,
                metadata={'matches_played': best.matches_played},
            ))

        best = max(stats, key=lambda s: s.wins)
        if best.wins > 0:
            candidates.append(_Candidate(
                'MOST_WINS', best.wins, user=best.user,
                metadata={'matches_played': best.matches_played},
            ))

        qualified = [s for s in stats if s.matches_played >= MIN_MATCHES_FOR_WIN_RATE]
        if qualified:
            best = max(qualified, key=lambda s: s.win_rate)
            candidates.append(_Candidate(
                'BEST_WIN_RATE', best.win_rate, user=best.user,
                metadata={'matches_played': best.matches_played, 'wins': best.wins},
            ))

        best = max(stats, key=lambda s: s.clean_sheets)
        if best.clean_sheets > 0:
            candidates.append(_Candidate(
                'MOST_CLEAN_SHEETS', best.clean_sheets, user=best.user,
            ))

        best = max(stats, key=lambda s: s.best_win_streak)
        if best.best_win_streak > 0:
            candidates.append(_Candidate(
                'LONGEST_WIN_STREAK', best.best_win_streak, user=best.user,
            ))

    ratings = list(PlayerLeagueRating.objects.filter(league=league))
    if ratings:
        best = max(ratings, key=lambda r: r.rating)
        candidates.append(_Candidate(
            'HIGHEST_RATING', best.rating, user=best.user,
            metadata={'matches_rated': best.matches_rated},
        ))

    candidates.extend(_match_candidates(league, team_based=False))
    return candidates


# ── records that come straight off a match ───────────────────────────────────

def _match_candidates(league, team_based):
    """Biggest margin and highest-scoring match, from verified matches only.

    A match only counts once it is VERIFIED and both scores are present.
    """
    played = Match.objects.filter(
        league=league, status='VERIFIED',
        home_score__isnull=False, away_score__isnull=False,
    ).select_related('home_user', 'away_user', 'home_team', 'away_team')

    candidates = []
    biggest = None
    highest = None

    for match in played:
        margin = abs(match.home_score - match.away_score)
        total = match.home_score + match.away_score

        if margin > 0 and (biggest is None or margin > biggest[0]):
            biggest = (margin, match)
        if highest is None or total > highest[0]:
            highest = (total, match)

    if biggest:
        margin, match = biggest
        winner_user, winner_team = _winner_of(match)
        candidates.append(_Candidate(
            'BIGGEST_WINNING_MARGIN', margin,
            user=winner_user, team=winner_team, match=match,
            metadata={
                'score': f'{match.home_score}-{match.away_score}',
                'home': match.home_display,
                'away': match.away_display,
            },
        ))

    if highest and highest[0] > 0:
        total, match = highest
        candidates.append(_Candidate(
            'MOST_GOALS_IN_MATCH', total, match=match,
            user=match.home_user, team=match.home_team,
            metadata={
                'score': f'{match.home_score}-{match.away_score}',
                'home': match.home_display,
                'away': match.away_display,
            },
        ))

    return candidates


def _winner_of(match):
    """(user, team) of the winning side. Draws never reach here."""
    home_won = match.home_score > match.away_score
    if home_won:
        return match.home_user, match.home_team
    return match.away_user, match.away_team


# ── persistence ──────────────────────────────────────────────────────────────

def _apply(league, candidate):
    """Make ``candidate`` the current holder if it beats the incumbent."""
    current = LeagueRecord.objects.filter(
        league=league, record_type=candidate.record_type, is_current=True
    ).first()

    if current is not None and current.value >= candidate.value:
        return

    with transaction.atomic():
        if current is not None:
            # Keep the superseded holder as history rather than deleting it.
            current.is_current = False
            current.save(update_fields=['is_current'])

        LeagueRecord.objects.create(
            league=league,
            record_type=candidate.record_type,
            user=candidate.user,
            team=candidate.team,
            value=candidate.value,
            match=candidate.match,
            is_current=True,
            metadata=candidate.metadata,
        )

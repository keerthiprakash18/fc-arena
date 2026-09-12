"""Automatic award computation.

Awards previously existed only as manual assignments, even though the model
carried an ``AUTO`` source. This service derives the standard honours from data
that survived verification, and is safe to re-run.

Organizer overrides are respected: only awards whose ``source`` is ``AUTO`` are
replaced. A manually assigned or overridden award for the same slot survives a
recompute untouched, so an organizer's decision is never silently undone.
"""

from django.db import transaction

from ratings.models import PlayerLeagueRating
from statistics.models import PlayerLeagueStatistics
from teams.models import TeamStatistics

from .models import Award

# A win rate over a couple of games is noise, so require a real sample.
MIN_MATCHES_FOR_RATE_AWARDS = 5

# Every award type this service is allowed to create or replace.
AUTO_AWARD_TYPES = [
    'GOLDEN_BOOT',
    'GOLDEN_BALL',
    'BEST_DEFENDER',
    'PLAYER_OF_SEASON',
    'FAIR_PLAY',
    'LEAGUE_CHAMPION',
    'TOURNAMENT_CHAMPION',
    'RUNNER_UP',
]


def _is_team_based(league):
    return TeamStatistics.objects.filter(team__league=league).exists()


def compute_awards(league, season=None, tournament=None, awarded_by=None):
    """Rebuild the automatic awards for a league, season or tournament.

    Returns the list of awards now in place. A category with no qualifying data
    produces no award at all — an empty cabinet is shown as empty rather than
    filled with a placeholder winner.

    A category already held by a MANUAL or OVERRIDE award is left alone: the
    organizer's pick wins, and the automatic pass does not add a second award
    alongside it.
    """
    team_based = _is_team_based(league)

    with transaction.atomic():
        # Types an organizer has already decided. These are off-limits.
        reserved = set(
            Award.objects.filter(
                league=league, season=season, tournament=tournament,
            ).exclude(source='AUTO').values_list('award_type', flat=True)
        )

        # Drop only what we own, then rebuild.
        Award.objects.filter(
            league=league, season=season, tournament=tournament,
            source='AUTO', award_type__in=AUTO_AWARD_TYPES,
        ).delete()

        if tournament is not None:
            candidates = _tournament_awards(league, season, tournament, team_based, awarded_by)
        else:
            candidates = _league_awards(league, season, team_based, awarded_by)

        created = [
            award for award in candidates
            if award.award_type not in reserved
        ]
        for award in created:
            award.save()

    return created


# ── league / season honours ──────────────────────────────────────────────────

def _league_awards(league, season, team_based, awarded_by):
    if team_based:
        rows = list(TeamStatistics.objects.filter(
            team__league=league, team__is_active=True
        ).select_related('team'))
        return _from_team_rows(league, season, rows, awarded_by)

    rows = list(PlayerLeagueStatistics.objects.filter(league=league).select_related('user'))
    if season is not None:
        rows = [r for r in rows if r.season_id == season.id]
    return _from_user_rows(league, season, rows, awarded_by)


def _from_team_rows(league, season, rows, awarded_by):
    if not rows:
        return []

    awards = []

    best = max(rows, key=lambda r: r.goals_scored)
    if best.goals_scored > 0:
        awards.append(_award(league, season, None, 'GOLDEN_BOOT', team=best.team,
                             awarded_by=awarded_by,
                             description=f'{best.goals_scored} goals scored'))

    best = max(rows, key=lambda r: (r.points, r.goal_difference))
    if best.matches_played > 0:
        awards.append(_award(league, season, None, 'LEAGUE_CHAMPION', team=best.team,
                             awarded_by=awarded_by,
                             description=f'{best.points} points from {best.matches_played} matches'))

    qualified = [r for r in rows if r.matches_played >= MIN_MATCHES_FOR_RATE_AWARDS]
    if qualified:
        best = max(qualified, key=lambda r: r.win_rate)
        awards.append(_award(league, season, None, 'PLAYER_OF_SEASON', team=best.team,
                             awarded_by=awarded_by,
                             description=f'{best.win_rate:.1f}% win rate'))

        # Fewest defeats is the closest honest analogue of fair play we can
        # derive — there is no card or foul data in the model.
        fairest = min(qualified, key=lambda r: (r.losses, r.matches_played))
        awards.append(_award(league, season, None, 'FAIR_PLAY', team=fairest.team,
                             awarded_by=awarded_by,
                             description=f'only {fairest.losses} defeat(s) in {fairest.matches_played} matches'))

    best = max(rows, key=lambda r: r.clean_sheets)
    if best.clean_sheets > 0:
        awards.append(_award(league, season, None, 'BEST_DEFENDER', team=best.team,
                             awarded_by=awarded_by,
                             description=f'{best.clean_sheets} clean sheet(s)'))

    return awards


def _from_user_rows(league, season, rows, awarded_by):
    if not rows:
        return []

    awards = []

    best = max(rows, key=lambda r: r.goals_scored)
    if best.goals_scored > 0:
        awards.append(_award(league, season, None, 'GOLDEN_BOOT', user=best.user,
                             awarded_by=awarded_by,
                             description=f'{best.goals_scored} goals scored'))

    best = max(rows, key=lambda r: (r.points, r.goal_difference))
    if best.matches_played > 0:
        awards.append(_award(league, season, None, 'LEAGUE_CHAMPION', user=best.user,
                             awarded_by=awarded_by,
                             description=f'{best.points} points from {best.matches_played} matches'))

    qualified = [r for r in rows if r.matches_played >= MIN_MATCHES_FOR_RATE_AWARDS]
    if qualified:
        best = max(qualified, key=lambda r: r.win_rate)
        awards.append(_award(league, season, None, 'PLAYER_OF_SEASON', user=best.user,
                             awarded_by=awarded_by,
                             description=f'{best.win_rate:.1f}% win rate'))

        fairest = min(qualified, key=lambda r: (r.losses, r.matches_played))
        awards.append(_award(league, season, None, 'FAIR_PLAY', user=fairest.user,
                             awarded_by=awarded_by,
                             description=f'only {fairest.losses} defeat(s) in {fairest.matches_played} matches'))

    best = max(rows, key=lambda r: r.clean_sheets)
    if best.clean_sheets > 0:
        awards.append(_award(league, season, None, 'BEST_DEFENDER', user=best.user,
                             awarded_by=awarded_by,
                             description=f'{best.clean_sheets} clean sheet(s)'))

    # Golden Ball is a rating honour, which only exists for user-based leagues.
    ratings = list(PlayerLeagueRating.objects.filter(league=league).select_related('user'))
    if ratings:
        best = max(ratings, key=lambda r: r.rating)
        awards.append(_award(league, season, None, 'GOLDEN_BALL', user=best.user,
                             awarded_by=awarded_by,
                             description=f'rating {best.rating}'))

    return awards


# ── tournament honours ───────────────────────────────────────────────────────

def _tournament_awards(league, season, tournament, team_based, awarded_by):
    """Champion and runner-up, read off the tournament's final.

    Only decided once the final is VERIFIED — an unfinished tournament has no
    champion, and inventing one would be exactly the kind of fake data the
    platform must not produce.
    """
    from matches.models import Match

    final = (
        Match.objects.filter(tournament=tournament, status='VERIFIED')
        .exclude(home_score=None).exclude(away_score=None)
        .order_by('-round__round_number')
        .first()
    )
    if final is None:
        return []

    # A draw in a final leaves no champion, so record nothing rather than
    # guessing from the seeding.
    if final.home_score == final.away_score:
        return []

    if final.home_score > final.away_score:
        winner_user, winner_team = final.home_user, final.home_team
        loser_user, loser_team = final.away_user, final.away_team
    else:
        winner_user, winner_team = final.away_user, final.away_team
        loser_user, loser_team = final.home_user, final.home_team

    awards = [
        _award(league, season, tournament, 'TOURNAMENT_CHAMPION',
               user=winner_user, team=winner_team, awarded_by=awarded_by,
               description=f'won the final {max(final.home_score, final.away_score)}'
                           f'-{min(final.home_score, final.away_score)}'),
    ]
    if loser_user or loser_team:
        awards.append(
            _award(league, season, tournament, 'RUNNER_UP',
                   user=loser_user, team=loser_team, awarded_by=awarded_by,
                   description='reached the final'),
        )
    return awards


def _award(league, season, tournament, award_type, user=None, team=None,
           awarded_by=None, description=''):
    """Build (but do not save) an automatic award.

    Saving is left to ``compute_awards`` so it can drop any category an
    organizer has already decided before writing anything.
    """
    return Award(
        league=league,
        season=season,
        tournament=tournament,
        award_type=award_type,
        user=user,
        team=team,
        source='AUTO',
        description=description,
        awarded_by=awarded_by,
    )

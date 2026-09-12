"""Team statistics, derived from VERIFIED matches.

Deliberately mirrors ``statistics.services`` (the user-based pipeline) so both
layers read the same way and are easy to reason about together.

Key difference: this service is *recomputing* rather than incremental. Team
matches are far rarer than player matches and a full rebuild is cheap, so we
trade a little CPU for the guarantee that the numbers can never drift out of
sync with the match table.
"""

from django.db import transaction
from django.db.models import Q

from matches.models import Match

from .models import Team, TeamStatistics

FORM_LENGTH = 5


def team_matches(team):
    """Verified matches this team played, oldest first (chronological)."""
    return (
        Match.objects.filter(status='VERIFIED')
        .filter(Q(home_team=team) | Q(away_team=team))
        .order_by('played_at', 'scheduled_at', 'id')
    )


def _outcome(team, match):
    """Return (goals_for, goals_against), or None if the score is incomplete."""
    if match.home_score is None or match.away_score is None:
        return None
    if match.home_team_id == team.id:
        return match.home_score, match.away_score
    return match.away_score, match.home_score


@transaction.atomic
def recompute_team_statistics(team):
    """Rebuild one team's record from scratch. Idempotent by construction."""
    played = wins = draws = losses = 0
    goals_for = goals_against = clean_sheets = 0
    results = []
    current_streak = best_streak = 0

    for match in team_matches(team):
        outcome = _outcome(team, match)
        if outcome is None:
            continue
        scored, conceded = outcome
        played += 1
        goals_for += scored
        goals_against += conceded
        if conceded == 0:
            clean_sheets += 1

        if scored > conceded:
            wins += 1
            results.append('W')
            current_streak += 1
            best_streak = max(best_streak, current_streak)
        elif scored == conceded:
            draws += 1
            results.append('D')
            current_streak = 0
        else:
            losses += 1
            results.append('L')
            current_streak = 0

    stats, _ = TeamStatistics.objects.get_or_create(team=team)
    stats.matches_played = played
    stats.wins = wins
    stats.draws = draws
    stats.losses = losses
    stats.goals_scored = goals_for
    stats.goals_conceded = goals_against
    stats.clean_sheets = clean_sheets
    stats.points = wins * 3 + draws
    stats.form = list(reversed(results))[:FORM_LENGTH]  # most recent first
    stats.current_win_streak = current_streak
    stats.best_win_streak = best_streak
    stats.save()
    return stats


def recompute_teams_for_match(match):
    """Refresh both sides of a team match. Called from the verification pipeline."""
    touched = []
    for team in (match.home_team, match.away_team):
        if team is not None:
            touched.append(recompute_team_statistics(team))
    return touched


def recompute_league_team_statistics(league):
    """Rebuild every active team in a league. Returns how many were processed."""
    count = 0
    for team in Team.objects.filter(league=league, is_active=True):
        recompute_team_statistics(team)
        count += 1
    return count


def team_standings(league):
    """Teams ranked by points, then goal difference, then goals scored.

    Mirrors ``statistics.services._recompute_ranks`` ordering so the two
    standings tables agree on tie-breaks.
    """
    rows = []
    for team in Team.objects.filter(league=league, is_active=True).order_by('name'):
        rows.append((team, getattr(team, 'statistics', None)))

    def sort_key(row):
        team, stats = row
        return (
            -(stats.points if stats else 0),
            -(stats.goal_difference if stats else 0),
            -(stats.goals_scored if stats else 0),
            team.name,
        )

    rows.sort(key=sort_key)
    return [
        {'rank': idx, 'team': team, 'statistics': stats}
        for idx, (team, stats) in enumerate(rows, start=1)
    ]

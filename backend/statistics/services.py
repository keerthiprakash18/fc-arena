from decimal import Decimal
from django.db import transaction
from django.db.models import F
from matches.models import Match
from .models import PlayerLeagueStatistics, LeagueStanding
from ratings.models import PlayerLeagueRating, RatingHistory


def process_verified_match(match):
    if match.is_idempotent_processed:
        return
    if match.status != 'VERIFIED':
        return
    if match.home_score is None or match.away_score is None:
        return

    with transaction.atomic():
        _update_statistics(match)
        _update_ratings(match)
        _update_standings(match)
        match.is_idempotent_processed = True
        match.save(update_fields=['is_idempotent_processed'])
        _recompute_ranks(match.league, match.tournament.season if match.tournament and hasattr(match.tournament, 'season') else None)


def _update_statistics(match):
    league = match.league
    season = match.tournament.season if match.tournament and hasattr(match.tournament, 'season') else None

    for user, is_home in [(match.home_user, True), (match.away_user, False)]:
        stats, _ = PlayerLeagueStatistics.objects.get_or_create(
            league=league, user=user, season=season
        )

        stats.matches_played = F('matches_played') + 1

        if is_home:
            scored = match.home_score
            conceded = match.away_score
        else:
            scored = match.away_score
            conceded = match.home_score

        stats.goals_scored = F('goals_scored') + scored
        stats.goals_conceded = F('goals_conceded') + conceded

        prev_streak = stats.current_win_streak or 0
        if scored > conceded:
            stats.wins = F('wins') + 1
            new_streak = prev_streak + 1
            stats.current_win_streak = new_streak
            stats.best_win_streak = max(stats.best_win_streak or 0, new_streak)
        elif scored == conceded:
            stats.draws = F('draws') + 1
            stats.current_win_streak = 0
        else:
            stats.losses = F('losses') + 1
            stats.current_win_streak = 0

        if conceded == 0:
            stats.clean_sheets = F('clean_sheets') + 1

        stats.save()
        stats.refresh_from_db()


def _update_ratings(match):
    league = match.league
    K = 32

    home_rating_obj, _ = PlayerLeagueRating.objects.get_or_create(
        league=league, user=match.home_user, defaults={'rating': 1000}
    )
    away_rating_obj, _ = PlayerLeagueRating.objects.get_or_create(
        league=league, user=match.away_user, defaults={'rating': 1000}
    )

    home_old = home_rating_obj.rating
    away_old = away_rating_obj.rating

    home_expected = _expected_score(home_old, away_old)
    away_expected = _expected_score(away_old, home_old)

    if match.home_score > match.away_score:
        home_actual = Decimal('1')
        away_actual = Decimal('0')
        result = 'WIN'
        away_result = 'LOSS'
    elif match.home_score < match.away_score:
        home_actual = Decimal('0')
        away_actual = Decimal('1')
        result = 'LOSS'
        away_result = 'WIN'
    else:
        home_actual = Decimal('0.5')
        away_actual = Decimal('0.5')
        result = 'DRAW'
        away_result = 'DRAW'

    home_new = home_old + K * (home_actual - home_expected)
    away_new = away_old + K * (away_actual - away_expected)

    home_rating_obj.rating = home_new
    home_rating_obj.peak_rating = max(home_rating_obj.peak_rating, home_new)
    home_rating_obj.matches_rated = F('matches_rated') + 1
    home_rating_obj.save()
    home_rating_obj.refresh_from_db()

    away_rating_obj.rating = away_new
    away_rating_obj.peak_rating = max(away_rating_obj.peak_rating, away_new)
    away_rating_obj.matches_rated = F('matches_rated') + 1
    away_rating_obj.save()
    away_rating_obj.refresh_from_db()

    RatingHistory.objects.create(
        league=league, user=match.home_user, match=match,
        old_rating=home_old, new_rating=home_new,
        rating_change=home_new - home_old,
        opponent_rating=away_old, result=result
    )
    RatingHistory.objects.create(
        league=league, user=match.away_user, match=match,
        old_rating=away_old, new_rating=away_new,
        rating_change=away_new - away_old,
        opponent_rating=home_old, result=away_result
    )


def _expected_score(rating_a, rating_b):
    return Decimal(1) / (Decimal(1) + Decimal(10) ** ((rating_b - rating_a) / Decimal(400)))


def _update_standings(match):
    league = match.league
    season = match.tournament.season if match.tournament and hasattr(match.tournament, 'season') else None

    for user, is_home in [(match.home_user, True), (match.away_user, False)]:
        standing, _ = LeagueStanding.objects.get_or_create(
            league=league, user=user, season=season
        )

        standing.matches_played = F('matches_played') + 1

        if is_home:
            scored = match.home_score
            conceded = match.away_score
        else:
            scored = match.away_score
            conceded = match.home_score

        standing.goals_for = F('goals_for') + scored
        standing.goals_against = F('goals_against') + conceded
        standing.goal_difference = F('goal_difference') + (scored - conceded)

        if scored > conceded:
            standing.wins = F('wins') + 1
            standing.points = F('points') + 3
        elif scored == conceded:
            standing.draws = F('draws') + 1
            standing.points = F('points') + 1
        else:
            standing.losses = F('losses') + 1

        standing.save()


def _recompute_ranks(league, season=None):
    standings = list(LeagueStanding.objects.filter(league=league, season=season))
    standings.sort(key=lambda s: (-(s.points or 0), -(s.goal_difference or 0), -(s.goals_for or 0)))
    for idx, standing in enumerate(standings, start=1):
        standing.rank = idx
        standing.save(update_fields=['rank'])


def rebuild_league_statistics(league, season=None):
    matches_qs = (Match.objects.filter(league=league, status='VERIFIED')
                  .exclude(home_score=None, away_score=None))
    if season:
        matches_qs = matches_qs.filter(tournament__season=season)

    if season:
        PlayerLeagueStatistics.objects.filter(league=league, season=season).delete()
        LeagueStanding.objects.filter(league=league, season=season).delete()
    else:
        PlayerLeagueStatistics.objects.filter(league=league).delete()
        LeagueStanding.objects.filter(league=league).delete()

    with transaction.atomic():
        for match in matches_qs.order_by('created_at'):
            match.is_idempotent_processed = False
            match.save(update_fields=['is_idempotent_processed'])
            _update_statistics(match)
            _update_standings(match)
            match.is_idempotent_processed = True
            match.save(update_fields=['is_idempotent_processed'])

        _recompute_ranks(league, season)
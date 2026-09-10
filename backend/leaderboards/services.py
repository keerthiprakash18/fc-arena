from django.db.models import Count, Sum, F, Q, Case, When, Value, DecimalField
from django.db.models.functions import Coalesce
from decimal import Decimal
from .models import Leaderboard
from statistics.models import PlayerLeagueStatistics
from ratings.models import PlayerLeagueRating


def calculate_leaderboards(league, season=None, tournament=None):
    Leaderboard.objects.filter(
        league=league, season=season, tournament=tournament
    ).delete()

    _calculate_rating(league, season, tournament)
    _calculate_wins(league, season, tournament)
    _calculate_goals(league, season, tournament)
    _calculate_win_rate(league, season, tournament)
    _calculate_goal_difference(league, season, tournament)
    _calculate_clean_sheets(league, season, tournament)


def _calculate_rating(league, season, tournament):
    entries = PlayerLeagueRating.objects.filter(league=league)
    for entry in entries:
        Leaderboard.objects.create(
            league=league, season=season, tournament=tournament,
            category='RATING', user=entry.user,
            value=entry.rating, rank=0
        )
    _assign_ranks(league, season, tournament, 'RATING')


def _calculate_wins(league, season, tournament):
    stats = PlayerLeagueStatistics.objects.filter(league=league)
    if season:
        stats = stats.filter(season=season)
    for s in stats:
        if s.wins > 0:
            Leaderboard.objects.create(
                league=league, season=season, tournament=tournament,
                category='WINS', user=s.user,
                value=s.wins, rank=0
            )
    _assign_ranks(league, season, tournament, 'WINS')


def _calculate_goals(league, season, tournament):
    stats = PlayerLeagueStatistics.objects.filter(league=league)
    if season:
        stats = stats.filter(season=season)
    for s in stats:
        if s.goals_scored > 0:
            Leaderboard.objects.create(
                league=league, season=season, tournament=tournament,
                category='GOALS', user=s.user,
                value=s.goals_scored, rank=0
            )
    _assign_ranks(league, season, tournament, 'GOALS')


def _calculate_win_rate(league, season, tournament):
    stats = PlayerLeagueStatistics.objects.filter(league=league, matches_played__gte=5)
    if season:
        stats = stats.filter(season=season)
    for s in stats:
        rate = (s.wins / s.matches_played) * 100
        Leaderboard.objects.create(
            league=league, season=season, tournament=tournament,
            category='WIN_RATE', user=s.user,
            value=Decimal(str(round(rate, 2))), rank=0
        )
    _assign_ranks(league, season, tournament, 'WIN_RATE')


def _calculate_goal_difference(league, season, tournament):
    stats = PlayerLeagueStatistics.objects.filter(league=league)
    if season:
        stats = stats.filter(season=season)
    for s in stats:
        gd = s.goals_scored - s.goals_conceded
        if gd != 0:
            Leaderboard.objects.create(
                league=league, season=season, tournament=tournament,
                category='GOAL_DIFF', user=s.user,
                value=Decimal(str(gd)), rank=0
            )
    _assign_ranks(league, season, tournament, 'GOAL_DIFF')


def _calculate_clean_sheets(league, season, tournament):
    stats = PlayerLeagueStatistics.objects.filter(league=league)
    if season:
        stats = stats.filter(season=season)
    for s in stats:
        if s.clean_sheets > 0:
            Leaderboard.objects.create(
                league=league, season=season, tournament=tournament,
                category='CLEAN_SHEETS', user=s.user,
                value=s.clean_sheets, rank=0
            )
    _assign_ranks(league, season, tournament, 'CLEAN_SHEETS')


def _assign_ranks(league, season, tournament, category):
    entries = Leaderboard.objects.filter(
        league=league, season=season, tournament=tournament,
        category=category
    ).order_by('-value')
    rank = 1
    for entry in entries:
        Leaderboard.objects.filter(pk=entry.pk).update(rank=rank)
        rank += 1
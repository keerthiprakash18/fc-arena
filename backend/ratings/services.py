from statistics.services import _update_ratings


def recalculate_all_ratings(league, season=None):
    from matches.models import Match
    from ratings.models import PlayerLeagueRating, RatingHistory

    PlayerLeagueRating.objects.filter(league=league).update(rating=1000, peak_rating=1000, matches_rated=0)
    RatingHistory.objects.filter(league=league).delete()

    matches_qs = Match.objects.filter(league=league, status='VERIFIED').select_related(
        'home_user', 'away_user'
    )
    if season:
        matches_qs = matches_qs.filter(tournament__season=season)

    for match in matches_qs.order_by('created_at'):
        _update_ratings(match)
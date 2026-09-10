from django.urls import path

from . import views

urlpatterns = [
    path('leagues/<int:league_id>/dashboard/overview/', views.LeagueOverviewView.as_view(), name='dashboard-overview'),
    path('leagues/<int:league_id>/dashboard/match-status/', views.MatchStatusDistributionView.as_view(), name='dashboard-match-status'),
    path('leagues/<int:league_id>/dashboard/rating-trends/', views.RatingTrendsView.as_view(), name='dashboard-rating-trends'),
    path('leagues/<int:league_id>/dashboard/pending-reviews/', views.PendingReviewsView.as_view(), name='dashboard-pending-reviews'),
    path('leagues/<int:league_id>/dashboard/activity/', views.RecentActivityView.as_view(), name='dashboard-activity'),
    path('leagues/<int:league_id>/dashboard/standings/', views.PlayerStandingsView.as_view(), name='dashboard-standings'),
    path('dashboard/platform/', views.PlatformOverviewView.as_view(), name='dashboard-platform'),
]
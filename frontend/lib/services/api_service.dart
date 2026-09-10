import 'dart:convert';
import 'dart:io';
import '../config/api.dart';
import '../models/user.dart';
import '../models/match.dart';
import '../models/leaderboard.dart';
import '../models/dashboard.dart';
import '../models/dispute.dart';
import '../models/season.dart';
import '../models/tournament.dart';
import '../models/award.dart';
import '../models/category.dart';

class ApiService {
  final ApiClient _client;

  ApiService(this._client);

  // ─── Auth ─────────────────────────────────────────────
  Future<User> login(String username, String password) async {
    final data = await _client.post('/auth/login/', {
      'username': username,
      'password': password,
    });
    await _client.saveTokens(data['access'], data['refresh']);
    return await getMe();
  }

  Future<User> register({
    required String username,
    required String email,
    required String password,
    String? gameUid,
    String? gameInGameName,
    String? phoneNumber,
  }) async {
    await _client.post('/auth/register/', {
      'username': username,
      'email': email,
      'password': password,
      if (gameUid != null && gameUid.isNotEmpty) 'game_uid': gameUid,
      if (gameInGameName != null && gameInGameName.isNotEmpty) 'game_in_game_name': gameInGameName,
      if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
    });
    return await login(username, password);
  }

  Future<User> getMe() async {
    final data = await _client.get('/auth/profile/');
    return User.fromJson(data);
  }

  Future<void> logout() async {
    await _client.clearTokens();
  }

  // ─── Leagues ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyLeagues() async {
    final data = await _client.getList('/leagues/');
    final results = data['results'] ?? data;
    if (results is List) return results.cast<Map<String, dynamic>>();
    return [];
  }

  // ─── Dashboard ────────────────────────────────────────
  Future<LeagueOverview> getLeagueOverview(int leagueId) async {
    final data = await _client.get('/leagues/$leagueId/dashboard/overview/');
    return LeagueOverview.fromJson(data);
  }

  Future<List<PlayerStanding>> getLeagueStandings(int leagueId, {int? seasonId}) async {
    final qs = seasonId != null ? '?season_id=$seasonId' : '';
    final data = await _client.getList('/leagues/$leagueId/standings/$qs');
    final results = data['results'] ?? data['players'] ?? data;
    if (results is List) {
      return results.map((p) => PlayerStanding.fromJson(p)).toList();
    }
    return [];
  }

  // ─── Matches ──────────────────────────────────────────
  Future<List<Match>> getLeagueMatches(int leagueId) async {
    final data = await _client.getList('/leagues/$leagueId/matches/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((m) => Match.fromJson(m)).toList();
    }
    return [];
  }

  Future<Match> getMatch(int leagueId, int matchId) async {
    final data = await _client.get('/leagues/$leagueId/matches/$matchId/');
    return Match.fromJson(data);
  }

  Future<Match> createMatch(int leagueId, {
    required int awayUserId,
    String? scheduledAt,
    int? tournamentId,
  }) async {
    final data = await _client.post('/leagues/$leagueId/matches/', {
      'home_user': await _getMyUserId(),
      'away_user': awayUserId,
      'scheduled_at': scheduledAt,
      'tournament': tournamentId,
    });
    return Match.fromJson(data);
  }

  Future<void> updateMatchStatus(int leagueId, int matchId, String status) async {
    await _client.post('/leagues/$leagueId/matches/$matchId/status/', {
      'status': status,
    });
  }

  Future<void> submitResult(int leagueId, int matchId, {
    required int homeScore,
    required int awayScore,
  }) async {
    await _client.post('/leagues/$leagueId/matches/$matchId/submit/', {
      'home_score': homeScore,
      'away_score': awayScore,
    });
  }

  // ─── Evidence ─────────────────────────────────────────
  Future<Map<String, dynamic>> uploadEvidence(int leagueId, int matchId, {
    required String filePath,
    required String fileName,
    required int fileSize,
    required String fileType,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final b64 = base64Encode(bytes);
    final data = await _client.post('/leagues/$leagueId/matches/$matchId/evidence/upload/', {
      'file_content_base64': b64,
      'file_name': fileName,
      'file_size': fileSize,
      'file_type': fileType,
    });
    return data;
  }

  Future<List<Map<String, dynamic>>> getMatchEvidences(int leagueId, int matchId) async {
    final data = await _client.getList('/leagues/$leagueId/matches/$matchId/evidence/');
    final results = data['results'] ?? data;
    if (results is List) return results.cast<Map<String, dynamic>>();
    return [];
  }

  Future<List<int>> getEvidenceFile(int leagueId, int matchId, int evidenceId) async {
    return _client.getBytes('/leagues/$leagueId/matches/$matchId/evidence/$evidenceId/file/');
  }

  // ─── Verification ────────────────────────────────────
  Future<VerificationTask> triggerVerification(int leagueId, int matchId) async {
    final data = await _client.post('/leagues/$leagueId/matches/$matchId/verify/', {});
    return VerificationTask.fromJson(data);
  }

  Future<VerificationTask> getVerificationTask(int leagueId, int matchId) async {
    final data = await _client.get('/leagues/$leagueId/matches/$matchId/verification/');
    return VerificationTask.fromJson(data);
  }

  Future<VerificationTask> adminReview(int leagueId, int matchId, {
    required bool approved,
    String notes = '',
  }) async {
    final data = await _client.post('/leagues/$leagueId/matches/$matchId/verification/review/', {
      'approved': approved,
      'notes': notes,
    });
    return VerificationTask.fromJson(data);
  }

  Future<PendingReviewsData> getPendingReviews(int leagueId) async {
    final data = await _client.get('/leagues/$leagueId/dashboard/pending-reviews/');
    final reviews = (data['verification_reviews'] as List? ?? [])
        .map((r) => AdminReviewItem.fromJson(r))
        .toList();
    final disputes = (data['open_disputes'] as List? ?? []).cast<Map<String, dynamic>>();
    return PendingReviewsData(reviews: reviews, disputes: disputes);
  }

  // ─── Leaderboard ─────────────────────────────────────
  Future<List<LeaderboardEntry>> getLeaderboard(int leagueId, {String category = 'RATING', int? seasonId}) async {
    var path = '/leagues/$leagueId/leaderboards/?category=$category';
    if (seasonId != null) path += '&season_id=$seasonId';
    final data = await _client.getList(path);
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((e) => LeaderboardEntry.fromJson(e)).toList();
    }
    return [];
  }

  // ─── Notifications ───────────────────────────────────
  Future<List<NotificationItem>> getNotifications() async {
    final data = await _client.getList('/notifications/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((n) => NotificationItem.fromJson(n)).toList();
    }
    return [];
  }

  Future<int> getUnreadNotificationCount() async {
    final data = await _client.get('/notifications/unread-count/');
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markNotificationRead(int id) async {
    await _client.post('/notifications/$id/read/', {});
  }

  Future<void> markAllNotificationsRead() async {
    await _client.post('/notifications/read-all/', {});
  }

  Future<void> deleteNotification(int id) async {
    await _client.delete('/notifications/$id/');
  }

  // ─── Disputes ────────────────────────────────────────
  Future<List<Dispute>> getDisputes(int leagueId) async {
    final data = await _client.getList('/leagues/$leagueId/disputes/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((d) => Dispute.fromJson(d)).toList();
    }
    return [];
  }

  Future<Dispute> getDispute(int leagueId, int disputeId) async {
    final data = await _client.get('/leagues/$leagueId/disputes/$disputeId/');
    return Dispute.fromJson(data);
  }

  Future<Dispute> createDispute(int leagueId, DisputeCreateData data) async {
    final response = await _client.post('/leagues/$leagueId/disputes/', {
      'match': data.matchId,
      'reason': data.reason,
      'description': data.description,
    });
    return Dispute.fromJson(response);
  }

  Future<Dispute> resolveDispute(int leagueId, int disputeId, {
    required String resolution,
    String resolutionNotes = '',
  }) async {
    final response = await _client.post('/leagues/$leagueId/disputes/$disputeId/resolve/', {
      'resolution': resolution,
      'resolution_notes': resolutionNotes,
    });
    return Dispute.fromJson(response);
  }

  Future<DisputeComment> addDisputeComment(int leagueId, int disputeId, String comment) async {
    final response = await _client.post('/leagues/$leagueId/disputes/$disputeId/comments/', {
      'comment': comment,
    });
    return DisputeComment.fromJson(response);
  }

  // ─── Seasons ─────────────────────────────────────────
  Future<List<Season>> getSeasons(int leagueId) async {
    final data = await _client.getList('/leagues/$leagueId/seasons/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((s) => Season.fromJson(s)).toList();
    }
    return [];
  }

  Future<Season> getCurrentSeason(int leagueId) async {
    final data = await _client.get('/leagues/$leagueId/seasons/current/');
    return Season.fromJson(data);
  }

  Future<Season> createSeason(int leagueId, {required String name, String description = '', String? startDate, String? endDate}) async {
    final data = await _client.post('/leagues/$leagueId/seasons/', {
      'name': name,
      'description': description,
      'start_date': ?startDate,
      'end_date': ?endDate,
    });
    return Season.fromJson(data);
  }

  Future<List<SeasonMember>> getSeasonMembers(int leagueId, int seasonId) async {
    final data = await _client.getList('/leagues/$leagueId/seasons/$seasonId/members/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((m) => SeasonMember.fromJson(m)).toList();
    }
    return [];
  }

  // ─── Tournaments ─────────────────────────────────────
  Future<List<Tournament>> getTournaments(int leagueId) async {
    final data = await _client.getList('/leagues/$leagueId/tournaments/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((t) => Tournament.fromJson(t)).toList();
    }
    return [];
  }

  Future<Tournament> getTournament(int leagueId, int tournamentId) async {
    final data = await _client.get('/leagues/$leagueId/tournaments/$tournamentId/');
    return Tournament.fromJson(data);
  }

  Future<Tournament> createTournament(int leagueId, {
    required String name,
    String description = '',
    String format = 'KNOCKOUT',
    int maxParticipants = 16,
    double entryFee = 0,
    double prizePool = 0,
    String? registrationDeadline,
    String? startDate,
    String? endDate,
  }) async {
    final data = await _client.post('/leagues/$leagueId/tournaments/', {
      'name': name,
      'description': description,
      'format': format,
      'max_participants': maxParticipants,
      'entry_fee': entryFee,
      'prize_pool': prizePool,
      '?registration_deadline': registrationDeadline,
      '?start_date': startDate,
      '?end_date': endDate,
    });
    return Tournament.fromJson(data);
  }

  Future<Tournament> updateTournamentStatus(int leagueId, int tournamentId, String newStatus) async {
    final data = await _client.post('/leagues/$leagueId/tournaments/$tournamentId/status/', {
      'status': newStatus,
    });
    return Tournament.fromJson(data);
  }

  Future<bool> registerForTournament(int leagueId, int tournamentId) async {
    await _client.post('/leagues/$leagueId/tournaments/$tournamentId/register/', {});
    return true;
  }

  Future<Map<String, dynamic>> generateTournamentFixtures(int leagueId, int tournamentId) async {
    return _client.post('/leagues/$leagueId/tournaments/$tournamentId/fixtures/', {});
  }

  Future<List<TournamentParticipant>> getTournamentParticipants(int leagueId, int tournamentId) async {
    final data = await _client.getList('/leagues/$leagueId/tournaments/$tournamentId/participants/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((p) => TournamentParticipant.fromJson(p)).toList();
    }
    return [];
  }

  Future<List<TournamentRound>> getTournamentRounds(int leagueId, int tournamentId) async {
    final data = await _client.getList('/leagues/$leagueId/tournaments/$tournamentId/rounds/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((r) => TournamentRound.fromJson(r)).toList();
    }
    return [];
  }

  // ─── Awards ──────────────────────────────────────────
  Future<List<Award>> getAwards(int leagueId, {int? seasonId, int? tournamentId}) async {
    String url = '/leagues/$leagueId/awards/';
    List<String> params = [];
    if (seasonId != null) params.add('season_id=$seasonId');
    if (tournamentId != null) params.add('tournament_id=$tournamentId');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final data = await _client.getList(url);
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((a) => Award.fromJson(a)).toList();
    }
    return [];
  }

  Future<Award> createAward(int leagueId, {
    required int? seasonId,
    required int? tournamentId,
    required String awardType,
    required int userId,
    String customName = '',
    String description = '',
  }) async {
    final data = await _client.post('/leagues/$leagueId/awards/create/', {
      'season': ?seasonId,
      'tournament': ?tournamentId,
      'award_type': awardType,
      'user': userId,
      if (customName.isNotEmpty) 'custom_name': customName,
      if (description.isNotEmpty) 'description': description,
    });
    return Award.fromJson(data);
  }

  // ─── Records ─────────────────────────────────────────
  Future<List<LeagueRecord>> getRecords(int leagueId) async {
    final data = await _client.getList('/leagues/$leagueId/records/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((r) => LeagueRecord.fromJson(r)).toList();
    }
    return [];
  }

  // ─── Ratings ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRatings(int leagueId) async {
    final data = await _client.getList('/leagues/$leagueId/ratings/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> getMyRatingDetail(int leagueId) async {
    final data = await _client.get('/leagues/$leagueId/ratings/');
    final results = data['results'] ?? data;
    if (results is List && results.isNotEmpty) {
      return results.first;
    }
    return {};
  }

  // ─── Player Statistics ───────────────────────────────
  Future<List<Map<String, dynamic>>> getPlayerStatistics(int leagueId, {int? seasonId}) async {
    final qs = seasonId != null ? '?season_id=$seasonId' : '';
    final data = await _client.getList('/leagues/$leagueId/statistics/$qs');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── Match Stats ─────────────────────────────────────
  Future<Map<String, dynamic>> getMatchStats(int leagueId, int matchId) async {
    try {
      final data = await _client.get('/leagues/$leagueId/matches/$matchId/statistics/');
      return data;
    } catch (e) {
      return {};
    }
  }

  // ─── Match Events ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMatchEvents(int leagueId, int matchId) async {
    final data = await _client.getList('/leagues/$leagueId/matches/$matchId/events/');
    final results = data['results'] ?? data;
    if (results is List) return results.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> addMatchEvent(int leagueId, int matchId, {
    required String eventType,
    required int minute,
    required int playerId,
    int? assistedById,
    String description = '',
  }) async {
    final data = await _client.post('/leagues/$leagueId/matches/$matchId/events/', {
      'event_type': eventType,
      'minute': minute,
      'player': playerId,
      'assisted_by': ?assistedById,
      'description': description,
    });
    return data;
  }

  // ─── Categories ─────────────────────────────────────
  Future<List<Category>> getCategories(int leagueId) async {
    final data = await _client.getList('/leagues/$leagueId/categories/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((c) => Category.fromJson(c)).toList();
    }
    return [];
  }

  Future<Category> createCategory(int leagueId, {
    required String name,
    String description = '',
    double minRating = 0,
    double maxRating = 99999,
    String color = '#e94560',
  }) async {
    final data = await _client.post('/leagues/$leagueId/categories/', {
      'name': name,
      'description': description,
      'min_rating': minRating,
      'max_rating': maxRating,
      'color': color,
    });
    return Category.fromJson(data);
  }

  Future<List<PlayerCategoryEntry>> getCategoryPlayers(int leagueId, int categoryId) async {
    final data = await _client.getList('/leagues/$leagueId/categories/$categoryId/players/');
    final results = data['results'] ?? data;
    if (results is List) {
      return results.map((p) => PlayerCategoryEntry.fromJson(p)).toList();
    }
    return [];
  }

  Future<void> assignCategoryPlayer(int leagueId, int categoryId, int playerId, {bool isPrimary = true}) async {
    await _client.post('/leagues/$leagueId/categories/$categoryId/assign/', {
      'player_id': playerId,
      'is_primary': isPrimary,
    });
  }

  Future<void> removeCategoryPlayer(int leagueId, int categoryId, int playerId) async {
    await _client.delete('/leagues/$leagueId/categories/$categoryId/players/$playerId/');
  }

  // ─── Head to Head ────────────────────────────────────
  Future<Map<String, dynamic>> getHeadToHead(int leagueId, int user1Id, int user2Id) async {
    final stats = await getPlayerStatistics(leagueId);
    final s1 = stats.firstWhere((s) => s['user'] == user1Id, orElse: () => {});
    final s2 = stats.firstWhere((s) => s['user'] == user2Id, orElse: () => {});
    final matches = await getLeagueMatches(leagueId);
    int user1Wins = 0, user2Wins = 0, draws = 0;
    List<Map<String, dynamic>> h2hMatches = [];
    for (var m in matches) {
      if ((m.homeUserId == user1Id && m.awayUserId == user2Id) ||
          (m.homeUserId == user2Id && m.awayUserId == user1Id)) {
        h2hMatches.add({
          'id': m.id, 'home': m.homeUsername, 'away': m.awayUsername,
          'homeScore': m.homeScore, 'awayScore': m.awayScore, 'status': m.status,
        });
        if (m.homeScore != null && m.awayScore != null) {
          final homeWon = m.homeScore! > m.awayScore!;
          if (m.homeUserId == user1Id) {
            if (homeWon) { user1Wins++; } else if (m.awayScore! > m.homeScore!) { user2Wins++; } else { draws++; }
          } else {
            if (homeWon) { user2Wins++; } else if (m.awayScore! > m.homeScore!) { user1Wins++; } else { draws++; }
          }
        }
      }
    }
    return {
      'player1': s1, 'player2': s2,
      'wins1': user1Wins, 'wins2': user2Wins, 'draws': draws,
      'matches': h2hMatches,
    };
  }

  // ─── Members ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLeagueMembers(int leagueId) async {
    final data = await _client.getList('/leagues/$leagueId/members/');
    final results = data['results'] ?? data;
    if (results is List) return results.cast<Map<String, dynamic>>();
    return [];
  }

  // ─── League Admin ────────────────────────────────────
  Future<Map<String, dynamic>> updateLeague(int leagueId, {String? name, String? description}) async {
    final data = await _client.patch('/leagues/$leagueId/',
      {'name': ?name, 'description': ?description});
    return data;
  }

  Future<List<Map<String, dynamic>>> getMyLeaguesAdmin() async {
    final data = await _client.getList('/leagues/');
    final results = data['results'] ?? data;
    if (results is List) return results.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> updateMemberRole(int leagueId, int userId, String role) async {
    final data = await _client.patch('/leagues/$leagueId/members/$userId/', {'role': role});
    return data;
  }

  Future<void> removeMember(int leagueId, int userId) async {
    await _client.delete('/leagues/$leagueId/members/$userId/');
  }

  Future<int> _getMyUserId() async {
    final user = await getMe();
    return user.id;
  }
}
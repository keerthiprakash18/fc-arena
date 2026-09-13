import '../utils/num_utils.dart';

class Category {
  final int id;
  final int leagueId;
  final String name;
  final String slug;
  final String description;
  final double minRating;
  final double maxRating;
  final bool isActive;
  final String color;
  final int playerCount;

  Category({
    required this.id,
    required this.leagueId,
    required this.name,
    required this.slug,
    required this.description,
    required this.minRating,
    required this.maxRating,
    required this.isActive,
    required this.color,
    required this.playerCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] ?? 0,
    leagueId: json['league'] ?? 0,
    name: json['name'] ?? '',
    slug: json['slug'] ?? '',
    description: json['description'] ?? '',
    // DRF serializes DecimalField as a quoted string — safeDouble handles both.
    minRating: safeDouble(json['min_rating']),
    maxRating: safeDouble(json['max_rating'], fallback: 99999),
    isActive: json['is_active'] ?? true,
    color: json['color'] ?? '#e94560',
    playerCount: json['player_count'] ?? 0,
  );
}

class PlayerCategoryEntry {
  final int id;
  final int playerId;
  final String username;
  final String categoryName;
  final bool isPrimary;

  PlayerCategoryEntry({required this.id, required this.playerId, required this.username, required this.categoryName, required this.isPrimary});

  factory PlayerCategoryEntry.fromJson(Map<String, dynamic> json) => PlayerCategoryEntry(
    id: json['id'] ?? 0,
    playerId: json['player'] ?? 0,
    username: json['username'] ?? '',
    categoryName: json['category_name'] ?? '',
    isPrimary: json['is_primary'] ?? true,
  );
}
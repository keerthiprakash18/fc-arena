class User {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? gameUid;
  final String? gameInGameName;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.gameUid,
    this.gameInGameName,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] ?? 0,
    username: json['username'] ?? '',
    email: json['email'] ?? '',
    firstName: json['first_name'],
    lastName: json['last_name'],
    gameUid: json['game_uid'],
    gameInGameName: json['game_in_game_name'],
  );

  String get displayName => gameInGameName ?? username;
}
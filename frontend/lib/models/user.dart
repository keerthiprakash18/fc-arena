class User {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? gameUid;
  final String? gameInGameName;
  final String? phoneNumber;
  final String? profilePhoto;
  final String? dateOfBirth;
  final bool isStaff;
  final bool isSuperuser;
  final String? dateJoined;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.gameUid,
    this.gameInGameName,
    this.phoneNumber,
    this.profilePhoto,
    this.dateOfBirth,
    this.isStaff = false,
    this.isSuperuser = false,
    this.dateJoined,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] ?? 0,
    username: json['username'] ?? '',
    email: json['email'] ?? '',
    firstName: json['first_name'],
    lastName: json['last_name'],
    gameUid: json['game_uid'],
    gameInGameName: json['game_in_game_name'],
    phoneNumber: json['phone_number'],
    profilePhoto: json['profile_photo'],
    dateOfBirth: json['date_of_birth'],
    isStaff: json['isStaff'] ?? json['is_staff'] ?? false,
    isSuperuser: json['isSuperuser'] ?? json['is_superuser'] ?? false,
    dateJoined: json['dateJoined'] ?? json['date_joined'],
  );

  String get displayName => gameInGameName ?? username;
}
/// Platform roles. Stored on `profiles.role`.
enum UserRole {
  player,
  organizer,
  admin;

  static UserRole fromString(String? v) => UserRole.values.firstWhere(
        (e) => e.name == v,
        orElse: () => UserRole.player,
      );

  String get label => switch (this) {
        UserRole.player => 'Player',
        UserRole.organizer => 'Organizer',
        UserRole.admin => 'Admin',
      };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.role = UserRole.player,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final String? avatarUrl;

  bool get isAdmin => role == UserRole.admin;
  bool get isOrganizer => role == UserRole.organizer || isAdmin;

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String,
        email: (m['email'] ?? '') as String,
        displayName: (m['display_name'] ?? 'Player') as String,
        role: UserRole.fromString(m['role'] as String?),
        avatarUrl: m['avatar_url'] as String?,
      );

  AppUser copyWith({String? displayName, UserRole? role, String? avatarUrl}) =>
      AppUser(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}

class UserProfileEntity {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  const UserProfileEntity({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });
}

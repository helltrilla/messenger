import '../../domain/entities/user_profile_entity.dart';

class UserProfileModel extends UserProfileEntity {
  const UserProfileModel({
    required super.id,
    required super.username,
    required super.displayName,
    super.avatarUrl,
  });

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      id: map['id'],
      username: map['username'] ?? '',
      displayName: map['display_name'] ?? map['username'] ?? 'User',
      avatarUrl: map['avatar_url'],
    );
  }
}

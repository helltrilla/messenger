import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    super.username,
    super.displayName,
    super.avatarUrl,
  });

  factory UserModel.fromSupabaseUser(User user) {
    final meta = user.userMetadata ?? {};
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      username: meta['username'],
      displayName: meta['display_name'] ?? meta['full_name'],
      avatarUrl: meta['avatar_url'],
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'] ?? '',
      username: map['username'],
      displayName: map['display_name'],
      avatarUrl: map['avatar_url'],
    );
  }
}

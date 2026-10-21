class SavedAccount {
  final String userId;
  final String email;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String refreshToken;

  const SavedAccount({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    required this.refreshToken,
  });

  SavedAccount copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? refreshToken,
  }) {
    return SavedAccount(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'username': username,
    'avatarUrl': avatarUrl,
    'refreshToken': refreshToken,
  };

  factory SavedAccount.fromMap(Map<String, dynamic> map) => SavedAccount(
    userId: map['userId'] as String? ?? '',
    email: map['email'] as String? ?? '',
    displayName: map['displayName'] as String? ?? '',
    username: map['username'] as String? ?? '',
    avatarUrl: map['avatarUrl'] as String?,
    refreshToken: map['refreshToken'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedAccount &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}

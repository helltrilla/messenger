import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../models/user_profile_model.dart';

abstract class ChatRemoteDataSource {
  Future<List<ChatModel>> fetchChats();
  Future<String> createDirectChat(String targetUserId);
  Future<List<UserProfileModel>> searchUsers(String query);
  Future<void> markChatAsRead(String chatId, String messageId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final SupabaseClient _client;

  ChatRemoteDataSourceImpl(this._client);

  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<List<ChatModel>> fetchChats() async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      final response = await _client
          .from('chats')
          .select('''
            id,
            type,
            title,
            avatar_url,
            last_message_text,
            last_message_sender_id,
            last_message_at,
            members:chat_members (
              user_id,
              unread_count,
              profile:profiles (
                id,
                username,
                display_name,
                avatar_url
              )
            )
          ''')
          .order('last_message_at', ascending: false);

      return (response as List<dynamic>)
          .map((map) => ChatModel.fromMap(map as Map<String, dynamic>, uid))
          .toList();
    } on PostgrestException catch (e) {
      if (e.message.contains('unread_count')) {
        final response = await _client
            .from('chats')
            .select('''
              id,
              type,
              title,
              avatar_url,
              last_message_text,
              last_message_sender_id,
              last_message_at,
              members:chat_members (
                user_id,
                profile:profiles (
                  id,
                  username,
                  display_name,
                  avatar_url
                )
              )
            ''')
            .order('last_message_at', ascending: false);

        return (response as List<dynamic>)
            .map((map) => ChatModel.fromMap(map as Map<String, dynamic>, uid))
            .toList();
      }
      rethrow;
    }
  }

  @override
  Future<String> createDirectChat(String targetUserId) async {
    final response = await _client.rpc(
      'get_or_create_direct_chat',
      params: {'target_user_id': targetUserId},
    );
    return response as String;
  }

  @override
  Future<List<UserProfileModel>> searchUsers(String query) async {
    final uid = currentUserId;
    if (uid == null) return [];

    final cleanQuery = query.replaceAll('@', '').trim();
    var q = _client
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .neq('id', uid);

    if (cleanQuery.isNotEmpty) {
      q = q.or('username.ilike.%$cleanQuery%,display_name.ilike.%$cleanQuery%');
    }

    final response = await q.limit(30);

    return (response as List<dynamic>)
        .map((map) => UserProfileModel.fromMap(map as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markChatAsRead(String chatId, String messageId) async {
    final uid = currentUserId;
    if (uid == null) return;

    // 1. Try RPC function
    try {
      await _client.rpc(
        'mark_chat_as_read',
        params: {
          'p_chat_id': chatId,
          if (messageId.isNotEmpty) 'p_message_id': messageId,
        },
      );
      return;
    } catch (_) {}

    // 2. Direct table update fallback
    try {
      final updateData = <String, dynamic>{
        'unread_count': 0,
        if (messageId.isNotEmpty) 'last_read_message_id': messageId,
      };
      await _client
          .from('chat_members')
          .update(updateData)
          .eq('chat_id', chatId)
          .eq('user_id', uid);
    } catch (_) {
      // 3. Fallback if unread_count column does not exist
      if (messageId.isNotEmpty) {
        try {
          await _client
              .from('chat_members')
              .update({'last_read_message_id': messageId})
              .eq('chat_id', chatId)
              .eq('user_id', uid);
        } catch (_) {}
      }
    }

    // 4. Update messages is_read
    try {
      await _client
          .from('messages')
          .update({'is_read': true})
          .eq('chat_id', chatId)
          .neq('sender_id', uid)
          .eq('is_read', false);
    } catch (_) {}
  }
}

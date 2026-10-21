import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import '../models/user_profile_model.dart';

abstract class ChatRemoteDataSource {
  Future<List<ChatModel>> fetchChats();
  Future<String> createDirectChat(String targetUserId);
  Future<String> createGroupChat({
    required String title,
    required List<String> memberIds,
  });
  Future<List<UserProfileModel>> searchUsers(String query);
  Future<void> markChatAsRead(String chatId, String messageId);
  Future<void> togglePinChat({required String chatId, required bool isPinned});
  Future<void> pinMessage({required String chatId, String? messageId});
  Future<ChatModel> getOrCreateSavedChat();
  Future<void> forwardToSavedMessages({
    required String? content,
    String type,
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
  });
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
            pinned_message_id,
            last_message_text,
            last_message_sender_id,
            last_message_at,
            members:chat_members (
              user_id,
              is_pinned,
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

      final chats = (response as List<dynamic>)
          .map((map) => ChatModel.fromMap(map as Map<String, dynamic>, uid))
          .toList();

      chats.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return chats;
    } on PostgrestException catch (_) {
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
  Future<String> createGroupChat({
    required String title,
    required List<String> memberIds,
  }) async {
    final response = await _client.rpc(
      'create_group_chat',
      params: {'p_title': title, 'p_member_ids': memberIds},
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
    } catch (_) {}

    try {
      await _client
          .from('messages')
          .update({'is_read': true})
          .eq('chat_id', chatId)
          .neq('sender_id', uid)
          .eq('is_read', false);
    } catch (_) {}
  }

  @override
  Future<void> togglePinChat({
    required String chatId,
    required bool isPinned,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _client.rpc(
        'toggle_pin_chat',
        params: {'p_chat_id': chatId, 'p_is_pinned': isPinned},
      );
    } catch (_) {
      await _client
          .from('chat_members')
          .update({'is_pinned': isPinned})
          .eq('chat_id', chatId)
          .eq('user_id', uid);
    }
  }

  @override
  Future<void> pinMessage({required String chatId, String? messageId}) async {
    try {
      await _client.rpc(
        'pin_message',
        params: {'p_chat_id': chatId, 'p_message_id': messageId},
      );
    } catch (_) {
      await _client
          .from('chats')
          .update({'pinned_message_id': messageId})
          .eq('id', chatId);
    }
  }

  @override
  Future<ChatModel> getOrCreateSavedChat() async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final key = 'saved_$uid';
    String? chatId;

    try {
      final res = await _client.rpc('get_or_create_saved_chat');
      if (res != null) {
        chatId = res.toString();
      }
    } catch (_) {}

    if (chatId == null) {
      final existing = await _client
          .from('chats')
          .select('id')
          .eq('direct_key', key)
          .maybeSingle();

      if (existing != null) {
        chatId = existing['id'] as String;
      } else {
        final newChatId = const Uuid().v4();
        try {
          await _client.from('chats').insert({
            'id': newChatId,
            'type': 'saved',
            'title': 'Избранное',
            'direct_key': key,
            'created_by': uid,
          });
          chatId = newChatId;
        } catch (_) {
          // Fallback if 'saved' type constraint check is not yet updated on database
          await _client.from('chats').insert({
            'id': newChatId,
            'type': 'direct',
            'title': 'Избранное',
            'direct_key': key,
            'created_by': uid,
          });
          chatId = newChatId;
        }
      }

      await _client.from('chat_members').upsert({
        'chat_id': chatId,
        'user_id': uid,
        'role': 'owner',
      });
    }

    final chatData = await _client
        .from('chats')
        .select('''
          id,
          type,
          title,
          avatar_url,
          pinned_message_id,
          last_message_text,
          last_message_sender_id,
          last_message_at
        ''')
        .eq('id', chatId)
        .single();

    return ChatModel(
      id: chatId,
      type: 'saved',
      title: 'Избранное',
      lastMessageText: chatData['last_message_text'],
      lastMessageAt: chatData['last_message_at'] != null
          ? DateTime.tryParse(chatData['last_message_at'])
          : null,
      unreadCount: 0,
      partnerId: uid,
    );
  }

  @override
  Future<void> forwardToSavedMessages({
    required String? content,
    String type = 'text',
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final savedChat = await getOrCreateSavedChat();

    final insertData = <String, dynamic>{
      'chat_id': savedChat.id,
      'sender_id': uid,
      'content': content,
      'type': type,
      'media_url': mediaUrl,
      'blurhash': blurhash,
      'duration_sec': durationSec,
      'is_read': true,
    };

    final newMsg = await _client
        .from('messages')
        .insert(insertData)
        .select()
        .single();

    final previewText = type == 'image'
        ? '📷 Фото'
        : type == 'voice'
        ? '🎤 Голосовое сообщение'
        : type == 'file'
        ? '📎 Файл'
        : type == 'video'
        ? '🎥 Видео'
        : (content ?? '');

    await _client
        .from('chats')
        .update({
          'last_message_id': newMsg['id'],
          'last_message_text': previewText,
          'last_message_sender_id': uid,
          'last_message_at': DateTime.now().toIso8601String(),
        })
        .eq('id', savedChat.id);
  }
}

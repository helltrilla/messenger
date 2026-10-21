import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../models/message_model.dart';

abstract class MessageRemoteDataSource {
  String? get currentUserId;
  Future<List<MessageModel>> fetchMessages({
    required String chatId,
    int limit = 50,
    DateTime? before,
  });
  Future<MessageModel> sendMessage({
    required String chatId,
    String? content,
    String type = 'text',
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
    String? replyToId,
  });
  Future<void> editMessage({
    required String messageId,
    required String chatId,
    required String newContent,
  });
  Future<void> deleteMessage({
    required String messageId,
    required String chatId,
    String? mediaUrl,
  });
  Future<String> uploadMedia({
    required Uint8List bytes,
    required String fileName,
  });
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  });
  Future<void> setTyping({required String chatId, required bool isTyping});
  Future<void> setUserPresence({required bool isOnline});
  Future<List<MessageModel>> searchMessages({
    required String chatId,
    required String query,
  });
}

class MessageRemoteDataSourceImpl implements MessageRemoteDataSource {
  final SupabaseClient _client;

  MessageRemoteDataSourceImpl(this._client);

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<List<MessageModel>> fetchMessages({
    required String chatId,
    int limit = 50,
    DateTime? before,
  }) async {
    final uid = currentUserId;
    if (uid == null) return [];

    var query = _client.from('messages').select().eq('chat_id', chatId);
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);
    if (response.isEmpty) return [];

    final messageIds = response.map((m) => m['id'] as String).toList();

    // 1. Fetch reactions for these messages
    final reactionsByMessageId = <String, List<Map<String, dynamic>>>{};
    try {
      final reactionsRes = await _client
          .from('message_reactions')
          .select('message_id, emoji, user_id')
          .inFilter('message_id', messageIds);
      for (final r in reactionsRes) {
        final mid = r['message_id'] as String;
        reactionsByMessageId.putIfAbsent(mid, () => []).add(r);
      }
    } catch (e) {
      debugPrint('Error fetching reactions: $e');
    }

    // 2. Fetch sender names
    final senderNamesByUserId = <String, String>{};
    try {
      final senderIds = response
          .map((m) => m['sender_id'] as String)
          .toSet()
          .toList();
      final profilesRes = await _client
          .from('profiles')
          .select('id, username, display_name')
          .inFilter('id', senderIds);
      for (final p in profilesRes) {
        final pid = p['id'] as String;
        final name =
            (p['display_name'] as String?) ?? (p['username'] as String?);
        if (name != null) senderNamesByUserId[pid] = name;
      }
    } catch (_) {}

    // 3. Fetch reply preview info
    final replyPreviews = <String, Map<String, dynamic>>{};
    final replyIds = response
        .map((m) => m['reply_to_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (replyIds.isNotEmpty) {
      try {
        final replyMsgs = await _client
            .from('messages')
            .select('id, content, sender_id')
            .inFilter('id', replyIds);
        for (final rm in replyMsgs) {
          replyPreviews[rm['id'] as String] = rm;
        }
      } catch (_) {}
    }

    // 4. Calculate partner unread count
    int partnerUnreadCount = 0;
    try {
      final membersResponse = await _client
          .from('chat_members')
          .select('user_id, unread_count')
          .eq('chat_id', chatId)
          .neq('user_id', uid)
          .maybeSingle();

      if (membersResponse != null) {
        partnerUnreadCount = membersResponse['unread_count'] as int? ?? 0;
      }
    } catch (_) {}

    int unreadOutgoingEncountered = 0;
    final list = <MessageModel>[];

    for (final e in response) {
      final map = Map<String, dynamic>.from(e);
      final isMine = map['sender_id'] == uid;
      final isReadInDb = map['is_read'] == true;

      bool isRead = isReadInDb;
      if (isMine && !isReadInDb) {
        if (partnerUnreadCount == 0) {
          isRead = true;
        } else if (unreadOutgoingEncountered < partnerUnreadCount) {
          isRead = false;
          unreadOutgoingEncountered++;
        } else {
          isRead = true;
        }
      }

      // Attach reactions
      map['reactions'] = reactionsByMessageId[map['id']] ?? [];

      // Attach sender profile
      final senderId = map['sender_id'] as String?;
      if (senderId != null && senderNamesByUserId.containsKey(senderId)) {
        map['profile'] = {'display_name': senderNamesByUserId[senderId]};
      }

      // Attach reply preview
      final replyToId = map['reply_to_id'] as String?;
      if (replyToId != null && replyPreviews.containsKey(replyToId)) {
        final rm = replyPreviews[replyToId]!;
        final rSenderId = rm['sender_id'] as String?;
        final rSenderName = rSenderId != null
            ? senderNamesByUserId[rSenderId]
            : null;
        map['reply_to'] = {
          'content': rm['content'],
          'profile': {'display_name': rSenderName},
        };
      }

      list.add(MessageModel.fromMap(map, uid, isReadExplicit: isRead));
    }

    return list;
  }

  @override
  Future<MessageModel> sendMessage({
    required String chatId,
    String? content,
    String type = 'text',
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
    String? replyToId,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final insertData = <String, dynamic>{
      'chat_id': chatId,
      'sender_id': uid,
      'content': content,
      'type': type,
      'media_url': mediaUrl,
      'blurhash': blurhash,
      'duration_sec': durationSec,
      'reply_to_id': ?replyToId,
    };

    final response = await _client
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
        : (content ?? '');

    unawaited(
      _client
          .from('chats')
          .update({
            'last_message_text': previewText,
            'last_message_at': DateTime.now().toIso8601String(),
            'last_message_id': response['id'],
            'last_message_sender_id': uid,
          })
          .eq('id', chatId)
          .catchError((_) {}),
    );

    return MessageModel.fromMap(response, uid);
  }

  @override
  Future<void> editMessage({
    required String messageId,
    required String chatId,
    required String newContent,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    await _client
        .from('messages')
        .update({
          'content': newContent,
          'is_edited': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', uid);

    unawaited(
      _client
          .from('chats')
          .update({'last_message_text': newContent})
          .eq('id', chatId)
          .eq('last_message_id', messageId)
          .catchError((_) {}),
    );
  }

  @override
  Future<void> deleteMessage({
    required String messageId,
    required String chatId,
    String? mediaUrl,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      try {
        final uri = Uri.tryParse(mediaUrl);
        if (uri != null) {
          final segments = uri.pathSegments;
          final bucketIndex = segments.indexOf(SupabaseConstants.mediaBucket);
          if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
            final storagePath = segments.sublist(bucketIndex + 1).join('/');
            await _client.storage.from(SupabaseConstants.mediaBucket).remove([
              storagePath,
            ]);
          }
        }
      } catch (_) {}
    }

    await _client
        .from('messages')
        .delete()
        .eq('id', messageId)
        .eq('sender_id', uid);

    try {
      final prevMessages = await _client
          .from('messages')
          .select('id, content, type, created_at, sender_id')
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .limit(1);

      if ((prevMessages as List).isNotEmpty) {
        final lastMsg = (prevMessages as List).first as Map<String, dynamic>;
        final previewText = lastMsg['type'] == 'image'
            ? '📷 Фото'
            : lastMsg['type'] == 'voice'
            ? '🎤 Голосовое сообщение'
            : lastMsg['type'] == 'file'
            ? '📎 Файл'
            : (lastMsg['content'] ?? '');

        await _client
            .from('chats')
            .update({
              'last_message_text': previewText,
              'last_message_at': lastMsg['created_at'],
              'last_message_id': lastMsg['id'],
              'last_message_sender_id': lastMsg['sender_id'],
            })
            .eq('id', chatId)
            .eq('last_message_id', messageId);
      } else {
        await _client
            .from('chats')
            .update({
              'last_message_text': null,
              'last_message_at': null,
              'last_message_id': null,
              'last_message_sender_id': null,
            })
            .eq('id', chatId)
            .eq('last_message_id', messageId);
      }
    } catch (_) {}
  }

  @override
  Future<String> uploadMedia({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = 'uploads/${timestamp}_${uid}_$cleanName';

    await _client.storage
        .from(SupabaseConstants.mediaBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    return _client.storage
        .from(SupabaseConstants.mediaBucket)
        .getPublicUrl(path);
  }

  @override
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    bool rpcSuccess = false;
    try {
      await _client.rpc(
        'toggle_message_reaction',
        params: {'p_message_id': messageId, 'p_emoji': emoji},
      );
      rpcSuccess = true;
    } catch (e) {
      debugPrint(
        'toggle_message_reaction RPC error: $e, using direct table toggle',
      );
    }

    if (!rpcSuccess) {
      final existing = await _client
          .from('message_reactions')
          .select('id')
          .eq('message_id', messageId)
          .eq('user_id', uid)
          .eq('emoji', emoji)
          .maybeSingle();

      if (existing != null) {
        await _client
            .from('message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', uid)
            .eq('emoji', emoji);
      } else {
        await _client.from('message_reactions').insert({
          'message_id': messageId,
          'user_id': uid,
          'emoji': emoji,
        });
      }
    }
  }

  @override
  Future<void> setTyping({
    required String chatId,
    required bool isTyping,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _client.rpc(
        'set_typing',
        params: {'p_chat_id': chatId, 'p_is_typing': isTyping},
      );
    } catch (_) {}
  }

  @override
  Future<void> setUserPresence({required bool isOnline}) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _client.rpc('set_user_presence', params: {'p_is_online': isOnline});
    } catch (_) {}
  }

  @override
  Future<List<MessageModel>> searchMessages({
    required String chatId,
    required String query,
  }) async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      final response = await _client.rpc(
        'search_messages',
        params: {'p_chat_id': chatId, 'p_query': query},
      );
      return (response as List<dynamic>)
          .map((m) => MessageModel.fromMap(m as Map<String, dynamic>, uid))
          .toList();
    } catch (_) {
      final response = await _client
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List<dynamic>)
          .map((m) => MessageModel.fromMap(m as Map<String, dynamic>, uid))
          .toList();
    }
  }
}

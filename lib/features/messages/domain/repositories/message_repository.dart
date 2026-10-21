import 'dart:typed_data';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/message_entity.dart';

abstract class MessageRepository {
  String? get currentUserId;
  Future<Result<Failure, List<MessageEntity>>> getMessages({
    required String chatId,
    int limit = 50,
    DateTime? before,
  });
  Future<Result<Failure, MessageEntity>> sendMessage({
    required String chatId,
    String? content,
    String type = 'text',
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
    String? replyToId,
  });
  Future<Result<Failure, void>> editMessage({
    required String messageId,
    required String chatId,
    required String newContent,
  });
  Future<Result<Failure, void>> deleteMessage({
    required String messageId,
    required String chatId,
    String? mediaUrl,
  });
  Future<Result<Failure, String>> uploadMedia({
    required Uint8List bytes,
    required String fileName,
  });
  Future<Result<Failure, void>> toggleReaction({
    required String messageId,
    required String emoji,
  });
  Future<Result<Failure, void>> setTyping({
    required String chatId,
    required bool isTyping,
  });
  Future<Result<Failure, void>> setUserPresence({required bool isOnline});
  Future<Result<Failure, List<MessageEntity>>> searchMessages({
    required String chatId,
    required String query,
  });
}

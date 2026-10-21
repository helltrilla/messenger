import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../entities/message_entity.dart';
import '../repositories/message_repository.dart';

class SendMessageUseCase {
  final MessageRepository _repository;

  const SendMessageUseCase(this._repository);

  Future<Result<Failure, MessageEntity>> call({
    required String chatId,
    String? content,
    String type = 'text',
    String? mediaUrl,
    String? blurhash,
    int? durationSec,
  }) {
    return _repository.sendMessage(
      chatId: chatId,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      blurhash: blurhash,
      durationSec: durationSec,
    );
  }
}

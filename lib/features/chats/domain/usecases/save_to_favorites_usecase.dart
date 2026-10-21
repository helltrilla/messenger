import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../messages/domain/entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class SaveToFavoritesUseCase {
  final ChatRepository _repository;

  const SaveToFavoritesUseCase(this._repository);

  Future<Result<Failure, void>> call(MessageEntity message) {
    return _repository.forwardToSavedMessages(
      content: message.content,
      type: message.type,
      mediaUrl: message.mediaUrl,
      blurhash: message.blurhash,
      durationSec: message.durationSec,
    );
  }
}

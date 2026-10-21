import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/message_repository.dart';

class ToggleReactionUseCase {
  final MessageRepository _repository;

  const ToggleReactionUseCase(this._repository);

  Future<Result<Failure, void>> call({
    required String messageId,
    required String emoji,
  }) {
    return _repository.toggleReaction(messageId: messageId, emoji: emoji);
  }
}

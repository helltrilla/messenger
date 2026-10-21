import 'dart:typed_data';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../repositories/message_repository.dart';

class UploadMediaUseCase {
  final MessageRepository _repository;

  const UploadMediaUseCase(this._repository);

  Future<Result<Failure, String>> call({
    required Uint8List bytes,
    required String fileName,
  }) {
    return _repository.uploadMedia(bytes: bytes, fileName: fileName);
  }
}

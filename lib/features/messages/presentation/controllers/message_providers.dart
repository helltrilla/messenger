import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/message_remote_data_source.dart';
import '../../data/repositories/message_repository_impl.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/usecases/delete_message_usecase.dart';
import '../../domain/usecases/edit_message_usecase.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import '../../domain/usecases/search_messages_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../domain/usecases/set_typing_usecase.dart';
import '../../domain/usecases/toggle_reaction_usecase.dart';
import '../../domain/usecases/upload_media_usecase.dart';

final messageRemoteDataSourceProvider = Provider<MessageRemoteDataSource>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return MessageRemoteDataSourceImpl(client);
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final dataSource = ref.watch(messageRemoteDataSourceProvider);
  return MessageRepositoryImpl(dataSource);
});

final getMessagesUseCaseProvider = Provider<GetMessagesUseCase>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return GetMessagesUseCase(repo);
});

final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return SendMessageUseCase(repo);
});

final editMessageUseCaseProvider = Provider<EditMessageUseCase>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return EditMessageUseCase(repo);
});

final deleteMessageUseCaseProvider = Provider<DeleteMessageUseCase>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return DeleteMessageUseCase(repo);
});

final uploadMediaUseCaseProvider = Provider<UploadMediaUseCase>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return UploadMediaUseCase(repo);
});

final toggleReactionUseCaseProvider = Provider<ToggleReactionUseCase>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return ToggleReactionUseCase(repo);
});

final setTypingUseCaseProvider = Provider<SetTypingUseCase>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return SetTypingUseCase(repo);
});

final searchMessagesUseCaseProvider = Provider<SearchMessagesUseCase>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return SearchMessagesUseCase(repo);
});

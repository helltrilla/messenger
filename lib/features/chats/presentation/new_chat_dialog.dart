import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import 'controllers/chat_list_controller.dart';
import 'controllers/user_search_controller.dart';
import '../domain/entities/chat_entity.dart';
import '../domain/entities/user_profile_entity.dart';
import 'widgets/user_avatar.dart';

class NewChatDialog extends ConsumerStatefulWidget {
  final Function(ChatEntity chat) onChatSelected;

  const NewChatDialog({super.key, required this.onChatSelected});

  @override
  ConsumerState<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends ConsumerState<NewChatDialog> {
  final _searchController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    ref.read(userSearchControllerProvider.notifier).search(query);
  }

  void _startChat(UserProfileEntity user) async {
    setState(() => _isCreating = true);
    try {
      final chatId = await ref
          .read(chatListControllerProvider.notifier)
          .createDirectChat(user.id);

      if (!mounted) return;

      final chatEntity = ChatEntity(
        id: chatId,
        type: 'direct',
        title: user.displayName,
        avatarUrl: user.avatarUrl,
        partnerId: user.id,
        partnerUsername: user.username,
      );

      Navigator.pop(context);
      widget.onChatSelected(chatEntity);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка создания чата: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(userSearchControllerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Новое сообщение',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Поиск по @username или имени...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondaryDark,
                ),
                filled: true,
                fillColor: AppColors.darkBackground,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isCreating
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : searchState.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Text(
                        'Ошибка поиска: $err',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    data: (users) {
                      if (users.isEmpty) {
                        return Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'Пока нет других пользователей'
                                : 'Никого не найдено',
                            style: const TextStyle(
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, _) => const Divider(
                          color: AppColors.darkDivider,
                          indent: 72,
                        ),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final username = user.username.isNotEmpty
                              ? '@${user.username}'
                              : '';

                          return ListTile(
                            leading: UserAvatar(
                              name: user.displayName,
                              imageUrl: user.avatarUrl,
                              radius: 22,
                            ),
                            title: Text(
                              user.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              username,
                              style: const TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontSize: 13,
                              ),
                            ),
                            onTap: () => _startChat(user),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

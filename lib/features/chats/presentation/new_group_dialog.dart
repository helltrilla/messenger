import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/entities/chat_entity.dart';
import '../domain/entities/user_profile_entity.dart';
import 'controllers/chat_list_controller.dart';
import 'controllers/user_search_controller.dart';
import 'widgets/user_avatar.dart';

class NewGroupDialog extends ConsumerStatefulWidget {
  final Function(ChatEntity chat) onGroupCreated;

  const NewGroupDialog({super.key, required this.onGroupCreated});

  @override
  ConsumerState<NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends ConsumerState<NewGroupDialog> {
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  final Map<String, UserProfileEntity> _selectedUsers = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите название группы')));
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного участника')),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final chatId = await ref
          .read(chatListControllerProvider.notifier)
          .createGroupChat(title, _selectedUserIds.toList());

      if (!mounted) return;
      Navigator.pop(context);

      final newGroupChat = ChatEntity(
        id: chatId,
        type: 'group',
        title: title,
        lastMessageText: 'Группа создана',
        lastMessageAt: DateTime.now(),
      );

      widget.onGroupCreated(newGroupChat);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка создания группы: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(userSearchControllerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.group_add_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                const Text(
                  'Новая группа',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_isCreating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: _createGroup,
                    child: Text(
                      'Создать (${_selectedUserIds.length})',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Group title input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Название группы...',
                hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: AppColors.darkBackground,
                prefixIcon: const Icon(
                  Icons.title_rounded,
                  color: AppColors.primary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),

          // Selected users avatars horizontal chips
          if (_selectedUsers.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _selectedUsers.values.map((u) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InputChip(
                      backgroundColor: AppColors.darkBackground,
                      avatar: UserAvatar(name: u.displayName, radius: 14),
                      label: Text(
                        u.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedUserIds.remove(u.id);
                          _selectedUsers.remove(u.id);
                        });
                      },
                      deleteIconColor: Colors.white70,
                    ),
                  );
                }).toList(),
              ),
            ),

          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) =>
                  ref.read(userSearchControllerProvider.notifier).search(val),
              decoration: InputDecoration(
                hintText: 'Поиск участников по имени или @username...',
                hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: AppColors.darkBackground,
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondaryDark,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),

          const Divider(color: AppColors.darkDivider, height: 16),

          // Search results with multi-select checkboxes
          Expanded(
            child: searchResults.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Ошибка: $err',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'Пользователи не найдены',
                      style: TextStyle(color: AppColors.textSecondaryDark),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedUserIds.contains(user.id);

                    return CheckboxListTile(
                      activeColor: AppColors.primary,
                      checkColor: Colors.white,
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedUserIds.add(user.id);
                            _selectedUsers[user.id] = user;
                          } else {
                            _selectedUserIds.remove(user.id);
                            _selectedUsers.remove(user.id);
                          }
                        });
                      },
                      secondary: UserAvatar(
                        name: user.displayName,
                        imageUrl: user.avatarUrl,
                        radius: 20,
                      ),
                      title: Text(
                        user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '@${user.username}',
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 13,
                        ),
                      ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/data/datasources/account_local_data_source.dart';
import '../../auth/domain/entities/saved_account.dart';
import '../../auth/presentation/controllers/account_switcher_controller.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/widgets/account_switcher_sheet.dart';
import '../../messages/presentation/chat_screen.dart';
import 'controllers/chat_list_controller.dart';
import 'controllers/chat_providers.dart';
import 'new_chat_dialog.dart';
import 'new_group_dialog.dart';
import 'widgets/chat_tile.dart';
import 'widgets/user_avatar.dart';
import '../domain/entities/chat_entity.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool _isAccountsExpanded = false;
  int _selectedFolderIndex = 0;

  void _openNewChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewChatDialog(
        onChatSelected: (chat) {
          ref
              .read(chatListControllerProvider.notifier)
              .markChatLocallyRead(chat.id);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
          ).then((_) {
            ref.read(chatListControllerProvider.notifier).loadChats();
          });
        },
      ),
    );
  }

  void _openNewGroup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewGroupDialog(
        onGroupCreated: (chat) {
          ref
              .read(chatListControllerProvider.notifier)
              .markChatLocallyRead(chat.id);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
          ).then((_) {
            ref.read(chatListControllerProvider.notifier).loadChats();
          });
        },
      ),
    );
  }

  void _showChatTileOptions(BuildContext context, ChatEntity chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isPinned = chat.isPinned;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    isPinned ? 'Открепить чат' : 'Закрепить чат',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(chatListControllerProvider.notifier)
                        .togglePinChat(chat.id);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.mark_chat_read_outlined,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'Пометить как прочитанный',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(chatListControllerProvider.notifier)
                        .markChatLocallyRead(chat.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSwitchAccount(SavedAccount account) async {
    Navigator.pop(context); // Close drawer
    try {
      final success = await ref
          .read(accountSwitcherControllerProvider.notifier)
          .switchToAccount(account);
      if (!mounted) return;
      if (success) {
        ref.invalidate(currentAuthUserProvider);
        ref.invalidate(chatListControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Вход выполнен как ${account.displayName} (${account.email})',
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Сессия для ${account.email} устарела. Войдите заново.',
          ),
          backgroundColor: Colors.redAccent,
          action: SnackBarAction(
            label: 'Войти',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(isAddingAccount: true),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _addNewAccount() async {
    Navigator.pop(context);
    await ref
        .read(accountSwitcherControllerProvider.notifier)
        .saveCurrentAccount();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(isAddingAccount: true),
      ),
    );
    ref.invalidate(accountSwitcherControllerProvider);
    ref.invalidate(currentAuthUserProvider);
    ref.invalidate(chatListControllerProvider);
  }

  void _onLogout(BuildContext context, String displayName, String? userId) {
    Navigator.pop(context);
    final savedAccounts =
        ref.read(accountSwitcherControllerProvider).value ?? [];

    if (savedAccounts.length > 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.darkSurface,
          title: const Text('Выход', style: TextStyle(color: Colors.white)),
          content: Text(
            'Выйти из аккаунта $displayName или со всех сохранённых аккаунтов?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (userId != null) {
                  await ref
                      .read(accountSwitcherControllerProvider.notifier)
                      .removeAccount(userId);
                }
              },
              child: const Text(
                'Только из этого',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(accountLocalDataSourceProvider).clearAll();
                ref.read(authControllerProvider.notifier).signOut();
              },
              child: const Text('Со всех'),
            ),
          ],
        ),
      );
    } else {
      ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatsState = ref.watch(chatListControllerProvider);
    final user = ref.watch(currentAuthUserProvider);
    final savedAccounts =
        ref.watch(accountSwitcherControllerProvider).value ?? [];
    final currentSaved = savedAccounts
        .where((a) => a.userId == user?.id)
        .firstOrNull;

    final userMeta = user?.userMetadata ?? {};
    final emailPrefix = (user?.email != null && user!.email!.contains('@'))
        ? user.email!.split('@').first
        : 'Пользователь';

    final displayName =
        currentSaved?.displayName ?? userMeta['display_name'] ?? emailPrefix;
    final username =
        currentSaved?.username ?? userMeta['username'] ?? emailPrefix;

    final otherAccounts = savedAccounts
        .where((a) => a.userId != user?.id)
        .toList();

    final chatsList = chatsState.value ?? [];
    final totalUnread = chatsList.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Telegram'),
            if (totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  totalUnread > 99 ? '99+' : '$totalUnread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _openNewChat(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _buildFoldersBar(chatsList),
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppColors.darkSurface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.darkBackground),
              currentAccountPicture: UserAvatar(name: displayName, radius: 32),
              otherAccountsPictures: otherAccounts
                  .take(3)
                  .map(
                    (a) => GestureDetector(
                      onTap: () => _handleSwitchAccount(a),
                      child: UserAvatar(
                        name: a.displayName,
                        imageUrl: a.avatarUrl,
                        radius: 18,
                      ),
                    ),
                  )
                  .toList(),
              onDetailsPressed: () {
                setState(() {
                  _isAccountsExpanded = !_isAccountsExpanded;
                });
              },
              accountName: Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              accountEmail: Text(
                user?.email ?? (username.isNotEmpty ? '@$username' : ''),
                style: const TextStyle(color: AppColors.textSecondaryDark),
              ),
            ),
            if (_isAccountsExpanded) ...[
              if (otherAccounts.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Нет других сохранённых аккаунтов.\nНажмите ниже, чтобы добавить второй email.',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 13,
                    ),
                  ),
                ),
              ] else ...[
                ...otherAccounts.map(
                  (a) => ListTile(
                    leading: UserAvatar(
                      name: a.displayName,
                      imageUrl: a.avatarUrl,
                      radius: 20,
                    ),
                    title: Text(
                      a.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      a.email,
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.primary,
                    ),
                    onTap: () => _handleSwitchAccount(a),
                  ),
                ),
              ],
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Добавить аккаунт',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Войти под вторым email',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                  ),
                ),
                onTap: _addNewAccount,
              ),
              const Divider(color: AppColors.darkDivider),
            ],
            ListTile(
              leading: const Icon(
                Icons.switch_account_outlined,
                color: AppColors.primary,
              ),
              title: const Text(
                'Сменить аккаунт',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                savedAccounts.length > 1
                    ? '${savedAccounts.length} аккаунта(ов) на устройстве'
                    : 'Быстрое переключение',
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.white38,
                size: 20,
              ),
              onTap: () {
                Navigator.pop(context);
                AccountSwitcherSheet.show(context);
              },
            ),
            const Divider(color: AppColors.darkDivider),
            ListTile(
              leading: const Icon(Icons.group_outlined, color: Colors.white70),
              title: const Text(
                'Создать группу',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _openNewGroup(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.bookmark_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Избранное',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final result = await ref.read(getSavedChatUseCaseProvider)();
                result.when(
                  success: (savedChat) {
                    if (context.mounted) {
                      ref
                          .read(chatListControllerProvider.notifier)
                          .markChatLocallyRead(savedChat.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(chat: savedChat),
                        ),
                      ).then((_) {
                        ref
                            .read(chatListControllerProvider.notifier)
                            .loadChats();
                      });
                    }
                  },
                  error: (f) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: ${f.message}')),
                      );
                    }
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'Настройки',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(color: AppColors.darkDivider),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Выйти',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () => _onLogout(context, displayName, user?.id),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.darkSurface,
        onRefresh: () async {
          await ref.read(chatListControllerProvider.notifier).loadChats();
        },
        child: chatsState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Не удалось загрузить чаты:\n$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref
                        .read(chatListControllerProvider.notifier)
                        .loadChats(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
          data: (chats) {
            final filteredChats = switch (_selectedFolderIndex) {
              1 => chats.where((c) => c.type == 'direct').toList(),
              2 => chats.where((c) => c.type == 'group').toList(),
              3 => chats.where((c) => c.type == 'saved').toList(),
              _ => chats,
            };

            if (filteredChats.isEmpty) {
              return _buildEmptyFolderState(context, _selectedFolderIndex);
            }

            return ListView.separated(
              itemCount: filteredChats.length,
              separatorBuilder: (_, _) => const Divider(
                color: AppColors.darkDivider,
                indent: 78,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final chat = filteredChats[index];
                return ChatTile(
                  chat: chat,
                  onLongPress: () => _showChatTileOptions(context, chat),
                  onTap: () {
                    ref
                        .read(chatListControllerProvider.notifier)
                        .markChatLocallyRead(chat.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)),
                    ).then((_) {
                      ref.read(chatListControllerProvider.notifier).loadChats();
                    });
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.darkSurface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.person_add_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Новый диалог',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openNewChat(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.group_add_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Новая группа',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openNewGroup(context);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFoldersBar(List<ChatEntity> allChats) {
    final unreadAll = allChats.fold<int>(0, (s, c) => s + c.unreadCount);
    final unreadDirect = allChats
        .where((c) => c.type == 'direct')
        .fold<int>(0, (s, c) => s + c.unreadCount);
    final unreadGroup = allChats
        .where((c) => c.type == 'group')
        .fold<int>(0, (s, c) => s + c.unreadCount);
    final unreadSaved = allChats
        .where((c) => c.type == 'saved')
        .fold<int>(0, (s, c) => s + c.unreadCount);

    final folders = [
      (title: 'Все', unread: unreadAll),
      (title: 'Личные', unread: unreadDirect),
      (title: 'Группы', unread: unreadGroup),
      (title: 'Избранное', unread: unreadSaved),
    ];

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.darkDivider, width: 0.5),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        scrollDirection: Axis.horizontal,
        itemCount: folders.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final item = folders[index];
          final isSelected = _selectedFolderIndex == index;
          return InkWell(
            onTap: () {
              setState(() {
                _selectedFolderIndex = index;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  if (item.unread > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.unread > 99 ? '99+' : '${item.unread}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyFolderState(BuildContext context, int folderIndex) {
    IconData icon;
    String title;
    String subtitle;
    Widget? actionButton;

    switch (folderIndex) {
      case 1:
        icon = Icons.person_outline_rounded;
        title = 'Нет личных чатов';
        subtitle = 'Начните личный диалог с любым пользователем';
        actionButton = ElevatedButton.icon(
          onPressed: () => _openNewChat(context),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Написать сообщение'),
        );
        break;
      case 2:
        icon = Icons.group_outlined;
        title = 'Нет групп';
        subtitle = 'Создайте группу для общения с друзьями или коллегами';
        actionButton = ElevatedButton.icon(
          onPressed: () => _openNewGroup(context),
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Создать группу'),
        );
        break;
      case 3:
        icon = Icons.bookmark_border_rounded;
        title = 'В Избранном пока пусто';
        subtitle = 'Сохраняйте важные сообщения, заметки и файлы';
        actionButton = ElevatedButton.icon(
          onPressed: () async {
            final result = await ref.read(getSavedChatUseCaseProvider)();
            result.when(
              success: (savedChat) {
                if (context.mounted) {
                  ref
                      .read(chatListControllerProvider.notifier)
                      .markChatLocallyRead(savedChat.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(chat: savedChat),
                    ),
                  ).then((_) {
                    ref.read(chatListControllerProvider.notifier).loadChats();
                  });
                }
              },
              error: (f) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: ${f.message}')),
                  );
                }
              },
            );
          },
          icon: const Icon(Icons.bookmark_rounded),
          label: const Text('Открыть Избранное'),
        );
        break;
      case 0:
      default:
        icon = Icons.chat_bubble_outline_rounded;
        title = 'Список чатов пуст';
        subtitle = 'Нажмите карандаш снизу, чтобы написать контактy';
        actionButton = null;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.darkSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryDark,
              ),
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 20),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }
}

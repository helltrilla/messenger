import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../chats/presentation/controllers/chat_list_controller.dart';
import '../../../chats/presentation/widgets/user_avatar.dart';
import '../../domain/entities/saved_account.dart';
import '../controllers/account_switcher_controller.dart';
import '../login_screen.dart';

class AccountSwitcherSheet extends ConsumerStatefulWidget {
  const AccountSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AccountSwitcherSheet(),
    );
  }

  @override
  ConsumerState<AccountSwitcherSheet> createState() =>
      _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<AccountSwitcherSheet> {
  String? _switchingUserId;

  Future<void> _switchTo(SavedAccount account) async {
    setState(() => _switchingUserId = account.userId);
    try {
      final success = await ref
          .read(accountSwitcherControllerProvider.notifier)
          .switchToAccount(account);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
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
    } finally {
      if (mounted) {
        setState(() => _switchingUserId = null);
      }
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

  void _confirmRemove(SavedAccount account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text(
          'Удалить аккаунт?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Вы уверены, что хотите удалить ${account.displayName} (${account.email}) с этого устройства?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(accountSwitcherControllerProvider.notifier)
                  .removeAccount(account.userId);
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountSwitcherControllerProvider);
    final currentUserId = ref.watch(currentAuthUserProvider)?.id;

    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.switch_account_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Смена аккаунта',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.darkDivider),

            // Accounts list
            accountsState.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Ошибка: $err',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              data: (accounts) {
                if (accounts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Нет сохранённых аккаунтов',
                      style: TextStyle(color: Colors.white60),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => const Divider(
                    color: AppColors.darkDivider,
                    indent: 72,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    final isCurrent = account.userId == currentUserId;
                    final isSwitching = _switchingUserId == account.userId;

                    return ListTile(
                      leading: Stack(
                        children: [
                          UserAvatar(
                            name: account.displayName,
                            imageUrl: account.avatarUrl,
                            radius: 22,
                          ),
                          if (isCurrent)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.darkSurface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Активен',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        account.username.isNotEmpty
                            ? '@${account.username} • ${account.email}'
                            : account.email,
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isSwitching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : isCurrent
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                              size: 22,
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.white38,
                                size: 20,
                              ),
                              tooltip: 'Удалить аккаунт',
                              onPressed: () => _confirmRemove(account),
                            ),
                      onTap: isCurrent || isSwitching
                          ? null
                          : () => _switchTo(account),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 8),
            const Divider(color: AppColors.darkDivider),

            // Add account button
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              title: const Text(
                'Добавить аккаунт',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: const Text(
                'Войти под другим email без выхода',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
              onTap: _addNewAccount,
            ),
          ],
        ),
      ),
    );
  }
}

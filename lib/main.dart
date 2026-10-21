import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/supabase_constants.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/chats/presentation/chat_list_screen.dart';
import 'features/chats/presentation/controllers/chat_list_controller.dart';
import 'features/messages/presentation/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Russian date formatting for intl
  try {
    await initializeDateFormatting('ru', null);
  } catch (e) {
    debugPrint('Date formatting initialization error: $e');
  }

  // Initialize Supabase
  if (SupabaseConstants.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConstants.supabaseUrl,
        publishableKey: SupabaseConstants.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
  } else {
    debugPrint(
      '⚠️ Supabase credentials not found. Run with: flutter run --dart-define-from-file=env.json',
    );
  }

  // Initialize notifications
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  runApp(const ProviderScope(child: TelegramMessengerApp()));
}

class TelegramMessengerApp extends ConsumerStatefulWidget {
  const TelegramMessengerApp({super.key});

  @override
  ConsumerState<TelegramMessengerApp> createState() =>
      _TelegramMessengerAppState();
}

class _TelegramMessengerAppState extends ConsumerState<TelegramMessengerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String?>? _notifSubscription;

  @override
  void initState() {
    super.initState();
    _notifSubscription = ref
        .read(notificationServiceProvider)
        .onNotificationTap
        .listen((chatId) {
          if (chatId != null && chatId.isNotEmpty) {
            _handleNotificationNavigation(chatId);
          }
        });
  }

  void _handleNotificationNavigation(String chatId) {
    final navContext = _navigatorKey.currentContext;
    if (navContext == null) return;

    final chats = ref.read(chatListControllerProvider).value ?? [];
    final match = chats.where((c) => c.id == chatId).firstOrNull;
    if (match != null) {
      Navigator.of(
        navContext,
      ).push(MaterialPageRoute(builder: (_) => ChatScreen(chat: match)));
    }
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Telegram 2.0',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInitialized = ref.watch(isSupabaseInitializedProvider);
    if (!isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: AppColors.textSecondaryDark,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Supabase Not Initialized',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please provide SUPABASE_URL and SUPABASE_ANON_KEY via env.json or environment variables.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (data) {
        final session =
            data.session ?? Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const ChatListScreen();
        } else {
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.send_rounded, size: 40, color: Colors.white),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      ),
      error: (error, _) => const LoginScreen(),
    );
  }
}

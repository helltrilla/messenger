import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static final StreamController<String?> _tapController =
      StreamController<String?>.broadcast();

  /// Stream of chat IDs when user taps a notification
  Stream<String?> get onNotificationTap => _tapController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _tapController.add(payload);
          }
        },
      );
      _isInitialized = true;
      await requestPermissions();
    } catch (_) {
      // Graceful fallback for platforms/testing
    }
  }

  Future<void> requestPermissions() async {
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();

      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

      final macImpl = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      await macImpl?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  Future<void> showMessageNotification({
    required int id,
    required String senderName,
    required String messageText,
    String? chatId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'messenger_channel_messages',
      'Сообщения',
      channelDescription: 'Уведомления о новых сообщениях в чатах',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.show(
        id: id,
        title: senderName,
        body: messageText,
        notificationDetails: details,
        payload: chatId,
      );
    } catch (_) {}
  }

  /// Registers user push token in Supabase user_push_tokens table
  Future<void> registerDeviceToken({
    required SupabaseClient client,
    String? token,
  }) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final effectiveToken =
          token ?? 'device_${uid.replaceAll('-', '').substring(0, 12)}';
      String deviceType = 'other';
      if (defaultTargetPlatform == TargetPlatform.android) {
        deviceType = 'android';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        deviceType = 'ios';
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        deviceType = 'macos';
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        deviceType = 'windows';
      }

      await client.from('user_push_tokens').upsert({
        'user_id': uid,
        'token': effectiveToken,
        'device_type': deviceType,
      });
    } catch (_) {}
  }

  /// Unregisters device push token upon logout
  Future<void> unregisterDeviceToken({
    required SupabaseClient client,
    String? token,
  }) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      if (token != null) {
        await client
            .from('user_push_tokens')
            .delete()
            .eq('user_id', uid)
            .eq('token', token);
      } else {
        await client.from('user_push_tokens').delete().eq('user_id', uid);
      }
    } catch (_) {}
  }
}

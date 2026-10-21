import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

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
          // Handle tap if needed
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
}

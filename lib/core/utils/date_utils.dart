import 'package:intl/intl.dart';

class ChatDateFormatter {
  static String formatChatListTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final local = dateTime.toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(local.year, local.month, local.day);
    final differenceDays = today.difference(messageDay).inDays;

    if (differenceDays == 0) {
      return DateFormat('HH:mm').format(local);
    } else if (differenceDays == 1) {
      return 'Вчера';
    } else if (differenceDays < 7) {
      // E.g. Пн, Вт, Ср
      return DateFormat('E', 'ru').format(local);
    } else {
      return DateFormat('d MMM', 'ru').format(local);
    }
  }

  static String formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('HH:mm').format(dateTime.toLocal());
  }
}

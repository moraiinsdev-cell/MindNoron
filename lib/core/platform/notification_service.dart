import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

import '../constants/app_constants.dart';

/// Native desktop toast notifications (timer completion, reminders).
///
/// Uses `local_notifier` for reliable Windows support. Abstracted here so the
/// backend can be swapped (e.g. flutter_local_notifications) without touching
/// callers.
class NotificationService {
  const NotificationService._();

  static Future<void> init() async {
    try {
      await localNotifier.setup(appName: AppConstants.appName);
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  static Future<void> show(
      {required String title, required String body}) async {
    try {
      final notification = LocalNotification(title: title, body: body);
      await notification.show();
    } catch (e) {
      debugPrint('NotificationService show failed: $e');
    }
  }
}

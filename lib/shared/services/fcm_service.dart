import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Request notification permissions (required for iOS, good practice for Android 13+).
  Future<void> requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Subscribe to camp topics based on user role and team.
  Future<void> subscribeToTopics({
    required String campId,
    required String role,
    String? team,
  }) async {
    await _messaging.subscribeToTopic('camp_${campId}_all');

    if (role == 'kid') {
      await _messaging.subscribeToTopic('camp_${campId}_kids');
      // Subscribe to team-specific topic for points notifications
      if (team != null) {
        await _messaging.subscribeToTopic('camp_${campId}_team_$team');
      }
    } else if (role == 'guide') {
      await _messaging.subscribeToTopic('camp_${campId}_guides');
    }

    debugPrint('FCM: Subscribed to camp_$campId topics as $role (team: $team)');
  }

  /// Unsubscribe from all camp topics.
  Future<void> unsubscribeFromTopics(String campId, {String? team}) async {
    await _messaging.unsubscribeFromTopic('camp_${campId}_all');
    await _messaging.unsubscribeFromTopic('camp_${campId}_kids');
    await _messaging.unsubscribeFromTopic('camp_${campId}_guides');
    if (team != null) {
      await _messaging.unsubscribeFromTopic('camp_${campId}_team_$team');
    }
    debugPrint('FCM: Unsubscribed from camp_$campId topics');
  }

  /// Set up foreground message handler.
  void onForegroundMessage(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  /// Initialize the local notifications plugin (Android heads-up display for
  /// foreground FCM messages) and enable native foreground presentation on iOS.
  Future<void> initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: android),
    );
    // iOS displays foreground FCM natively when presentation options are set —
    // no local-notification plumbing needed there.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Android-only: iOS shows foreground notifications natively via the
  /// presentation options above.
  Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final type = message.data['type'] as String?;
    final channelId = type == 'emergency' ? 'emergency' : 'announcements';
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == 'emergency' ? 'Emergency' : 'Announcements',
          importance: channelId == 'emergency'
              ? Importance.max
              : Importance.defaultImportance,
          priority:
              channelId == 'emergency' ? Priority.max : Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: type,
    );
  }

  /// Handle notification tap when app is in background/terminated.
  void onMessageOpenedApp(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  /// Check if app was opened from a notification (when terminated).
  Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }
}

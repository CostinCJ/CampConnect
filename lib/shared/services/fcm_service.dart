import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Request notification permissions (required for iOS, good practice for Android 13+).
  Future<void> requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
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

  /// Handle notification tap when app is in background/terminated.
  void onMessageOpenedApp(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  /// Check if app was opened from a notification (when terminated).
  Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }
}

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

/// Handles FCM token registration, foreground/background notification display,
/// and deep-link routing from notification taps.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'cip_high_importance',
    'CIP Notifications',
    description: 'Crew Intelligence Platform — bids, trades, and alerts',
    importance: Importance.high,
  );

  // ── Initialization ─────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    // Request permission
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Local notifications setup
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create high-importance channel on Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App opened from terminated state via notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Register token
    await _registerToken();

    // Token refresh listener
    messaging.onTokenRefresh.listen(_saveToken);
  }

  // ── Token Registration ─────────────────────────────────────────────────────
  static Future<void> _registerToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? token;
    if (Platform.isIOS) {
      token = await FirebaseMessaging.instance.getAPNSToken();
      if (token == null) {
        await Future.delayed(const Duration(seconds: 3));
        token = await FirebaseMessaging.instance.getAPNSToken();
      }
    }
    token ??= await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
  }

  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('fcmTokens')
        .doc('${user.uid}_${Platform.operatingSystem}')
        .set({
      'userId': user.uid,
      'token': token,
      'platform': Platform.operatingSystem,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseMessaging.instance.deleteToken();
    await FirebaseFirestore.instance
        .collection('fcmTokens')
        .doc('${user.uid}_${Platform.operatingSystem}')
        .delete();
  }

  // ── Foreground Message Handler ─────────────────────────────────────────────
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          color: const Color(0xFF1B4F8A),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['deepLink'] ?? '/home',
    );
  }

  // ── Notification Tap Handlers ──────────────────────────────────────────────
  static void _onNotificationTap(NotificationResponse response) {
    final deepLink = response.payload ?? '/home';
    _navigateTo(deepLink);
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final deepLink = message.data['deepLink'] ?? '/home';
    _navigateTo(deepLink);
  }

  static GlobalKey<NavigatorState>? _navigatorKey;
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static void _navigateTo(String path) {
    _navigatorKey?.currentContext?.go(path);
  }

  // ── Show Local Notification (for in-app triggered alerts) ─────────────────
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String deepLink = '/home',
    String type = 'info',
  }) async {
    final color = switch (type) {
      'bid_awarded' => const Color(0xFF2ECC71),
      'violation'   => const Color(0xFFE74C3C),
      'warning'     => const Color(0xFFF39C12),
      _             => const Color(0xFF1B4F8A),
    };

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          importance: Importance.high,
          priority: Priority.high,
          color: color,
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: deepLink,
    );
  }
}

/// Background message handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized in main() before this is called
  // Just log — local notification shown by system automatically for background
}

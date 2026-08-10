import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/router/app_router.dart';
import 'package:travla_customer_app/core/push/push_repository.dart';

/// Handles messages that arrive while the app is terminated/background. The OS
/// renders the notification; tapping it routes the user via [PushService] on
/// resume.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No work needed — data is read on tap (getInitialMessage / onMessageOpenedApp).
}

const _channelId = 'travla_alerts';
const _channelName = 'Travla alerts';

/// Wires Firebase Cloud Messaging into the app: permission, token registration,
/// **foreground display** (Android shows nothing on its own while the app is
/// open, so we render a local notification), and tap-to-open deep links.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _token;

  /// Called when a user becomes authenticated — sets up listeners once, then
  /// (re)registers this device's token for the current user.
  Future<void> onAuthenticated() async {
    try {
      await _initOnce();
      final token = await _messaging.getToken();
      if (token != null) {
        _token = token;
        await _ref
            .read(pushRepositoryProvider)
            .register(token: token, platform: _platform());
      }
    } catch (error, stack) {
      // Never let push break sign-in.
      debugPrint('PushService.onAuthenticated failed: $error\n$stack');
    }
  }

  /// Called on sign-out — detach this device so the previous user stops getting
  /// pushes here.
  Future<void> onLoggedOut() async {
    final token = _token;
    try {
      if (token != null) {
        await _ref.read(pushRepositoryProvider).unregister(token);
      }
      await _messaging.deleteToken();
    } catch (_) {
      // Best-effort cleanup.
    }
    _token = null;
  }

  Future<void> _initOnce() async {
    if (_initialized) return;
    _initialized = true;

    await _initLocalNotifications();

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // App in foreground: Android delivers the message but shows no banner, so
    // render it ourselves.
    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleRoute(m.data));
    _messaging.onTokenRefresh.listen((token) {
      _token = token;
      _ref
          .read(pushRepositoryProvider)
          .register(token: token, platform: _platform());
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleRoute(initial.data);
  }

  Future<void> _initLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _navigate(payload);
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Renewals, transfers, claims and account alerts.',
            importance: Importance.high,
          ),
        );
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    await _local.show(
      id: notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _routeFor(message.data),
    );
  }

  void _handleRoute(Map<String, dynamic> data) => _navigate(_routeFor(data));

  void _navigate(String route) {
    if (route.isEmpty) return;
    // Defer until the router is ready (handles cold-start-from-notification).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _ref.read(appRouterProvider).go(route);
      } catch (_) {
        // Route not available — stay put.
      }
    });
  }

  /// Always resolves to a valid in-app route. Deep-links to the specific
  /// notification when the backend includes its id, else the notifications list.
  String _routeFor(Map<String, dynamic> data) {
    final id = data['notification_id']?.toString();
    if (id != null && id.isNotEmpty) {
      return '/notifications?selected=${Uri.encodeComponent(id)}';
    }
    return '/notifications';
  }

  String _platform() => Platform.isIOS ? 'ios' : 'android';
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

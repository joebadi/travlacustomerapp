import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/router/app_router.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/push/push_repository.dart';
import 'package:travla_customer_app/features/notifications/data/notification_repository.dart';
import 'package:travla_customer_app/features/notifications/domain/app_notification.dart';

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

  /// A tapped notification's destination that couldn't be opened yet — e.g. a
  /// cold start from the notification, before sign-in has been restored.
  String? _pendingRoute;

  /// Called when a user becomes authenticated — sets up listeners once, then
  /// (re)registers this device's token for the current user.
  Future<void> onAuthenticated() async {
    try {
      await _initOnce();
      // A tap that arrived while signing in can be opened now.
      _flushPending();
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
    // A foreground (local) notification tapped after the app was closed
    // relaunches the app without calling onDidReceiveNotificationResponse.
    final launch = await _local.getNotificationAppLaunchDetails();
    final launchPayload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _navigate(launchPayload);
    }

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

  void _handleRoute(Map<String, dynamic> data) {
    final route = _routeFor(data);
    // Opening an article straight from the push skips the notifications
    // screen, so mark the in-app copy read here instead.
    final id = data['notification_id']?.toString();
    if (route.startsWith('/news/') && id != null && id.isNotEmpty) {
      _ref.read(notificationRepositoryProvider).markRead(id).catchError((_) {});
    }
    _navigate(route);
  }

  void _navigate(String route) {
    if (route.isEmpty) return;
    _pendingRoute = route;
    _flushPending();
  }

  /// Opens the pending route once the user is signed in and the router is up.
  /// Called on every tap and again after sign-in, so a cold start from a
  /// notification still lands on its destination rather than the home screen.
  void _flushPending() {
    final route = _pendingRoute;
    if (route == null) return;
    if (_ref.read(authControllerProvider).phase != AuthPhase.authenticated) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingRoute != route) return;
      _pendingRoute = null;
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
    // A Car Talk article push opens the article itself.
    final target = nativeNotificationPath(data['action_url']?.toString());
    if (target != null && target.startsWith('/news/')) return target;

    final id = data['notification_id']?.toString();
    if (id != null && id.isNotEmpty) {
      return '/notifications?selected=${Uri.encodeComponent(id)}';
    }
    return '/notifications';
  }

  String _platform() => Platform.isIOS ? 'ios' : 'android';
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

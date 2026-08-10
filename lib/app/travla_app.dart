import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/router/app_router.dart';
import 'package:travla_customer_app/app/theme/app_theme.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/config/app_config.dart';
import 'package:travla_customer_app/core/push/push_service.dart';

class TravlaApp extends ConsumerStatefulWidget {
  const TravlaApp({super.key});

  @override
  ConsumerState<TravlaApp> createState() => _TravlaAppState();
}

class _TravlaAppState extends ConsumerState<TravlaApp> {
  @override
  void initState() {
    super.initState();
    // Register/detach this device's push token as the auth phase changes.
    ref.listenManual<AuthSessionState>(authControllerProvider, (
      previous,
      next,
    ) {
      final wasAuthed = previous?.phase == AuthPhase.authenticated;
      final isAuthed = next.phase == AuthPhase.authenticated;
      if (isAuthed && !wasAuthed) {
        ref.read(pushServiceProvider).onAuthenticated();
      } else if (!isAuthed && wasAuthed) {
        ref.read(pushServiceProvider).onLoggedOut();
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

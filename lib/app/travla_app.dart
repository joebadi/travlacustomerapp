import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/router/app_router.dart';
import 'package:travla_customer_app/app/theme/app_theme.dart';
import 'package:travla_customer_app/core/config/app_config.dart';

class TravlaApp extends ConsumerWidget {
  const TravlaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

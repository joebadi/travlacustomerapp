import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLaunchPhase { loading, ready }

class AppLaunchState {
  const AppLaunchState({
    required this.phase,
    required this.onboardingCompleted,
  });

  const AppLaunchState.loading()
    : this(phase: AppLaunchPhase.loading, onboardingCompleted: false);

  final AppLaunchPhase phase;
  final bool onboardingCompleted;
}

final appLaunchControllerProvider =
    NotifierProvider<AppLaunchController, AppLaunchState>(
      AppLaunchController.new,
    );

class AppLaunchController extends Notifier<AppLaunchState> {
  static const _onboardingKey = 'customer_onboarding_completed_v1';
  static const _minimumSplashDuration = Duration(milliseconds: 1450);

  @override
  AppLaunchState build() {
    unawaited(Future<void>.microtask(_load));
    return const AppLaunchState.loading();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      Future<void>.delayed(_minimumSplashDuration),
    ]);
    final preferences = results.first as SharedPreferences;

    state = AppLaunchState(
      phase: AppLaunchPhase.ready,
      onboardingCompleted: preferences.getBool(_onboardingKey) ?? false,
    );
  }

  Future<void> completeOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingKey, true);
    state = const AppLaunchState(
      phase: AppLaunchPhase.ready,
      onboardingCompleted: true,
    );
  }
}

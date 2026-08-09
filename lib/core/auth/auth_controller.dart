import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:travla_customer_app/core/auth/secure_token_store.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/auth/data/auth_repository.dart';
import 'package:travla_customer_app/features/auth/domain/app_user.dart';

enum AuthPhase { booting, authenticated, unauthenticated }

class AuthSessionState {
  const AuthSessionState({
    required this.phase,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  const AuthSessionState.booting() : this(phase: AuthPhase.booting);

  final AuthPhase phase;
  final AppUser? user;
  final bool isSubmitting;
  final String? errorMessage;

  AuthSessionState copyWith({
    AuthPhase? phase,
    AppUser? user,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthSessionState(
      phase: phase ?? this.phase,
      user: user ?? this.user,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  return SecureTokenStore(const FlutterSecureStorage());
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(secureTokenStoreProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureTokenStoreProvider),
  );
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthSessionState>(AuthController.new);

class AuthController extends Notifier<AuthSessionState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthSessionState build() {
    unawaited(Future<void>.microtask(_restore));
    return const AuthSessionState.booting();
  }

  Future<void> _restore() async {
    if (!await _repository.hasSession()) {
      state = const AuthSessionState(phase: AuthPhase.unauthenticated);
      return;
    }

    try {
      final user = await _repository.currentUser();
      state = AuthSessionState(phase: AuthPhase.authenticated, user: user);
    } on ApiFailure catch (failure) {
      state = AuthSessionState(
        phase: AuthPhase.unauthenticated,
        errorMessage: failure.statusCode == 401 ? null : failure.message,
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthSessionState(phase: AuthPhase.authenticated, user: user);
    } on ApiFailure catch (failure) {
      state = AuthSessionState(
        phase: AuthPhase.unauthenticated,
        errorMessage: failure.message,
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    await _repository.logout();
    state = const AuthSessionState(phase: AuthPhase.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

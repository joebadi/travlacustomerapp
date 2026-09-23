import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

/// Shown when the app can't reach Travla to verify the session on launch. The
/// user isn't necessarily signed out — it's a connectivity problem — so we say
/// so plainly and offer a retry, instead of dropping them on the login screen.
class OfflineScreen extends ConsumerWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(
      authControllerProvider.select((s) => s.errorMessage),
    );
    final booting = ref.watch(
      authControllerProvider.select((s) => s.phase == AuthPhase.booting),
    );

    return Scaffold(
      backgroundColor: AppColors.forest950,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.center,
                child: TravlaLogo(onDark: true, width: 150),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .06),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .12),
                          ),
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          color: AppColors.orange,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No internet connection',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message?.isNotEmpty == true
                            ? message!
                            : "You're offline, so Travla can't load right now. "
                                  'Check your connection and try again — you '
                                  "won't need to sign in again.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9AB9AD),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: booting
                      ? null
                      : () => ref
                          .read(authControllerProvider.notifier)
                          .retryRestore(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: booting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(booting ? 'Checking…' : 'Try again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/features/auth/data/registration_providers.dart';
import 'package:travla_customer_app/features/auth/domain/registration.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_key.currentState?.validate() ?? false)) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(email: _email.text, password: _password.text);
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.verificationPhone != null) {
      context.go(
        '/verify-otp',
        extra: RegistrationStart(
          message: state.errorMessage ?? 'Verify your account.',
          phone: state.verificationPhone!,
          deliveryChannel: state.verificationChannel ?? 'sms',
          destinationHint: state.verificationDestination ?? '',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final config = ref.watch(registrationConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.forest950,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TravlaLogo(onDark: true, width: 150),
                    const Spacer(),
                    Text(
                      'Your vehicle life,\nconnected.',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Documents, ownership, transactions and journeys in one secure account.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .62),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                  child: Form(
                    key: _key,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign in',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Access your Travla customer account.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 26),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email address.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) => (v?.isEmpty ?? true)
                              ? 'Enter your password.'
                              : null,
                        ),
                        if (auth.errorMessage != null &&
                            auth.verificationPhone == null) ...[
                          const SizedBox(height: 14),
                          _InlineError(auth.errorMessage!),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: auth.isSubmitting ? null : _login,
                          child: auth.isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign in securely'),
                        ),
                        const SizedBox(height: 22),
                        config.when(
                          loading: () => const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          error: (_, _) => const Text(
                            'Registration availability could not be checked.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          data: (value) => value.registrationsEnabled
                              ? OutlinedButton(
                                  onPressed: () => context.go('/register'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  child: const Text('Create a Travla account'),
                                )
                              : const Text(
                                  'Public registration is currently closed. Existing users can still sign in.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: const TextStyle(
        color: AppColors.danger,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

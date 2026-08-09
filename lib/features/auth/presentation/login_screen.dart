import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/features/auth/data/registration_providers.dart';
import 'package:travla_customer_app/features/auth/domain/registration.dart';
import 'package:travla_customer_app/features/auth/presentation/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(authControllerProvider.notifier)
        .login(email: _email.text.trim(), password: _password.text);

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

    return AuthPageScaffold(
      title: 'Welcome back',
      subtitle:
          'Sign in to manage your vehicles, documents and transactions securely.',
      footer: config.when(
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
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        data: (value) => value.registrationsEnabled
            ? AuthSwitch(
                prompt: 'New to Travla?',
                action: 'Create account',
                onPressed: () => context.go('/register'),
              )
            : const Text(
                'Public registration is currently closed. Existing customers can still sign in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumAuthField(
                controller: _email,
                focusNode: _emailFocus,
                label: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                      ? null
                      : 'Enter a valid email address.';
                },
              ),
              const SizedBox(height: 14),
              PremiumAuthField(
                controller: _password,
                focusNode: _passwordFocus,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                obscureText: _obscure,
                onSubmitted: (_) => _login(),
                suffix: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      key: ValueKey(_obscure),
                      color: AppColors.muted,
                      size: 21,
                    ),
                  ),
                ),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'Enter your password.' : null,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child:
                    auth.errorMessage != null && auth.verificationPhone == null
                    ? Padding(
                        key: ValueKey(auth.errorMessage),
                        padding: const EdgeInsets.only(top: 14),
                        child: AuthInlineMessage(message: auth.errorMessage!),
                      )
                    : const SizedBox.shrink(key: ValueKey('no-error')),
              ),
              const SizedBox(height: 22),
              AuthPrimaryButton(
                label: 'Sign in securely',
                loading: auth.isSubmitting,
                onPressed: auth.isSubmitting ? null : _login,
              ),
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Your session is encrypted and securely stored',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

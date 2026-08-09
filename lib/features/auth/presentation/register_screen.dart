import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/auth/data/registration_providers.dart';
import 'package:travla_customer_app/features/auth/domain/registration.dart';
import 'package:travla_customer_app/features/auth/presentation/auth_widgets.dart';
import 'package:travla_customer_app/features/auth/presentation/recaptcha_challenge.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    this.transferId,
    this.expires,
    this.signature,
    super.key,
  });

  final String? transferId;
  final String? expires;
  final String? signature;

  bool get hasInvitation =>
      transferId?.isNotEmpty == true &&
      expires?.isNotEmpty == true &&
      signature?.isNotEmpty == true;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _identityKey = GlobalKey<FormState>();
  final _securityKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  int _step = 0;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _submitting = false;
  bool _loadingInvitation = false;
  String? _error;
  TransferInvitationPrefill? _invitation;

  @override
  void initState() {
    super.initState();
    if (widget.hasInvitation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvitation());
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _loadInvitation() async {
    setState(() => _loadingInvitation = true);
    try {
      final value = await ref
          .read(authRepositoryProvider)
          .transferInvitation(
            transferId: widget.transferId!,
            expires: widget.expires!,
            signature: widget.signature!,
          );
      if (!mounted) return;
      _firstName.text = value.firstName;
      _lastName.text = value.lastName;
      _email.text = value.email;
      _phone.text = value.phone;
      setState(() => _invitation = value);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loadingInvitation = false);
    }
  }

  void _continueToSecurity() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_identityKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = null;
      _step = 1;
    });
  }

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_step == 1) {
      setState(() {
        _error = null;
        _step = 0;
      });
      return;
    }
    context.go('/login');
  }

  Future<void> _submit(RegistrationConfig config) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_securityKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    String? captchaToken;
    try {
      if (config.recaptchaEnabled) {
        final url = config.recaptchaChallengeUrl;
        if (url == null || url.isEmpty) {
          throw const ApiFailure(
            'The security check is temporarily unavailable.',
          );
        }
        captchaToken = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: AppColors.white,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (_) => FractionallySizedBox(
            heightFactor: .72,
            child: RecaptchaChallenge(url: url),
          ),
        );
        if (captchaToken == null || captchaToken.isEmpty) {
          throw const ApiFailure('Complete the security check to continue.');
        }
      }

      final payload = <String, dynamic>{
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'password_confirmation': _confirmation.text,
        if (widget.hasInvitation) ...{
          'transfer_invitation': widget.transferId,
          'invitation_expires': widget.expires,
          'invitation_signature': widget.signature,
        },
      };
      if (captchaToken != null) payload['recaptcha_token'] = captchaToken;

      final result = await ref.read(authRepositoryProvider).register(payload);
      if (mounted) context.go('/verify-otp', extra: result);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(registrationConfigProvider);
    return config.when(
      loading: () => const AuthPageScaffold(
        title: 'Create your account',
        subtitle: 'Checking registration availability securely.',
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => AuthPageScaffold(
        title: 'Unable to connect',
        subtitle: 'Registration availability could not be checked.',
        onBack: () => context.go('/login'),
        child: _StateMessage(
          icon: Icons.cloud_off_rounded,
          message: 'Check your connection, then try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(registrationConfigProvider),
        ),
      ),
      data: (value) {
        if (!value.registrationsEnabled && !widget.hasInvitation) {
          return AuthPageScaffold(
            title: 'Registration opens soon',
            subtitle:
                'Travla is preparing for launch. Existing customers can still sign in.',
            onBack: () => context.go('/login'),
            child: _StateMessage(
              icon: Icons.lock_clock_rounded,
              message:
                  'New public accounts are temporarily paused by the Travla administrator.',
              actionLabel: 'Go to sign in',
              onAction: () => context.go('/login'),
            ),
          );
        }
        return _buildForm(value);
      },
    );
  }

  Widget _buildForm(RegistrationConfig config) {
    if (_loadingInvitation) {
      return AuthPageScaffold(
        title: 'Preparing your account',
        subtitle: 'Bringing your ownership transfer details across securely.',
        onBack: () => context.go('/login'),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final title = widget.hasInvitation
        ? 'Activate your account'
        : _step == 0
        ? 'Create your account'
        : 'Secure your account';
    final subtitle = widget.hasInvitation
        ? 'Confirm your details, then create a password to receive your vehicle transfer.'
        : _step == 0
        ? 'Tell us who you are and how Travla can reach you.'
        : 'Choose a strong password to protect your vehicle records.';

    return AuthPageScaffold(
      title: title,
      subtitle: subtitle,
      onBack: _back,
      headerAccessory: _StepIndicator(step: _step + 1),
      footer: AuthSwitch(
        prompt: 'Already have an account?',
        action: 'Sign in',
        onPressed: () => context.go('/login'),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final enteringFrom = _step == 0 ? -.05 : .05;
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(enteringFrom, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _step == 0
              ? _IdentityStep(
                  key: const ValueKey('identity'),
                  formKey: _identityKey,
                  firstName: _firstName,
                  lastName: _lastName,
                  email: _email,
                  phone: _phone,
                  invitation: _invitation,
                  error: _error,
                  onContinue: _continueToSecurity,
                )
              : _SecurityStep(
                  key: const ValueKey('security'),
                  formKey: _securityKey,
                  email: _email.text,
                  phone: _phone.text,
                  password: _password,
                  confirmation: _confirmation,
                  obscurePassword: _obscurePassword,
                  obscureConfirmation: _obscureConfirmation,
                  recaptchaEnabled: config.recaptchaEnabled,
                  submitting: _submitting,
                  error: _error,
                  onEditDetails: () => setState(() => _step = 0),
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  onToggleConfirmation: () => setState(
                    () => _obscureConfirmation = !_obscureConfirmation,
                  ),
                  onSubmit: () => _submit(config),
                ),
        ),
      ),
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.formKey,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.invitation,
    required this.error,
    required this.onContinue,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController email;
  final TextEditingController phone;
  final TransferInvitationPrefill? invitation;
  final String? error;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final locksEmail = invitation?.email.isNotEmpty == true;
    final locksPhone = invitation?.phone.isNotEmpty == true;

    return AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (invitation != null) ...[
              _TransferInvitationCard(invitation: invitation!),
              const SizedBox(height: 16),
            ],
            PremiumAuthField(
              controller: firstName,
              label: 'First name',
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              validator: _requiredName,
            ),
            const SizedBox(height: 13),
            PremiumAuthField(
              controller: lastName,
              label: 'Last name',
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.familyName],
              validator: _requiredName,
            ),
            const SizedBox(height: 13),
            PremiumAuthField(
              controller: email,
              label: 'Email address',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              readOnly: locksEmail,
              suffix: locksEmail ? const _LockedFieldIcon() : null,
              validator: (value) {
                final input = value?.trim() ?? '';
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input)
                    ? null
                    : 'Enter a valid email address.';
              },
            ),
            const SizedBox(height: 13),
            PremiumAuthField(
              controller: phone,
              label: 'Nigerian phone number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              readOnly: locksPhone,
              suffix: locksPhone ? const _LockedFieldIcon() : null,
              onSubmitted: (_) => onContinue(),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length >= 10
                    ? null
                    : 'Enter a valid Nigerian phone number.';
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              AuthInlineMessage(message: error!),
            ],
            const SizedBox(height: 22),
            AuthPrimaryButton(label: 'Continue', onPressed: onContinue),
          ],
        ),
      ),
    );
  }

  static String? _requiredName(String? value) {
    final input = value?.trim() ?? '';
    return input.length >= 2 ? null : 'Enter at least 2 characters.';
  }
}

class _SecurityStep extends StatelessWidget {
  const _SecurityStep({
    required this.formKey,
    required this.email,
    required this.phone,
    required this.password,
    required this.confirmation,
    required this.obscurePassword,
    required this.obscureConfirmation,
    required this.recaptchaEnabled,
    required this.submitting,
    required this.error,
    required this.onEditDetails,
    required this.onTogglePassword,
    required this.onToggleConfirmation,
    required this.onSubmit,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final String email;
  final String phone;
  final TextEditingController password;
  final TextEditingController confirmation;
  final bool obscurePassword;
  final bool obscureConfirmation;
  final bool recaptchaEnabled;
  final bool submitting;
  final String? error;
  final VoidCallback onEditDetails;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmation;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContactSummary(email: email, phone: phone, onEdit: onEditDetails),
          const SizedBox(height: 16),
          PremiumAuthField(
            controller: password,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            suffix: _VisibilityButton(
              obscure: obscurePassword,
              onPressed: onTogglePassword,
            ),
            validator: _passwordValidator,
          ),
          const SizedBox(height: 13),
          PremiumAuthField(
            controller: confirmation,
            label: 'Confirm password',
            icon: Icons.lock_reset_rounded,
            obscureText: obscureConfirmation,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            suffix: _VisibilityButton(
              obscure: obscureConfirmation,
              onPressed: onToggleConfirmation,
            ),
            onSubmitted: (_) => onSubmit(),
            validator: (value) {
              final baseError = _passwordValidator(value);
              if (baseError != null) return baseError;
              return value == password.text ? null : 'Passwords do not match.';
            },
          ),
          const SizedBox(height: 11),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: AppColors.forest600,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Use at least 8 characters with letters and numbers.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            AuthInlineMessage(message: error!),
          ],
          const SizedBox(height: 22),
          AuthPrimaryButton(
            label: recaptchaEnabled ? 'Continue securely' : 'Create account',
            loading: submitting,
            onPressed: submitting ? null : onSubmit,
          ),
          if (recaptchaEnabled) ...[
            const SizedBox(height: 11),
            const Text(
              'A quick security check will open before your account is created.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  static String? _passwordValidator(String? value) {
    final input = value ?? '';
    if (input.length < 8 ||
        !input.contains(RegExp(r'[A-Za-z]')) ||
        !input.contains(RegExp(r'\d'))) {
      return 'Use 8+ characters with letters and numbers.';
    }
    return null;
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E3DB)),
      ),
      child: Text(
        '$step of 2',
        style: const TextStyle(
          color: AppColors.forest700,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ContactSummary extends StatelessWidget {
  const _ContactSummary({
    required this.email,
    required this.phone,
    required this.onEdit,
  });

  final String email;
  final String phone;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.forest100),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.forest600),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  phone,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }
}

class _TransferInvitationCard extends StatelessWidget {
  const _TransferInvitationCard({required this.invitation});

  final TransferInvitationPrefill invitation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC9B7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppColors.orangeDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ownership transfer ready',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${invitation.vehicle}${invitation.plateNumber.isEmpty ? '' : ' • ${invitation.plateNumber}'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityButton extends StatelessWidget {
  const _VisibilityButton({required this.obscure, required this.onPressed});

  final bool obscure;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscure ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          key: ValueKey(obscure),
          color: AppColors.muted,
          size: 21,
        ),
      ),
    );
  }
}

class _LockedFieldIcon extends StatelessWidget {
  const _LockedFieldIcon();

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: 'Provided by the transfer invitation',
      child: Icon(Icons.lock_outline_rounded, color: AppColors.muted, size: 19),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            color: AppColors.forest50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.forest700, size: 29),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 22),
        AuthPrimaryButton(label: actionLabel, onPressed: onAction),
      ],
    );
  }
}

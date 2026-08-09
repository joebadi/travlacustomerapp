import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/auth/data/registration_providers.dart';
import 'package:travla_customer_app/features/auth/domain/registration.dart';
import 'package:travla_customer_app/features/auth/presentation/recaptcha_challenge.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
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

  Future<void> _submit(RegistrationConfig config) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
      if (captchaToken != null) {
        payload['recaptcha_token'] = captchaToken;
      }
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
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const TravlaLogo(width: 116),
      ),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _StateMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Unable to check registration',
          message: 'Check your connection, then try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(registrationConfigProvider),
        ),
        data: (value) {
          if (!value.registrationsEnabled && !widget.hasInvitation) {
            return _StateMessage(
              icon: Icons.lock_clock_rounded,
              title: 'Registration is not open yet',
              message:
                  'Travla is preparing for launch. Existing customers can continue to sign in.',
              actionLabel: 'Go to sign in',
              onAction: () => context.go('/login'),
            );
          }
          return _buildForm(value);
        },
      ),
    );
  }

  Widget _buildForm(RegistrationConfig config) {
    if (_loadingInvitation) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.hasInvitation
                  ? 'Activate your account'
                  : 'Create your account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.hasInvitation
                  ? 'Your transfer details have been securely brought across. Confirm them and choose a password.'
                  : 'Start managing your vehicles and documents in one secure place.',
              style: const TextStyle(color: AppColors.muted, height: 1.5),
            ),
            if (_invitation != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.forest50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.forest100),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.forest700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_invitation!.vehicle}${_invitation!.plateNumber.isEmpty ? '' : ' • ${_invitation!.plateNumber}'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    _firstName,
                    'First name',
                    Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _lastName,
                    'Last name',
                    Icons.person_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _field(
              _email,
              'Email address',
              Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              readOnly:
                  widget.hasInvitation && _invitation?.email.isNotEmpty == true,
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address.'
                  : null,
            ),
            const SizedBox(height: 14),
            _field(
              _phone,
              'Nigerian phone number',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              readOnly:
                  widget.hasInvitation && _invitation?.phone.isNotEmpty == true,
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length < 10
                    ? 'Enter a valid Nigerian phone number.'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            _passwordField(_password, 'Password', _obscurePassword, () {
              setState(() => _obscurePassword = !_obscurePassword);
            }),
            const SizedBox(height: 14),
            _passwordField(
              _confirmation,
              'Confirm password',
              _obscureConfirmation,
              () {
                setState(() => _obscureConfirmation = !_obscureConfirmation);
              },
              confirmation: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Use at least 8 characters, including letters and numbers.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _InlineMessage(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : () => _submit(config),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      config.recaptchaEnabled
                          ? 'Continue securely'
                          : 'Create account',
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      textCapitalization: keyboardType == null
          ? TextCapitalization.words
          : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: readOnly
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : null,
      ),
      validator:
          validator ??
          (value) => (value?.trim().isEmpty ?? true) ? 'Required.' : null,
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    bool obscure,
    VoidCallback toggle, {
    bool confirmation = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (value) {
        if (value == null ||
            value.length < 8 ||
            !value.contains(RegExp(r'[A-Za-z]')) ||
            !value.contains(RegExp(r'\d'))) {
          return 'Use 8+ letters and numbers.';
        }
        if (confirmation && value != _password.text) {
          return 'Passwords do not match.';
        }
        return null;
      },
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
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

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.forest700),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}

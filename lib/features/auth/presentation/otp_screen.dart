import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/auth/domain/registration.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.registration, super.key});
  final RegistrationStart registration;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _remaining = 45;
  String? _notice;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _remaining = 45;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining <= 1) {
        timer.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) {
      setState(() => _notice = 'Enter the complete 6-digit code.');
      return;
    }
    setState(() => _notice = null);
    await ref
        .read(authControllerProvider.notifier)
        .verifyRegistrationOtp(
          phone: widget.registration.phone,
          code: _code.text,
        );
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _notice = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resendOtp(widget.registration.phone);
      if (mounted) {
        setState(() => _notice = 'A new verification code has been sent.');
        _startTimer();
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _notice = failure.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final destination = widget.registration.destinationHint.isEmpty
        ? widget.registration.phone
        : widget.registration.destinationHint;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const TravlaLogo(width: 116),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.forest50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.forest700,
                  size: 29,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify your account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the code sent via ${widget.registration.deliveryChannel.toUpperCase()} to $destination.',
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  contentPadding: EdgeInsets.symmetric(vertical: 20),
                ),
                onSubmitted: (_) => _verify(),
              ),
              if (auth.errorMessage != null || _notice != null) ...[
                const SizedBox(height: 14),
                Text(
                  auth.errorMessage ?? _notice!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: auth.errorMessage != null
                        ? AppColors.danger
                        : AppColors.forest700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.isSubmitting ? null : _verify,
                child: auth.isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verify and continue'),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _remaining > 0 || _resending ? null : _resend,
                child: Text(
                  _remaining > 0
                      ? 'Resend code in ${_remaining}s'
                      : 'Resend code',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

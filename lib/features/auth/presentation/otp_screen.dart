import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/auth/domain/registration.dart';
import 'package:travla_customer_app/features/auth/presentation/auth_widgets.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.registration, super.key});

  final RegistrationStart registration;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  Timer? _timer;
  int _remaining = 45;
  String? _notice;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(_codeChanged);
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codeFocus.requestFocus();
    });
  }

  void _codeChanged() {
    setState(() => _notice = null);
    if (_code.text.length == 6) {
      Future<void>.delayed(const Duration(milliseconds: 160), () {
        if (mounted && _code.text.length == 6) _verify();
      });
    }
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
    _code.removeListener(_codeChanged);
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (ref.read(authControllerProvider).isSubmitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_code.text.length != 6) {
      setState(() => _notice = 'Enter the complete 6-digit code.');
      _codeFocus.requestFocus();
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
      if (!mounted) return;
      _code.clear();
      setState(() => _notice = 'A new verification code has been sent.');
      _startTimer();
      _codeFocus.requestFocus();
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

    return AuthPageScaffold(
      title: 'Verify your account',
      subtitle:
          'Enter the code sent via ${widget.registration.deliveryChannel.toUpperCase()} to $destination.',
      onBack: () => context.go('/login'),
      footer: TextButton(
        onPressed: _remaining > 0 || _resending ? null : _resend,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _resending
                ? 'Sending a new code…'
                : _remaining > 0
                ? 'Resend available in ${_remaining}s'
                : 'Didn’t receive it? Resend code',
            key: ValueKey('$_remaining-$_resending'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OtpCodeInput(controller: _code, focusNode: _codeFocus),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: auth.errorMessage != null || _notice != null
                ? Padding(
                    key: ValueKey(auth.errorMessage ?? _notice),
                    padding: const EdgeInsets.only(top: 16),
                    child: AuthInlineMessage(
                      message: auth.errorMessage ?? _notice!,
                      isError: auth.errorMessage != null,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-message')),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Verify and continue',
            icon: Icons.verified_user_outlined,
            loading: auth.isSubmitting,
            onPressed: auth.isSubmitting ? null : _verify,
          ),
          const SizedBox(height: 14),
          const Text(
            'For your security, this code expires shortly and can only be used once.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _OtpCodeInput extends StatelessWidget {
  const _OtpCodeInput({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final digits = controller.text.split('');
    return Semantics(
      label: 'Six digit verification code',
      textField: true,
      child: GestureDetector(
        onTap: focusNode.requestFocus,
        child: Stack(
          children: [
            Row(
              children: List.generate(6, (index) {
                final hasDigit = index < digits.length;
                final active = index == digits.length && digits.length < 6;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 62,
                    margin: EdgeInsets.only(right: index == 5 ? 0 : 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: active
                            ? AppColors.forest600
                            : hasDigit
                            ? AppColors.forest100
                            : const Color(0xFFD9DED9),
                        width: active ? 1.7 : 1,
                      ),
                      boxShadow: active
                          ? const [
                              BoxShadow(
                                color: Color(0x1F08754E),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ]
                          : const [],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        hasDigit ? digits[index] : '',
                        key: ValueKey(hasDigit ? digits[index] : 'empty$index'),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: .01,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: ''),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

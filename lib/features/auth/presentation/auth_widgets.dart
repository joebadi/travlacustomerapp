import 'dart:async';

import 'package:flutter/material.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';

const _authCanvas = Color(0xFFF8F6EE);

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.footer,
    this.headerAccessory,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? footer;
  final Widget? headerAccessory;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _authCanvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFEFA), Color(0xFFF6F2E5)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 600 ? 28.0 : 20.0;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  14,
                  horizontal,
                  keyboardInset > 0 ? 24 : 18,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 44,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (onBack != null)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: AuthBackButton(onPressed: onBack!),
                                  ),
                                if (headerAccessory != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: headerAccessory,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const AuthReveal(
                            child: Center(child: TravlaAuthMark()),
                          ),
                          const SizedBox(height: 14),
                          AuthReveal(
                            delay: const Duration(milliseconds: 70),
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: 24,
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.7,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AuthReveal(
                            delay: const Duration(milliseconds: 120),
                            child: Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.muted,
                                height: 1.5,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          AuthReveal(
                            delay: const Duration(milliseconds: 170),
                            offset: const Offset(0, .025),
                            child: child,
                          ),
                          if (footer != null) ...[
                            const SizedBox(height: 20),
                            AuthReveal(
                              delay: const Duration(milliseconds: 240),
                              child: footer!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class TravlaAuthMark extends StatelessWidget {
  const TravlaAuthMark({this.size = 64, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E6DC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16052C20),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/icon/travla-app-icon-foreground.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Travla',
        ),
      ),
    );
  }
}

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: .9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.arrow_back_rounded, size: 21),
        ),
      ),
    );
  }
}

class PremiumAuthField extends StatefulWidget {
  const PremiumAuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.suffix,
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  State<PremiumAuthField> createState() => _PremiumAuthFieldState();
}

class _PremiumAuthFieldState extends State<PremiumAuthField> {
  late final FocusNode _ownedFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode;

  @override
  void initState() {
    super.initState();
    _ownedFocusNode = FocusNode();
    _focusNode.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(covariant PremiumAuthField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocusNode).removeListener(_focusChanged);
      _focusNode.addListener(_focusChanged);
    }
  }

  void _focusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_focusChanged);
    _ownedFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: widget.readOnly ? const Color(0xFFF2F3EF) : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? AppColors.forest600 : const Color(0xFFD9DED9),
          width: focused ? 1.6 : 1,
        ),
        boxShadow: focused
            ? const [
                BoxShadow(
                  color: Color(0x1F08754E),
                  blurRadius: 20,
                  offset: Offset(0, 7),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x0C14211C),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        textCapitalization: widget.textCapitalization,
        validator: widget.validator,
        obscureText: widget.obscureText,
        readOnly: widget.readOnly,
        enabled: widget.enabled,
        onFieldSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        cursorColor: AppColors.forest600,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: focused ? AppColors.forest700 : AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: const TextStyle(
            color: AppColors.forest700,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              widget.icon,
              key: ValueKey(focused),
              color: focused ? AppColors.forest600 : AppColors.muted,
              size: 21,
            ),
          ),
          suffixIcon: widget.suffix,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorStyle: const TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon = Icons.arrow_forward_rounded,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        child: SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: enabled ? widget.onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest600,
              disabledBackgroundColor: AppColors.forest100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: widget.loading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: AppColors.white,
                      ),
                    )
                  : Row(
                      key: const ValueKey('label'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Icon(widget.icon, size: 19),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthInlineMessage extends StatelessWidget {
  const AuthInlineMessage({
    required this.message,
    this.isError = true,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.forest700;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFF1F0) : AppColors.forest50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .14)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline,
              color: color,
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthSwitch extends StatelessWidget {
  const AuthSwitch({
    required this.prompt,
    required this.action,
    required this.onPressed,
    super.key,
  });

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: const TextStyle(color: AppColors.muted)),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.forest600,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            minimumSize: const Size(0, 40),
          ),
          child: Text(
            action,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class AuthReveal extends StatefulWidget {
  const AuthReveal({
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, .05),
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<AuthReveal> createState() => _AuthRevealState();
}

class _AuthRevealState extends State<AuthReveal> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : widget.offset,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

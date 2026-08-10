import 'package:flutter/material.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';

/// A premium dropdown that anchors its **top-right corner to the trigger's
/// bottom-right corner** — so it always drops straight down from the control
/// that opened it, on any screen width, with no magic offsets. Dismisses on an
/// outside tap and animates in from the anchor.
class AnchoredMenu extends StatefulWidget {
  const AnchoredMenu({
    super.key,
    required this.width,
    required this.triggerBuilder,
    required this.menuBuilder,
    this.gap = 8,
  });

  /// Fixed width of the dropdown panel.
  final double width;

  /// Vertical gap between the trigger and the panel.
  final double gap;

  /// Builds the tappable control. Call [toggle] to open/close.
  final Widget Function(BuildContext context, bool isOpen, VoidCallback toggle)
  triggerBuilder;

  /// Builds the panel contents. Call [close] to dismiss (e.g. after navigation).
  final Widget Function(BuildContext context, VoidCallback close) menuBuilder;

  @override
  State<AnchoredMenu> createState() => _AnchoredMenuState();
}

class _AnchoredMenuState extends State<AnchoredMenu>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    reverseDuration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.95,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openMenu() {
    if (_open) return;
    setState(() => _open = true);
    _portal.show();
    _controller.forward(from: 0);
  }

  void _closeMenu() {
    if (!_open) return;
    _controller.reverse().whenComplete(() {
      if (!mounted) return;
      _portal.hide();
      setState(() => _open = false);
    });
  }

  void _toggle() => _open ? _closeMenu() : _openMenu();

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeMenu,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: Offset(0, widget.gap),
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    width: widget.width,
                    child: MenuSurface(
                      child: widget.menuBuilder(context, _closeMenu),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: widget.triggerBuilder(context, _open, _toggle),
      ),
    );
  }
}

/// The floating panel chrome — rounded, hairline-bordered, with a soft layered
/// shadow. Hosts a [Material] so inner items ripple correctly.
class MenuSurface extends StatelessWidget {
  const MenuSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest950.withValues(alpha: .20),
            blurRadius: 36,
            spreadRadius: -8,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: AppColors.forest950.withValues(alpha: .10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

/// A single dropdown action row — an icon in a soft chip plus a label, with a
/// full-width press ripple.
class PremiumMenuItem extends StatelessWidget {
  const PremiumMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.danger : AppColors.forest700;
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.forest50,
      splashColor: AppColors.forest50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: danger ? const Color(0xFFFDECEA) : AppColors.forest50,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: danger ? AppColors.danger : AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hairline separator sized for [MenuSurface].
class MenuDivider extends StatelessWidget {
  const MenuDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.border);
}

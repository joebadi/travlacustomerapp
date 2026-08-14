import 'package:flutter/material.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

/// A standard app bar that carries the Travla wordmark, so the brand is present
/// on every screen (not just the dashboard). On pushed sub-pages Flutter adds
/// the back button automatically; the logo stays centered.
///
class TravlaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TravlaAppBar({
    super.key,
    this.actions,
    this.bottom,
    this.logoWidth = 104,
  });

  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double logoWidth;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: TravlaLogo(width: logoWidth),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}

import 'package:flutter/material.dart';
import 'package:travla_customer_app/app/router/customer_shell.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

/// A standard app bar that carries the Travla wordmark, so the brand is present
/// on every screen (not just the dashboard). On pushed sub-pages Flutter adds
/// the back button automatically; the logo stays centered.
///
/// [showMenuButton] puts a hamburger before the logo, opening the shared
/// [AppDrawer] via [openAppDrawer] — set it on bottom-nav tab ROOTS only
/// (pushed sub-pages should keep their automatic back button instead).
class TravlaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TravlaAppBar({
    super.key,
    this.actions,
    this.bottom,
    this.logoWidth = 104,
    this.showMenuButton = false,
  });

  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double logoWidth;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      leading: showMenuButton
          ? IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_rounded),
              onPressed: openAppDrawer,
            )
          : null,
      automaticallyImplyLeading: !showMenuButton,
      title: TravlaLogo(width: logoWidth),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}

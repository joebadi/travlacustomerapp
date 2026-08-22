import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/features/home/presentation/dashboard_header_actions.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

/// The complete customer top bar: left-aligned branding, account controls and
/// automatic back navigation on pushed pages.
///
class TravlaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TravlaAppBar({
    super.key,
    this.actions,
    this.bottom,
    this.logoWidth = 100,
    this.showWallet = false,
    this.showNavigationActions = true,
  });

  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double logoWidth;
  final bool showWallet;
  final bool showNavigationActions;

  @override
  Widget build(BuildContext context) {
    final hasBackButton = Navigator.of(context).canPop();

    return AppBar(
      toolbarHeight: 60,
      centerTitle: false,
      titleSpacing: hasBackButton ? 0 : 16,
      foregroundColor: AppColors.white,
      iconTheme: const IconThemeData(color: AppColors.white),
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: Colors.transparent,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.forest950, AppColors.forest700],
          ),
          border: Border(
            bottom: BorderSide(color: Color(0x2EFFFFFF), width: 1),
          ),
        ),
      ),
      title: TravlaLogo(onDark: true, width: logoWidth),
      actions:
          actions ??
          (showNavigationActions
              ? [
                  DashboardHeaderActions(showWallet: showWallet),
                  const SizedBox(width: 12),
                ]
              : null),
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(60 + (bottom?.preferredSize.height ?? 0));
}

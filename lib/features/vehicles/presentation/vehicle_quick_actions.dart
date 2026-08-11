import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';

/// Reusable "Quick actions" block for the vehicle workspace — shown at the
/// bottom of every tab. Tiles use the same white-card + tinted icon-square
/// look as the dashboard's KPI tiles ([_StatTile] in home_screen.dart), for a
/// consistent visual language across the app, and deep-link to the flow
/// preselected for this vehicle.
class VehicleQuickActions extends StatelessWidget {
  const VehicleQuickActions({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.event_repeat_rounded,
        label: 'Renew papers',
        description: 'Registration & docs',
        iconColor: AppColors.forest700,
        iconBg: AppColors.forest50,
        onTap: () => context.push('/more/renewals/new?vehicle=$vehicleId'),
      ),
      _QuickAction(
        icon: Icons.report_gmailerrorred_rounded,
        label: 'Report Accident',
        description: 'File an insurance claim',
        iconColor: AppColors.orangeDark,
        iconBg: const Color(0xFFFBE9DE),
        onTap: () => context.push('/more/claims/new?vehicle=$vehicleId'),
      ),
      _QuickAction(
        icon: Icons.swap_horiz_rounded,
        label: 'Change Ownership',
        description: 'Transfer this vehicle',
        iconColor: const Color(0xFF2F6FEB),
        iconBg: const Color(0xFFE7EDFB),
        onTap: () => context.push('/more/transfers/new?vehicle=$vehicleId'),
      ),
      _QuickAction(
        icon: Icons.gpp_maybe_outlined,
        label: 'Report Stolen',
        description: 'Alert the registry',
        iconColor: AppColors.danger,
        iconBg: const Color(0xFFFCE7E5),
        onTap: () => context.push('/more/stolen/report?vehicle=$vehicleId'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Text(
            'QUICK ACTIONS',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        // A hand-rolled 2-column grid (IntrinsicHeight rows, no fixed
        // height) rather than a GridView with mainAxisExtent — see the note
        // on home_screen.dart's _StatGrid for why a fixed cell height risks
        // overflow at larger system font scales.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i += 2) ...[
              if (i > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _QuickActionBox(action: actions[i])),
                    const SizedBox(width: 12),
                    Expanded(
                      child: i + 1 < actions.length
                          ? _QuickActionBox(action: actions[i + 1])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;
}

class _QuickActionBox extends StatelessWidget {
  const _QuickActionBox({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: action.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.iconColor, size: 18),
              ),
              const SizedBox(height: 14),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                action.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

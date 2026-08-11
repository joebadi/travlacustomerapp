import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';

/// Reusable "Quick actions" block for the vehicle workspace — shown at the
/// bottom of every tab. Each action deep-links to the flow preselected for this
/// vehicle.
class VehicleQuickActions extends StatelessWidget {
  const VehicleQuickActions({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.event_repeat_rounded,
        label: 'Renew papers',
        tone: AppColors.orange,
        onTap: () => context.push('/more/renewals/new?vehicle=$vehicleId'),
      ),
      _QuickAction(
        icon: Icons.report_gmailerrorred_rounded,
        label: 'Report Accident',
        tone: AppColors.orangeDark,
        onTap: () => context.push('/more/claims/new?vehicle=$vehicleId'),
      ),
      _QuickAction(
        icon: Icons.swap_horiz_rounded,
        label: 'Change Ownership',
        tone: AppColors.forest700,
        onTap: () => context.push('/more/transfers/new?vehicle=$vehicleId'),
      ),
      _QuickAction(
        icon: Icons.gpp_maybe_outlined,
        label: 'Report Stolen',
        tone: AppColors.danger,
        onTap: () => context.push('/more/stolen/report?vehicle=$vehicleId'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Text(
            'QUICK ACTIONS',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: actions.map((a) => _QuickActionBox(action: a)).toList(),
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;
}

class _QuickActionBox extends StatelessWidget {
  const _QuickActionBox({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0.5,
      shadowColor: AppColors.forest950.withValues(alpha: .12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          action.tone,
                          Color.lerp(action.tone, Colors.black, .18) ?? action.tone,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: action.tone.withValues(alpha: .35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(action.icon, color: Colors.white, size: 22),
                  ),
                  Icon(Icons.arrow_outward_rounded, size: 16, color: AppColors.muted.withValues(alpha: .6)),
                ],
              ),
              Text(
                action.label,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

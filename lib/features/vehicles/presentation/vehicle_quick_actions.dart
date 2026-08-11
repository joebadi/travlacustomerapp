import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';

/// Reusable "Quick actions" block for the vehicle workspace — shown at the
/// bottom of every tab. Each action is a soft tinted tile with a solid icon
/// badge, title and description, and deep-links to the flow preselected for
/// this vehicle.
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
        badge: AppColors.forest950,
        background: const Color(0xFFE7F3EC),
        onTap: () => context.push('/more/renewals/new?vehicle=$vehicleId'),
      ),
      _QuickAction(
        icon: Icons.report_gmailerrorred_rounded,
        label: 'Report Accident',
        description: 'File an insurance claim',
        badge: AppColors.orange,
        background: const Color(0xFFFBE9DE),
        onTap: () => context.push('/more/claims/new?vehicle=$vehicleId'),
      ),
      _QuickAction(
        icon: Icons.swap_horiz_rounded,
        label: 'Change Ownership',
        description: 'Transfer this vehicle',
        badge: const Color(0xFF2F6FEB),
        background: const Color(0xFFE7EDFB),
        onTap: () => context.push('/more/transfers/new?vehicle=$vehicleId'),
      ),
      _QuickAction(
        icon: Icons.gpp_maybe_outlined,
        label: 'Report Stolen',
        description: 'Alert the registry',
        badge: AppColors.danger,
        background: const Color(0xFFFCE7E5),
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
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 168,
          ),
          itemBuilder: (context, index) =>
              _QuickActionBox(action: actions[index]),
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
    required this.badge,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color badge;
  final Color background;
  final VoidCallback onTap;
}

class _QuickActionBox extends StatelessWidget {
  const _QuickActionBox({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: action.background,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: action.badge,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(action.icon, color: Colors.white, size: 26),
              ),
              const Spacer(),
              Text(
                action.label,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                action.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

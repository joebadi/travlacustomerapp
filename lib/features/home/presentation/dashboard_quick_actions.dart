import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';

/// The dashboard's six primary service entry points.
///
/// Vehicle-bound actions resolve a vehicle before opening their flow. This
/// keeps the dashboard useful for customers with one car, several cars, or an
/// empty garage without sending an incomplete vehicle id to the API.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({required this.vehicles, super.key});

  final List<VehicleSummary> vehicles;

  @override
  Widget build(BuildContext context) {
    final actions = <_DashboardAction>[
      _DashboardAction(
        icon: Icons.event_repeat_rounded,
        label: 'Renew papers',
        color: AppColors.forest700,
        background: AppColors.forest50,
        onTap: () => _openVehicleFlow(
          context,
          title: 'Renew papers for',
          pathFor: (id) => '/more/renewals/new?vehicle=$id',
        ),
      ),
      _DashboardAction(
        icon: Icons.report_gmailerrorred_rounded,
        label: 'Report accident',
        color: AppColors.orangeDark,
        background: const Color(0xFFFBE9DE),
        onTap: () => _openVehicleFlow(
          context,
          title: 'Report an accident for',
          pathFor: (id) => '/more/claims/new?vehicle=$id',
        ),
      ),
      _DashboardAction(
        icon: Icons.swap_horiz_rounded,
        label: 'Change ownership',
        color: const Color(0xFF2F6FEB),
        background: const Color(0xFFE7EDFB),
        onTap: () => _openVehicleFlow(
          context,
          title: 'Transfer ownership of',
          pathFor: (id) => '/more/transfers/new?vehicle=$id',
        ),
      ),
      _DashboardAction(
        icon: Icons.gpp_maybe_outlined,
        label: 'Report stolen',
        color: AppColors.danger,
        background: const Color(0xFFFCE7E5),
        onTap: () => _openVehicleFlow(
          context,
          title: 'Report a stolen vehicle',
          pathFor: (id) => '/more/stolen/report?vehicle=$id',
        ),
      ),
      _DashboardAction(
        icon: Icons.badge_outlined,
        label: "Driver's licence",
        color: const Color(0xFF7B4FB3),
        background: const Color(0xFFF0E9F8),
        onTap: () => context.push('/more/drivers-license'),
      ),
      _DashboardAction(
        icon: Icons.corporate_fare_rounded,
        label: 'Fleet',
        color: AppColors.forest900,
        background: AppColors.forest100,
        onTap: () => context.push('/more/fleet'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
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
            TextButton(
              onPressed: () => context.push('/more/marketplace'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 2),
              ),
              child: const Text('Marketplace →'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final width = (constraints.maxWidth - gap * 2) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: actions
                  .map(
                    (action) => SizedBox(
                      width: width,
                      child: _ActionTile(action: action),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openVehicleFlow(
    BuildContext context, {
    required String title,
    required String Function(String vehicleId) pathFor,
  }) async {
    if (vehicles.isEmpty) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.white,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.directions_car_outlined,
                  size: 34,
                  color: AppColors.forest700,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Add a vehicle first',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text(
                  'This action needs a vehicle from your Travla garage.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          context.push('/vehicles/add-existing');
                        },
                        child: const Text('Add existing'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          context.push('/vehicles/register-new');
                        },
                        child: const Text('Register new'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (vehicles.length == 1) {
      context.push(pathFor(vehicles.first.id));
      return;
    }

    final selected = await showModalBottomSheet<VehicleSummary>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: vehicles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];
                  return ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.forest50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_car_outlined,
                        color: AppColors.forest700,
                      ),
                    ),
                    title: Text(
                      vehicle.displayName.isEmpty
                          ? 'Vehicle'
                          : vehicle.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: vehicle.plateNumber?.isNotEmpty == true
                        ? Text(vehicle.plateNumber!)
                        : null,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(vehicle),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && context.mounted) context.push(pathFor(selected.id));
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final _DashboardAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: action.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 18),
              ),
              const SizedBox(height: 11),
              Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 11.5,
                  height: 1.16,
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

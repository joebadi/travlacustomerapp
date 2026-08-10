import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';
import 'package:travla_customer_app/features/insurance/presentation/insurance_widgets.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';

/// Insurance home — surfaces policies expiring soon and lets the customer open
/// any vehicle's insurance workspace (verification + policies).
class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);
    final expiring = ref.watch(expiringPoliciesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Insurance')),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: () async {
          ref.invalidate(expiringPoliciesProvider);
          ref.invalidate(garageProvider);
          await ref.read(garageProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
          children: [
            expiring.maybeWhen(
              data: (policies) => policies.isEmpty
                  ? const SizedBox.shrink()
                  : _ExpiringSection(policies: policies),
              orElse: () => const SizedBox.shrink(),
            ),
            Card(
              margin: const EdgeInsets.only(bottom: 18),
              child: ListTile(
                onTap: () => context.push('/more/claims'),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.forest50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    color: AppColors.forest700,
                  ),
                ),
                title: const Text(
                  'Claims',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'File and track incident claims',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
            const _SectionLabel('Your vehicles'),
            garage.when(
              loading: () => const _Loading(),
              error: (error, _) => InsuranceErrorState(
                message: error is ApiFailure
                    ? error.message
                    : 'Your vehicles could not be loaded.',
                onRetry: () => ref.invalidate(garageProvider),
              ),
              data: (snapshot) => snapshot.vehicles.isEmpty
                  ? const _EmptyVehicles()
                  : Column(
                      children: snapshot.vehicles
                          .map((v) => _VehicleRow(vehicle: v))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiringSection extends StatelessWidget {
  const _ExpiringSection({required this.policies});

  final List<InsurancePolicy> policies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Expiring soon'),
        ...policies.map(
          (p) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFC9B7)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/more/insurance/${p.vehicleId}'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_moon_outlined,
                      color: AppColors.orangeDark,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.vehicleName ?? p.provider ?? 'Insurance policy',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            p.daysToExpiry != null
                                ? '${p.coverageLabel ?? 'Cover'} · expires in ${p.daysToExpiry} day${p.daysToExpiry == 1 ? '' : 's'}'
                                : '${p.coverageLabel ?? 'Cover'} · expiring soon',
                            style: const TextStyle(
                              color: AppColors.orangeDark,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.orangeDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle});

  final VehicleSummary vehicle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/more/insurance/${vehicle.id}'),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.forest50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.directions_car_filled_outlined,
            color: AppColors.forest700,
          ),
        ),
        title: Text(
          vehicle.displayName.isEmpty ? 'Vehicle' : vehicle.displayName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          vehicle.plateNumber?.isNotEmpty == true
              ? vehicle.plateNumber!
              : 'No plate assigned',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EmptyVehicles extends StatelessWidget {
  const _EmptyVehicles();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'Add a vehicle first, then you can record and verify its insurance here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          height: 66,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

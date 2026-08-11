import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';

class FleetOrgScreen extends ConsumerWidget {
  const FleetOrgScreen({super.key, required this.organisationId});

  final String organisationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(fleetOrgProvider(organisationId));
    final dashboard = ref.watch(fleetDashboardProvider(organisationId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(org.value?.name ?? 'Company'),
      ),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: () async {
          ref.invalidate(fleetOrgProvider(organisationId));
          ref.invalidate(fleetDashboardProvider(organisationId));
          await ref.read(fleetOrgProvider(organisationId).future).catchError((_) => throw Exception());
        },
        child: org.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            children: [
              Center(child: Text(error is ApiFailure ? error.message : 'This company could not be loaded.', textAlign: TextAlign.center)),
            ],
          ),
          data: (detail) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _RoleBanner(detail: detail),
              const SizedBox(height: 14),
              dashboard.maybeWhen(
                data: (k) => _KpiGrid(kpis: k, fuelBalance: detail.fuelBalanceNaira),
                orElse: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
              ),
              const SizedBox(height: 18),
              _Label('Members (${detail.members.length})'),
              ...detail.members.map((m) => _MemberRow(member: m)),
              const SizedBox(height: 18),
              _Label('Vehicles (${detail.vehicles.length})'),
              if (detail.vehicles.isEmpty)
                const _Empty('No vehicles assigned to your scope yet.')
              else
                ...detail.vehicles.map((v) => _VehicleRow(vehicle: v)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBanner extends StatelessWidget {
  const _RoleBanner({required this.detail});

  final FleetOrgDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail.name ?? 'Company',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                if (detail.myRoleLabel != null) ...[
                  const SizedBox(height: 2),
                  Text('You are ${detail.myRoleLabel}',
                      style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 12)),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Fuel available', style: TextStyle(color: Colors.white70, fontSize: 10)),
              Text('₦${detail.fuelAvailableNaira}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis, required this.fuelBalance});

  final FleetKpis kpis;
  final String fuelBalance;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _tile('Vehicles', '${kpis.totalVehicles}', Icons.directions_car_filled_outlined),
      _tile('Compliant', '${kpis.compliantVehicles}', Icons.verified_outlined, tone: AppColors.forest700),
      _tile('Need attention', '${kpis.attentionVehicles}', Icons.warning_amber_rounded, tone: AppColors.orangeDark),
      _tile('Live now', '${kpis.liveVehicles}/${kpis.trackedVehicles}', Icons.sensors_rounded),
      _tile('Members', '${kpis.activeMembers}', Icons.groups_outlined),
      _tile('Fuel balance', '₦$fuelBalance', Icons.local_gas_station_outlined),
    ];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.favorite_rounded, color: AppColors.forest700, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Fleet health: ${kpis.healthLabel ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text('${kpis.healthScore}%', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.forest700, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: tiles,
        ),
      ],
    );
  }

  Widget _tile(String label, String value, IconData icon, {Color tone = AppColors.ink}) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: tone)),
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10.5), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final OrgMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.forest100,
            foregroundColor: AppColors.forest800,
            child: Text((member.name ?? '?').isNotEmpty ? member.name![0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name ?? 'Member', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                Text([member.roleLabel, member.seesAllRegions ? 'All regions' : 'Scoped'].where((s) => s != null).join(' · '),
                    style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
              ],
            ),
          ),
          if (member.status != null && member.status != 'ACTIVE')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.orangeSoft, borderRadius: BorderRadius.circular(20)),
              child: Text(member.status!.toLowerCase(),
                  style: const TextStyle(color: AppColors.orangeDark, fontSize: 9.5, fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle});

  final OrgVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final tone = switch (vehicle.complianceStatus) {
      'VALID' => AppColors.forest700,
      'EXPIRING_SOON' => AppColors.orangeDark,
      'EXPIRED' => AppColors.danger,
      _ => AppColors.muted,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.forest50, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.directions_car_filled_outlined, color: AppColors.forest700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                Text(
                  [
                    if (vehicle.plateNumber != null) vehicle.plateNumber!,
                    if (vehicle.regionName != null) vehicle.regionName!,
                    if (vehicle.driverName != null) vehicle.driverName!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (vehicle.hasTracker) const Icon(Icons.sensors_rounded, size: 15, color: AppColors.forest600),
          const SizedBox(width: 6),
          if (vehicle.complianceLabel != null)
            Text(vehicle.complianceLabel!, style: TextStyle(color: tone, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
      );
}

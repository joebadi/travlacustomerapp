import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';
import 'package:travla_customer_app/shared/widgets/section_heading.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(garageProvider);
    await ref.read(garageProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Vehicles')),
      body: garage.when(
        loading: () => const _GarageLoading(),
        error: (error, stackTrace) => _GarageError(
          message: error is ApiFailure
              ? error.message
              : 'Your vehicle workspace could not be loaded.',
          onRetry: () => ref.invalidate(garageProvider),
        ),
        data: (snapshot) => RefreshIndicator(
          color: AppColors.forest700,
          onRefresh: () => _refresh(ref),
          child: _GarageContent(snapshot: snapshot),
        ),
      ),
    );
  }
}

class _GarageContent extends StatelessWidget {
  const _GarageContent({required this.snapshot});

  final GarageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final hasAnyVehicle =
        snapshot.vehicles.isNotEmpty || snapshot.incomingVehicles.isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
      children: [
        SectionHeading(
          title: 'Your vehicle workspace',
          description: hasAnyVehicle
              ? '${snapshot.vehicles.length} owned · ${snapshot.incomingVehicles.length} incoming'
              : 'Owned vehicles, incoming transfers and document readiness stay together.',
        ),
        if (snapshot.pendingTransfers.isNotEmpty) ...[
          const SizedBox(height: 18),
          ...snapshot.pendingTransfers.map(_PendingTransferCard.new),
        ],
        if (snapshot.incomingVehicles.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _ListLabel('INCOMING OWNERSHIP'),
          ...snapshot.incomingVehicles.map(_IncomingVehicleCard.new),
        ],
        if (snapshot.vehicles.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _ListLabel('OWNED VEHICLES'),
          ...snapshot.vehicles.map(_VehicleCard.new),
        ],
        if (!hasAnyVehicle && snapshot.pendingTransfers.isEmpty) ...[
          const SizedBox(height: 22),
          const _EmptyGarage(),
        ],
      ],
    );
  }
}

class _PendingTransferCard extends StatelessWidget {
  const _PendingTransferCard(this.transfer);

  final IncomingTransferSummary transfer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC9B7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_unread_outlined, color: AppColors.orange),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incoming ownership transfer',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  '${transfer.currentOwnerName} is transferring ${transfer.vehicleName.isEmpty ? 'a vehicle' : transfer.vehicleName} to you.',
                  style: const TextStyle(color: AppColors.muted, height: 1.45),
                ),
                if (transfer.trackingNumber.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    transfer.trackingNumber,
                    style: const TextStyle(
                      color: AppColors.orangeDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingVehicleCard extends StatelessWidget {
  const _IncomingVehicleCard(this.transfer);

  final IncomingTransferSummary transfer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF0F2F1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE2E0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.directions_car_outlined,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transfer.vehicleName.isEmpty
                        ? 'Incoming vehicle'
                        : transfer.vehicleName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF53615B),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    transfer.plateNumber?.isNotEmpty == true
                        ? transfer.plateNumber!
                        : 'Plate not assigned',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    transfer.reviewStatusLabel.isEmpty
                        ? 'Transfer in progress'
                        : transfer.reviewStatusLabel,
                    style: const TextStyle(
                      color: AppColors.orangeDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.lock_clock_outlined, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard(this.vehicle);

  final VehicleSummary vehicle;

  @override
  Widget build(BuildContext context) {
    final status = _StatusStyle.from(vehicle.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 154,
            width: double.infinity,
            child: vehicle.images.isEmpty
                ? const _VehicleImageFallback()
                : Image.network(
                    vehicle.images.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const _VehicleImageFallback();
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.displayName.isEmpty
                                ? 'Vehicle'
                                : vehicle.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            [
                              if (vehicle.year != null) vehicle.year.toString(),
                              if (vehicle.color.isNotEmpty) vehicle.color,
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: status.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        vehicle.statusLabel ?? 'Papers not added',
                        style: TextStyle(
                          color: status.foreground,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.pin_outlined,
                      size: 18,
                      color: AppColors.forest700,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      vehicle.plateNumber?.isNotEmpty == true
                          ? vehicle.plateNumber!
                          : 'Plate not assigned',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      '${vehicle.documentsCount} paper${vehicle.documentsCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleImageFallback extends StatelessWidget {
  const _VehicleImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.forest50,
      child: const Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          size: 60,
          color: AppColors.forest100,
        ),
      ),
    );
  }
}

class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppColors.forest100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_road_rounded,
                size: 32,
                color: AppColors.forest700,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Start with your first vehicle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your add-vehicle and new-registration choices will appear here in the next form milestone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _GarageLoading extends StatelessWidget {
  const _GarageLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: List.generate(
        3,
        (index) => Container(
          height: index == 0 ? 76 : 220,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _GarageError extends StatelessWidget {
  const _GarageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListLabel extends StatelessWidget {
  const _ListLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle(this.foreground, this.background);

  final Color foreground;
  final Color background;

  factory _StatusStyle.from(String? status) {
    return switch (status) {
      'VALID' => const _StatusStyle(AppColors.forest700, AppColors.forest100),
      'EXPIRING_SOON' => const _StatusStyle(
        AppColors.orangeDark,
        AppColors.orangeSoft,
      ),
      'EXPIRED' => const _StatusStyle(AppColors.danger, Color(0xFFFFE9E7)),
      _ => const _StatusStyle(AppColors.muted, Color(0xFFEEF1F0)),
    };
  }
}

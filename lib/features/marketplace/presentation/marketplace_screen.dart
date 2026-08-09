import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/features/marketplace/data/marketplace_repository.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';

class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myMarketplaceListingsProvider);
    final garage = ref.watch(garageProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myMarketplaceListingsProvider);
          ref.invalidate(garageProvider);
          await ref.read(myMarketplaceListingsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.forest800, AppColors.forest950],
                ),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TRAVLA MARKETPLACE',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .9,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Trusted vehicle transactions.',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'List a vehicle with its ownership record and transfer readiness already connected.',
                    style: TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                    ),
                    onPressed: garage.asData?.value.vehicles.isNotEmpty == true
                        ? () => _chooseVehicle(
                            context,
                            garage.asData!.value.vehicles,
                          )
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('List a vehicle'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your listings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 3),
            const Text(
              'Active, reserved and withdrawn vehicle listings.',
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
            const SizedBox(height: 11),
            listings.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stackTrace) => const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Text(
                    'Your listings could not be loaded. Pull down to try again.',
                  ),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              color: AppColors.muted,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No marketplace listings yet',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Choose one of your vehicles to create a verified listing.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: items
                          .map(
                            (listing) => Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.orangeSoft,
                                  child: Icon(
                                    Icons.directions_car_outlined,
                                    color: AppColors.orangeDark,
                                  ),
                                ),
                                title: Text(
                                  listing.vehicleName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  '₦${listing.priceNaira} · ${listing.status}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseVehicle(
    BuildContext context,
    List<VehicleSummary> vehicles,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a vehicle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Eligibility is checked after you select its condition.',
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
            const SizedBox(height: 13),
            Flexible(
              child: ListView(
                children: vehicles
                    .map(
                      (vehicle) => Card(
                        child: ListTile(
                          title: Text(
                            vehicle.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${vehicle.year ?? ''} · ${vehicle.plateNumber ?? 'No plate'}',
                          ),
                          trailing: const Icon(Icons.arrow_forward_rounded),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push(
                              '/more/marketplace/list-new?vehicle=${vehicle.id}',
                            );
                          },
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

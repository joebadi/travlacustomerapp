import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/marketplace/data/marketplace_repository.dart';
import 'package:travla_customer_app/features/marketplace/domain/marketplace_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_detail_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';

class NewMarketplaceListingScreen extends ConsumerStatefulWidget {
  const NewMarketplaceListingScreen({required this.vehicleId, super.key});
  final String vehicleId;
  @override
  ConsumerState<NewMarketplaceListingScreen> createState() =>
      _NewMarketplaceListingScreenState();
}

class _NewMarketplaceListingScreenState
    extends ConsumerState<NewMarketplaceListingScreen> {
  final _detailsKey = GlobalKey<FormState>();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _mileage = TextEditingController();
  final _description = TextEditingController();
  final _features = TextEditingController();
  String? _condition;
  String? _transmission;
  String? _fuelType;
  MarketplaceEligibility? _eligibility;
  final List<MarketplaceImageUpload> _newImages = [];
  final Set<String> _visibleExisting = {};
  String? _error;
  bool _checking = false;
  bool _publishing = false;
  int _step = 1;
  bool _galleryInitialized = false;

  @override
  void dispose() {
    _price.dispose();
    _location.dispose();
    _mileage.dispose();
    _description.dispose();
    _features.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(marketplaceMetaProvider);
    final vehicle = ref.watch(vehicleDetailProvider(widget.vehicleId));
    return Scaffold(
      appBar: AppBar(title: const Text('Sell on marketplace')),
      body: meta.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _PageError(
          message: error is ApiFailure
              ? error.message
              : 'Marketplace settings could not be loaded.',
          onRetry: () => ref.invalidate(marketplaceMetaProvider),
        ),
        data: (marketMeta) => vehicle.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _PageError(
            message: error is ApiFailure
                ? error.message
                : 'The selected vehicle could not be loaded.',
            onRetry: () =>
                ref.invalidate(vehicleDetailProvider(widget.vehicleId)),
          ),
          data: (selectedVehicle) {
            if (!_galleryInitialized) {
              _galleryInitialized = true;
              _visibleExisting.addAll(selectedVehicle.images);
            }
            if (!marketMeta.canSell) {
              return _SellerActivation(onActivate: _activateSelling);
            }
            return _buildFlow(marketMeta, selectedVehicle);
          },
        ),
      ),
    );
  }

  Widget _buildFlow(MarketplaceMeta meta, VehicleDetail vehicle) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 34),
      children: [
        _ListingHero(vehicle: vehicle),
        const SizedBox(height: 12),
        _Stepper(step: _step),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _Alert(message: _error!),
        ],
        const SizedBox(height: 12),
        if (_step == 1) _detailsStep(meta, vehicle),
        if (_step == 2) _photosStep(vehicle),
        if (_step == 3) _reviewStep(vehicle),
      ],
    );
  }

  Widget _detailsStep(MarketplaceMeta meta, VehicleDetail vehicle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Form(
          key: _detailsKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepHeading(
                number: '01',
                title: 'Price and describe it',
                body:
                    'Accurate information builds trust and reduces repetitive questions.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Asking price',
                  prefixText: '₦ ',
                ),
                validator: (value) =>
                    (double.tryParse(value?.replaceAll(',', '') ?? '') ?? 0) <=
                        0
                    ? 'Enter a valid asking price.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Vehicle location',
                  hintText: 'Lekki, Lagos',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) => value == null || value.trim().length < 3
                    ? 'Enter the vehicle location.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _condition,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: meta.conditions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.value,
                        child: Text(option.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _checking
                    ? null
                    : (value) {
                        setState(() {
                          _condition = value;
                          _eligibility = null;
                        });
                        if (value != null) _checkEligibility(value);
                      },
                validator: (value) =>
                    value == null ? 'Select the vehicle condition.' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _transmission,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Transmission',
                      ),
                      items: meta.transmissions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_pretty(value)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) =>
                          setState(() => _transmission = value),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _fuelType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Fuel'),
                      items: meta.fuelTypes
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_pretty(value)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) => setState(() => _fuelType = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mileage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mileage · optional',
                  suffixText: 'km',
                ),
                validator: (value) =>
                    value?.isNotEmpty == true && int.tryParse(value!) == null
                    ? 'Enter mileage using numbers only.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLength: 2000,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Owner’s description · optional',
                  alignLabelWithHint: true,
                ),
              ),
              TextFormField(
                controller: _features,
                decoration: const InputDecoration(
                  labelText: 'Features · comma separated',
                  hintText: 'Leather seats, reverse camera, sunroof',
                ),
              ),
              if (_checking) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
              if (_eligibility != null) ...[
                const SizedBox(height: 14),
                _EligibilityPanel(
                  eligibility: _eligibility!,
                  onDocuments: () =>
                      context.push('/vehicles/${vehicle.id}?tab=documents'),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _checking || _eligibility?.isReady != true
                      ? null
                      : () {
                          if (_detailsKey.currentState!.validate()) {
                            setState(() => _step = 2);
                          }
                        },
                  child: const Text('Continue to photos'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photosStep(VehicleDetail vehicle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeading(
              number: '02',
              title: 'Create the showroom',
              body:
                  'Hide existing photos from this listing only, or add new photos that will also join My Vehicles.',
            ),
            if (vehicle.images.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${_visibleExisting.length} of ${vehicle.images.length} existing photos shown',
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              const SizedBox(height: 9),
              _ImageGrid(
                count: vehicle.images.length,
                builder: (index) {
                  final url = vehicle.images[index];
                  final visible = _visibleExisting.contains(url);
                  return GestureDetector(
                    onTap: () => setState(
                      () => visible
                          ? _visibleExisting.remove(url)
                          : _visibleExisting.add(url),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(url, fit: BoxFit.cover),
                        if (!visible)
                          const ColoredBox(color: Color(0x99021B13)),
                        Positioned(
                          right: 5,
                          top: 5,
                          child: Icon(
                            visible
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: AppColors.white,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _newImages.length >= 8 ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _newImages.isEmpty
                    ? 'Add listing photos'
                    : '${_newImages.length} new photo(s) selected',
              ),
            ),
            if (_newImages.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ImageGrid(
                count: _newImages.length,
                builder: (index) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(_newImages[index].path), fit: BoxFit.cover),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Material(
                        color: AppColors.forest950.withValues(alpha: .75),
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: () =>
                              setState(() => _newImages.removeAt(index)),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.white,
                            size: 16,
                          ),
                          constraints: const BoxConstraints.tightFor(
                            width: 30,
                            height: 30,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step = 1),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton(
                    onPressed: _visibleExisting.isEmpty && _newImages.isEmpty
                        ? null
                        : () => setState(() => _step = 3),
                    child: const Text('Review listing'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewStep(VehicleDetail vehicle) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeading(
            number: '03',
            title: 'Review and publish',
            body:
                'Buyers can offer or accept your asking price. Ownership remains with you until the approved sale and transfer process completes.',
          ),
          const SizedBox(height: 17),
          _ReviewRow('Vehicle', vehicle.displayName),
          _ReviewRow('Plate', vehicle.plateNumber),
          _ReviewRow('Asking price', '₦${_price.text}'),
          _ReviewRow('Location', _location.text),
          _ReviewRow('Condition', _pretty(_condition ?? '')),
          _ReviewRow(
            'Photos',
            '${_visibleExisting.length + _newImages.length} visible',
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.forest950,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Protected payment does not transfer ownership immediately. Vehicle handover must first be confirmed with the buyer’s OTP.',
              style: TextStyle(
                color: Color(0xBBFFFFFF),
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _publishing
                      ? null
                      : () => setState(() => _step = 2),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _publishing ? null : _publish,
                  icon: _publishing
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.storefront_outlined),
                  label: Text(_publishing ? 'Publishing…' : 'Publish listing'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _activateSelling() async {
    try {
      await ref.read(marketplaceRepositoryProvider).activateSelling();
      ref.invalidate(marketplaceMetaProvider);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  Future<void> _checkEligibility(String condition) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(marketplaceRepositoryProvider)
          .eligibility(widget.vehicleId, condition);
      if (mounted) setState(() => _eligibility = result);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
    );
    if (!mounted || result == null) return;
    final accepted = <MarketplaceImageUpload>[];
    var oversize = false;
    for (final file in result.files.take(8 - _newImages.length)) {
      if (file.size > 5 * 1024 * 1024) {
        oversize = true;
        continue;
      }
      if (file.path != null) {
        accepted.add(MarketplaceImageUpload(path: file.path!, name: file.name));
      }
    }
    setState(() {
      _newImages.addAll(accepted);
      _error = oversize
          ? 'Some photos were skipped because they exceed 5 MB.'
          : null;
    });
  }

  Future<void> _publish() async {
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .createListing(
            vehicleId: widget.vehicleId,
            priceNaira: _price.text.replaceAll(',', ''),
            description: _description.text,
            condition: _condition!,
            transmission: _transmission ?? '',
            fuelType: _fuelType ?? '',
            mileageKm: _mileage.text,
            location: _location.text,
            features: _features.text
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false),
            visibleExistingImages: _visibleExisting.toList(growable: false),
            images: _newImages,
          );
      ref.invalidate(myMarketplaceListingsProvider);
      ref.invalidate(vehicleDetailProvider(widget.vehicleId));
      ref.invalidate(garageProvider);
      if (mounted) {
        context.go('/more/marketplace');
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _step = 1;
        });
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }
}

class _SellerActivation extends ConsumerWidget {
  const _SellerActivation({required this.onActivate});
  final Future<void> Function() onActivate;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.forest950,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SELLER ACTIVATION',
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'List vehicles you genuinely own.',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Activate selling once. Travla verifies your account and vehicle ownership before buyers see a listing.',
              style: TextStyle(
                color: Color(0xAAFFFFFF),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✓ Verified Travla account required\n\n✓ Vehicle must be linked to you\n\n✓ Dealer or temporary plates are excluded',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onActivate,
                  child: const Text('Activate marketplace selling'),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ListingHero extends StatelessWidget {
  const _ListingHero({required this.vehicle});
  final VehicleDetail vehicle;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.forest950,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.sell_outlined, color: AppColors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VERIFIED VEHICLE LISTING',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  vehicle.displayName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  vehicle.plateNumber,
                  style: const TextStyle(
                    color: Color(0x88FFFFFF),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(3, (index) {
      final number = index + 1;
      return Expanded(
        child: Container(
          margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: step == number ? AppColors.forest800 : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: step == number ? AppColors.forest800 : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            number < step ? '✓' : '$number',
            style: TextStyle(
              color: step == number
                  ? AppColors.white
                  : number < step
                  ? AppColors.forest700
                  : AppColors.muted,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }),
  );
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.number,
    required this.title,
    required this.body,
  });
  final String number;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'STEP $number',
        style: const TextStyle(
          color: AppColors.orangeDark,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
      const SizedBox(height: 3),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 3),
      Text(
        body,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          height: 1.4,
        ),
      ),
    ],
  );
}

class _EligibilityPanel extends StatelessWidget {
  const _EligibilityPanel({
    required this.eligibility,
    required this.onDocuments,
  });
  final MarketplaceEligibility eligibility;
  final VoidCallback onDocuments;
  @override
  Widget build(BuildContext context) {
    final ready = eligibility.isReady;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ready ? AppColors.forest50 : const Color(0xFFFFE9E7),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: ready ? AppColors.forest100 : const Color(0xFFF0C6C2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ready
                ? 'Ready for marketplace and transfer'
                : 'Not eligible for sale yet',
            style: TextStyle(
              color: ready ? AppColors.forest700 : AppColors.danger,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          if (ready)
            Text(
              eligibility.documentsExempt
                  ? 'Brand-new vehicles are exempt from existing-paper checks.'
                  : eligibility.expiredDocuments.isEmpty
                  ? 'All required transferable and renewable papers are present.'
                  : '${eligibility.expiredDocuments.length} expired paper(s) are allowed and can be renewed after transfer.',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                height: 1.4,
              ),
            )
          else ...[
            ...eligibility.problems.map(
              (problem) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $problem',
                  style: const TextStyle(color: AppColors.danger, fontSize: 10),
                ),
              ),
            ),
            TextButton(
              onPressed: onDocuments,
              child: const Text('Open vehicle documents'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.count, required this.builder});
  final int count;
  final Widget Function(int) builder;
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: count,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 7,
      mainAxisSpacing: 7,
    ),
    itemBuilder: (context, index) => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: builder(index),
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class _Alert extends StatelessWidget {
  const _Alert({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE9E7),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.danger, fontSize: 10),
    ),
  );
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.muted),
          const SizedBox(height: 9),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

String _pretty(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

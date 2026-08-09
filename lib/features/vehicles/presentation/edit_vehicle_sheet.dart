import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_detail_repository.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_setup_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_catalogue.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';

Future<bool?> showEditVehicleSheet({
  required BuildContext context,
  required VehicleDetail vehicle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => EditVehicleSheet(vehicle: vehicle),
  );
}

class EditVehicleSheet extends ConsumerStatefulWidget {
  const EditVehicleSheet({required this.vehicle, super.key});

  final VehicleDetail vehicle;

  @override
  ConsumerState<EditVehicleSheet> createState() => _EditVehicleSheetState();
}

class _EditVehicleSheetState extends ConsumerState<EditVehicleSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _yearController;
  late final TextEditingController _colorController;
  late final TextEditingController _plateController;
  late final TextEditingController _engineController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _reasonController;

  late String _make;
  late String _model;
  late String _category;
  late bool _isTinted;
  final List<String> _removedImages = [];
  final List<VehicleImageUpload> _newImages = [];
  String? _error;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _make = vehicle.make;
    _model = vehicle.model;
    _category = vehicle.categoryValue;
    _isTinted = vehicle.isTinted;
    _yearController = TextEditingController(
      text: vehicle.year?.toString() ?? '',
    );
    _colorController = TextEditingController(text: vehicle.color);
    _plateController = TextEditingController(text: vehicle.plateNumber);
    _engineController = TextEditingController(text: vehicle.engineNumber);
    _descriptionController = TextEditingController(text: vehicle.description);
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _engineController.dispose();
    _descriptionController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(vehicleCatalogueProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: .95,
        child: Column(
          children: [
            _SheetHeader(
              isSubmitting: _isSubmitting,
              onClose: () => Navigator.of(context).pop(false),
            ),
            const Divider(height: 1),
            Expanded(
              child: catalogue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _CatalogueError(
                  message: error is ApiFailure
                      ? error.message
                      : 'The vehicle catalogue could not be loaded.',
                  onRetry: () => ref.invalidate(vehicleCatalogueProvider),
                ),
                data: _buildForm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(VehicleCatalogue catalogue) {
    final selectedMake = _findMake(catalogue, _make);
    final selectedCategory = catalogue.category(_category);
    final currentImages = widget.vehicle.images
        .where((image) => !_removedImages.contains(image))
        .toList(growable: false);
    final identifierChanged = _identifierChanged;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          if (_error != null) ...[
            _FormAlert(message: _error!),
            const SizedBox(height: 14),
          ],
          const _SectionLabel(
            title: 'VEHICLE IDENTITY',
            description:
                'Make and model determine the category. VIN remains permanent.',
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: catalogue.makes.any((item) => item.name == _make)
                ? _make
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Make',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
            items: catalogue.makes
                .map(
                  (make) => DropdownMenuItem(
                    value: make.name,
                    child: Text(make.name),
                  ),
                )
                .toList(growable: false),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _make = value;
                      _model = '';
                      _category = '';
                      _error = null;
                    });
                  },
            validator: (value) => value == null || value.isEmpty
                ? 'Select the vehicle make.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('$_make-$_model'),
            initialValue:
                selectedMake?.models.any((item) => item.name == _model) == true
                ? _model
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Model',
              prefixIcon: Icon(Icons.commute_outlined),
            ),
            items: (selectedMake?.models ?? const <VehicleModelOption>[])
                .map(
                  (model) => DropdownMenuItem(
                    value: model.name,
                    child: Text(model.name),
                  ),
                )
                .toList(growable: false),
            onChanged: _isSubmitting || selectedMake == null
                ? null
                : (value) {
                    if (value == null) return;
                    final model = selectedMake.models.firstWhere(
                      (item) => item.name == value,
                    );
                    setState(() {
                      _model = value;
                      _category = model.category.isEmpty
                          ? catalogue.fallbackCategory
                          : model.category;
                      _error = null;
                    });
                  },
            validator: (value) => value == null || value.isEmpty
                ? 'Select the vehicle model.'
                : null,
          ),
          const SizedBox(height: 12),
          _LockedCategory(category: selectedCategory),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _yearController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year'),
                  validator: _validateYear,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _colorController,
                  enabled: !_isSubmitting,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Colour'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the colour.'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: widget.vehicle.chassisNumber,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'VIN / chassis number',
              helperText: 'Permanent vehicle identity — cannot be changed.',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel(
            title: 'CHANGEABLE IDENTIFIERS',
            description:
                'Plate reissues and engine swaps are checked and written to the audit trail.',
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _plateController,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Plate number',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            validator: (value) =>
                RegExp(r'^[A-Za-z0-9\- ]{5,15}$').hasMatch(value?.trim() ?? '')
                ? null
                : 'Use 5–15 letters, numbers, spaces or hyphens.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _engineController,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Engine number',
              prefixIcon: Icon(Icons.settings_outlined),
            ),
            validator: (value) =>
                RegExp(r'^[A-Za-z0-9\- ]{4,30}$').hasMatch(value?.trim() ?? '')
                ? null
                : 'Use 4–30 letters, numbers, spaces or hyphens.',
          ),
          if (identifierChanged) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              enabled: !_isSubmitting,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason for identifier change',
                hintText: 'For example: plate reissued after re-registration',
                prefixIcon: Icon(Icons.history_edu_outlined),
              ),
              validator: (value) =>
                  identifierChanged &&
                      (value == null || value.trim().length < 5)
                  ? 'Explain why the plate or engine number changed.'
                  : null,
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _isTinted,
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _isTinted = value),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text(
              'Tinted glass',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'This controls applicable tint-permit requirements.',
              style: TextStyle(fontSize: 10),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            enabled: !_isSubmitting,
            maxLength: 500,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Vehicle note · optional',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          const _SectionLabel(
            title: 'VEHICLE PHOTOS',
            description:
                'Keep up to six images. Removing an image here affects the main vehicle gallery.',
          ),
          const SizedBox(height: 11),
          if (currentImages.isNotEmpty || _newImages.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: currentImages.length + _newImages.length,
              itemBuilder: (context, index) {
                if (index < currentImages.length) {
                  final image = currentImages[index];
                  return _ExistingImageTile(
                    url: image,
                    onRemove: _isSubmitting
                        ? null
                        : () => setState(() => _removedImages.add(image)),
                  );
                }
                final newIndex = index - currentImages.length;
                final image = _newImages[newIndex];
                return _NewImageTile(
                  image: image,
                  onRemove: _isSubmitting
                      ? null
                      : () => setState(() => _newImages.removeAt(newIndex)),
                );
              },
            ),
          if (currentImages.isNotEmpty || _newImages.isNotEmpty)
            const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isSubmitting ||
                          currentImages.length + _newImages.length >= 6
                      ? null
                      : () => _pickImages(currentImages.length),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    currentImages.length + _newImages.length >= 6
                        ? 'Six-photo limit reached'
                        : 'Add photos',
                  ),
                ),
              ),
              if (_removedImages.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(_removedImages.clear),
                  child: const Text('Undo removals'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'JPG, PNG or WebP · maximum 5 MB each. New photos are appended after retained photos.',
            style: TextStyle(color: AppColors.muted, fontSize: 9, height: 1.4),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _isSubmitting
                ? null
                : () => _submit(catalogue, selectedCategory),
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSubmitting ? 'Saving changes…' : 'Save changes'),
          ),
        ],
      ),
    );
  }

  bool get _identifierChanged =>
      _normalizeIdentifier(_plateController.text) !=
          _normalizeIdentifier(widget.vehicle.plateNumber) ||
      _normalizeIdentifier(_engineController.text) !=
          _normalizeIdentifier(widget.vehicle.engineNumber);

  VehicleMakeOption? _findMake(VehicleCatalogue catalogue, String make) {
    for (final item in catalogue.makes) {
      if (item.name == make) return item;
    }
    return null;
  }

  String? _validateYear(String? value) {
    final year = int.tryParse(value ?? '');
    if (year == null) return 'Enter a valid year.';
    if (year < 1950 || year > DateTime.now().year + 1) {
      return 'Use a year from 1950 to ${DateTime.now().year + 1}.';
    }
    return null;
  }

  Future<void> _pickImages(int retainedCount) async {
    final remaining = 6 - retainedCount - _newImages.length;
    if (remaining <= 0) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
    );
    if (!mounted || result == null) return;

    final accepted = <VehicleImageUpload>[];
    var rejectedForSize = false;
    for (final file in result.files.take(remaining)) {
      if (file.size > 5 * 1024 * 1024) {
        rejectedForSize = true;
        continue;
      }
      if (file.path == null || file.path!.isEmpty) continue;
      accepted.add(
        VehicleImageUpload(
          path: file.path!,
          name: file.name,
          sizeBytes: file.size,
        ),
      );
    }
    setState(() {
      _newImages.addAll(accepted);
      _error = rejectedForSize
          ? 'Some images were skipped because they exceed 5 MB.'
          : null;
    });
  }

  Future<void> _submit(
    VehicleCatalogue catalogue,
    VehicleCategoryOption? category,
  ) async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final selectedMake = _findMake(catalogue, _make);
    final model = selectedMake?.models
        .where((item) => item.name == _model)
        .firstOrNull;
    if (model == null || category == null || _category.isEmpty) {
      setState(() {
        _error =
            'The category assigned to this make and model is not currently available.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(vehicleDetailRepositoryProvider)
          .updateVehicle(
            vehicleId: widget.vehicle.id,
            make: _make,
            model: _model,
            year: int.parse(_yearController.text),
            color: _colorController.text,
            plateNumber: _plateController.text,
            engineNumber: _engineController.text,
            category: _category,
            isTinted: _isTinted,
            description: _descriptionController.text,
            changeReason: _reasonController.text,
            newImages: _newImages,
            removedImages: _removedImages,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      final conflictField = failure.details['conflict_field']?.toString();
      setState(() {
        _error = conflictField == null
            ? failure.message
            : 'That $conflictField number belongs to another account. Travla opened an ownership verification request; the vehicle was not changed.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.isSubmitting, required this.onClose});

  final bool isSubmitting;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                onPressed: isSubmitting ? null : onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.forest100,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.edit_road_outlined,
                  color: AppColors.forest700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit vehicle',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Update details and maintain the main gallery.',
                      style: TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LockedCategory extends StatelessWidget {
  const _LockedCategory({required this.category});

  final VehicleCategoryOption? category;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Vehicle category',
        prefixIcon: Icon(Icons.category_outlined),
        helperText: 'Automatically assigned from the selected make and model.',
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category?.label ?? 'Select make and model',
              style: TextStyle(
                color: category == null ? AppColors.muted : AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.forest100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'LOCKED',
              style: TextStyle(
                color: AppColors.forest700,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.forest700,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ExistingImageTile extends StatelessWidget {
  const _ExistingImageTile({required this.url, required this.onRemove});

  final String url;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return _ImageTileFrame(
      onRemove: onRemove,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: AppColors.forest50,
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _NewImageTile extends StatelessWidget {
  const _NewImageTile({required this.image, required this.onRemove});

  final VehicleImageUpload image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return _ImageTileFrame(
      onRemove: onRemove,
      badge: 'NEW',
      child: Image.file(
        File(image.path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: AppColors.forest50,
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _ImageTileFrame extends StatelessWidget {
  const _ImageTileFrame({
    required this.child,
    required this.onRemove,
    this.badge,
  });

  final Widget child;
  final VoidCallback? onRemove;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x55000000), Colors.transparent],
                stops: [0, .45],
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Material(
              color: AppColors.forest950.withValues(alpha: .72),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const SizedBox.square(
                  dimension: 28,
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              left: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FormAlert extends StatelessWidget {
  const _FormAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E7),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFF5BBB5)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.danger,
          fontSize: 11,
          height: 1.4,
        ),
      ),
    );
  }
}

class _CatalogueError extends StatelessWidget {
  const _CatalogueError({required this.message, required this.onRetry});

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
            const Icon(Icons.cloud_off_outlined, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
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

String _normalizeIdentifier(String value) {
  return value.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
}

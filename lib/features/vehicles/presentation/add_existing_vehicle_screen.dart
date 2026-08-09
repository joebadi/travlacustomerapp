import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/auth/presentation/auth_widgets.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_setup_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_catalogue.dart';

const _other = 'Other';

class AddExistingVehicleScreen extends ConsumerStatefulWidget {
  const AddExistingVehicleScreen({super.key});

  @override
  ConsumerState<AddExistingVehicleScreen> createState() =>
      _AddExistingVehicleScreenState();
}

class _AddExistingVehicleScreenState
    extends ConsumerState<AddExistingVehicleScreen> {
  final _detailsKey = GlobalKey<FormState>();
  final _identifiersKey = GlobalKey<FormState>();
  final _customMake = TextEditingController();
  final _customModel = TextEditingController();
  final _year = TextEditingController();
  final _colour = TextEditingController();
  final _plate = TextEditingController();
  final _chassis = TextEditingController();
  final _engine = TextEditingController();
  String? _make;
  String? _model;
  String? _category;
  bool _tinted = false;
  bool _submitting = false;
  String? _error;
  int _step = 0;

  @override
  void dispose() {
    _customMake.dispose();
    _customModel.dispose();
    _year.dispose();
    _colour.dispose();
    _plate.dispose();
    _chassis.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _selectMake(String? value, VehicleCatalogue catalogue) {
    setState(() {
      _make = value;
      _model = null;
      _category = value == _other ? catalogue.fallbackCategory : null;
      _customMake.clear();
      _customModel.clear();
    });
  }

  void _selectModel(String? value, VehicleCatalogue catalogue) {
    final selectedMake = catalogue.makes
        .where((item) => item.name == _make)
        .firstOrNull;
    final selectedModel = selectedMake?.models
        .where((item) => item.name == value)
        .firstOrNull;
    setState(() {
      _model = value;
      _category = value == _other
          ? catalogue.fallbackCategory
          : selectedModel?.category;
      _customModel.clear();
    });
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_detailsKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = null;
      _step = 1;
    });
  }

  Future<void> _submit(VehicleCatalogue catalogue) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_identifiersKey.currentState?.validate() ?? false)) return;
    final make = _make == _other ? _customMake.text.trim() : _make ?? '';
    final model = _model == _other || _make == _other
        ? _customModel.text.trim()
        : _model ?? '';
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(vehicleSetupRepositoryProvider)
          .addExisting({
            'make': make,
            'model': model,
            'year': int.parse(_year.text),
            'color': _colour.text.trim(),
            'plate_number': _plate.text.trim().toUpperCase(),
            'chassis_number': _chassis.text.trim().toUpperCase(),
            'engine_number': _engine.text.trim().toUpperCase(),
            'vehicle_category': _category ?? catalogue.fallbackCategory,
            'is_tinted': _tinted,
          });
      if (!mounted) return;
      if (result.stolenMatch != null) {
        await _showStolenWarning(result.stolenMatch!);
        if (!mounted) return;
      }
      ref.invalidate(garageProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle added to your Travla garage.')),
      );
      context.go('/vehicles');
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showStolenWarning(Map<String, dynamic> match) {
    final name = [
      match['make'],
      match['model'],
    ].where((value) => value?.toString().isNotEmpty == true).join(' ');
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.report_gmailerrorred_rounded,
          color: AppColors.danger,
          size: 38,
        ),
        title: const Text('Possible stolen-vehicle match'),
        content: Text(
          '${name.isEmpty ? 'This vehicle' : name} matches a vehicle reported stolen on Travla. The report has been flagged for review.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(vehicleCatalogueProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6EE),
        leading: IconButton(
          onPressed: () => _step == 0
              ? context.go('/vehicles')
              : setState(() {
                  _error = null;
                  _step = 0;
                }),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Add existing vehicle'),
      ),
      body: catalogue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _CatalogueError(
          message: error is ApiFailure
              ? error.message
              : 'The vehicle catalogue could not be loaded.',
          onRetry: () => ref.invalidate(vehicleCatalogueProvider),
        ),
        data: _buildForm,
      ),
    );
  }

  Widget _buildForm(VehicleCatalogue catalogue) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VehicleFormHeader(step: _step),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: _step == 0
                      ? _buildDetails(catalogue)
                      : _buildIdentifiers(catalogue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(VehicleCatalogue catalogue) {
    final selectedMake = catalogue.makes
        .where((item) => item.name == _make)
        .firstOrNull;
    return Form(
      key: _detailsKey,
      child: Column(
        key: const ValueKey('vehicle-details'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VehicleSelect(
            key: ValueKey('make-$_make'),
            label: 'Make',
            icon: Icons.directions_car_outlined,
            value: _make,
            values: [
              ...catalogue.makes.map((item) => item.name),
              if (!catalogue.makes.any((item) => item.name == _other)) _other,
            ],
            onChanged: (value) => _selectMake(value, catalogue),
          ),
          if (_make == _other) ...[
            const SizedBox(height: 13),
            PremiumAuthField(
              controller: _customMake,
              label: 'Specify make',
              icon: Icons.edit_road_outlined,
              textCapitalization: TextCapitalization.words,
              validator: _requiredText,
            ),
          ],
          const SizedBox(height: 13),
          if (_make == _other)
            PremiumAuthField(
              controller: _customModel,
              label: 'Model',
              icon: Icons.car_repair_outlined,
              textCapitalization: TextCapitalization.words,
              validator: _requiredText,
            )
          else
            _VehicleSelect(
              key: ValueKey('model-$_make-$_model'),
              label: 'Model',
              icon: Icons.car_repair_outlined,
              value: _model,
              enabled: selectedMake != null,
              values: [
                ...?selectedMake?.models.map((item) => item.name),
                if (selectedMake != null &&
                    !selectedMake.models.any((item) => item.name == _other))
                  _other,
              ],
              onChanged: (value) => _selectModel(value, catalogue),
            ),
          if (_model == _other && _make != _other) ...[
            const SizedBox(height: 13),
            PremiumAuthField(
              controller: _customModel,
              label: 'Specify model',
              icon: Icons.edit_outlined,
              textCapitalization: TextCapitalization.words,
              validator: _requiredText,
            ),
          ],
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PremiumAuthField(
                  controller: _year,
                  label: 'Year',
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final year = int.tryParse(value ?? '');
                    final maximum = DateTime.now().year + 1;
                    return year != null && year >= 1950 && year <= maximum
                        ? null
                        : '1950–$maximum';
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumAuthField(
                  controller: _colour,
                  label: 'Colour',
                  icon: Icons.palette_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: _requiredText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AutoCategory(category: _category),
          const SizedBox(height: 24),
          AuthPrimaryButton(label: 'Continue', onPressed: _continue),
        ],
      ),
    );
  }

  Widget _buildIdentifiers(VehicleCatalogue catalogue) {
    return Form(
      key: _identifiersKey,
      child: Column(
        key: const ValueKey('vehicle-identifiers'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _IdentifierNotice(),
          const SizedBox(height: 16),
          PremiumAuthField(
            controller: _plate,
            label: 'Plate number',
            icon: Icons.pin_outlined,
            textCapitalization: TextCapitalization.characters,
            validator: (value) =>
                RegExp(r'^[A-Za-z0-9\- ]{5,15}$').hasMatch(value?.trim() ?? '')
                ? null
                : 'Enter a valid plate number.',
          ),
          const SizedBox(height: 13),
          PremiumAuthField(
            controller: _chassis,
            label: 'Chassis / VIN number',
            icon: Icons.qr_code_2_rounded,
            textCapitalization: TextCapitalization.characters,
            validator: (value) =>
                RegExp(r'^[A-Za-z0-9\- ]{6,30}$').hasMatch(value?.trim() ?? '')
                ? null
                : 'Enter a valid chassis number.',
          ),
          const SizedBox(height: 13),
          PremiumAuthField(
            controller: _engine,
            label: 'Engine number',
            icon: Icons.settings_outlined,
            textCapitalization: TextCapitalization.characters,
            validator: (value) =>
                RegExp(r'^[A-Za-z0-9\- ]{4,30}$').hasMatch(value?.trim() ?? '')
                ? null
                : 'Engine number is required.',
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            value: _tinted,
            onChanged: (value) => setState(() => _tinted = value),
            activeTrackColor: AppColors.forest600,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text(
              'Tinted glass',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Travla will include a tinted-glass permit in document readiness.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthInlineMessage(message: _error!),
          ],
          const SizedBox(height: 22),
          AuthPrimaryButton(
            label: 'Add vehicle',
            icon: Icons.add_road_rounded,
            loading: _submitting,
            onPressed: _submitting ? null : () => _submit(catalogue),
          ),
        ],
      ),
    );
  }

  static String? _requiredText(String? value) {
    return (value?.trim().length ?? 0) >= 2 ? null : 'Required.';
  }
}

class _VehicleSelect extends StatelessWidget {
  const _VehicleSelect({
    required this.label,
    required this.icon,
    required this.value,
    required this.values,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(17)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFD9DED9)),
        ),
      ),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(growable: false),
      onChanged: enabled ? onChanged : null,
      validator: (selected) => selected == null ? 'Select $label.' : null,
    );
  }
}

class _VehicleFormHeader extends StatelessWidget {
  const _VehicleFormHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step == 0 ? 'Tell us about the vehicle' : 'Confirm its identifiers',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 7),
        Text(
          step == 0
              ? 'For a vehicle that is already registered and has a plate number.'
              : 'These details protect ownership and are checked against Travla records.',
          style: const TextStyle(color: AppColors.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(
            2,
            (index) => Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 5,
                margin: EdgeInsets.only(right: index == 0 ? 8 : 0),
                decoration: BoxDecoration(
                  color: index <= step
                      ? index == step
                            ? AppColors.orange
                            : AppColors.forest600
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoCategory extends StatelessWidget {
  const _AutoCategory({required this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.forest100),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.forest600),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehicle category',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  category?.replaceAll('_', ' ').toUpperCase() ??
                      'SELECT MAKE AND MODEL',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Text(
            'AUTO',
            style: TextStyle(
              color: AppColors.forest600,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentifierNotice extends StatelessWidget {
  const _IdentifierNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.orangeDark),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Enter the values exactly as they appear on the vehicle papers. Engine number is compulsory.',
              style: TextStyle(color: AppColors.orangeDark, height: 1.4),
            ),
          ),
        ],
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
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
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

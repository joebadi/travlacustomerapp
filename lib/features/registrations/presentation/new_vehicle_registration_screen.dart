import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/auth/presentation/auth_widgets.dart';
import 'package:travla_customer_app/features/registrations/data/registration_repository.dart';
import 'package:travla_customer_app/features/registrations/domain/registration_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_setup_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_catalogue.dart';

const _vehicleColours = [
  'Black',
  'White',
  'Silver',
  'Grey',
  'Blue',
  'Red',
  'Green',
  'Gold',
  'Brown',
  'Beige',
  'Orange',
  'Yellow',
  'Purple',
  'Maroon',
];

class NewVehicleRegistrationScreen extends ConsumerStatefulWidget {
  const NewVehicleRegistrationScreen({super.key});

  @override
  ConsumerState<NewVehicleRegistrationScreen> createState() =>
      _NewVehicleRegistrationScreenState();
}

class _NewVehicleRegistrationScreenState
    extends ConsumerState<NewVehicleRegistrationScreen> {
  final _vehicleKey = GlobalKey<FormState>();
  final _handoverKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _vin = TextEditingController();
  final _engine = TextEditingController();
  final _customPlate = TextEditingController();
  final _deliveryAddress = TextEditingController();
  String? _make;
  String? _model;
  String? _category;
  String? _year;
  String? _colour;
  String _plateType = 'STANDARD';
  bool _tinted = false;
  String _deliveryMethod = 'PICKUP';
  String? _city;
  String? _state;
  final Set<String> _options = {};
  final Map<String, PlatformFile> _documents = {};
  List<PlatformFile> _images = [];
  RegistrationQuote? _quote;
  RegistrationCreated? _created;
  int _step = 0;
  bool _quoting = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _scroll.dispose();
    _vin.dispose();
    _engine.dispose();
    _customPlate.dispose();
    _deliveryAddress.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _error = null;
      _step = step;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _selectMake(String? value, VehicleCatalogue catalogue) {
    setState(() {
      _make = value;
      _model = null;
      _category = null;
      _quote = null;
    });
  }

  void _selectModel(String? value, VehicleCatalogue catalogue) {
    final make = catalogue.makes
        .where((item) => item.name == _make)
        .firstOrNull;
    final model = make?.models.where((item) => item.name == value).firstOrNull;
    setState(() {
      _model = value;
      _category = model?.category;
      _quote = null;
    });
  }

  void _continueVehicle(VehicleCatalogue catalogue) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_vehicleKey.currentState?.validate() ?? false)) return;
    if (catalogue.category(_category) == null) {
      setState(() {
        _error =
            'The category assigned to this make and model is not available.';
      });
      return;
    }
    _goToStep(1);
  }

  Future<void> _pickDocument(RegistrationDocumentField field) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.size > 5 * 1024 * 1024) {
      setState(() => _error = '${field.name} must not exceed 5MB.');
      return;
    }
    setState(() {
      _error = null;
      _documents[field.key] = file;
    });
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (!mounted || result == null) return;
    final oversized = result.files.where((file) => file.size > 5 * 1024 * 1024);
    if (oversized.isNotEmpty) {
      setState(() => _error = 'Each vehicle photo must not exceed 5MB.');
      return;
    }
    setState(() {
      _error = null;
      _images = result.files.take(6).toList(growable: false);
    });
  }

  void _continueDocuments(RegistrationSetup setup) {
    final missing = setup.documentFields
        .where((field) => field.required && !_documents.containsKey(field.key))
        .map((field) => field.name)
        .toList(growable: false);
    if (missing.isNotEmpty) {
      setState(() => _error = 'Upload: ${missing.join(', ')}.');
      return;
    }
    _goToStep(2);
  }

  Future<void> _review() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_handoverKey.currentState?.validate() ?? false)) return;
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final quote = await ref
          .read(registrationRepositoryProvider)
          .quote(
            make: _make!,
            model: _model!,
            plateType: _plateType,
            options: _options.toList(growable: false),
            deliveryMethod: _deliveryMethod,
            city: _city!,
          );
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _step = 3;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _submit() async {
    final quote = _quote;
    if (quote == null || !quote.sufficientBalance) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(registrationRepositoryProvider)
          .create(
            fields: {
              'make': _make!,
              'model': _model!,
              'year': _year!,
              'color': _colour!,
              'vin': _vin.text.trim().toUpperCase(),
              'engine_number': _engine.text.trim().toUpperCase(),
              'vehicle_category': _category!,
              'is_tinted': _tinted ? '1' : '0',
              'plate_type': _plateType,
              if (_plateType == 'CUSTOM')
                'custom_plate_text': _customPlate.text.trim().toUpperCase(),
              'city': _city!,
              'state': _state!,
              'delivery_method': _deliveryMethod,
              if (_deliveryMethod == 'DELIVERY')
                'delivery_address': _deliveryAddress.text.trim(),
            },
            options: _options.toList(growable: false),
            images: _images,
            documents: _documents,
          );
      if (!mounted) return;
      ref.invalidate(garageProvider);
      setState(() => _created = created);
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.details['needs_topup'] == true
              ? '${failure.message} Top up your wallet, then request a fresh quote.'
              : failure.message;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _back() {
    if (_step > 0) {
      _goToStep(_step - 1);
    } else {
      context.go('/vehicles');
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(registrationSetupProvider);
    final catalogue = ref.watch(vehicleCatalogueProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _created == null ? _back : () => context.go('/vehicles'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Register new vehicle'),
      ),
      body: _created != null
          ? _RegistrationSuccess(created: _created!)
          : setup.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _SetupError(
                message: error is ApiFailure
                    ? error.message
                    : 'Registration settings could not be loaded.',
                onRetry: () => ref.invalidate(registrationSetupProvider),
              ),
              data: (registrationSetup) => catalogue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _SetupError(
                  message: error is ApiFailure
                      ? error.message
                      : 'Vehicle choices could not be loaded.',
                  onRetry: () => ref.invalidate(vehicleCatalogueProvider),
                ),
                data: (vehicleCatalogue) =>
                    _buildWizard(registrationSetup, vehicleCatalogue),
              ),
            ),
    );
  }

  Widget _buildWizard(RegistrationSetup setup, VehicleCatalogue catalogue) {
    return SafeArea(
      top: false,
      child: ListView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          const _RegistrationHero(),
          const SizedBox(height: 12),
          _RegistrationProgress(step: _step),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthInlineMessage(message: _error!),
          ],
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: switch (_step) {
              0 => _vehicleStep(setup, catalogue),
              1 => _documentsStep(setup),
              2 => _handoverStep(setup),
              _ => _reviewStep(catalogue),
            },
          ),
        ],
      ),
    );
  }

  Widget _vehicleStep(RegistrationSetup setup, VehicleCatalogue catalogue) {
    final make = catalogue.makes
        .where((item) => item.name == _make)
        .firstOrNull;
    final category = catalogue.category(_category);
    final years = List.generate(
      DateTime.now().year - 1949 + 1,
      (index) => (DateTime.now().year + 1 - index).toString(),
    );
    return _WizardCard(
      key: const ValueKey('vehicle-step'),
      child: Form(
        key: _vehicleKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeading(
              eyebrow: 'STEP 1 OF 4',
              title: 'Tell us about the vehicle',
              description:
                  'Use the exact identifiers on the purchase or import documents.',
            ),
            _CompactSelect(
              key: ValueKey('reg-make-$_make'),
              label: 'Make',
              value: _make,
              values: catalogue.makes.map((item) => item.name).toList(),
              onChanged: (value) => _selectMake(value, catalogue),
            ),
            const SizedBox(height: 11),
            _CompactSelect(
              key: ValueKey('reg-model-$_make-$_model'),
              label: 'Model',
              value: _model,
              values:
                  make?.models.map((item) => item.name).toList() ?? const [],
              enabled: make != null,
              onChanged: (value) => _selectModel(value, catalogue),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: _CompactSelect(
                    key: ValueKey('reg-year-$_year'),
                    label: 'Model year',
                    value: _year,
                    values: years,
                    onChanged: (value) => setState(() => _year = value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactSelect(
                    key: ValueKey('reg-colour-$_colour'),
                    label: 'Colour',
                    value: _colour,
                    values: _vehicleColours,
                    onChanged: (value) => setState(() => _colour = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            PremiumAuthField(
              controller: _vin,
              label: 'Chassis / VIN',
              icon: Icons.qr_code_2_rounded,
              textCapitalization: TextCapitalization.characters,
              validator: _vinValidator,
            ),
            const SizedBox(height: 11),
            PremiumAuthField(
              controller: _engine,
              label: 'Engine number',
              icon: Icons.settings_outlined,
              textCapitalization: TextCapitalization.characters,
              validator: _engineValidator,
            ),
            const SizedBox(height: 12),
            _RegistrationCategory(
              category: category,
              fallbackFee: setup.baseFeeNaira,
            ),
            const SizedBox(height: 16),
            const Text(
              'Plate preference',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _ChoiceTile(
                    selected: _plateType == 'STANDARD',
                    title: 'Standard',
                    subtitle: 'Included',
                    onTap: () => setState(() => _plateType = 'STANDARD'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoiceTile(
                    selected: _plateType == 'CUSTOM',
                    title: 'Custom',
                    subtitle: '+₦${setup.customPlateFeeNaira}',
                    onTap: () => setState(() => _plateType = 'CUSTOM'),
                  ),
                ),
              ],
            ),
            if (_plateType == 'CUSTOM') ...[
              const SizedBox(height: 11),
              PremiumAuthField(
                controller: _customPlate,
                label: 'Custom plate text',
                icon: Icons.pin_outlined,
                textCapitalization: TextCapitalization.characters,
                validator: (value) =>
                    (value?.trim().isNotEmpty == true &&
                        value!.trim().length <= 8)
                    ? null
                    : 'Enter up to 8 characters.',
              ),
            ],
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              value: _tinted,
              onChanged: (value) => setState(() => _tinted = value),
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppColors.forest600,
              title: const Text(
                'Tinted glass',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Select for factory or aftermarket tint.',
                style: TextStyle(fontSize: 10),
              ),
            ),
            const SizedBox(height: 12),
            AuthPrimaryButton(
              label: 'Continue to documents',
              onPressed: () => _continueVehicle(catalogue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentsStep(RegistrationSetup setup) {
    return _WizardCard(
      key: const ValueKey('documents-step'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeading(
            eyebrow: 'STEP 2 OF 4',
            title: 'Build the evidence pack',
            description: 'Upload clear PDF, JPG or PNG files, up to 5MB each.',
          ),
          ...setup.documentFields.map((field) {
            final file = _documents[field.key];
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _UploadTile(
                title: field.name,
                description: field.description,
                required: field.required,
                fileName: file?.name,
                onPick: () => _pickDocument(field),
                onRemove: file == null
                    ? null
                    : () => setState(() => _documents.remove(field.key)),
              ),
            );
          }),
          if (setup.options.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Optional registration services',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            ...setup.options.map(
              (option) => CheckboxListTile(
                value: _options.contains(option.key),
                onChanged: (_) => setState(() {
                  _options.contains(option.key)
                      ? _options.remove(option.key)
                      : _options.add(option.key);
                  _quote = null;
                }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.forest600,
                title: Text(
                  option.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${option.description ?? 'Optional add-on'} · +₦${option.feeNaira}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _PhotoPicker(
            files: _images,
            onPick: _pickImages,
            onClear: () => setState(() => _images = []),
          ),
          const SizedBox(height: 18),
          _WizardActions(
            onBack: () => _goToStep(0),
            nextLabel: 'Continue to handover',
            onNext: () => _continueDocuments(setup),
          ),
        ],
      ),
    );
  }

  Widget _handoverStep(RegistrationSetup setup) {
    return _WizardCard(
      key: const ValueKey('handover-step'),
      child: Form(
        key: _handoverKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeading(
              eyebrow: 'STEP 3 OF 4',
              title: 'Choose your handover',
              description:
                  'Select the processing city and how you want the plate and papers.',
            ),
            Row(
              children: [
                Expanded(
                  child: _ChoiceTile(
                    selected: _deliveryMethod == 'PICKUP',
                    title: 'Office pickup',
                    subtitle: 'No rider fee',
                    onTap: () => setState(() {
                      _deliveryMethod = 'PICKUP';
                      _quote = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoiceTile(
                    selected: _deliveryMethod == 'DELIVERY',
                    title: 'Doorstep',
                    subtitle: 'Rider delivery',
                    onTap: () => setState(() {
                      _deliveryMethod = 'DELIVERY';
                      _quote = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CompactSelect(
              key: ValueKey('service-city-$_city'),
              label: 'Processing city',
              value: _city,
              values: setup.serviceCities.map((item) => item.city).toList(),
              onChanged: (value) {
                final city = setup.serviceCities
                    .where((item) => item.city == value)
                    .firstOrNull;
                setState(() {
                  _city = value;
                  _state = city?.state;
                  _quote = null;
                });
              },
            ),
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF1F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    color: AppColors.forest600,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _state ?? 'State fills automatically',
                    style: TextStyle(
                      color: _state == null ? AppColors.muted : AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_deliveryMethod == 'DELIVERY') ...[
              const SizedBox(height: 11),
              PremiumAuthField(
                controller: _deliveryAddress,
                label: 'Delivery address',
                icon: Icons.location_on_outlined,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => (value?.trim().length ?? 0) >= 8
                    ? null
                    : 'Enter a complete delivery address.',
              ),
            ],
            const SizedBox(height: 18),
            _WizardActions(
              onBack: () => _goToStep(1),
              nextLabel: 'Review and pay',
              loading: _quoting,
              onNext: _quoting ? null : _review,
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewStep(VehicleCatalogue catalogue) {
    final quote = _quote!;
    return _WizardCard(
      key: const ValueKey('review-step'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeading(
            eyebrow: 'STEP 4 OF 4',
            title: 'Review and submit',
            description:
                'Your wallet is charged only after you confirm this request.',
          ),
          _ReviewSummary(
            vehicle: '$_year $_make $_model',
            category: quote.vehicleCategoryLabel.isNotEmpty
                ? quote.vehicleCategoryLabel
                : catalogue.category(_category)?.label ?? _category!,
            identifiers:
                'VIN ${_vin.text.trim().toUpperCase()} · Engine ${_engine.text.trim().toUpperCase()}',
            plate: _plateType == 'CUSTOM'
                ? 'Custom · ${_customPlate.text.trim().toUpperCase()}'
                : 'Standard issue',
            handover:
                '${_deliveryMethod == 'DELIVERY' ? 'Doorstep delivery' : 'Office pickup'} · $_city',
          ),
          const SizedBox(height: 14),
          const Text(
            'Complete price breakdown',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          ...quote.lineItems.map(_PriceLine.new),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.forest950,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total payable',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '₦${quote.totalNaira}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Wallet balance',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '₦${quote.walletBalanceNaira}',
                style: TextStyle(
                  color: quote.sufficientBalance
                      ? AppColors.forest600
                      : AppColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (!quote.sufficientBalance) ...[
            const SizedBox(height: 12),
            AuthInlineMessage(
              message:
                  'Your wallet is short by ₦${quote.shortfallNaira}. Top up on Travla, then return for a fresh quote.',
              isError: false,
            ),
          ],
          const SizedBox(height: 18),
          _WizardActions(
            onBack: () => _goToStep(2),
            nextLabel: quote.sufficientBalance
                ? 'Pay ₦${quote.totalNaira} and submit'
                : 'Insufficient wallet balance',
            loading: _submitting,
            onNext: quote.sufficientBalance && !_submitting ? _submit : null,
          ),
        ],
      ),
    );
  }

  static String? _vinValidator(String? value) {
    return RegExp(r'^[A-Za-z0-9\- ]{6,30}$').hasMatch(value?.trim() ?? '')
        ? null
        : 'Enter a valid chassis / VIN.';
  }

  static String? _engineValidator(String? value) {
    return RegExp(r'^[A-Za-z0-9\- ]{4,30}$').hasMatch(value?.trim() ?? '')
        ? null
        : 'Engine number is required.';
  }
}

class _RegistrationHero extends StatelessWidget {
  const _RegistrationHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FIRST REGISTRATION',
            style: TextStyle(
              color: Color(0xFF75DFB8),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Put your new vehicle on the road.',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Travla handles verified documents, payment, processing and handover.',
            style: TextStyle(
              color: Color(0xAFFFFFFF),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationProgress extends StatelessWidget {
  const _RegistrationProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Vehicle', 'Documents', 'Handover', 'Payment'];
    return Row(
      children: List.generate(4, (index) {
        final active = step == index;
        final done = step > index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 3 ? 0 : 5),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.orange
                        : done
                        ? AppColors.forest600
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppColors.ink : AppColors.muted,
                    fontSize: 8,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _WizardCard extends StatelessWidget {
  const _WizardCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: AppColors.forest600,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSelect extends StatelessWidget {
  const _CompactSelect({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(growable: false),
      onChanged: enabled ? onChanged : null,
      validator: (value) => value == null ? 'Select $label.' : null,
    );
  }
}

class _RegistrationCategory extends StatelessWidget {
  const _RegistrationCategory({
    required this.category,
    required this.fallbackFee,
  });

  final VehicleCategoryOption? category;
  final String fallbackFee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.forest100),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.forest600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category?.label ?? 'Select make and model',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Registration ₦${category?.registrationFeeNaira ?? fallbackFee}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const Text(
            'AUTO',
            style: TextStyle(
              color: AppColors.forest600,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.forest50 : AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.forest600 : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.forest600 : AppColors.muted,
                size: 18,
              ),
              const SizedBox(height: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.title,
    required this.description,
    required this.required,
    required this.fileName,
    required this.onPick,
    required this.onRemove,
  });

  final String title;
  final String? description;
  final bool required;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fileName == null ? AppColors.white : AppColors.forest50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fileName == null ? AppColors.border : AppColors.forest100,
        ),
      ),
      child: Row(
        children: [
          Icon(
            fileName == null
                ? Icons.upload_file_outlined
                : Icons.check_circle_rounded,
            color: fileName == null ? AppColors.muted : AppColors.forest600,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title${required ? ' *' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fileName ?? description ?? 'Optional evidence',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 9),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          TextButton(
            onPressed: onPick,
            child: Text(fileName == null ? 'Choose' : 'Change'),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.files,
    required this.onPick,
    required this.onClear,
  });

  final List<PlatformFile> files;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_library_outlined, color: AppColors.forest600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehicle photos (optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  files.isEmpty
                      ? 'Up to 6 clear images'
                      : '${files.length} photo${files.length == 1 ? '' : 's'} selected',
                  style: const TextStyle(color: AppColors.muted, fontSize: 9),
                ),
              ],
            ),
          ),
          if (files.isNotEmpty)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          TextButton(onPressed: onPick, child: const Text('Choose')),
        ],
      ),
    );
  }
}

class _WizardActions extends StatelessWidget {
  const _WizardActions({
    required this.onBack,
    required this.nextLabel,
    required this.onNext,
    this.loading = false,
  });

  final VoidCallback onBack;
  final String nextLabel;
  final VoidCallback? onNext;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthPrimaryButton(
          label: nextLabel,
          loading: loading,
          onPressed: onNext,
        ),
        const SizedBox(height: 5),
        TextButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.vehicle,
    required this.category,
    required this.identifiers,
    required this.plate,
    required this.handover,
  });

  final String vehicle;
  final String category;
  final String identifiers;
  final String plate;
  final String handover;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _ReviewRow(label: 'Vehicle', value: vehicle),
          _ReviewRow(label: 'Category', value: category),
          _ReviewRow(label: 'Identifiers', value: identifiers),
          _ReviewRow(label: 'Plate', value: plate),
          _ReviewRow(label: 'Handover', value: handover, last: true),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine(this.item);

  final RegistrationLineItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            item.kind == 'delivery'
                ? Icons.local_shipping_outlined
                : item.kind == 'plate'
                ? Icons.pin_outlined
                : item.kind == 'option'
                ? Icons.add_circle_outline_rounded
                : Icons.description_outlined,
            color: item.kind == 'delivery'
                ? AppColors.orange
                : AppColors.forest600,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.description.isNotEmpty)
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 9),
                  ),
              ],
            ),
          ),
          Text(
            '₦${item.amountNaira}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RegistrationSuccess extends StatelessWidget {
  const _RegistrationSuccess({required this.created});

  final RegistrationCreated created;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: AppColors.forest100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.forest700,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Registration submitted',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 7),
                Text(
                  'Travla has received your application and wallet payment of ₦${created.amountNaira}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TRACKING NUMBER',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .9,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        created.trackingNumber,
                        style: const TextStyle(
                          color: AppColors.forest700,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        created.statusLabel,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: 'Return to My Vehicles',
                  onPressed: () => context.go('/vehicles'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupError extends StatelessWidget {
  const _SetupError({required this.message, required this.onRetry});

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
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
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

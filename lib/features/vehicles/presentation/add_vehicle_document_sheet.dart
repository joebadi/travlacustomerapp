import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_detail_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';

enum DocumentTypeFilter { all, renewable, other }

Future<bool?> showAddVehicleDocumentSheet({
  required BuildContext context,
  required String vehicleId,
  DocumentTypeFilter filter = DocumentTypeFilter.all,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) =>
        AddVehicleDocumentSheet(vehicleId: vehicleId, filter: filter),
  );
}

class AddVehicleDocumentSheet extends ConsumerStatefulWidget {
  const AddVehicleDocumentSheet({
    required this.vehicleId,
    required this.filter,
    super.key,
  });

  final String vehicleId;
  final DocumentTypeFilter filter;

  @override
  ConsumerState<AddVehicleDocumentSheet> createState() =>
      _AddVehicleDocumentSheetState();
}

class _AddVehicleDocumentSheetState
    extends ConsumerState<AddVehicleDocumentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _authorityController = TextEditingController();

  String? _selectedTypeValue;
  String? _selectedState;
  String? _selectedAuthorityId;
  DateTime? _issuedDate;
  PlatformFile? _file;
  String? _error;
  bool _isSubmitting = false;
  double? _uploadProgress;

  @override
  void dispose() {
    _numberController.dispose();
    _authorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(
      availableDocumentTypesProvider(widget.vehicleId),
    );
    final states = ref.watch(vehicleDocumentStatesProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: .94,
        child: Column(
          children: [
            _SheetHeader(
              title: _title,
              onClose: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: available.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _CatalogueError(
                  message: error is ApiFailure
                      ? error.message
                      : 'The document catalogue could not be loaded.',
                  onRetry: () => ref.invalidate(
                    availableDocumentTypesProvider(widget.vehicleId),
                  ),
                ),
                data: (items) => _buildForm(
                  items.where(_matchesFilter).toList(growable: false),
                  states,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    List<AvailableDocumentType> types,
    AsyncValue<List<String>> states,
  ) {
    final selected = types
        .where((type) => type.type == _selectedTypeValue)
        .firstOrNull;
    final isRenewable = selected?.isRenewable == true;
    final derivedExpiry = _issuedDate == null
        ? null
        : oneYearAfterNoOverflow(_issuedDate!);
    final authorityCatalogue = selected != null && _selectedState != null
        ? ref.watch(
            issuingAuthoritiesProvider((
              documentType: selected.type,
              state: _selectedState!,
            )),
          )
        : const AsyncValue<List<IssuingAuthorityOption>>.data([]);

    if (types.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'No applicable document types are configured for this vehicle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE9E7),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFFF5BBB5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _FormSection(
                  number: '01',
                  title: 'Choose the paper',
                  helper: 'Select the exact record you want to store.',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedTypeValue,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Document type',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    items: types
                        .map(
                          (type) => DropdownMenuItem(
                            value: type.type,
                            child: Text(
                              type.alreadyAdded
                                  ? '${type.name} · replace'
                                  : type.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedTypeValue = value;
                              _selectedAuthorityId = null;
                              _authorityController.clear();
                              _error = null;
                            });
                          },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Select a document type.'
                        : null,
                  ),
                ),
                if (selected?.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.forest50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.forest100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.forest700,
                          size: 18,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            selected!.description!,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (selected != null) ...[
                  const SizedBox(height: 14),
                  _FormSection(
                    number: '02',
                    title: 'Record the details',
                    helper: isRenewable
                        ? 'These details are used to track validity.'
                        : 'Add any available reference information.',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _numberController,
                          enabled: !_isSubmitting,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: isRenewable
                                ? 'Document number · optional'
                                : 'Reference / document number',
                            hintText: 'Optional',
                            prefixIcon: const Icon(Icons.numbers_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedState,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: isRenewable
                                ? 'Issuing state'
                                : 'Issuing state · optional',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                          items: (states.asData?.value ?? const <String>[])
                              .map(
                                (state) => DropdownMenuItem(
                                  value: state,
                                  child: Text(state),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _isSubmitting || states.isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedState = value;
                                    _selectedAuthorityId = null;
                                    _authorityController.clear();
                                    _error = null;
                                  });
                                },
                          validator: (value) => isRenewable && value == null
                              ? 'Select the issuing state.'
                              : null,
                        ),
                        if (_selectedState != null) ...[
                          const SizedBox(height: 12),
                          authorityCatalogue.when(
                            loading: () => const _AuthorityLoadingField(),
                            error: (error, stackTrace) => _AuthorityCatalogueNotice(
                              message:
                                  'We could not load the approved issuing authorities.',
                              actionLabel: 'Try again',
                              onAction: () => ref.invalidate(
                                issuingAuthoritiesProvider((
                                  documentType: selected.type,
                                  state: _selectedState!,
                                )),
                              ),
                            ),
                            data: (authorities) => authorities.isEmpty
                                ? _AuthorityCatalogueNotice(
                                    message:
                                        'No issuing authority has been configured by Travla for $_selectedState. Contact support before uploading this document.',
                                  )
                                : DropdownButtonFormField<String>(
                                    key: const ValueKey(
                                      'issuing-authority-dropdown',
                                    ),
                                    initialValue: _selectedAuthorityId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Issuing authority',
                                      prefixIcon: Icon(
                                        Icons.account_balance_outlined,
                                      ),
                                    ),
                                    items: authorities
                                        .map(
                                          (authority) => DropdownMenuItem(
                                            value: authority.id,
                                            child: Text(
                                              authority.displayName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: _isSubmitting
                                        ? null
                                        : (value) => setState(
                                            () => _selectedAuthorityId = value,
                                          ),
                                    validator: (value) =>
                                        isRenewable && value == null
                                        ? 'Select the issuing authority.'
                                        : null,
                                  ),
                          ),
                        ] else if (!isRenewable) ...[
                          const SizedBox(height: 12),
                          _ManualAuthorityField(
                            controller: _authorityController,
                            enabled: !_isSubmitting,
                            required: false,
                          ),
                        ],
                        const SizedBox(height: 12),
                        _DateField(
                          label: isRenewable
                              ? 'Issue date'
                              : 'Issue date · optional',
                          value: _issuedDate,
                          enabled: !_isSubmitting,
                          onTap: _selectIssuedDate,
                          errorText: isRenewable && _issuedDate == null
                              ? 'Required for renewable papers'
                              : null,
                        ),
                        if (isRenewable) ...[
                          const SizedBox(height: 12),
                          _AutomaticExpiryCard(expiry: derivedExpiry),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FormSection(
                    number: '03',
                    title: 'Attach the secure copy',
                    helper: selected.fileRequired
                        ? 'A file is required for this document type.'
                        : 'Optional, but useful when you need the original quickly.',
                    child: _FilePickerCard(
                      file: _file,
                      required: selected.fileRequired,
                      enabled: !_isSubmitting,
                      onPick: _pickFile,
                      onRemove: () => setState(() => _file = null),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SecureStorageNote(),
                ],
              ],
            ),
          ),
          if (selected != null)
            _SubmitBar(
              isSubmitting: _isSubmitting,
              uploadProgress: _uploadProgress,
              isReplacement: selected.alreadyAdded,
              onSubmit: () => _submit(selected),
            ),
        ],
      ),
    );
  }

  String get _title => switch (widget.filter) {
    DocumentTypeFilter.renewable => 'Add renewable paper',
    DocumentTypeFilter.other => 'Add other document',
    DocumentTypeFilter.all => 'Add vehicle document',
  };

  bool _matchesFilter(AvailableDocumentType type) {
    return switch (widget.filter) {
      DocumentTypeFilter.all => true,
      DocumentTypeFilter.renewable => type.isRenewable,
      DocumentTypeFilter.other => !type.isRenewable,
    };
  }

  Future<void> _selectIssuedDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _issuedDate ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (selected != null && mounted) {
      setState(() {
        _issuedDate = selected;
        _error = null;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final selected = result.files.single;
    if (selected.size > 5 * 1024 * 1024) {
      setState(() {
        _error = 'The document must be 5 MB or smaller.';
        _file = null;
      });
      return;
    }
    if (selected.path == null || selected.path!.isEmpty) {
      setState(() => _error = 'This file could not be accessed. Try again.');
      return;
    }
    setState(() {
      _file = selected;
      _error = null;
    });
  }

  Future<void> _submit(AvailableDocumentType type) async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (type.isRenewable && _issuedDate == null) {
      setState(() => _error = 'Select the issue date.');
      return;
    }
    if (type.isRenewable && _selectedState == null) {
      setState(() => _error = 'Select the issuing state.');
      return;
    }
    if (type.isRenewable && _selectedAuthorityId == null) {
      setState(() {
        _error =
            'Select an issuing authority configured by Travla for this state.';
      });
      return;
    }
    if (type.fileRequired && _file == null) {
      setState(() {
        _error = 'This document type requires a JPG, PNG or PDF file.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0;
    });
    try {
      await ref
          .read(vehicleDetailRepositoryProvider)
          .uploadDocument(
            vehicleId: widget.vehicleId,
            documentType: type.type,
            documentNumber: _numberController.text,
            issuingAuthority: _authorityController.text,
            issuingAuthorityId: _selectedAuthorityId,
            issuingState: _selectedState,
            issuedDate: _issuedDate,
            filePath: _file?.path,
            fileName: _file?.name,
            onProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => _uploadProgress = (sent / total).clamp(0, 1));
            },
          );
      ref.invalidate(vehicleDetailProvider(widget.vehicleId));
      ref.invalidate(availableDocumentTypesProvider(widget.vehicleId));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _uploadProgress = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _AuthorityLoadingField extends StatelessWidget {
  const _AuthorityLoadingField();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Loading approved issuing authorities…',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorityCatalogueNotice extends StatelessWidget {
  const _AuthorityCatalogueNotice({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3D6A2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF9A5B00),
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF754800),
                    fontSize: 10,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 7),
                  TextButton.icon(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.forest800,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(actionLabel!),
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

class _ManualAuthorityField extends StatelessWidget {
  const _ManualAuthorityField({
    required this.controller,
    required this.enabled,
    required this.required,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: required ? 'Issuing authority' : 'Issued by',
        hintText: required ? 'Enter the name exactly as printed' : 'Optional',
        helperText:
            'The authority catalogue is not configured for this paper yet.',
        prefixIcon: const Icon(Icons.account_balance_outlined),
      ),
      validator: (value) => required && value!.trim().isEmpty
          ? 'Enter the issuing authority.'
          : null,
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -38,
            bottom: -64,
            child: Container(
              width: 154,
              height: 154,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .06),
                  width: 25,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 9, 10, 17),
            child: Column(
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: onClose,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .09),
                        foregroundColor: AppColors.white,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .12),
                        ),
                      ),
                      child: const Icon(
                        Icons.post_add_rounded,
                        color: AppColors.orange,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Stored privately in this vehicle’s document vault.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .62),
                              fontSize: 9,
                            ),
                          ),
                        ],
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

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.number,
    required this.title,
    required this.helper,
    required this.child,
  });

  final String number;
  final String title;
  final String helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A021B13),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.forest950,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      helper,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _AutomaticExpiryCard extends StatelessWidget {
  const _AutomaticExpiryCard({required this.expiry});

  final DateTime? expiry;

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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: AppColors.forest700,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EXPIRY DATE · AUTOMATIC',
                  style: TextStyle(
                    color: AppColors.forest700,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    expiry == null
                        ? 'Select the issue date first'
                        : _displayDate(expiry!),
                    key: ValueKey(expiry),
                    style: TextStyle(
                      color: expiry == null ? AppColors.muted : AppColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Always exactly one calendar year after issue.',
                  style: TextStyle(color: AppColors.muted, fontSize: 8),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.muted,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _SecureStorageNote extends StatelessWidget {
  const _SecureStorageNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, color: AppColors.muted, size: 13),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            'Private storage · secure, short-lived viewing links',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 8),
          ),
        ),
      ],
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.isSubmitting,
    required this.uploadProgress,
    required this.isReplacement,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final double? uploadProgress;
  final bool isReplacement;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x10021B13),
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSubmitting && uploadProgress != null) ...[
              Row(
                children: [
                  const Text(
                    'SECURE UPLOAD',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(uploadProgress! * 100).round()}%',
                    style: const TextStyle(
                      color: AppColors.forest700,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: uploadProgress,
                minHeight: 3,
                color: AppColors.forest600,
                backgroundColor: AppColors.forest100,
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest800,
                foregroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 19),
              label: Text(
                isSubmitting
                    ? 'Saving securely…'
                    : isReplacement
                    ? 'Replace saved document'
                    : 'Save to document vault',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          errorText: null,
          helperText: errorText,
          helperStyle: const TextStyle(color: AppColors.muted),
        ),
        child: Text(
          value == null ? 'Select date' : _displayDate(value!),
          style: TextStyle(
            color: value == null ? AppColors.muted : AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({
    required this.file,
    required this.required,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final PlatformFile? file;
  final bool required;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      child: file == null
          ? Material(
              key: const ValueKey('empty-file'),
              color: AppColors.forest50,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                onTap: enabled ? onPick : null,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.forest100, width: 1.2),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.upload_file_outlined,
                          color: AppColors.orange,
                          size: 23,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        required
                            ? 'Choose the required document file'
                            : 'Add a scanned copy or clear photo',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'PDF, JPG or PNG · maximum 5 MB',
                        style: TextStyle(color: AppColors.muted, fontSize: 9),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.forest800,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'Choose file',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Container(
              key: ValueKey(file!.name),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.forest50,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.forest100),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      file!.extension?.toLowerCase() == 'pdf'
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                      color: AppColors.forest700,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.forest600,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'READY TO UPLOAD',
                              style: TextStyle(
                                color: AppColors.forest700,
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          file!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fileSize(file!.size),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Replace file',
                    onPressed: enabled ? onPick : null,
                    icon: const Icon(Icons.sync_rounded, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Remove file',
                    onPressed: enabled ? onRemove : null,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.danger,
                      size: 19,
                    ),
                  ),
                ],
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

String _displayDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

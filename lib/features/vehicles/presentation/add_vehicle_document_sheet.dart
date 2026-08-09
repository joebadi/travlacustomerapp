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
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
  DateTime? _issuedDate;
  PlatformFile? _file;
  String? _error;
  bool _isSubmitting = false;

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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: .92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
              child: Row(
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
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.forest100,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.post_add_rounded,
                      color: AppColors.forest700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Add a legal paper to this vehicle’s private vault.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(List<AvailableDocumentType> types) {
    final selected = types
        .where((type) => type.type == _selectedTypeValue)
        .firstOrNull;
    final isRenewable = selected?.isRenewable == true;
    final derivedExpiry = _issuedDate == null
        ? null
        : oneYearAfterNoOverflow(_issuedDate!);

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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9E7),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFFF5BBB5)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          DropdownButtonFormField<String>(
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
                      type.alreadyAdded ? '${type.name} · replace' : type.name,
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
                      _error = null;
                    });
                  },
            validator: (value) => value == null || value.isEmpty
                ? 'Select a document type.'
                : null,
          ),
          if (selected?.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.forest50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                selected!.description!,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (selected != null) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberController,
              enabled: !_isSubmitting,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: isRenewable
                    ? 'Document number'
                    : 'Reference / document number',
                hintText: isRenewable ? null : 'Optional',
                prefixIcon: const Icon(Icons.numbers_rounded),
              ),
              validator: (value) => isRenewable && value!.trim().isEmpty
                  ? 'Enter the document number.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorityController,
              enabled: !_isSubmitting,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: isRenewable ? 'Issuing authority' : 'Issued by',
                hintText: isRenewable ? null : 'Optional',
                prefixIcon: const Icon(Icons.account_balance_outlined),
              ),
              validator: (value) => isRenewable && value!.trim().isEmpty
                  ? 'Enter the issuing authority.'
                  : null,
            ),
            const SizedBox(height: 12),
            _DateField(
              label: isRenewable ? 'Issue date' : 'Issue date · optional',
              value: _issuedDate,
              enabled: !_isSubmitting,
              onTap: _selectIssuedDate,
              errorText: isRenewable && _issuedDate == null
                  ? 'Required for renewable papers'
                  : null,
            ),
            if (isRenewable) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Expiry date · automatic',
                  prefixIcon: Icon(Icons.event_available_outlined),
                  helperText: 'Exactly one calendar year after the issue date.',
                ),
                child: Text(
                  derivedExpiry == null
                      ? 'Select the issue date'
                      : _displayDate(derivedExpiry),
                  style: TextStyle(
                    color: derivedExpiry == null
                        ? AppColors.muted
                        : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _FilePickerCard(
              file: _file,
              required: selected.fileRequired,
              enabled: !_isSubmitting,
              onPick: _pickFile,
              onRemove: () => setState(() => _file = null),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : () => _submit(selected),
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _isSubmitting
                    ? 'Saving document…'
                    : selected.alreadyAdded
                    ? 'Replace document'
                    : 'Save document',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Files are stored privately and accessed through short-lived secure links.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
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
    if (type.fileRequired && _file == null) {
      setState(() {
        _error = 'This document type requires a JPG, PNG or PDF file.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(vehicleDetailRepositoryProvider)
          .uploadDocument(
            vehicleId: widget.vehicleId,
            documentType: type.type,
            documentNumber: _numberController.text,
            issuingAuthority: _authorityController.text,
            issuedDate: _issuedDate,
            filePath: _file?.path,
            fileName: _file?.name,
          );
      ref.invalidate(vehicleDetailProvider(widget.vehicleId));
      ref.invalidate(availableDocumentTypesProvider(widget.vehicleId));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: file == null
          ? Row(
              children: [
                const Icon(
                  Icons.attach_file_rounded,
                  color: AppColors.forest700,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        required ? 'Document file · required' : 'Document file',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'JPG, PNG or PDF · maximum 5 MB',
                        style: TextStyle(color: AppColors.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: enabled ? onPick : null,
                  child: const Text('Choose'),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.forest50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.task_outlined,
                    color: AppColors.forest700,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _fileSize(file!.size),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove file',
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.close_rounded, size: 20),
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

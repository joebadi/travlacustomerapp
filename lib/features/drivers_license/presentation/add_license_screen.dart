import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/drivers_license/data/drivers_license_repository.dart';
import 'package:travla_customer_app/features/drivers_license/domain/drivers_license.dart';
import 'package:travla_customer_app/shared/data/nigerian_states.dart';
import 'package:travla_customer_app/shared/widgets/travla_app_bar.dart';

class AddLicenseScreen extends ConsumerStatefulWidget {
  const AddLicenseScreen({super.key});

  @override
  ConsumerState<AddLicenseScreen> createState() => _AddLicenseScreenState();
}

class _AddLicenseScreenState extends ConsumerState<AddLicenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();

  DateTime? _dob;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  String? _state;
  String? _class;
  PlatformFile? _document;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _document = result.files.first);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dob == null || _issueDate == null || _expiryDate == null) {
      setState(() => _error = 'Set the date of birth, issue and expiry dates.');
      return;
    }
    if (_state == null || _class == null) {
      setState(() => _error = 'Select the state and licence class.');
      return;
    }
    if (!_expiryDate!.isAfter(_issueDate!)) {
      setState(() => _error = 'Expiry date must be after the issue date.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final DriversLicense created = await ref
          .read(driversLicenseRepositoryProvider)
          .create(
            licenseNumber: _number.text,
            firstName: _firstName.text,
            lastName: _lastName.text,
            dateOfBirth: _ymd(_dob!),
            address: _address.text,
            city: _city.text,
            state: _state!,
            licenseClass: _class!,
            issueDate: _ymd(_issueDate!),
            expiryDate: _ymd(_expiryDate!),
            document: _document,
          );
      ref.invalidate(driversLicensesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${created.holderName}\'s licence added.')),
      );
      context.pop();
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const TravlaAppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          children: [
            Text(
              'Add driver\'s licence',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter the details exactly as they appear on the licence.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              _ErrorBanner(_error!),
              const SizedBox(height: 14),
            ],
            _field(
              _number,
              'Licence number',
              icon: Icons.badge_outlined,
              textCapitalization: TextCapitalization.characters,
            ),
            Row(
              children: [
                Expanded(child: _field(_firstName, 'First name')),
                const SizedBox(width: 10),
                Expanded(child: _field(_lastName, 'Last name')),
              ],
            ),
            _DateTile(
              label: 'Date of birth',
              value: _dob,
              onTap: () => _pickDate(
                initial: _dob ?? DateTime(now.year - 25),
                first: DateTime(1940),
                last: DateTime(now.year - 16, now.month, now.day),
                onPicked: (d) => setState(() => _dob = d),
              ),
            ),
            _field(_address, 'Address', icon: Icons.home_outlined),
            Row(
              children: [
                Expanded(child: _field(_city, 'City')),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _state,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'State'),
                    items: nigerianStates
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _state = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _class,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Licence class',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: licenseClassOptions
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.value,
                      child: Text(c.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (v) => setState(() => _class = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Issue date',
                    value: _issueDate,
                    onTap: () => _pickDate(
                      initial: _issueDate ?? now,
                      first: DateTime(1990),
                      last: now,
                      onPicked: (d) => setState(() => _issueDate = d),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateTile(
                    label: 'Expiry date',
                    value: _expiryDate,
                    onTap: () => _pickDate(
                      initial: _expiryDate ?? DateTime(now.year + 3),
                      first: now,
                      last: DateTime(now.year + 10),
                      onPicked: (d) => setState(() => _expiryDate = d),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DocumentPicker(
              file: _document,
              onPick: _pickDocument,
              onClear: () => setState(() => _document = null),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(
                _submitting ? 'Saving…' : 'Save licence',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.event_outlined),
          ),
          child: Text(
            value == null
                ? 'Select'
                : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: value == null ? AppColors.muted : AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  final PlatformFile? file;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasFile ? AppColors.forest700 : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.check_circle_rounded : Icons.upload_file_outlined,
              color: hasFile ? AppColors.forest700 : AppColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? file!.name : 'Upload a copy (optional)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'JPG, PNG or PDF · needed later to renew',
                    style: TextStyle(color: AppColors.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (hasFile)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5BBB5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

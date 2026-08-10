import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';

class AddPolicyScreen extends ConsumerStatefulWidget {
  const AddPolicyScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<AddPolicyScreen> createState() => _AddPolicyScreenState();
}

class _AddPolicyScreenState extends ConsumerState<AddPolicyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _providerCtrl = TextEditingController();
  final _policyNumberCtrl = TextEditingController();
  final _premiumCtrl = TextEditingController();
  final _excessCtrl = TextEditingController();

  static const _otherInsurer = '__other__';

  String? _insurerId; // company id, or _otherInsurer, or null
  String? _coverageType;
  DateTime? _startDate;
  DateTime? _endDate;
  PlatformFile? _document;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _providerCtrl.dispose();
    _policyNumberCtrl.dispose();
    _premiumCtrl.dispose();
    _excessCtrl.dispose();
    super.dispose();
  }

  bool get _isOther => _insurerId == _otherInsurer;

  int? _kobo(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', ''));
    if (value == null) return null;
    return (value * 100).round();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? (_startDate ?? now) : (_endDate ?? now),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _document = result.files.first);
    }
  }

  Future<void> _submit(List<InsuranceCompany> insurers) async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_coverageType == null) {
      setState(() => _error = 'Choose a coverage type.');
      return;
    }
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Set the cover start and end dates.');
      return;
    }
    if (!_endDate!.isAfter(_startDate!)) {
      setState(() => _error = 'The end date must be after the start date.');
      return;
    }

    final companyId = (_insurerId != null && !_isOther) ? _insurerId : null;
    final provider = _isOther || _insurerId == null
        ? _providerCtrl.text.trim()
        : insurers.firstWhere((c) => c.id == _insurerId).name;
    if (provider.isEmpty) {
      setState(() => _error = 'Enter the insurer name.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(insuranceRepositoryProvider).addPolicy(
            vehicleId: widget.vehicleId,
            insuranceCompanyId: companyId,
            provider: provider,
            policyNumber: _policyNumberCtrl.text,
            coverageType: _coverageType!,
            startDate: _ymd(_startDate!),
            endDate: _ymd(_endDate!),
            premiumKobo: _kobo(_premiumCtrl.text),
            excessKobo: _kobo(_excessCtrl.text),
            document: _document,
          );
      ref.invalidate(vehicleInsuranceProvider(widget.vehicleId));
      ref.invalidate(expiringPoliciesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Policy added.')));
      context.pop();
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insurersAsync = ref.watch(insurersProvider);
    final insurers = insurersAsync.value ?? const <InsuranceCompany>[];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Add insurance policy')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
          children: [
            if (_error != null) ...[
              _ErrorBanner(_error!),
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<String>(
              initialValue: _insurerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Insurer'),
              items: [
                ...insurers.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                ),
                const DropdownMenuItem(
                  value: _otherInsurer,
                  child: Text('Other (type the name)'),
                ),
              ],
              validator: (value) =>
                  value == null ? 'Choose your insurer.' : null,
              onChanged: (value) => setState(() => _insurerId = value),
            ),
            if (_isOther) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _providerCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Insurer name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter the insurer name.'
                    : null,
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _policyNumberCtrl,
              decoration: const InputDecoration(labelText: 'Policy number'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter the policy number.'
                  : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _coverageType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Coverage type'),
              items: coverageTypeOptions
                  .map(
                    (o) => DropdownMenuItem(
                      value: o.value,
                      child: Text(o.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _coverageType = value),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Start date',
                    value: _startDate,
                    onTap: () => _pickDate(start: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTile(
                    label: 'End date',
                    value: _endDate,
                    onTap: () => _pickDate(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _premiumCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Premium (₦)',
                      hintText: 'Optional',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _excessCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Excess (₦)',
                      hintText: 'Optional',
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : () => _submit(insurers),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save policy'),
            ),
          ],
        ),
      ),
    );
  }

  String _ymd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value == null
              ? 'Select'
              : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
          style: TextStyle(
            color: value == null ? AppColors.muted : AppColors.ink,
            fontWeight: FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, color: AppColors.forest700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file == null ? 'Certificate (optional)' : file!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                const Text(
                  'PDF, JPG or PNG · up to 8MB',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          file == null
              ? TextButton(onPressed: onPick, child: const Text('Attach'))
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ],
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

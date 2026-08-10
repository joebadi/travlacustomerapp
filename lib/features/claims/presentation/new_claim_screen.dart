import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/claims/data/claim_repository.dart';
import 'package:travla_customer_app/features/claims/presentation/claim_widgets.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';

/// Files a claim draft. Collects the incident details in one scroll; evidence
/// uploads and the police-report-fee payment happen on the claim detail after
/// the draft is created.
class NewClaimScreen extends ConsumerStatefulWidget {
  const NewClaimScreen({super.key, this.vehicleId});

  final String? vehicleId;

  @override
  ConsumerState<NewClaimScreen> createState() => _NewClaimScreenState();
}

class _NewClaimScreenState extends ConsumerState<NewClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _damageCtrl = TextEditingController();
  final _policeNumberCtrl = TextEditingController();
  final _otherPlateCtrl = TextEditingController();
  final _witnessCtrl = TextEditingController();
  final _estimateCtrl = TextEditingController();

  String? _vehicleId;
  String? _claimType;
  String? _severity;
  DateTime? _incidentDate;
  bool _thirdParty = false;
  String? _fault;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vehicleId = (widget.vehicleId?.isNotEmpty ?? false) ? widget.vehicleId : null;
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _damageCtrl.dispose();
    _policeNumberCtrl.dispose();
    _otherPlateCtrl.dispose();
    _witnessCtrl.dispose();
    _estimateCtrl.dispose();
    super.dispose();
  }

  int? _kobo(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', ''));
    if (value == null) return null;
    return (value * 100).round();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) setState(() => _incidentDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_vehicleId == null) {
      setState(() => _error = 'Choose the vehicle involved.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_claimType == null) {
      setState(() => _error = 'Choose what kind of claim this is.');
      return;
    }
    if (_incidentDate == null) {
      setState(() => _error = 'Set the incident date.');
      return;
    }

    final payload = <String, dynamic>{
      'claim_type': _claimType,
      'incident_date': _ymd(_incidentDate!),
      'location': _locationCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      if (_severity != null) 'severity': _severity,
      if (_damageCtrl.text.trim().isNotEmpty)
        'damage_description': _damageCtrl.text.trim(),
      if (_policeNumberCtrl.text.trim().isNotEmpty)
        'police_report_number': _policeNumberCtrl.text.trim(),
      'third_party_involved': _thirdParty,
      if (_thirdParty && _fault != null) 'fault': _fault,
      if (_thirdParty && _otherPlateCtrl.text.trim().isNotEmpty)
        'other_vehicle_plate': _otherPlateCtrl.text.trim(),
      if (_witnessCtrl.text.trim().isNotEmpty)
        'witness_info': _witnessCtrl.text.trim(),
      if (_kobo(_estimateCtrl.text) != null)
        'estimated_cost_kobo': _kobo(_estimateCtrl.text),
    };

    setState(() => _submitting = true);
    try {
      final claim = await ref.read(claimRepositoryProvider).createDraft(
            vehicleId: _vehicleId!,
            payload: payload,
          );
      ref.invalidate(claimsListProvider);
      if (!mounted) return;
      context.pushReplacement('/more/claims/${claim.id}');
    } on ClaimsUnavailable {
      if (mounted) {
        setState(() {
          _error = 'The claims feature is not available for your account yet.';
          _submitting = false;
        });
      }
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
    final meta = ref.watch(claimMetaProvider);
    final garage = ref.watch(garageProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('File a claim')),
      body: meta.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => error is ClaimsUnavailable
            ? const ClaimsComingSoon()
            : ClaimErrorState(
                message: error is ApiFailure
                    ? error.message
                    : 'The claim form could not be loaded.',
                onRetry: () => ref.invalidate(claimMetaProvider),
              ),
        data: (meta) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              if (_error != null) ...[
                _Banner(_error!),
                const SizedBox(height: 14),
              ],
              _Label('Vehicle'),
              garage.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Vehicles could not be loaded.'),
                data: (snapshot) => _VehiclePicker(
                  vehicles: snapshot.vehicles,
                  value: _vehicleId,
                  onChanged: (v) => setState(() => _vehicleId = v),
                ),
              ),
              const SizedBox(height: 18),
              _Label('Incident'),
              DropdownButtonFormField<String>(
                initialValue: _claimType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Claim type'),
                items: meta.types
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.value,
                        child: Text(t.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _claimType = v),
              ),
              const SizedBox(height: 14),
              _DateTile(value: _incidentDate, onTap: _pickDate),
              const SizedBox(height: 14),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Where did it happen?',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter the incident location.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Describe what happened.'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Severity (optional)',
                ),
                items: meta.severities
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(_titleCase(s)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _severity = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _damageCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Damage description (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              _Label('Third party'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.forest700,
                title: const Text(
                  'Another vehicle or party was involved',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                value: _thirdParty,
                onChanged: (v) => setState(() => _thirdParty = v),
              ),
              if (_thirdParty) ...[
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _fault,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Who was at fault?'),
                  items: const [
                    DropdownMenuItem(value: 'SELF', child: Text('I was at fault')),
                    DropdownMenuItem(
                      value: 'OTHER',
                      child: Text('The other party'),
                    ),
                    DropdownMenuItem(value: 'SHARED', child: Text('Shared fault')),
                    DropdownMenuItem(value: 'UNSURE', child: Text('Not sure yet')),
                  ],
                  onChanged: (v) => setState(() => _fault = v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _otherPlateCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Other vehicle plate (optional)',
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _Label('More'),
              TextFormField(
                controller: _policeNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Police report number (optional)',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _estimateCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Estimated repair cost ₦ (optional)',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _witnessCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Witness details (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.forest50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.forest100),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.forest700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You\'ll add photos and documents, then pay the police-report fee (₦${meta.policeReportFeeNaira}) to submit — on the next screen.',
                        style: const TextStyle(
                          color: AppColors.forest800,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.orange,
                ),
                child: Text(
                  _submitting ? 'Saving…' : 'Save draft & continue',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String _titleCase(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker({
    required this.vehicles,
    required this.value,
    required this.onChanged,
  });

  final List<VehicleSummary> vehicles;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return const Text(
        'Add an insured vehicle before filing a claim.',
        style: TextStyle(color: AppColors.muted),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Vehicle involved',
        prefixIcon: Icon(Icons.directions_car_outlined),
      ),
      items: vehicles
          .map(
            (v) => DropdownMenuItem(
              value: v.id,
              child: Text(
                v.plateNumber?.isNotEmpty == true
                    ? '${v.displayName} · ${v.plateNumber}'
                    : v.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Incident date',
          prefixIcon: Icon(Icons.event_outlined),
        ),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.message);

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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/presentation/location_pin_button.dart';

class ReportStolenScreen extends ConsumerStatefulWidget {
  const ReportStolenScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<ReportStolenScreen> createState() => _ReportStolenScreenState();
}

class _ReportStolenScreenState extends ConsumerState<ReportStolenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _policeCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  DateTime? _occurredAt;
  bool _public = true;
  bool _submitting = false;
  bool _locating = false;
  double? _latitude;
  double? _longitude;
  String? _error;

  @override
  void dispose() {
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _policeCtrl.dispose();
    _rewardCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Turn on location (GPS), then try again.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('Location permission is required to pin the exact spot.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _occurredAt = picked);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final rewardKobo = () {
      final v = double.tryParse(_rewardCtrl.text.trim().replaceAll(',', ''));
      return v == null ? null : (v * 100).round();
    }();

    final payload = <String, dynamic>{
      'last_known_location': _locationCtrl.text.trim(),
      if (_latitude != null) 'last_known_latitude': _latitude,
      if (_longitude != null) 'last_known_longitude': _longitude,
      if (_occurredAt != null) 'theft_occurred_at': _ymd(_occurredAt!),
      if (_descriptionCtrl.text.trim().isNotEmpty)
        'description': _descriptionCtrl.text.trim(),
      if (_policeCtrl.text.trim().isNotEmpty)
        'police_report_number': _policeCtrl.text.trim(),
      'reward_kobo': ?rewardKobo,
      if (_contactCtrl.text.trim().isNotEmpty)
        'contact_info': _contactCtrl.text.trim(),
      'is_public': _public,
    };

    setState(() => _submitting = true);
    try {
      final report = await ref
          .read(stolenRepositoryProvider)
          .report(vehicleId: widget.vehicleId, payload: payload);
      ref.invalidate(myStolenReportsProvider);
      if (!mounted) return;
      context.pushReplacement('/more/stolen/${report.id}');
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
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Report stolen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Filing here alerts the Travla community and lets others report sightings. Also report to the police.',
                style: TextStyle(
                  color: AppColors.orangeDark,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              _Banner(_error!),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Where was it last seen?',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the last known location.'
                  : null,
            ),
            const SizedBox(height: 8),
            LocationPinButton(
              latitude: _latitude,
              longitude: _longitude,
              busy: _locating,
              onTap: _captureLocation,
            ),
            const SizedBox(height: 14),
            _DateTile(value: _occurredAt, onTap: _pickDate),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'What happened? (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _policeCtrl,
              decoration: const InputDecoration(
                labelText: 'Police report number (optional)',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _rewardCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Reward ₦ (optional)',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact for tips (optional)',
                hintText: 'Phone or email shown to the community',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.forest700,
              title: const Text(
                'List publicly in the community registry',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: const Text(
                'Lets anyone check the plate and report sightings.',
                style: TextStyle(fontSize: 11.5),
              ),
              value: _public,
              onChanged: (v) => setState(() => _public = v),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.danger,
              ),
              child: Text(
                _submitting ? 'Reporting…' : 'Report as stolen',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
          labelText: 'When was it stolen? (optional)',
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

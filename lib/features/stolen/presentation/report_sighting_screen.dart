import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';

class ReportSightingScreen extends ConsumerStatefulWidget {
  const ReportSightingScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<ReportSightingScreen> createState() => _ReportSightingScreenState();
}

class _ReportSightingScreenState extends ConsumerState<ReportSightingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();
  final _directionCtrl = TextEditingController();

  String? _state;
  DateTime? _date;
  bool _anonymous = false;
  final List<PlatformFile> _photos = [];
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _driverCtrl.dispose();
    _directionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result != null) {
      setState(() {
        for (final f in result.files) {
          if (_photos.length < 5 && !_photos.any((p) => p.name == f.name)) _photos.add(f);
        }
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final fields = <String, dynamic>{
      'location': _locationCtrl.text.trim(),
      if (_descriptionCtrl.text.trim().isNotEmpty) 'description': _descriptionCtrl.text.trim(),
      if (_driverCtrl.text.trim().isNotEmpty) 'driver_description': _driverCtrl.text.trim(),
      if (_state != null) 'vehicle_state': _state,
      if (_directionCtrl.text.trim().isNotEmpty) 'direction_of_travel': _directionCtrl.text.trim(),
      'submit_anonymously': _anonymous,
      if (_date != null) 'sighting_date': _ymd(_date!),
    };

    setState(() => _submitting = true);
    try {
      await ref.read(stolenRepositoryProvider).reportSighting(
            reportId: widget.reportId,
            fields: fields,
            photos: _photos,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Thank you — your sighting was reported.')));
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
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Report a sighting')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            if (_error != null) ...[
              _Banner(_error!),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Where did you see it?',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter where you saw it.' : null,
            ),
            const SizedBox(height: 14),
            _DateTile(value: _date, onTap: _pickDate),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _state,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Vehicle state (optional)'),
              items: sightingStateOptions
                  .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
                  .toList(),
              onChanged: (v) => setState(() => _state = v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _directionCtrl,
              decoration: const InputDecoration(labelText: 'Direction of travel (optional)', hintText: 'e.g. heading north on Awolowo Rd'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _driverCtrl,
              decoration: const InputDecoration(labelText: 'Driver description (optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Anything else? (optional)', alignLabelWithHint: true),
            ),
            const SizedBox(height: 14),
            _PhotoPicker(
              photos: _photos,
              onAdd: _pickPhotos,
              onRemove: (f) => setState(() => _photos.remove(f)),
            ),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.forest700,
              title: const Text('Report anonymously', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Your name is not shown to the owner.', style: TextStyle(fontSize: 11.5)),
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppColors.orange),
              child: Text(_submitting ? 'Submitting…' : 'Submit sighting', style: const TextStyle(fontWeight: FontWeight.w900)),
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
        decoration: const InputDecoration(labelText: 'When? (optional)', prefixIcon: Icon(Icons.event_outlined)),
        child: Text(
          value == null
              ? 'Select'
              : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
          style: TextStyle(color: value == null ? AppColors.muted : AppColors.ink, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photos, required this.onAdd, required this.onRemove});
  final List<PlatformFile> photos;
  final VoidCallback onAdd;
  final void Function(PlatformFile) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Photos (optional, up to 5)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              if (photos.length < 5)
                TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_a_photo_outlined, size: 18), label: const Text('Add')),
            ],
          ),
          if (photos.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: photos
                  .map((f) => Chip(
                        label: Text(f.name, overflow: TextOverflow.ellipsis),
                        onDeleted: () => onRemove(f),
                      ))
                  .toList(),
            ),
        ],
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
      decoration: BoxDecoration(color: const Color(0xFFFFE3E1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 12.5))),
        ],
      ),
    );
  }
}

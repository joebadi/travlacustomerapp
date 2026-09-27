import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';
import 'package:travla_customer_app/features/stolen/presentation/location_pin_button.dart';

/// A private tip about a suspicious vehicle that isn't on the stolen registry.
/// Never published: Travla holds it for 30 days and passes it to the owner as
/// an anonymous sighting only if the vehicle is (or gets) reported stolen.
class ReportTipScreen extends ConsumerStatefulWidget {
  const ReportTipScreen({super.key, this.initialPlate});

  final String? initialPlate;

  @override
  ConsumerState<ReportTipScreen> createState() => _ReportTipScreenState();
}

class _ReportTipScreenState extends ConsumerState<ReportTipScreen> {
  static const _maxPhotos = 3;
  static const _windowDays = 30;

  final _formKey = GlobalKey<FormState>();
  late final _plateCtrl = TextEditingController(
    text: widget.initialPlate ?? '',
  );
  final _locationCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String? _state;
  // Null means "just now" — the server stamps it, so a fast phone clock can't
  // trip the "in the future" check.
  DateTime? _spottedAt;
  bool _locating = false;
  String? _locationNote;
  double? _latitude;
  double? _longitude;
  final List<PlatformFile> _photos = [];
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-capture where the user is standing — that's usually where they saw it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureLocation());
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _locationCtrl.dispose();
    _vehicleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _locating = true;
      _locationNote = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationNote =
            'Location is off — type where you saw it instead, or turn on GPS and tap to retry.';
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationNote =
            'No location permission — type where you saw it instead.';
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      _latitude = position.latitude;
      _longitude = position.longitude;
    } catch (_) {
      _locationNote =
          'Couldn’t get your location — type where you saw it instead.';
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickSpottedAt() async {
    final now = DateTime.now();
    final current = _spottedAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: _windowDays - 1)),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted) return;
    var picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? current.hour,
      time?.minute ?? current.minute,
    );
    if (picked.isAfter(now)) picked = now;
    setState(() => _spottedAt = picked);
  }

  Future<void> _addPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final shot = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 1600,
        );
        picked = shot == null ? const [] : [shot];
      } else {
        picked = await picker.pickMultiImage(
          imageQuality: 70,
          maxWidth: 1600,
          limit: _maxPhotos - _photos.length,
        );
      }
      if (picked.isEmpty || !mounted) return;
      final files = <PlatformFile>[];
      for (final x in picked) {
        files.add(
          PlatformFile(name: x.name, path: x.path, size: await x.length()),
        );
      }
      if (!mounted) return;
      setState(() {
        for (final f in files) {
          if (_photos.length < _maxPhotos) _photos.add(f);
        }
      });
    } catch (_) {
      _snack('Couldn’t add that photo.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final hasPin = _latitude != null && _longitude != null;
    if (!hasPin && _locationCtrl.text.trim().isEmpty) {
      setState(
        () =>
            _error = 'Share your location, or type where you saw the vehicle.',
      );
      return;
    }

    final fields = <String, dynamic>{
      'plate_number': _plateCtrl.text.trim(),
      if (hasPin) 'latitude': _latitude,
      if (hasPin) 'longitude': _longitude,
      if (_locationCtrl.text.trim().isNotEmpty)
        'location': _locationCtrl.text.trim(),
      if (_vehicleCtrl.text.trim().isNotEmpty)
        'vehicle_description': _vehicleCtrl.text.trim(),
      if (_state != null) 'vehicle_state': _state,
      if (_descriptionCtrl.text.trim().isNotEmpty)
        'description': _descriptionCtrl.text.trim(),
      if (_spottedAt != null)
        'spotted_at': _spottedAt!.toUtc().toIso8601String(),
    };

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(stolenRepositoryProvider)
          .submitTip(fields: fields, photos: _photos);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            result.onPublicRegistry
                ? Icons.campaign_outlined
                : Icons.lock_outline_rounded,
            color: AppColors.forest700,
          ),
          title: Text(
            result.onPublicRegistry ? 'Sent to the owner' : 'Tip received',
          ),
          content: Text(result.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
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
      appBar: AppBar(title: const Text('Suspicious vehicle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            const _PrivacyCard(),
            const SizedBox(height: 14),
            if (_error != null) ...[
              _Banner(_error!),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _plateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Plate number',
                hintText: 'e.g. ABC 123 XY',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              validator: (v) {
                final plate = (v ?? '').replaceAll(RegExp('[^A-Za-z0-9]'), '');
                if (plate.length < 3) return 'Enter the plate number you saw.';
                if (!RegExp(r'^[A-Za-z0-9 \-]+$').hasMatch(v!.trim())) {
                  return 'Use letters, numbers, spaces or dashes.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            LocationPinButton(
              latitude: _latitude,
              longitude: _longitude,
              busy: _locating,
              onTap: _captureLocation,
              label: 'Use my current location',
            ),
            if (_locationNote != null) ...[
              const SizedBox(height: 6),
              Text(
                _locationNote!,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                labelText: _latitude != null
                    ? 'Landmark or street (optional)'
                    : 'Where did you see it?',
                hintText: 'e.g. near Enerhen junction, Warri',
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 14),
            _WhenTile(value: _spottedAt, onTap: _pickSpottedAt),
            const SizedBox(height: 14),
            TextFormField(
              controller: _vehicleCtrl,
              decoration: const InputDecoration(
                labelText: 'Vehicle (optional)',
                hintText: 'e.g. black Toyota Camry, cracked windscreen',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _state,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Vehicle state (optional)',
              ),
              items: sightingStateOptions
                  .map(
                    (o) =>
                        DropdownMenuItem(value: o.value, child: Text(o.label)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _state = v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'What looked suspicious? (optional)',
                hintText:
                    'e.g. plates being swapped, parked for days, no plates…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 6),
            _PhotoPicker(
              photos: _photos,
              max: _maxPhotos,
              onCamera: () => _addPhoto(ImageSource.camera),
              onGallery: () => _addPhoto(ImageSource.gallery),
              onRemove: (f) => setState(() => _photos.remove(f)),
            ),
            const SizedBox(height: 14),
            const _SafetyNote(),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.orange,
              ),
              child: Text(
                _submitting ? 'Sending…' : 'Send private tip',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: AppColors.forest700,
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This tip is private',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  'It’s never published. If this vehicle is reported stolen within 30 days, '
                  'we pass it to the owner as a sighting — without your name. Otherwise it’s '
                  'deleted. False or malicious tips can lead to your account being suspended.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.orange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Stay safe: never approach, follow or confront anyone. If you believe a crime '
              'is happening, call the police (112).',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhenTile extends StatelessWidget {
  const _WhenTile({required this.value, required this.onTap});
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final text = v == null
        ? 'Just now'
        : '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}, '
              '${TimeOfDay.fromDateTime(v).format(context)}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'When did you see it?',
          prefixIcon: Icon(Icons.schedule_outlined),
          suffixIcon: Icon(Icons.edit_calendar_outlined, size: 20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.max,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });
  final List<PlatformFile> photos;
  final int max;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final void Function(PlatformFile) onRemove;

  @override
  Widget build(BuildContext context) {
    final canAdd = photos.length < max;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
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
              Expanded(
                child: Text(
                  'Photos (optional, up to $max)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (canAdd) ...[
                IconButton(
                  tooltip: 'Take a photo',
                  onPressed: onCamera,
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Choose from gallery',
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                ),
              ],
            ],
          ),
          if (photos.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: photos
                  .map(
                    (f) => Chip(
                      label: Text(f.name, overflow: TextOverflow.ellipsis),
                      onDeleted: () => onRemove(f),
                    ),
                  )
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

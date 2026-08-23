import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/journeys/data/journey_repository.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_models.dart';

/// Bottom sheet to drop a road-report tag at [position] while recording or
/// following — pick a type, add a note, and optionally attach a photo, a voice
/// note, or a short video. Calls [onDone] after a successful submit.
Future<void> showDropRoadTagSheet(
  BuildContext context, {
  required LatLng position,
  VoidCallback? onDone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DropRoadTagSheet(position: position, onDone: onDone),
  );
}

class _DropRoadTagSheet extends ConsumerStatefulWidget {
  const _DropRoadTagSheet({required this.position, this.onDone});

  final LatLng position;
  final VoidCallback? onDone;

  @override
  ConsumerState<_DropRoadTagSheet> createState() => _DropRoadTagSheetState();
}

class _DropRoadTagSheetState extends ConsumerState<_DropRoadTagSheet> {
  final _noteCtrl = TextEditingController();
  final _recorder = AudioRecorder();

  String? _type;
  String? _photoPath;
  String? _audioPath;
  String? _videoPath;
  bool _recordingAudio = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (x != null) setState(() => _photoPath = x.path);
  }

  Future<void> _pickVideo() async {
    final x = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    if (x != null) setState(() => _videoPath = x.path);
  }

  Future<void> _toggleAudio() async {
    if (_recordingAudio) {
      final path = await _recorder.stop();
      setState(() {
        _recordingAudio = false;
        _audioPath = path;
      });
      return;
    }
    if (!await _recorder.hasPermission()) {
      setState(() => _error = 'Microphone permission is needed to record audio.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/tag_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _recordingAudio = true;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final type = _type;
    if (type == null) {
      setState(() => _error = 'Choose what you are reporting.');
      return;
    }
    if (_recordingAudio) await _toggleAudio(); // stop a running recording first
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(journeyRepositoryProvider).createRoadReport(
            type: type,
            latitude: widget.position.latitude,
            longitude: widget.position.longitude,
            description: _noteCtrl.text.trim(),
            photoPath: _photoPath,
            audioPath: _audioPath,
            videoPath: _videoPath,
          );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDone?.call();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Tag dropped. Thank you!')));
      }
    } on ApiFailure catch (f) {
      setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(roadReportCatalogueProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Drop a road tag',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 2),
              const Text(
                'Pinned at your current spot for anyone following this route.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              catalogue.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const Text('Tag types could not be loaded.',
                    style: TextStyle(color: AppColors.danger, fontSize: 12.5)),
                data: (types) => DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'What is it?'),
                  items: [
                    for (final RoadReportType t in types)
                      DropdownMenuItem(value: t.value, child: Text(t.label)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _type = v),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. deep pothole in the right lane',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _mediaButton(
                    icon: _photoPath != null ? Icons.check_circle_rounded : Icons.photo_camera_outlined,
                    label: 'Photo',
                    active: _photoPath != null,
                    onTap: _busy ? null : _pickPhoto,
                  ),
                  const SizedBox(width: 8),
                  _mediaButton(
                    icon: _recordingAudio
                        ? Icons.stop_circle_rounded
                        : (_audioPath != null ? Icons.check_circle_rounded : Icons.mic_none_rounded),
                    label: _recordingAudio ? 'Stop' : 'Audio',
                    active: _audioPath != null || _recordingAudio,
                    onTap: _busy ? null : _toggleAudio,
                  ),
                  const SizedBox(width: 8),
                  _mediaButton(
                    icon: _videoPath != null ? Icons.check_circle_rounded : Icons.videocam_outlined,
                    label: 'Video',
                    active: _videoPath != null,
                    onTap: _busy ? null : _pickVideo,
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.orange,
                ),
                child: Text(_busy ? 'Submitting…' : 'Drop tag'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: active ? AppColors.forest700 : AppColors.ink,
          side: BorderSide(color: active ? AppColors.forest700 : AppColors.border),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
      ),
    );
  }
}

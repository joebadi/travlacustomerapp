import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/journeys/data/journey_repository.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_models.dart';
import 'package:video_player/video_player.dart';

/// View a road tag's details + media, and confirm it's there or counter it
/// ("it's been repaired / not there") with photo/video evidence.
Future<void> showRoadTagSheet(
  BuildContext context, {
  required NearbyRoadReport report,
  VoidCallback? onVoted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RoadTagSheet(report: report, onVoted: onVoted),
  );
}

class _RoadTagSheet extends ConsumerStatefulWidget {
  const _RoadTagSheet({required this.report, this.onVoted});

  final NearbyRoadReport report;
  final VoidCallback? onVoted;

  @override
  ConsumerState<_RoadTagSheet> createState() => _RoadTagSheetState();
}

class _RoadTagSheetState extends ConsumerState<_RoadTagSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    await _vote('CONFIRM');
  }

  Future<void> _counter() async {
    // Disputing demands visual proof — capture a photo or a short video.
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                'Show us it is no longer there — add a photo or a short video.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(c).pop('photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Record a video'),
              onTap: () => Navigator.of(c).pop('video'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final XFile? file = source == 'photo'
        ? await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600)
        : await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 30));
    if (file == null) return;
    await _vote('DISPUTE', evidencePath: file.path);
  }

  Future<void> _vote(String vote, {String? evidencePath}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(journeyRepositoryProvider).voteRoadReport(
            widget.report.id,
            vote: vote,
            evidencePath: evidencePath,
          );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onVoted?.call();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(vote == 'CONFIRM' ? 'Thanks — confirmed.' : 'Thanks — countered.'),
          ));
      }
    } on ApiFailure catch (f) {
      setState(() => _error = f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    r.isDirectional ? Icons.do_not_disturb_on_outlined : Icons.warning_amber_rounded,
                    color: r.isDirectional ? const Color(0xFF6B7A99) : AppColors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.typeLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  if (r.verificationLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.forest50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(r.verificationLabel!,
                          style: const TextStyle(
                              color: AppColors.forest700, fontSize: 9.5, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              if (r.description != null && r.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(r.description!,
                    style: const TextStyle(color: AppColors.ink, height: 1.4)),
              ],
              if (r.hasMedia) ...[
                const SizedBox(height: 14),
                _MediaStrip(media: r.media),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _confirm,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: AppColors.forest700,
                        side: const BorderSide(color: AppColors.forest700),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text("It's here"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _counter,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: AppColors.danger,
                      ),
                      icon: const Icon(Icons.report_gmailerrorred_outlined, size: 18),
                      label: const Text('Not there'),
                    ),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const Center(
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaStrip extends StatelessWidget {
  const _MediaStrip({required this.media});

  final List<ReportMedia> media;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in media)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: m.isPhoto
                ? _PhotoThumb(url: m.url)
                : m.isAudio
                    ? _AudioChip(url: m.url)
                    : _VideoThumb(url: m.url),
          ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: 160,
            color: AppColors.canvas,
            child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _AudioChip extends StatefulWidget {
  const _AudioChip({required this.url});
  final String url;

  @override
  State<_AudioChip> createState() => _AudioChipState();
}

class _AudioChipState extends State<_AudioChip> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(widget.url));
      setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(_playing ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                color: AppColors.forest700, size: 26),
            const SizedBox(width: 10),
            const Text('Voice note', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _VideoDialog(url: url),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(width: 14),
            Icon(Icons.play_circle_fill_rounded, color: AppColors.forest700, size: 30),
            SizedBox(width: 10),
            Text('Video clip', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _VideoDialog extends StatefulWidget {
  const _VideoDialog({required this.url});
  final String url;

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late final VideoPlayerController _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
          _c.play();
        }
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: _ready
          ? GestureDetector(
              onTap: () => setState(() => _c.value.isPlaying ? _c.pause() : _c.play()),
              child: AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
            )
          : const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
    );
  }
}

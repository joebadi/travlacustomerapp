import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/journeys/data/journey_repository.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_models.dart';

class JourneyDetailScreen extends ConsumerWidget {
  const JourneyDetailScreen({super.key, required this.journeyId});

  final String journeyId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this journey?'),
        content: const Text('This permanently removes the saved trail.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(journeyRepositoryProvider).delete(journeyId);
      ref.invalidate(journeysProvider);
      if (context.mounted) context.pop();
    } on ApiFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  void _openShareSheet(BuildContext context, Journey journey) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ShareSheet(journeyId: journeyId),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final copy = await ref.read(journeyRepositoryProvider).importJourney(journeyId);
      ref.invalidate(journeysProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved to your journeys.')));
      context.pushReplacement('/journeys/${copy.id}');
    } on ApiFailure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(journeyProvider(journeyId));
    final journey = async.value;
    final isMine = journey?.isMine ?? true;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(journey?.title ?? 'Journey'),
        actions: [
          if (journey != null && isMine) ...[
            IconButton(
              tooltip: 'Share',
              onPressed: () => _openShareSheet(context, journey),
              icon: const Icon(Icons.ios_share_rounded),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => _delete(context, ref),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error is ApiFailure ? error.message : 'This journey could not be loaded.', textAlign: TextAlign.center),
          ),
        ),
        data: (journey) {
          // Prefer the road-snapped path when available; fall back to the raw
          // recorded trail otherwise.
          final points =
              journey.displayTrail.map((p) => LatLng(p.lat, p.lng)).toList();
          return Column(
            children: [
              Expanded(
                child: points.length < 2
                    // A trail needs at least two points to draw or fit bounds;
                    // a single point can't (CameraFit on one coordinate is
                    // degenerate), so show a clear empty state instead.
                    ? const Center(
                        child: Text(
                          'No trail was recorded for this journey.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCameraFit: CameraFit.coordinates(
                            coordinates: points,
                            padding: const EdgeInsets.all(48),
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'ng.com.travla.customer',
                          ),
                          PolylineLayer(polylines: [Polyline(points: points, strokeWidth: 5, color: AppColors.orange)]),
                          MarkerLayer(markers: [
                            _pin(points.first, AppColors.forest700),
                            _pin(points.last, AppColors.danger),
                          ]),
                        ],
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (journey.transportModeLabel != null ||
                        journey.vehiclePlate != null ||
                        journey.isMatched)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          [
                            journey.transportModeLabel,
                            journey.vehiclePlate,
                            if (journey.isMatched) 'Snapped to road',
                          ].where((s) => s != null).join(' · '),
                          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                        ),
                      ),
                    Row(
                      children: [
                        _stat('${journey.distanceKm.toStringAsFixed(2)} km', 'Distance'),
                        _stat(journey.durationLabel, 'Duration'),
                        _stat('${journey.pointCount}', 'Points'),
                      ],
                    ),
                    if (journey.description != null && journey.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(journey.description!, style: const TextStyle(color: AppColors.ink, height: 1.4)),
                    ],
                    if (!journey.isMine)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.visibility_off_outlined,
                                size: 14, color: AppColors.muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Shared journey — start and end are hidden for privacy.',
                                style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (journey.displayTrail.length >= 2) ...[
                      const SizedBox(height: 14),
                      _HealthBanner(journeyId: journeyId),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.push('/journeys/$journeyId/follow'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.forest700,
                        ),
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text('Follow this journey'),
                      ),
                    ],
                    if (!journey.isMine) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _import(context, ref),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: AppColors.forest700,
                          side: const BorderSide(color: AppColors.forest700),
                        ),
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Save to my journeys'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Marker _pin(LatLng at, Color color) => Marker(
        point: at,
        width: 20,
        height: 20,
        child: Container(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
        ),
      );

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink)),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      );
}

/// Visibility + share-link control for a journey the signed-in user owns.
class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.journeyId});

  final String journeyId;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(journeyProvider(widget.journeyId));
      ref.invalidate(journeysProvider);
    } on ApiFailure catch (f) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  JourneyRepository get _repo => ref.read(journeyRepositoryProvider);

  @override
  Widget build(BuildContext context) {
    final journey = ref.watch(journeyProvider(widget.journeyId)).value;
    final visibility = journey?.visibility ?? 'PRIVATE';
    final url = journey?.shareUrl;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share journey',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 2),
            const Text(
              'Anyone you share with sees the route, but never your exact start '
              'and end — the first and last stretch stays private.',
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 14),
            _option(
              selected: visibility == 'PRIVATE',
              icon: Icons.lock_outline_rounded,
              title: 'Private',
              subtitle: 'Only you can see this journey.',
              onTap: _busy ? null : () => _run(() async {
                await _repo.setVisibility(widget.journeyId, 'PRIVATE');
              }),
            ),
            _option(
              selected: visibility == 'LINK',
              icon: Icons.link_rounded,
              title: 'Anyone with the link',
              subtitle: 'Share a private link that you can revoke anytime.',
              onTap: _busy ? null : () => _run(() async {
                await _repo.share(widget.journeyId);
              }),
            ),
            _option(
              selected: visibility == 'PUBLIC',
              icon: Icons.public_rounded,
              title: 'Public',
              subtitle: 'Discoverable by anyone in Travla.',
              onTap: _busy ? null : () => _run(() async {
                await _repo.setVisibility(widget.journeyId, 'PUBLIC');
              }),
            ),
            if ((journey?.isShared ?? false) && url != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.ink)),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(const SnackBar(content: Text('Link copied.')));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              if (visibility == 'LINK') ...[
                const SizedBox(height: 10),
                const Text('Link expiry',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    _expiryChip('No expiry', null, journey?.shareExpiresAt == null),
                    _expiryChip('7 days', 7, false),
                    _expiryChip('30 days', 30, false),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => SharePlus.instance.share(
                        ShareParams(text: url, subject: journey?.title ?? 'Travla journey')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.forest700,
                ),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share link'),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expiryChip(String label, int? days, bool selected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _busy ? null : (_) => _run(() async {
        await _repo.share(widget.journeyId, expiresInDays: days);
      }),
    );
  }

  Widget _option({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.forest700 : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          color: selected ? AppColors.forest50 : AppColors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.forest700 : AppColors.muted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: selected ? AppColors.forest700 : AppColors.ink)),
                  Text(subtitle,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.forest700, size: 20),
          ],
        ),
      ),
    );
  }
}

/// A subtle "recorded N ago · K road changes along this route" prompt so a
/// follower reviews a stale route before setting off. Silent when there's
/// nothing worth flagging.
class _HealthBanner extends ConsumerWidget {
  const _HealthBanner({required this.journeyId});

  final String journeyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(journeyHealthProvider(journeyId)).value;
    final summary = health?.summary;
    if (health == null || summary == null) return const SizedBox.shrink();

    final warn = health.isStale || health.hasChanges;
    final color = warn ? AppColors.orangeDark : AppColors.muted;
    final bg = warn ? const Color(0xFFFFF3EC) : AppColors.canvas;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warn ? const Color(0xFFFFD3BC) : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(warn ? Icons.info_outline_rounded : Icons.history_rounded,
              size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(summary,
                style: TextStyle(color: color, fontSize: 12, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

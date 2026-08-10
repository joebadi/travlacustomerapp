import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';

class StolenReportDetailScreen extends ConsumerStatefulWidget {
  const StolenReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<StolenReportDetailScreen> createState() => _StolenReportDetailScreenState();
}

class _StolenReportDetailScreenState extends ConsumerState<StolenReportDetailScreen> {
  bool _busy = false;

  void _refresh() {
    ref.invalidate(stolenReportProvider(widget.reportId));
    ref.invalidate(myStolenReportsProvider);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (done != null) _snack(done);
    } on ApiFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String confirm, {String? body}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: Text(confirm)),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stolenReportProvider(widget.reportId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Stolen report')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error is ApiFailure ? error.message : 'This report could not be loaded.',
                textAlign: TextAlign.center),
          ),
        ),
        data: (report) => Stack(
          children: [
            RefreshIndicator(
              color: AppColors.forest700,
              onRefresh: () async {
                _refresh();
                await ref.read(stolenReportProvider(widget.reportId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  _header(report),
                  const SizedBox(height: 14),
                  _details(report),
                  const SizedBox(height: 14),
                  _Label('Sightings (${report.sightings.length})'),
                  if (report.sightings.isEmpty)
                    const _Empty('No sightings reported yet.')
                  else
                    ...report.sightings.map((s) => _SightingCard(
                          sighting: s,
                          busy: _busy,
                          onVerify: () => _run(
                              () => ref.read(stolenRepositoryProvider).verifySighting(s.id),
                              done: 'Sighting verified.'),
                          onDismiss: () => _run(
                              () => ref.read(stolenRepositoryProvider).dismissSighting(s.id),
                              done: 'Sighting dismissed.'),
                        )),
                  if (report.isStolen) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (await _confirm('Mark as recovered?', 'Recovered',
                                  body: 'This flags the vehicle as found and closes the alert.')) {
                                _run(() => ref.read(stolenRepositoryProvider).recover(report.id),
                                    done: 'Marked recovered.');
                              }
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppColors.forest700,
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Mark as recovered'),
                    ),
                    const SizedBox(height: 9),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (await _confirm('Close this report?', 'Close',
                                  body: 'Removes the alert without marking the vehicle recovered.')) {
                                _run(() => ref.read(stolenRepositoryProvider).close(report.id),
                                    done: 'Report closed.');
                              }
                            },
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close report'),
                    ),
                  ],
                ],
              ),
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x22000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(StolenReport report) {
    final stolen = report.isStolen;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: stolen
              ? const [Color(0xFF8A1C13), AppColors.danger]
              : const [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(report.vehicle?.name ?? 'Vehicle',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(30)),
                child: Text(report.statusLabel.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          if (report.vehicle?.plateNumber != null) ...[
            const SizedBox(height: 4),
            Text(report.vehicle!.plateNumber!,
                style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ],
        ],
      ),
    );
  }

  Widget _details(StolenReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.lastKnownLocation != null) _line('Last seen', report.lastKnownLocation!),
          if (report.theftOccurredAt != null) _line('Stolen on', _fmt(report.theftOccurredAt)),
          if (report.dateReported != null) _line('Reported', _fmt(report.dateReported)),
          if (report.rewardNaira != null && report.rewardNaira != '0.00') _line('Reward', '₦${report.rewardNaira}'),
          if (report.policeReportNumber != null) _line('Police report', report.policeReportNumber!),
          if (report.contactInfo != null) _line('Contact', report.contactInfo!),
          _line('Listed publicly', report.isPublic ? 'Yes' : 'No'),
          if (report.description != null) ...[
            const SizedBox(height: 10),
            Text(report.description!, style: const TextStyle(color: AppColors.ink, height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5))),
            Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _SightingCard extends StatelessWidget {
  const _SightingCard({
    required this.sighting,
    required this.busy,
    required this.onVerify,
    required this.onDismiss,
  });

  final VehicleSighting sighting;
  final bool busy;
  final VoidCallback onVerify;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dimmed = sighting.isDismissed;
    return Opacity(
      opacity: dimmed ? .55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sighting.isVerified ? AppColors.forest700 : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: AppColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(sighting.location ?? 'Unknown location',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                if (sighting.isVerified)
                  const _Tag('Verified', AppColors.forest700)
                else if (sighting.isDismissed)
                  const _Tag('Dismissed', AppColors.muted),
              ],
            ),
            if (sighting.description != null) ...[
              const SizedBox(height: 6),
              Text(sighting.description!, style: const TextStyle(fontSize: 12.5, height: 1.4)),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                if (sighting.vehicleState != null) _meta(Icons.info_outline, _titleCase(sighting.vehicleState!)),
                if (sighting.directionOfTravel != null) _meta(Icons.navigation_outlined, sighting.directionOfTravel!),
                _meta(Icons.person_outline, sighting.submittedAnonymously ? 'Anonymous' : (sighting.reporterName ?? 'Reporter')),
                if (sighting.sightingDate != null) _meta(Icons.schedule, _fmt(sighting.sightingDate)),
              ],
            ),
            if (sighting.photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sighting.photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(sighting.photos[i], width: 64, height: 64, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(width: 64, height: 64, color: AppColors.border)),
                  ),
                ),
              ),
            ],
            if (!sighting.isVerified && !sighting.isDismissed) ...[
              const Divider(height: 20),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : onDismiss,
                    style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Dismiss'),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onVerify,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.forest50, foregroundColor: AppColors.forest800),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Verify'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.muted),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      );
}

String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase().replaceAll('_', ' ');

String _fmt(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

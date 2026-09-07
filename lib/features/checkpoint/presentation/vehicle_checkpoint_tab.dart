import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/checkpoint/data/checkpoint_repository.dart';
import 'package:travla_customer_app/features/checkpoint/domain/checkpoint_models.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compact owner control shown inside the vehicle Overview. The QR opens the
/// public, browser-based Checkpoint page; the app does not recreate the
/// officer-facing result as a native tab.
class VehicleCheckpointOverviewCard extends ConsumerStatefulWidget {
  const VehicleCheckpointOverviewCard({
    required this.vehicleId,
    required this.plateNumber,
    super.key,
  });

  final String vehicleId;
  final String plateNumber;

  @override
  ConsumerState<VehicleCheckpointOverviewCard> createState() =>
      _VehicleCheckpointOverviewCardState();
}

class _VehicleCheckpointOverviewCardState
    extends ConsumerState<VehicleCheckpointOverviewCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(checkpointProvider(widget.vehicleId));

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: workspace.when(
        loading: () => const SizedBox(
          height: 168,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
        error: (error, stackTrace) => const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CheckpointMark(active: false),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Travla Checkpoint',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Your printable vehicle QR will appear here when Checkpoint is available.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        data: _buildState,
      ),
    );
  }

  Widget _buildState(CheckpointState state) {
    final credential = state.credential;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 4, color: AppColors.orange),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CheckpointMark(active: state.active),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TRAVLA CHECKPOINT',
                          style: TextStyle(
                            color: AppColors.forest700,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.active
                              ? 'Your vehicle’s roadside QR'
                              : 'One QR for this vehicle’s papers',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: state.active ? 'ACTIVE' : 'NOT SET UP',
                    color: state.active
                        ? AppColors.forest700
                        : AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              const Text(
                'Scan to open a mobile-friendly public page with this vehicle’s current paper status. This is optional and does not replace original papers or official roadside checks.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              if (!state.eligible && state.eligibilityMessage != null) ...[
                const SizedBox(height: 12),
                _Notice(text: state.eligibilityMessage!),
              ],
              if (state.active && credential != null) ...[
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 184,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10021B13),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox.square(
                          dimension: 154,
                          child: _CheckpointQr(dataUri: credential.qrDataUri),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.plateNumber.isEmpty
                              ? 'TRAVLA VEHICLE'
                              : widget.plateNumber,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Scan to view current paper status',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _openPublic(credential.publicUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('View Checkpoint page'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _download(compact: false),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Printable QR'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Manage Checkpoint QR',
                      onPressed: _busy ? null : () => _showManagement(state),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: !state.eligible || _busy ? null : _enable,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_2_rounded, size: 19),
                  label: const Text('Set up Checkpoint QR'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _enable() => _run(
    () => ref.read(checkpointRepositoryProvider).enable(widget.vehicleId),
    'Checkpoint QR is now active.',
  );

  Future<void> _openPublic(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _message('The public Checkpoint page could not be opened.', error: true);
    }
  }

  Future<void> _download({required bool compact}) async {
    if (_busy) return;
    setState(() => _busy = true);
    File? file;
    try {
      file = await ref
          .read(checkpointRepositoryProvider)
          .download(widget.vehicleId, compact: compact);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Travla Checkpoint',
          text: 'Save or print this Travla Checkpoint credential.',
        ),
      );
    } on ApiFailure catch (failure) {
      _message(failure.message, error: true);
    } finally {
      if (file != null && await file.exists()) await file.delete();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showManagement(CheckpointState state) async {
    final credential = state.credential;
    if (credential == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          18 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Manage Checkpoint QR',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FALLBACK CODE',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    credential.displayCode,
                    style: const TextStyle(
                      color: AppColors.forest700,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Public status refreshed ${_formatDateTime(credential.snapshotUpdatedAt)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Download compact card'),
              onTap: () => Navigator.pop(context, 'compact'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.autorenew_rounded),
              title: const Text('Replace QR code'),
              subtitle: const Text('Existing printed copies will stop working.'),
              onTap: () => Navigator.pop(context, 'rotate'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_off_rounded, color: AppColors.danger),
              title: const Text(
                'Disable QR',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.pop(context, 'disable'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'compact') {
      await _download(compact: true);
      return;
    }
    await _confirm(action);
  }

  Future<void> _confirm(String action) async {
    final replace = action == 'rotate';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(replace ? 'Replace this QR?' : 'Disable this QR?'),
        content: Text(
          replace
              ? 'Every existing printed copy will become inactive. Download and print the replacement after continuing.'
              : 'Every printed copy will become inactive. This code cannot be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: replace
                  ? AppColors.forest700
                  : AppColors.danger,
            ),
            child: Text(replace ? 'Replace QR' : 'Disable QR'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await _run(() async {
      final repository = ref.read(checkpointRepositoryProvider);
      if (replace) {
        await repository.rotate(widget.vehicleId);
      } else {
        await repository.disable(widget.vehicleId);
      }
    }, replace ? 'A replacement QR is active.' : 'Checkpoint QR disabled.');
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(checkpointProvider(widget.vehicleId));
      _message(success);
    } on ApiFailure catch (failure) {
      _message(failure.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? AppColors.danger : AppColors.forest800,
      ),
    );
  }
}

class _CheckpointQr extends StatelessWidget {
  const _CheckpointQr({required this.dataUri});

  final String dataUri;

  @override
  Widget build(BuildContext context) {
    try {
      final svg = UriData.parse(dataUri).contentAsString();
      return SvgPicture.string(svg, fit: BoxFit.contain);
    } catch (_) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFFF3F6F4)),
        child: Center(
          child: Icon(
            Icons.qr_code_2_rounded,
            color: AppColors.forest700,
            size: 82,
          ),
        ),
      );
    }
  }
}

class _CheckpointMark extends StatelessWidget {
  const _CheckpointMark({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE9F8F1) : const Color(0xFFF1F4F2),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        Icons.qr_code_2_rounded,
        color: active ? AppColors.forest700 : AppColors.muted,
        size: 23,
      ),
    );
  }
}

class VehicleCheckpointTab extends ConsumerStatefulWidget {
  const VehicleCheckpointTab({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<VehicleCheckpointTab> createState() =>
      _VehicleCheckpointTabState();
}

class _VehicleCheckpointTabState extends ConsumerState<VehicleCheckpointTab> {
  bool _mutating = false;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(checkpointProvider(widget.vehicleId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      child: workspace.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 54),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => _Unavailable(
          message: error is ApiFailure
              ? error.message
              : 'Travla Checkpoint could not be loaded.',
          onRetry: () => ref.invalidate(checkpointProvider(widget.vehicleId)),
        ),
        data: _buildWorkspace,
      ),
    );
  }

  Widget _buildWorkspace(CheckpointState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.forest950, AppColors.forest700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRAVLA CHECKPOINT',
                style: TextStyle(
                  color: Color(0xFF73DCB0),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'One code for the vehicle’s current paper status.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'An optional roadside convenience—not a replacement for government records, original papers or lawful procedure.',
                style: TextStyle(
                  color: Color(0xBFFFFFFF),
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              if (!state.active)
                FilledButton.icon(
                  onPressed: !state.eligible || _mutating
                      ? null
                      : () => _enable(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.forest900,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: _mutating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Set up Checkpoint'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _openPublic(state.credential!.publicUrl),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x66FFFFFF)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open public Checkpoint'),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _showPreview(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD7F6E8),
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Preview exactly what the public will see'),
              ),
            ],
          ),
        ),
        if (!state.eligible && state.eligibilityMessage != null) ...[
          const SizedBox(height: 12),
          _Notice(text: state.eligibilityMessage!),
        ],
        const SizedBox(height: 16),
        if (!state.active)
          const _Benefits()
        else ...[
          _CredentialCard(
            credential: state.credential!,
            busy: _mutating,
            onA4: () => _download(compact: false),
            onCompact: () => _download(compact: true),
            onRotate: () => _confirm('rotate'),
            onDisable: () => _confirm('disable'),
          ),
          if (state.snapshot != null) ...[
            const SizedBox(height: 16),
            CheckpointSnapshotView(snapshot: state.snapshot!),
          ],
        ],
      ],
    );
  }

  Future<void> _enable() => _run(() async {
    await ref.read(checkpointRepositoryProvider).enable(widget.vehicleId);
  }, success: 'Checkpoint is active. Download a printable copy when ready.');

  Future<void> _confirm(String action) async {
    final rotate = action == 'rotate';
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          22,
          20,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              rotate ? Icons.autorenew_rounded : Icons.link_off_rounded,
              size: 30,
              color: rotate ? AppColors.orange : AppColors.danger,
            ),
            const SizedBox(height: 14),
            Text(
              rotate ? 'Rotate Checkpoint code?' : 'Disable Checkpoint?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              rotate
                  ? 'Every existing printed copy will stop working immediately. Download and print the new credential after rotation.'
                  : 'Every printed copy will become inactive. The current code cannot be restored, but you can set up a new one later.',
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.5,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: rotate
                          ? AppColors.forest700
                          : AppColors.danger,
                    ),
                    child: Text(rotate ? 'Rotate code' : 'Disable'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    await _run(
      () async {
        final repository = ref.read(checkpointRepositoryProvider);
        if (rotate) {
          await repository.rotate(widget.vehicleId);
        } else {
          await repository.disable(widget.vehicleId);
        }
      },
      success: rotate
          ? 'A new Checkpoint code is active.'
          : 'Checkpoint disabled.',
    );
  }

  Future<void> _download({required bool compact}) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    File? file;
    try {
      file = await ref
          .read(checkpointRepositoryProvider)
          .download(widget.vehicleId, compact: compact);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Travla Checkpoint',
          text:
              'Save or print this owner-controlled Travla Checkpoint credential.',
        ),
      );
    } on ApiFailure catch (failure) {
      _message(failure.message, error: true);
    } catch (_) {
      _message('The printable Checkpoint could not be shared.', error: true);
    } finally {
      if (file != null && await file.exists()) await file.delete();
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _showPreview() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .86,
        minChildSize: .55,
        maxChildSize: .96,
        builder: (context, controller) => FutureBuilder<CheckpointPreview>(
          future: ref
              .read(checkpointRepositoryProvider)
              .preview(widget.vehicleId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              final error = snapshot.error;
              return _Unavailable(
                message: error is ApiFailure
                    ? error.message
                    : 'The privacy preview could not be loaded.',
                onRetry: () => Navigator.pop(context),
              );
            }
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Public privacy preview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _Notice(text: snapshot.data!.disclaimer),
                const SizedBox(height: 14),
                CheckpointSnapshotView(snapshot: snapshot.data!.snapshot),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openPublic(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _message('The public Checkpoint page could not be opened.', error: true);
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
      ref.invalidate(checkpointProvider(widget.vehicleId));
      _message(success);
    } on ApiFailure catch (failure) {
      _message(failure.message, error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? AppColors.danger : AppColors.forest800,
      ),
    );
  }
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({
    required this.credential,
    required this.busy,
    required this.onA4,
    required this.onCompact,
    required this.onRotate,
    required this.onDisable,
  });

  final CheckpointCredential credential;
  final bool busy;
  final VoidCallback onA4;
  final VoidCallback onCompact;
  final VoidCallback onRotate;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _StatusPill(label: 'ACTIVE', color: AppColors.forest700),
                const Spacer(),
                Text(
                  'Version ${credential.version}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'PRINTED FALLBACK CODE',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              credential.displayCode,
              style: const TextStyle(
                color: AppColors.forest700,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Snapshot updated ${_formatDateTime(credential.snapshotUpdatedAt)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onA4,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('A4 PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onCompact,
                    child: const Text('Compact'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onRotate,
                    child: const Text('Rotate code'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : onDisable,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Disable'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CheckpointSnapshotView extends StatelessWidget {
  const CheckpointSnapshotView({required this.snapshot, super.key});
  final CheckpointSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final vehicle = snapshot.vehicle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.forest900,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EXACT PUBLIC VEHICLE IDENTITY',
                style: TextStyle(
                  color: Color(0xFF78DEB4),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                vehicle.plateNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${vehicle.year ?? ''} ${vehicle.make} ${vehicle.model} · ${vehicle.colour}${vehicle.category?.isNotEmpty == true ? ' · ${vehicle.category}' : ''}',
                style: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: snapshot.security.status == 'REPORTED_STOLEN'
                ? const Color(0xFFFFEEEB)
                : AppColors.forest50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: snapshot.security.status == 'REPORTED_STOLEN'
                  ? const Color(0xFFF0BBB2)
                  : AppColors.forest100,
            ),
          ),
          child: Text(
            snapshot.security.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 14),
        if (snapshot.documents.isEmpty)
          const _Notice(text: 'No vehicle-paper records will be shown yet.')
        else
          ...snapshot.documents.map(
            (document) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _StatusBlock(
                              title: 'VALIDITY',
                              status: document.validity,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatusBlock(
                              title: 'AUTHENTICITY',
                              status: document.authenticity,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.title, required this.status});
  final String title;
  final CheckpointStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status.status);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 7),
          _StatusPill(label: status.label, color: color),
          if (status.expiryDate != null) ...[
            const SizedBox(height: 6),
            Text(
              'Expires ${status.expiryDate}',
              style: const TextStyle(color: AppColors.muted, fontSize: 9),
            ),
          ] else if (status.evidenceLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              status.evidenceLabel!,
              style: const TextStyle(color: AppColors.muted, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.privacy_tip_outlined,
        'Privacy first',
        'No owner identity, NIN, contact, bank, engine or full chassis details.',
      ),
      (
        Icons.autorenew_rounded,
        'Revocable',
        'Rotate or disable it. Old printed copies become inactive immediately.',
      ),
      (
        Icons.offline_bolt_outlined,
        'Snapshot only',
        'A public scan never starts a new authority check.',
      ),
    ];
    return Column(
      children: items
          .map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                leading: CircleAvatar(
                  backgroundColor: AppColors.forest50,
                  child: Icon(item.$1, color: AppColors.forest700, size: 21),
                ),
                title: Text(
                  item.$2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.$3,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.4,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.orangeSoft,
      borderRadius: BorderRadius.circular(12),
      border: const Border(left: BorderSide(color: AppColors.orange, width: 4)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF64331E),
        height: 1.45,
        fontSize: 11,
      ),
    ),
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34),
    child: Column(
      children: [
        const Icon(Icons.qr_code_2_rounded, color: AppColors.muted, size: 38),
        const SizedBox(height: 12),
        const Text(
          'Travla Checkpoint is not available yet.',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            height: 1.45,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

Color _statusColor(String status) {
  if (const ['VALID', 'VERIFIED', 'FOUND', 'ACTIVE'].contains(status)) {
    return AppColors.forest700;
  }
  if (const [
    'EXPIRED',
    'MISMATCH',
    'NO_RECORD',
    'CANCELLED',
  ].contains(status)) {
    return AppColors.danger;
  }
  return const Color(0xFF9A5A00);
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'not yet';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

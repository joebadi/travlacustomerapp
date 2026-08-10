import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/claims/data/claim_repository.dart';
import 'package:travla_customer_app/features/claims/domain/claim_models.dart';
import 'package:travla_customer_app/features/claims/presentation/claim_widgets.dart';

class ClaimDetailScreen extends ConsumerStatefulWidget {
  const ClaimDetailScreen({super.key, required this.claimId});

  final String claimId;

  @override
  ConsumerState<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class _ClaimDetailScreenState extends ConsumerState<ClaimDetailScreen> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _refresh() {
    ref.invalidate(claimDetailProvider(widget.claimId));
    ref.invalidate(claimsListProvider);
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (done != null) _snack(done);
    } on ClaimsUnavailable {
      _snack('Claims are not available for your account.');
    } on ApiFailure catch (failure) {
      _snack(failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addEvidence() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'mp4', 'mov'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    await _run(() async {
      await ref.read(claimRepositoryProvider).uploadEvidence(
            claimId: widget.claimId,
            file: file,
            fileType: _inferType(file.name),
          );
      _refresh();
    }, done: 'Evidence added.');
  }

  Future<void> _removeEvidence(ClaimEvidence e) async {
    final ok = await _confirm('Remove this file?', 'Remove');
    if (!ok) return;
    await _run(() async {
      await ref.read(claimRepositoryProvider).removeEvidence(e.id);
      _refresh();
    }, done: 'Removed.');
  }

  Future<void> _submit(InsuranceClaim claim) async {
    final fee = claim.policeReportFeeNaira ?? '';
    final ok = await _confirm(
      'Submit this claim?',
      'Pay ₦$fee & submit',
      body:
          'The police-report fee of ₦$fee is charged from your wallet, and your '
          'claim is sent to the insurer for review.',
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(claimRepositoryProvider).submit(widget.claimId);
      _refresh();
    }, done: 'Claim submitted.');
  }

  Future<void> _deleteDraft() async {
    final ok = await _confirm(
      'Delete this draft?',
      'Delete',
      body: 'This permanently removes the claim draft.',
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(claimRepositoryProvider).destroy(widget.claimId);
      ref.invalidate(claimsListProvider);
      if (mounted) context.pop();
    });
  }

  Future<void> _postMessage() async {
    final controller = TextEditingController();
    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reply to the insurer',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Type your message…'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(controller.text.trim()),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    if (body == null || body.isEmpty) return;
    await _run(() async {
      await ref
          .read(claimRepositoryProvider)
          .postMessage(claimId: widget.claimId, body: body);
      ref.invalidate(claimThreadProvider(widget.claimId));
    }, done: 'Message sent.');
  }

  Future<void> _openDispute() async {
    final reasonCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open a dispute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Details'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (reasonCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
      _snack('Add a reason and details for the dispute.');
      return;
    }
    await _run(() async {
      await ref.read(claimRepositoryProvider).openDispute(
            claimId: widget.claimId,
            reason: reasonCtrl.text,
            description: descCtrl.text,
          );
      _refresh();
    }, done: 'Dispute opened.');
  }

  Future<void> _escalate(ClaimDispute dispute) async {
    final ok = await _confirm(
      'Escalate to NAICOM?',
      'Escalate',
      body:
          'Escalate this dispute to the insurance regulator (NAICOM) for '
          'independent review.',
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(claimRepositoryProvider).escalateDispute(dispute.id);
      _refresh();
    }, done: 'Escalated to NAICOM.');
  }

  Future<bool> _confirm(String title, String confirm, {String? body}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(claimDetailProvider(widget.claimId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Claim'),
        actions: [
          async.maybeWhen(
            data: (claim) => claim.canEdit
                ? IconButton(
                    tooltip: 'Delete draft',
                    onPressed: _busy ? null : _deleteDraft,
                    icon: const Icon(Icons.delete_outline_rounded),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => error is ClaimsUnavailable
            ? const ClaimsComingSoon()
            : ClaimErrorState(
                message: error is ApiFailure
                    ? error.message
                    : 'This claim could not be loaded.',
                onRetry: () =>
                    ref.invalidate(claimDetailProvider(widget.claimId)),
              ),
        data: (claim) => Stack(
          children: [
            RefreshIndicator(
              color: AppColors.forest700,
              onRefresh: () async {
                _refresh();
                await ref.read(claimDetailProvider(widget.claimId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  _headerCard(claim),
                  if (claim.status != 'DRAFT' &&
                      claim.status != 'PENDING_PAYMENT') ...[
                    const SizedBox(height: 14),
                    _Section(
                      title: 'Progress',
                      child: ClaimTimeline(status: claim.status),
                    ),
                  ],
                  if (claim.isDecided) ...[
                    const SizedBox(height: 14),
                    _decisionCard(claim),
                  ],
                  const SizedBox(height: 14),
                  _incidentCard(claim),
                  if (claim.policies.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _policiesCard(claim),
                  ],
                  const SizedBox(height: 14),
                  _evidenceCard(claim),
                  const SizedBox(height: 14),
                  _messagesCard(),
                  if (claim.isDecided || claim.disputes.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _disputesCard(claim),
                  ],
                  if (claim.canEdit) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _submit(claim),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.orange,
                      ),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        'Pay ₦${claim.policeReportFeeNaira ?? ''} & submit',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
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

  Widget _headerCard(InsuranceClaim claim) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest950, AppColors.forest700],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  claim.claimTypeLabel ?? 'Claim',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ClaimStatusPill(status: claim.status, label: claim.statusLabel),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (claim.claimNumber != null) claim.claimNumber!,
              if (claim.vehicleName != null) claim.vehicleName!,
              if (claim.vehiclePlate != null) claim.vehiclePlate!,
            ].join('  ·  '),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .82),
              fontSize: 12.5,
            ),
          ),
          if (claim.needsPayment) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Pay the ₦${claim.policeReportFeeNaira ?? ''} police-report fee to send this claim to the insurer.',
                style: const TextStyle(color: Colors.white, fontSize: 11.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _decisionCard(InsuranceClaim claim) {
    return _Section(
      title: 'Decision',
      child: Column(
        children: [
          if (claim.approvedAmountNaira != null)
            _Line(label: 'Approved', value: '₦${claim.approvedAmountNaira}'),
          if (claim.excessNaira != null)
            _Line(label: 'Excess', value: '₦${claim.excessNaira}'),
          if (claim.settlementAmountNaira != null)
            _Line(label: 'Settlement', value: '₦${claim.settlementAmountNaira}'),
          if (claim.decisionNote != null) ...[
            const SizedBox(height: 8),
            _Note(claim.decisionNote!),
          ],
          if (claim.assessorNote != null) ...[
            const SizedBox(height: 8),
            _Note(claim.assessorNote!),
          ],
        ],
      ),
    );
  }

  Widget _incidentCard(InsuranceClaim claim) {
    return _Section(
      title: 'Incident',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (claim.incidentDate != null)
            _Line(label: 'Date', value: _fmtDate(claim.incidentDate)),
          if (claim.location != null)
            _Line(label: 'Location', value: claim.location!),
          if (claim.severity != null)
            _Line(label: 'Severity', value: _titleCase(claim.severity!)),
          if (claim.thirdPartyInvolved == true)
            _Line(
              label: 'Third party',
              value: claim.otherVehiclePlate ?? 'Involved',
            ),
          if (claim.estimatedCostNaira != null)
            _Line(label: 'Estimated cost', value: '₦${claim.estimatedCostNaira}'),
          if (claim.description != null) ...[
            const SizedBox(height: 10),
            Text(
              claim.description!,
              style: const TextStyle(color: AppColors.ink, height: 1.5),
            ),
          ],
          if (claim.lateNotice) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Filed after the 30-day notice window — the insurer may ask for a reason.',
                style: TextStyle(color: AppColors.orangeDark, fontSize: 11.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _policiesCard(InsuranceClaim claim) {
    return _Section(
      title: 'Filed against',
      child: Column(
        children: claim.policies
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppColors.forest700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${p.provider ?? 'Policy'}${p.policyNumber != null ? ' · ${p.policyNumber}' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (p.coverageLabel != null)
                      Text(
                        p.coverageLabel!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _evidenceCard(InsuranceClaim claim) {
    return _Section(
      title: 'Evidence & documents',
      trailing: claim.canEdit
          ? TextButton.icon(
              onPressed: _busy ? null : _addEvidence,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Add'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (claim.documentChecklist.isNotEmpty) ...[
            ...claim.documentChecklist.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      d.provided
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 17,
                      color: d.provided ? AppColors.forest700 : AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.label,
                        style: TextStyle(
                          color: d.provided ? AppColors.ink : AppColors.muted,
                          fontSize: 12.5,
                          fontWeight: d.provided
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 22),
          ],
          if (claim.evidence.isEmpty)
            const Text(
              'No files uploaded yet.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            )
          else
            ...claim.evidence.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(_evidenceIcon(e.fileType), size: 20, color: AppColors.forest700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.originalFilename ?? e.fileType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (e.description != null)
                            Text(
                              e.description!,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (claim.canEdit)
                      IconButton(
                        onPressed: _busy ? null : () => _removeEvidence(e),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _messagesCard() {
    final thread = ref.watch(claimThreadProvider(widget.claimId));
    return _Section(
      title: 'Correspondence',
      trailing: TextButton.icon(
        onPressed: _busy ? null : _postMessage,
        icon: const Icon(Icons.reply_rounded, size: 18),
        label: const Text('Reply'),
      ),
      child: thread.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: LinearProgressIndicator(),
        ),
        error: (_, _) => const Text(
          'Messages could not be loaded.',
          style: TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
        data: (thread) => thread.messages.isEmpty
            ? const Text(
                'No messages yet. Replies from the insurer appear here.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              )
            : Column(
                children: thread.messages
                    .map((m) => _MessageBubble(message: m))
                    .toList(),
              ),
      ),
    );
  }

  Widget _disputesCard(InsuranceClaim claim) {
    return _Section(
      title: 'Disputes',
      trailing: (claim.isDecided && claim.status != 'SETTLED')
          ? TextButton.icon(
              onPressed: _busy ? null : _openDispute,
              icon: const Icon(Icons.gavel_rounded, size: 18),
              label: const Text('Open'),
            )
          : null,
      child: claim.disputes.isEmpty
          ? const Text(
              'No disputes. If you disagree with the decision, you can open one.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            )
          : Column(
              children: claim.disputes.map((d) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.reason ?? 'Dispute',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (d.status != null)
                            Text(
                              d.status!,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      if (d.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          d.description!,
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ],
                      if (d.response != null) ...[
                        const SizedBox(height: 6),
                        _Note(d.response!),
                      ],
                      if (d.naicomEscalated)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Escalated to NAICOM${d.naicomReference != null ? ' · ${d.naicomReference}' : ''}',
                            style: const TextStyle(
                              color: AppColors.forest700,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : () => _escalate(d),
                            child: const Text('Escalate to NAICOM'),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  String _inferType(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (['jpg', 'jpeg', 'png'].contains(ext)) return 'PHOTO';
    if (['mp4', 'mov'].contains(ext)) return 'VIDEO';
    return 'DOCUMENT';
  }

  IconData _evidenceIcon(String type) => switch (type) {
    'PHOTO' => Icons.image_outlined,
    'VIDEO' => Icons.videocam_outlined,
    _ => Icons.description_outlined,
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.ink),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ClaimMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromMotorist;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .74,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.forest700 : AppColors.canvas,
          borderRadius: BorderRadius.circular(14),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && message.author != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  message.author!,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Text(
              message.body ?? '',
              style: TextStyle(
                color: mine ? Colors.white : AppColors.ink,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _titleCase(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

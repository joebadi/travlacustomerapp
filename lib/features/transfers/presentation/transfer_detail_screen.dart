import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/marketplace/data/marketplace_repository.dart';
import 'package:travla_customer_app/features/transfers/data/transfer_repository.dart';
import 'package:travla_customer_app/features/transfers/domain/transfer_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class TransferDetailScreen extends ConsumerStatefulWidget {
  const TransferDetailScreen({required this.transferId, super.key});
  final String transferId;

  @override
  ConsumerState<TransferDetailScreen> createState() =>
      _TransferDetailScreenState();
}

class _TransferDetailScreenState extends ConsumerState<TransferDetailScreen> {
  final _otp = TextEditingController();
  bool _mutating = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transfer = ref.watch(transferDetailProvider(widget.transferId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer record'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: transfer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _DetailError(
          message: error is ApiFailure
              ? error.message
              : 'This transfer could not be loaded.',
          onRetry: _refresh,
        ),
        data: _content,
      ),
    );
  }

  Widget _content(TransferRecord transfer) {
    final progress = _progressFor(transfer);
    return RefreshIndicator(
      color: AppColors.forest700,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          _RecordHero(transfer: transfer, progress: progress),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _MessagePanel(message: _error!, error: true),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _MessagePanel(message: _notice!),
          ],
          const SizedBox(height: 14),
          if (transfer.awaitsMyConsent) ...[
            _ConsentCard(
              controller: _otp,
              submitting: _mutating,
              onSubmit: _verifyConsent,
              onResend: _resendConsent,
            ),
            const SizedBox(height: 12),
          ],
          _ReviewNotice(transfer: transfer),
          const SizedBox(height: 12),
          _ProgressCard(progress: progress),
          const SizedBox(height: 12),
          _TransferFacts(transfer: transfer),
          if (transfer.documents.isNotEmpty) ...[
            const SizedBox(height: 12),
            _EvidencePack(documents: transfer.documents, onOpen: _openDocument),
          ],
          if (transfer.history.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AuditTrail(events: transfer.history),
          ],
          if (transfer.canCancel) ...[
            const SizedBox(height: 14),
            _CancelPanel(
              reopensMarketplace: transfer.cancellationReopensMarketplace,
              hasFee: transfer.amountKobo > 0,
              loading: _mutating,
              onCancel: () => _cancel(transfer),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(transferDetailProvider(widget.transferId));
    await ref.read(transferDetailProvider(widget.transferId).future);
  }

  Future<void> _verifyConsent() async {
    final code = _otp.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _error = 'Enter the complete six-digit consent code.');
      return;
    }
    await _runAction(
      () => ref
          .read(transferRepositoryProvider)
          .verifyConsent(widget.transferId, code),
      success: 'Ownership confirmed. The vehicle record is being refreshed.',
      refreshGarage: true,
    );
    _otp.clear();
  }

  Future<void> _resendConsent() => _runAction(
    () => ref.read(transferRepositoryProvider).resendConsent(widget.transferId),
    success: 'A fresh consent code has been queued for delivery.',
  );

  Future<void> _cancel(TransferRecord transfer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this transfer?'),
        content: Text(
          [
            transfer.amountKobo > 0
                ? 'The transfer fee will be refunded to your Travla wallet.'
                : 'No payment was taken, so no refund is required.',
            if (transfer.cancellationReopensMarketplace)
              'The linked marketplace sale will be cancelled and its listing restored.',
          ].join(' '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep transfer'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAction(
      () => ref.read(transferRepositoryProvider).cancel(widget.transferId),
      success: transfer.cancellationReopensMarketplace
          ? 'Transfer cancelled and marketplace listing restored.'
          : 'Transfer cancelled successfully.',
      refreshGarage: true,
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
    bool refreshGarage = false,
  }) async {
    setState(() {
      _mutating = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      ref.invalidate(transferDetailProvider(widget.transferId));
      ref.invalidate(transferListProvider);
      if (refreshGarage) ref.invalidate(garageProvider);
      ref.invalidate(myMarketplaceListingsProvider);
      if (!mounted) return;
      setState(() => _notice = success);
      await ref.read(transferDetailProvider(widget.transferId).future);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _openDocument(TransferEvidenceDocument document) async {
    final uri = Uri.tryParse(document.url);
    if (uri == null || !uri.hasScheme) {
      setState(() => _error = 'This evidence file does not have a valid link.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'The evidence file could not be opened.');
    }
  }
}

class _RecordHero extends StatelessWidget {
  const _RecordHero({required this.transfer, required this.progress});
  final TransferRecord transfer;
  final List<_ProgressStep> progress;

  @override
  Widget build(BuildContext context) {
    final completed = progress.where((step) => step.done).length;
    final percent = progress.isEmpty
        ? 0
        : (completed * 100 / progress.length).round();
    final name = transfer.vehicle?.displayName.isNotEmpty == true
        ? transfer.vehicle!.displayName
        : 'Ownership transfer';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forest950, AppColors.forest800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _HeroTag(transfer.amISender ? 'SENT BY YOU' : 'RECEIVED BY YOU'),
              _HeroTag(transfer.statusLabel.toUpperCase(), orange: true),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            name,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              transfer.vehicle?.plateNumber ?? '',
              transfer.trackingNumber,
            ].where((value) => value.isNotEmpty).join(' · '),
            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 10),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  transfer.reviewStatusLabel,
                  style: const TextStyle(
                    color: Color(0xBBFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 7,
              color: AppColors.orange,
              backgroundColor: const Color(0x22FFFFFF),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroFact(
                  label: transfer.transferMode == 'MANAGED'
                      ? 'TRANSFER SERVICE'
                      : 'VERIFICATION FEE',
                  value: transfer.amountKobo == 0
                      ? 'No fee'
                      : '₦${transfer.amountNaira}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroFact(
                  label: 'OWNERSHIP PATH',
                  value:
                      '${transfer.currentOwner?.name ?? 'Owner'} → ${transfer.recipient.name}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag(this.label, {this.orange = false});
  final String label;
  final bool orange;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: orange ? AppColors.orange : const Color(0x18FFFFFF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 7,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0x12FFFFFF),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0x77FFFFFF),
            fontSize: 7,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
    required this.onResend,
  });
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.orangeSoft,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFC9B7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MANAGER APPROVED',
          style: TextStyle(
            color: AppColors.orangeDark,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Confirm and receive this vehicle',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        const Text(
          'Enter your private code only if you recognise this transfer. Confirmation moves the vehicle and its verified papers to your account.',
          style: TextStyle(color: AppColors.muted, fontSize: 10, height: 1.45),
        ),
        const SizedBox(height: 13),
        TextField(
          controller: controller,
          enabled: !submitting,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 7,
          ),
          decoration: const InputDecoration(
            labelText: 'Six-digit consent code',
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: Text(submitting ? 'Confirming…' : 'Confirm & receive'),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: submitting ? null : onResend,
            child: const Text('Send me a fresh code'),
          ),
        ),
      ],
    ),
  );
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({required this.transfer});
  final TransferRecord transfer;

  @override
  Widget build(BuildContext context) {
    final (
      icon,
      title,
      body,
      color,
      background,
    ) = switch (transfer.reviewStatus) {
      'AWAITING_AGENT' => (
        Icons.assignment_ind_outlined,
        'Agent preparation',
        'Travla is assigning an agent to prepare the official documents. The recipient has not been contacted.',
        AppColors.forest700,
        AppColors.forest50,
      ),
      'AWAITING_ADMIN_REVIEW' => (
        Icons.fact_check_outlined,
        'Manager verification',
        'A Travla manager is checking the official evidence. The recipient has not been contacted yet.',
        AppColors.forest700,
        AppColors.forest50,
      ),
      'NEEDS_CORRECTION' => (
        Icons.warning_amber_rounded,
        'Correction required',
        transfer.reviewNotes?.isNotEmpty == true
            ? transfer.reviewNotes!
            : 'A manager requested corrections to this transfer evidence.',
        AppColors.orangeDark,
        AppColors.orangeSoft,
      ),
      'AWAITING_RECIPIENT' => (
        Icons.mark_email_read_outlined,
        'Waiting for recipient',
        transfer.amISender
            ? '${transfer.recipient.name} can now confirm with their private consent code.'
            : 'Manager verification passed. Your private confirmation is required.',
        AppColors.orangeDark,
        AppColors.orangeSoft,
      ),
      _ => (
        transfer.status == 'COMPLETED'
            ? Icons.verified_rounded
            : Icons.info_outline_rounded,
        transfer.statusLabel,
        transfer.status == 'COMPLETED'
            ? 'Ownership has been transferred and the vehicle papers are available to the new owner.'
            : transfer.reviewStatusLabel,
        transfer.status == 'REJECTED' || transfer.status == 'CANCELLED'
            ? AppColors.danger
            : AppColors.forest700,
        transfer.status == 'REJECTED' || transfer.status == 'CANCELLED'
            ? const Color(0xFFFFE9E7)
            : AppColors.forest50,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(color: color, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final List<_ProgressStep> progress;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIVE PROGRESS',
            style: TextStyle(
              color: AppColors.orangeDark,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          ...progress.indexed.map((entry) {
            final index = entry.$1;
            final step = entry.$2;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: step.done
                            ? AppColors.forest700
                            : AppColors.white,
                        border: Border.all(
                          color: step.done
                              ? AppColors.forest700
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        step.done ? '✓' : '${index + 1}',
                        style: TextStyle(
                          color: step.done ? AppColors.white : AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (index < progress.length - 1)
                      Container(
                        width: 1,
                        height: 28,
                        color: step.done
                            ? AppColors.forest100
                            : AppColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      step.label,
                      style: TextStyle(
                        color: step.done ? AppColors.ink : AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    ),
  );
}

class _TransferFacts extends StatelessWidget {
  const _TransferFacts({required this.transfer});
  final TransferRecord transfer;
  @override
  Widget build(BuildContext context) {
    final facts = <(String, String)>[
      ('Reason', transfer.transferBasisLabel),
      ('Transfer path', transfer.transferModeLabel),
      ('From', transfer.currentOwner?.name ?? 'Current owner'),
      ('To', transfer.recipient.name),
      (
        'Jurisdiction',
        '${transfer.collectionCity}, ${transfer.jurisdictionState}',
      ),
      (
        'Payment',
        transfer.amountKobo == 0
            ? 'No fee charged'
            : '₦${transfer.amountNaira} · ${transfer.paymentStatus}',
      ),
      if (transfer.transferMode == 'MANAGED')
        ('Document handover', transfer.deliveryMethodLabel),
      ('Created', _dateTime(transfer.createdAt)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ownership record',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            ...facts.map(
              (fact) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        fact.$1.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        fact.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidencePack extends StatelessWidget {
  const _EvidencePack({required this.documents, required this.onOpen});
  final List<TransferEvidenceDocument> documents;
  final ValueChanged<TransferEvidenceDocument> onOpen;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Submitted documents',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Official evidence and the papers published to the vehicle vault.',
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 12),
          ...documents.map(
            (document) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppColors.forest700,
                ),
                title: Text(
                  document.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  [
                    if (document.documentNumber?.isNotEmpty == true)
                      'No. ${document.documentNumber}',
                    if (document.expiryDate?.isNotEmpty == true)
                      'Expires ${document.expiryDate}',
                    document.published
                        ? 'In vehicle vault'
                        : document.verificationStatus,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 9),
                ),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: document.url.isEmpty ? null : () => onOpen(document),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AuditTrail extends StatelessWidget {
  const _AuditTrail({required this.events});
  final List<TransferHistoryEvent> events;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transfer activity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.description.isEmpty
                              ? event.label
                              : event.description,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _dateTime(event.createdAt),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CancelPanel extends StatelessWidget {
  const _CancelPanel({
    required this.reopensMarketplace,
    required this.hasFee,
    required this.loading,
    required this.onCancel,
  });
  final bool reopensMarketplace;
  final bool hasFee;
  final bool loading;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7F6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF0C6C2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          reopensMarketplace
              ? 'Cancellation refunds the fee and restores the marketplace listing.'
              : hasFee
              ? 'Cancellation refunds the transfer fee to your wallet.'
              : 'This request has not entered processing and can still be cancelled.',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: loading ? null : onCancel,
          icon: const Icon(Icons.cancel_outlined),
          label: Text(hasFee ? 'Cancel & refund' : 'Cancel transfer'),
        ),
      ],
    ),
  );
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFE9E7) : AppColors.forest50,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: error ? AppColors.danger : AppColors.forest700,
        fontSize: 10,
      ),
    ),
  );
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _ProgressStep {
  const _ProgressStep(this.label, this.done);
  final String label;
  final bool done;
}

List<_ProgressStep> _progressFor(TransferRecord transfer) {
  final evidenceSubmitted = {
    'AWAITING_ADMIN_REVIEW',
    'AWAITING_RECIPIENT',
    'NEEDS_CORRECTION',
    'APPROVED',
  }.contains(transfer.reviewStatus);
  final verified =
      transfer.legalTransferVerifiedAt != null ||
      {'AWAITING_RECIPIENT', 'APPROVED'}.contains(transfer.reviewStatus);
  final steps = <_ProgressStep>[
    const _ProgressStep('Transfer request created', true),
    _ProgressStep(
      transfer.transferMode == 'MANAGED'
          ? 'Official documents prepared'
          : 'Official evidence submitted',
      evidenceSubmitted,
    ),
    _ProgressStep('Manager verified', verified),
    _ProgressStep(
      'Recipient confirmed and ownership linked',
      transfer.status == 'COMPLETED',
    ),
  ];
  if (transfer.transferMode == 'MANAGED' && transfer.status == 'COMPLETED') {
    final deliveryStatus = transfer.delivery?.status ?? '';
    if (transfer.deliveryMethod == 'DELIVERY') {
      steps.addAll([
        _ProgressStep(
          'Rider collected from agent',
          {'PICKED_UP', 'IN_TRANSIT', 'DELIVERED'}.contains(deliveryStatus),
        ),
        _ProgressStep(
          'Out for delivery',
          {'IN_TRANSIT', 'DELIVERED'}.contains(deliveryStatus),
        ),
        _ProgressStep('Papers delivered', deliveryStatus == 'DELIVERED'),
      ]);
    } else {
      steps.add(
        _ProgressStep('Papers collected', deliveryStatus == 'DELIVERED'),
      );
    }
  }
  return steps;
}

String _dateTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day}/${local.month}/${local.year} · $hour:$minute $period';
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/renewals/data/renewal_repository.dart';
import 'package:travla_customer_app/features/renewals/domain/renewal_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/wallet/data/wallet_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class RenewalOrderScreen extends ConsumerStatefulWidget {
  const RenewalOrderScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<RenewalOrderScreen> createState() => _RenewalOrderScreenState();
}

class _RenewalOrderScreenState extends ConsumerState<RenewalOrderScreen> {
  Timer? _poller;
  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poller = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(renewalOrderProvider(widget.groupId));
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(renewalOrderProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Renewal order'),
        actions: [
          IconButton(
            tooltip: 'Refresh progress',
            onPressed: () =>
                ref.invalidate(renewalOrderProvider(widget.groupId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _OrderLoadError(
          message: error is ApiFailure
              ? error.message
              : 'This renewal order could not be loaded.',
          onRetry: () => ref.invalidate(renewalOrderProvider(widget.groupId)),
        ),
        data: (items) => items.isEmpty
            ? _OrderLoadError(
                message: 'This renewal order could not be found.',
                onRetry: () => context.go('/more/renewals'),
              )
            : _content(
                RenewalOrderSummary(
                  groupId: widget.groupId,
                  reference: items.first.orderReference,
                  items: items,
                ),
              ),
      ),
    );
  }

  Widget _content(RenewalOrderSummary order) {
    final first = order.first;
    final progress = _OrderProgress.from(order);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(renewalOrderProvider(widget.groupId));
        await ref.read(renewalOrderProvider(widget.groupId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 36),
        children: [
          _OrderHero(order: order),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _OrderError(message: _error!),
          ],
          if (first.actionRequest case final request?) ...[
            const SizedBox(height: 12),
            _ActionRequired(request: request),
          ],
          if (progress.showOtp) ...[
            const SizedBox(height: 12),
            _HandoverCode(
              code: progress.handoverOtp!,
              delivery: progress.isDelivery,
            ),
          ],
          const SizedBox(height: 12),
          _LiveProgress(progress: progress),
          if (progress.delivery?.rider case final rider?) ...[
            const SizedBox(height: 12),
            _RiderPanel(
              rider: rider,
              delivery: progress.delivery!,
              onCall: rider.phone.isEmpty ? null : () => _call(rider.phone),
              onMap:
                  progress.delivery!.status == 'IN_TRANSIT' &&
                      progress.delivery!.riderLatitude != null &&
                      progress.delivery!.riderLongitude != null
                  ? () => _openMap(progress.delivery!)
                  : null,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order contents',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${order.completedCount} of ${order.items.length} ready',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...order.items.indexed.map(
            (entry) => _DocumentOrderCard(
              index: entry.$1 + 1,
              record: entry.$2,
              onOpenCurrent: entry.$2.currentDocument?.documentUrl == null
                  ? null
                  : () => _openFile(entry.$2.currentDocument!.documentUrl!),
              onOpenPrevious: entry.$2.previousDocument?.documentUrl == null
                  ? null
                  : () => _openFile(entry.$2.previousDocument!.documentUrl!),
              onOpenRenewed: entry.$2.renewedDocument?.documentUrl == null
                  ? null
                  : () => _openFile(entry.$2.renewedDocument!.documentUrl!),
            ),
          ),
          if (first.deliveryAddress?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            _DeliveryAddress(address: first.deliveryAddress!),
          ],
          if (order.canCancel) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F4),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Changed your mind?',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'A pending order is cancelled as one purchase, and the complete payment is returned to your wallet.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: _cancelling ? null : () => _confirmCancel(order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    icon: _cancelling
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(
                      _cancelling ? 'Cancelling order…' : 'Cancel and refund',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(RenewalOrderSummary order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'All ${order.items.length} selected paper${order.items.length == 1 ? '' : 's'} will be cancelled together. Travla will refund the complete payment to your wallet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cancel and refund'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _cancelling = true;
      _error = null;
    });
    try {
      await ref.read(renewalRepositoryProvider).cancelOrder(widget.groupId);
      ref.invalidate(renewalOrderProvider(widget.groupId));
      ref.invalidate(renewalOrdersProvider);
      ref.invalidate(walletWorkspaceProvider);
      ref.invalidate(garageProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Renewal order cancelled and refund requested.'),
          ),
        );
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _openFile(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That document could not be opened.')),
      );
    }
  }

  Future<void> _call(String phone) async {
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _openMap(RenewalDelivery delivery) async {
    final latitude = delivery.riderLatitude;
    final longitude = delivery.riderLongitude;
    if (latitude == null || longitude == null) return;
    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _OrderProgress {
  const _OrderProgress({
    required this.steps,
    required this.title,
    required this.message,
    required this.isDelivery,
    required this.delivery,
    required this.handoverOtp,
    required this.showOtp,
  });

  final List<_ProgressStep> steps;
  final String title;
  final String message;
  final bool isDelivery;
  final RenewalDelivery? delivery;
  final String? handoverOtp;
  final bool showOtp;

  factory _OrderProgress.from(RenewalOrderSummary order) {
    final first = order.first;
    final isDelivery = first.deliveryMethod == 'DELIVERY';
    final processing = order.items.any(
      (item) => {'PROCESSING', 'COMPLETED'}.contains(item.status),
    );
    final completed = order.items.every((item) => item.status == 'COMPLETED');
    final deliveries = order.items
        .map((item) => item.delivery)
        .whereType<RenewalDelivery>()
        .toList(growable: false);
    final delivery = deliveries.isEmpty ? null : deliveries.first;
    final stage = completed && deliveries.isNotEmpty
        ? deliveries.map((item) => item.stage).reduce((a, b) => a < b ? a : b)
        : 0;
    final delivered = completed && stage >= 4;
    final otp = deliveries
        .map((item) => item.handoverOtp)
        .whereType<String>()
        .where((code) => code.isNotEmpty)
        .firstOrNull;

    final steps = <_ProgressStep>[
      _ProgressStep(
        label: 'Order placed and paid',
        done: true,
        date: first.requestDate,
      ),
      _ProgressStep(label: 'Agent processing', done: processing),
      _ProgressStep(
        label: 'Renewed and ready',
        done: completed,
        date: completed ? first.completionDate : null,
      ),
      if (isDelivery) ...[
        _ProgressStep(
          label: 'Rider collected from agent',
          done: completed && stage >= 2,
        ),
        _ProgressStep(label: 'Out for delivery', done: completed && stage >= 3),
        _ProgressStep(
          label: 'Delivered to you',
          done: delivered,
          date: delivered ? delivery?.deliveryDate : null,
        ),
      ] else
        _ProgressStep(
          label: 'Collected by you',
          done: delivered,
          date: delivered ? delivery?.deliveryDate : null,
        ),
    ];

    final title = !processing
        ? 'Awaiting an agent'
        : !completed
        ? 'Being processed'
        : delivered
        ? (isDelivery ? 'Delivered' : 'Collected')
        : isDelivery
        ? stage >= 3
              ? 'Out for delivery'
              : stage >= 2
              ? 'Collected by rider'
              : 'Ready for rider collection'
        : 'Ready to collect';
    final message = !processing
        ? 'Your payment is confirmed and the complete order is waiting for a verified agent.'
        : !completed
        ? 'Your agent is validating and renewing the selected papers.'
        : delivered
        ? 'The complete order has been handed over successfully.'
        : isDelivery
        ? stage >= 3
              ? 'Live rider tracking is active. Keep the handover code private until the sealed order is in your hands.'
              : stage >= 2
              ? 'The rider has collected your sealed order and will start delivery when ready.'
              : 'Your renewed papers are sealed and waiting for rider collection.'
        : 'Present the pickup code when collecting the complete order.';

    return _OrderProgress(
      steps: steps,
      title: title,
      message: message,
      isDelivery: isDelivery,
      delivery: delivery,
      handoverOtp: otp,
      showOtp: completed && !delivered && otp != null,
    );
  }
}

class _ProgressStep {
  const _ProgressStep({required this.label, required this.done, this.date});

  final String label;
  final bool done;
  final DateTime? date;
}

class _OrderHero extends StatelessWidget {
  const _OrderHero({required this.order});

  final RenewalOrderSummary order;

  @override
  Widget build(BuildContext context) {
    final first = order.first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forest950, AppColors.forest700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
                  order.reference.isEmpty ? 'RENEWAL ORDER' : order.reference,
                  style: const TextStyle(
                    color: Color(0xFFBBD8CD),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
              _OrderStatusPill(status: first.status, label: first.statusLabel),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            '${order.items.length} paper${order.items.length == 1 ? '' : 's'}, one tracked order',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${first.vehicle?.displayName ?? 'Vehicle'} · ${first.vehicle?.plateNumber ?? ''}',
            style: const TextStyle(color: Color(0xFFBBD8CD), fontSize: 11),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _OrderMetric(
                  label: 'TOTAL PAID',
                  value: '₦${_moneyFromKobo(order.totalKobo)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OrderMetric(
                  label: 'FULFILMENT',
                  value: first.deliveryMethodLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _OrderMetric(
            label: 'SERVICE AREA',
            value: '${first.city}, ${first.state}',
          ),
        ],
      ),
    );
  }
}

class _OrderMetric extends StatelessWidget {
  const _OrderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF91B5A8),
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusPill extends StatelessWidget {
  const _OrderStatusPill({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = status == 'COMPLETED'
        ? const Color(0xFF78E0B4)
        : status == 'CANCELLED'
        ? const Color(0xFFFF9E91)
        : const Color(0xFFFFB59E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActionRequired extends StatelessWidget {
  const _ActionRequired({required this.request});

  final RenewalActionRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5D8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF4D27A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF9A6700)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.reasonLabel,
                  style: const TextStyle(
                    color: Color(0xFF6E4B00),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.message,
                  style: const TextStyle(
                    color: Color(0xFF765900),
                    fontSize: 11,
                    height: 1.4,
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

class _HandoverCode extends StatelessWidget {
  const _HandoverCode({required this.code, required this.delivery});

  final String code;
  final bool delivery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.forest950,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppColors.orange),
              SizedBox(width: 8),
              Text(
                'SECURE HANDOVER',
                style: TextStyle(
                  color: Color(0xFFBBD8CD),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            delivery
                ? 'Only show this code when the rider is present and the sealed order is in your hands.'
                : 'Present this code to the agent when collecting the complete order.',
            style: const TextStyle(
              color: Color(0xFFBBD8CD),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveProgress extends StatelessWidget {
  const _LiveProgress({required this.progress});

  final _OrderProgress progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE PROGRESS',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(progress.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              progress.message,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            ...progress.steps.indexed.map((entry) {
              final index = entry.$1;
              final step = entry.$2;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 27,
                        height: 27,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: step.done ? AppColors.forest700 : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: step.done
                                ? AppColors.forest700
                                : AppColors.border,
                          ),
                        ),
                        child: step.done
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              )
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 9,
                                ),
                              ),
                      ),
                      if (index < progress.steps.length - 1)
                        Container(
                          width: 1,
                          height: 29,
                          color: step.done
                              ? AppColors.forest100
                              : AppColors.border,
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.label,
                            style: TextStyle(
                              color: step.done
                                  ? AppColors.ink
                                  : AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (step.date != null)
                            Text(
                              _longDate(step.date),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 9,
                              ),
                            ),
                        ],
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
}

class _RiderPanel extends StatelessWidget {
  const _RiderPanel({
    required this.rider,
    required this.delivery,
    required this.onCall,
    required this.onMap,
  });

  final RenewalRider rider;
  final RenewalDelivery delivery;
  final VoidCallback? onCall;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.forest700,
                  foregroundColor: Colors.white,
                  child: Text(
                    rider.name.isEmpty ? 'R' : rider.name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ASSIGNED RIDER',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        rider.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        delivery.statusLabel,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCall != null)
                  IconButton(
                    tooltip: 'Call rider',
                    onPressed: onCall,
                    icon: const Icon(Icons.call_outlined),
                  ),
              ],
            ),
            if (onMap != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open live rider location'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentOrderCard extends StatelessWidget {
  const _DocumentOrderCard({
    required this.index,
    required this.record,
    required this.onOpenCurrent,
    required this.onOpenPrevious,
    required this.onOpenRenewed,
  });

  final int index;
  final RenewalRecord record;
  final VoidCallback? onOpenCurrent;
  final VoidCallback? onOpenPrevious;
  final VoidCallback? onOpenRenewed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.forest950,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.documentName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        record.trackingNumber,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₦${_moneyFromKobo(record.amountKobo)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    _OrderStatusPill(
                      status: record.status,
                      label: record.statusLabel,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (record.renewedDocument != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _DocumentFacet(
                      title: 'Previous paper',
                      document:
                          record.previousDocument ?? record.currentDocument,
                      onOpen: onOpenPrevious ?? onOpenCurrent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DocumentFacet(
                      title: 'Renewed paper',
                      document: record.renewedDocument,
                      onOpen: onOpenRenewed,
                      renewed: true,
                    ),
                  ),
                ],
              ),
            ] else
              _DocumentFacet(
                title: 'Current paper on file',
                document: record.currentDocument,
                onOpen: onOpenCurrent,
              ),
            if (record.deliveryFeeKobo > 0) ...[
              const Divider(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Shared door-to-door delivery',
                      style: TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  ),
                  Text(
                    '₦${_moneyFromKobo(record.deliveryFeeKobo)}',
                    style: const TextStyle(
                      color: AppColors.orangeDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentFacet extends StatelessWidget {
  const _DocumentFacet({
    required this.title,
    required this.document,
    required this.onOpen,
    this.renewed = false,
  });

  final String title;
  final RenewalDocumentSnapshot? document;
  final VoidCallback? onOpen;
  final bool renewed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: renewed ? AppColors.forest50 : const Color(0xFFF4F5F4),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: renewed ? const Color(0xFFB9DECF) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: renewed ? AppColors.forest700 : AppColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            document?.documentNumber?.isNotEmpty == true
                ? document!.documentNumber!
                : 'Number unavailable',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            'Expires ${document?.expiryDate ?? '—'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 9),
          ),
          if (onOpen != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Open', style: TextStyle(fontSize: 9)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryAddress extends StatelessWidget {
  const _DeliveryAddress({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.location_on_outlined,
          color: AppColors.forest700,
        ),
        title: const Text(
          'Delivery destination',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(address, style: const TextStyle(fontSize: 10)),
      ),
    );
  }
}

class _OrderError extends StatelessWidget {
  const _OrderError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E6),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFF0C6C2)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.danger, fontSize: 11),
      ),
    );
  }
}

class _OrderLoadError extends StatelessWidget {
  const _OrderLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

String _moneyFromKobo(int kobo) {
  final whole = kobo ~/ 100;
  final decimal = (kobo % 100).abs().toString().padLeft(2, '0');
  final digits = whole.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${whole < 0 ? '-' : ''}$buffer.$decimal';
}

String _longDate(DateTime? date) {
  if (date == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute $period';
}

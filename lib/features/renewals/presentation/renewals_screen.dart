import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/renewals/data/renewal_repository.dart';
import 'package:travla_customer_app/features/renewals/domain/renewal_models.dart';

enum _RenewalFilter { all, active, completed }

class RenewalsScreen extends ConsumerStatefulWidget {
  const RenewalsScreen({super.key});

  @override
  ConsumerState<RenewalsScreen> createState() => _RenewalsScreenState();
}

class _RenewalsScreenState extends ConsumerState<RenewalsScreen> {
  _RenewalFilter _filter = _RenewalFilter.all;

  @override
  Widget build(BuildContext context) {
    final renewals = ref.watch(renewalOrdersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Renewals'),
        actions: [
          IconButton(
            tooltip: 'New renewal',
            onPressed: () => context.push('/more/renewals/new'),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: renewals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _RenewalLoadError(
          message: error is ApiFailure
              ? error.message
              : 'Your renewal orders could not be loaded.',
          onRetry: () => ref.invalidate(renewalOrdersProvider),
        ),
        data: _content,
      ),
    );
  }

  Widget _content(List<RenewalRecord> records) {
    final allOrders = RenewalOrderSummary.group(records);
    final orders = allOrders
        .where((order) {
          return switch (_filter) {
            _RenewalFilter.all => true,
            _RenewalFilter.active => order.statuses.any(
              (status) =>
                  !{'COMPLETED', 'CANCELLED', 'REJECTED'}.contains(status),
            ),
            _RenewalFilter.completed => order.statuses.every(
              (status) => status == 'COMPLETED',
            ),
          };
        })
        .toList(growable: false);
    final activeCount = allOrders
        .where(
          (order) => order.statuses.any(
            (status) =>
                !{'COMPLETED', 'CANCELLED', 'REJECTED'}.contains(status),
          ),
        )
        .length;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(renewalOrdersProvider);
        await ref.read(renewalOrdersProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 36),
        children: [
          _RenewalHero(
            orderCount: allOrders.length,
            activeCount: activeCount,
            onStart: () => context.push('/more/renewals/new'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your orders',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${allOrders.length} total',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<_RenewalFilter>(
            segments: const [
              ButtonSegment(value: _RenewalFilter.all, label: Text('All')),
              ButtonSegment(
                value: _RenewalFilter.active,
                label: Text('Active'),
              ),
              ButtonSegment(
                value: _RenewalFilter.completed,
                label: Text('Complete'),
              ),
            ],
            selected: {_filter},
            showSelectedIcon: false,
            onSelectionChanged: (value) {
              setState(() => _filter = value.first);
            },
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            _EmptyRenewals(
              filtered: allOrders.isNotEmpty,
              onStart: () => context.push('/more/renewals/new'),
            )
          else
            ...orders.map(
              (order) => _OrderCard(
                order: order,
                onTap: () =>
                    context.push('/more/renewals/orders/${order.groupId}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RenewalHero extends StatelessWidget {
  const _RenewalHero({
    required this.orderCount,
    required this.activeCount,
    required this.onStart,
  });

  final int orderCount;
  final int activeCount;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
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
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: AppColors.orange),
              SizedBox(width: 8),
              Text(
                'VEHICLE PAPER RENEWALS',
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
          const Text(
            'Renew together. Track as one order.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Choose eligible papers, see every fee before payment and follow processing through secure handover.',
            style: TextStyle(
              color: Color(0xFFBBD8CD),
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(value: '$activeCount', label: 'Active'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroMetric(value: '$orderCount', label: 'All orders'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onStart,
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Start a renewal'),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFBBD8CD), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final RenewalOrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = order.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(first.status).withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_repeat_rounded,
                  color: _statusColor(first.status),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.reference.isEmpty
                                ? 'Renewal order'
                                : order.reference,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '₦${_moneyFromKobo(order.totalKobo)}',
                          style: const TextStyle(
                            color: AppColors.forest700,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.documentNames,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${first.vehicle?.displayName ?? 'Vehicle'} · ${first.vehicle?.plateNumber ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        ...order.statuses.map(
                          (status) => _StatusBadge(
                            status: status,
                            label: order.items
                                .firstWhere((item) => item.status == status)
                                .statusLabel,
                          ),
                        ),
                        Text(
                          '${order.items.length} paper${order.items.length == 1 ? '' : 's'} · ${_shortDate(first.requestDate)}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
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

class _EmptyRenewals extends StatelessWidget {
  const _EmptyRenewals({required this.filtered, required this.onStart});

  final bool filtered;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          children: [
            const Icon(
              Icons.event_available_outlined,
              color: AppColors.forest700,
              size: 38,
            ),
            const SizedBox(height: 10),
            Text(
              filtered ? 'No orders in this view' : 'No renewal orders yet',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              filtered
                  ? 'Choose another filter to see your other orders.'
                  : 'Start when a paper expires or enters its 30-day renewal window.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            if (!filtered) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onStart,
                child: const Text('Start renewal'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RenewalLoadError extends StatelessWidget {
  const _RenewalLoadError({required this.message, required this.onRetry});

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
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status) => switch (status) {
  'COMPLETED' => AppColors.forest700,
  'PROCESSING' => const Color(0xFF1769AA),
  'PENDING' => AppColors.orangeDark,
  'CANCELLED' || 'REJECTED' => AppColors.danger,
  _ => AppColors.muted,
};

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

String _shortDate(DateTime? value) {
  if (value == null) return 'Date unavailable';
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
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

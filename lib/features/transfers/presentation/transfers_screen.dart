import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/transfers/data/transfer_repository.dart';
import 'package:travla_customer_app/features/transfers/domain/transfer_models.dart';

enum _TransferFilter { all, sent, received }

class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});

  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  _TransferFilter _filter = _TransferFilter.all;

  @override
  Widget build(BuildContext context) {
    final transfers = ref.watch(transferListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ownership transfers')),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            _TransferDeskHero(
              transfers: transfers.asData?.value ?? const [],
              loading: transfers.isLoading,
              onStart: () => context.go('/vehicles'),
            ),
            const SizedBox(height: 18),
            _FilterBar(
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 14),
            transfers.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 54),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => _TransferLoadError(
                message: error is ApiFailure
                    ? error.message
                    : 'Your transfers could not be loaded.',
                onRetry: _refresh,
              ),
              data: (items) {
                final visible = items
                    .where((item) {
                      return switch (_filter) {
                        _TransferFilter.all => true,
                        _TransferFilter.sent => item.amISender,
                        _TransferFilter.received => item.amIRecipient,
                      };
                    })
                    .toList(growable: false);
                if (visible.isEmpty) {
                  return _EmptyTransfers(filtered: items.isNotEmpty);
                }
                return Column(
                  children: visible
                      .map(
                        (item) => _TransferCard(
                          transfer: item,
                          onTap: () =>
                              context.push('/more/transfers/${item.id}'),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(transferListProvider);
    await ref.read(transferListProvider.future);
  }
}

class _TransferDeskHero extends StatelessWidget {
  const _TransferDeskHero({
    required this.transfers,
    required this.loading,
    required this.onStart,
  });
  final List<TransferRecord> transfers;
  final bool loading;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final active = transfers.where((item) => !item.isFinished).length;
    final awaiting = transfers.where((item) => item.awaitsMyConsent).length;
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
          const Text(
            'OWNERSHIP DESK',
            style: TextStyle(
              color: AppColors.orange,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .9,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Every ownership change, clearly tracked.',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 23,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manager verification happens before a recipient is invited to confirm and receive a vehicle.',
            style: TextStyle(
              color: Color(0xAAFFFFFF),
              fontSize: 10,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'ALL',
                  value: loading ? '—' : '${transfers.length}',
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _HeroMetric(
                  label: 'ACTIVE',
                  value: loading ? '—' : '$active',
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _HeroMetric(
                  label: 'NEEDS YOU',
                  value: loading ? '—' : '$awaiting',
                  accent: awaiting > 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: onStart,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Choose a vehicle to transfer'),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    decoration: BoxDecoration(
      color: accent ? AppColors.orange : const Color(0x12FFFFFF),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0x18FFFFFF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0x88FFFFFF),
            fontSize: 7,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});
  final _TransferFilter selected;
  final ValueChanged<_TransferFilter> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<_TransferFilter>(
    segments: const [
      ButtonSegment(value: _TransferFilter.all, label: Text('All')),
      ButtonSegment(value: _TransferFilter.sent, label: Text('Sent')),
      ButtonSegment(value: _TransferFilter.received, label: Text('Received')),
    ],
    selected: {selected},
    onSelectionChanged: (values) => onChanged(values.first),
    showSelectedIcon: false,
  );
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.transfer, required this.onTap});
  final TransferRecord transfer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _TransferTone.from(transfer.status, transfer.reviewStatus);
    final vehicleName = transfer.vehicle?.displayName.isNotEmpty == true
        ? transfer.vehicle!.displayName
        : 'Vehicle ownership transfer';
    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Pill(
                        transfer.directionLabel.toUpperCase(),
                        AppColors.forest700,
                      ),
                      _Pill(transfer.reviewStatusLabel, tone.foreground),
                      _Pill(
                        transfer.transferMode == 'MANAGED'
                            ? 'Travla managed'
                            : 'Offline documents',
                        AppColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tone.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.directions_car_outlined,
                          color: tone.foreground,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicleName,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                transfer.vehicle?.plateNumber ?? '',
                                transfer.trackingNumber,
                              ].where((part) => part.isNotEmpty).join(' · '),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PartyLabel(
                          label: 'FROM',
                          name: transfer.currentOwner?.name ?? 'Current owner',
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.orange,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: _PartyLabel(
                          label: 'TO',
                          name: transfer.recipient.name,
                          right: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              color: tone.background,
              child: Text(
                transfer.awaitsMyConsent
                    ? 'Approved — your confirmation is required'
                    : transfer.status == 'COMPLETED'
                    ? 'Open verified ownership record'
                    : transfer.reviewStatusLabel,
                style: TextStyle(
                  color: tone.foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyLabel extends StatelessWidget {
  const _PartyLabel({
    required this.label,
    required this.name,
    this.right = false,
  });
  final String label;
  final String name;
  final bool right;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: right
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 7,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        name.isEmpty ? 'Recipient' : name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900),
    ),
  );
}

class _TransferTone {
  const _TransferTone(this.foreground, this.background);
  final Color foreground;
  final Color background;
  factory _TransferTone.from(String status, String reviewStatus) {
    if (status == 'COMPLETED') {
      return const _TransferTone(AppColors.forest700, AppColors.forest50);
    }
    if (status == 'CANCELLED' || status == 'REJECTED') {
      return const _TransferTone(AppColors.danger, Color(0xFFFFE9E7));
    }
    if (reviewStatus == 'AWAITING_RECIPIENT') {
      return const _TransferTone(AppColors.orangeDark, AppColors.orangeSoft);
    }
    return const _TransferTone(AppColors.forest700, AppColors.forest50);
  }
}

class _EmptyTransfers extends StatelessWidget {
  const _EmptyTransfers({required this.filtered});
  final bool filtered;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      child: Column(
        children: [
          const Icon(
            Icons.swap_horiz_rounded,
            color: AppColors.muted,
            size: 34,
          ),
          const SizedBox(height: 9),
          Text(
            filtered ? 'No transfers in this view' : 'No ownership transfers',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            filtered
                ? 'Choose another filter to see your transfer records.'
                : 'Transfers you send or receive will appear here.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _TransferLoadError extends StatelessWidget {
  const _TransferLoadError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

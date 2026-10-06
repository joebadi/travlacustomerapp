import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';
import 'package:travla_customer_app/features/wallet/data/wallet_repository.dart';

class FleetFuelScreen extends ConsumerStatefulWidget {
  const FleetFuelScreen({super.key, required this.organisationId});

  final String organisationId;

  @override
  ConsumerState<FleetFuelScreen> createState() => _FleetFuelScreenState();
}

class _FleetFuelScreenState extends ConsumerState<FleetFuelScreen> {
  final _search = TextEditingController();
  List<FleetFuelTransaction> _transactions = const [];
  int _page = 0;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _load(reset: true));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(fleetRepositoryProvider)
          .fuelTransactions(
            widget.organisationId,
            page: reset ? 1 : _page + 1,
            query: _search.text,
            status: _status,
          );
      if (!mounted) return;
      setState(() {
        _transactions = reset
            ? result.items
            : [..._transactions, ...result.items];
        _page = result.page;
        _lastPage = result.lastPage;
        _total = result.total;
      });
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(fleetFuelSummaryProvider(widget.organisationId));
    await Future.wait([
      ref.read(fleetFuelSummaryProvider(widget.organisationId).future),
      _load(reset: true),
    ]);
  }

  Future<void> _openFunding(FleetFuelSummary summary) async {
    final receipt = await showModalBottomSheet<FleetFundingReceipt>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      builder: (_) => _FundFleetSheet(
        organisationId: widget.organisationId,
        organisationName: summary.organisationName ?? 'this fleet',
        fleetAvailableNaira: summary.availableNaira,
      ),
    );
    if (receipt == null || !mounted) return;
    ref.invalidate(walletBalanceProvider);
    ref.invalidate(walletWorkspaceProvider);
    ref.invalidate(fleetOrgProvider(widget.organisationId));
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '₦${receipt.amountNaira} transferred. Fleet balance: ₦${receipt.fleetBalanceNaira}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(fleetFuelSummaryProvider(widget.organisationId));
    final canFund =
        ref
            .watch(fleetOrgProvider(widget.organisationId))
            .value
            ?.capabilities
            .fundFleet ??
        false;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Fleet fuel')),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            summary.when(
              loading: () => const SizedBox(
                height: 190,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _FuelError(
                message: error is ApiFailure
                    ? error.message
                    : 'Fleet fuel information could not be loaded.',
                onRetry: () => ref.invalidate(
                  fleetFuelSummaryProvider(widget.organisationId),
                ),
              ),
              data: (data) => _FuelSummary(
                summary: data,
                onFund: canFund ? () => _openFunding(data) : null,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Fuel activity',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$_total record${_total == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(reset: true),
              decoration: InputDecoration(
                hintText: 'Search plate, vehicle or station',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: () => _load(reset: true),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filter('All', null),
                  _filter('In progress', 'ACTIVE'),
                  _filter('Completed', 'COMPLETED'),
                  _filter('Cancelled', 'CANCELLED'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              _FuelError(message: _error!, onRetry: () => _load(reset: true))
            else if (_loading && _transactions.isEmpty)
              const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_transactions.isEmpty)
              const _FuelEmpty()
            else
              ..._transactions.map(
                (transaction) => _FuelTransactionCard(
                  transaction: transaction,
                  onTap: () => context.push(
                    '/more/fleet/${widget.organisationId}/fuel/transactions/${transaction.id}',
                  ),
                ),
              ),
            if (_transactions.isNotEmpty && _page < _lastPage)
              Center(
                child: TextButton.icon(
                  onPressed: _loading ? null : () => _load(reset: false),
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text('Load more (${_transactions.length} of $_total)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filter(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _status == value,
        onSelected: _loading
            ? null
            : (_) {
                setState(() => _status = value);
                _load(reset: true);
              },
      ),
    );
  }
}

class FleetFuelTransactionScreen extends ConsumerWidget {
  const FleetFuelTransactionScreen({
    super.key,
    required this.organisationId,
    required this.transactionId,
  });

  final String organisationId;
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (organisationId: organisationId, transactionId: transactionId);
    final transaction = ref.watch(fleetFuelTransactionProvider(key));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Fuel transaction')),
      body: transaction.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FuelError(
              message: error is ApiFailure
                  ? error.message
                  : 'This fuel transaction could not be loaded.',
              onRetry: () => ref.invalidate(fleetFuelTransactionProvider(key)),
            ),
          ],
        ),
        data: (item) => RefreshIndicator(
          color: AppColors.forest700,
          onRefresh: () async {
            ref.invalidate(fleetFuelTransactionProvider(key));
            await ref.read(fleetFuelTransactionProvider(key).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _TransactionHero(transaction: item),
              const SizedBox(height: 14),
              _DetailPanel(
                title: 'Purchase details',
                icon: Icons.local_gas_station_outlined,
                children: [
                  _DetailLine('Vehicle', item.plateNumber ?? 'Unavailable'),
                  _DetailLine(
                    'Vehicle type',
                    item.vehicleLabel ?? 'Unavailable',
                  ),
                  _DetailLine('Region', item.regionName ?? 'Unassigned'),
                  _DetailLine('Station', item.stationName ?? 'Unavailable'),
                  if (item.stationAddress != null)
                    _DetailLine('Address', item.stationAddress!),
                  _DetailLine(
                    'Volume',
                    item.litersDispensed == null
                        ? 'Not recorded'
                        : '${item.litersDispensed} L',
                  ),
                  _DetailLine('Price per litre', '₦${item.pricePerLiterNaira}'),
                  _DetailLine(
                    'Fuel card',
                    item.cardLastFour == null
                        ? 'Unavailable'
                        : '•••• ${item.cardLastFour}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DetailPanel(
                title: 'Processing timeline',
                icon: Icons.receipt_long_outlined,
                children: [
                  _DetailLine('Status', item.statusLabel),
                  _DetailLine('Started', _fleetDateTime(item.createdAt)),
                  _DetailLine(
                    'Completed',
                    item.completedAt == null
                        ? 'Not completed'
                        : _fleetDateTime(item.completedAt),
                  ),
                  _DetailLine('Amount state', switch (item.amountState) {
                    'SETTLED' => 'Settled amount',
                    'RESERVED' => 'Funds reserved',
                    _ => 'Amount unavailable',
                  }),
                ],
              ),
              const SizedBox(height: 14),
              const _MoneyBoundaryNotice(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuelSummary extends StatelessWidget {
  const _FuelSummary({required this.summary, this.onFund});

  final FleetFuelSummary summary;
  final VoidCallback? onFund;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
              Text(
                summary.organisationName ?? 'Fleet workspace',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'AVAILABLE FOR FUEL',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '₦${summary.availableNaira}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeroAmount(
                      label: 'Total pool',
                      value: '₦${summary.balanceNaira}',
                    ),
                  ),
                  Expanded(
                    child: _HeroAmount(
                      label: 'Reserved',
                      value: '₦${summary.reservedNaira}',
                    ),
                  ),
                  Expanded(
                    child: _HeroAmount(
                      label: 'Model',
                      value: summary.fundingModelLabel ?? 'Not set',
                    ),
                  ),
                ],
              ),
              if (onFund != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onFund,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.add_card_rounded, size: 19),
                    label: const Text('Fund fuel pool'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _SummaryMetric(
                label: 'This month',
                value: '₦${summary.monthSpendNaira}',
              ),
              _SummaryMetric(
                label: 'Active cards',
                value:
                    '${summary.activeCardCount}/${summary.visibleVehicleCount}',
              ),
              _SummaryMetric(
                label: 'In progress',
                value: '${summary.activeTransactionCount}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _MoneyBoundaryNotice(),
        const SizedBox(height: 8),
        _FuelScopeNotice(scope: summary.scope),
      ],
    );
  }
}

class _FundFleetSheet extends ConsumerStatefulWidget {
  const _FundFleetSheet({
    required this.organisationId,
    required this.organisationName,
    required this.fleetAvailableNaira,
  });

  final String organisationId;
  final String organisationName;
  final String fleetAvailableNaira;

  @override
  ConsumerState<_FundFleetSheet> createState() => _FundFleetSheetState();
}

class _FundFleetSheetState extends ConsumerState<_FundFleetSheet> {
  final _amount = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;
  int? _pendingAmount;
  String? _stepUpToken;
  String? _idempotencyKey;

  int? get _amountNaira => int.tryParse(_amount.text.trim());
  bool get _hasPendingAttempt =>
      _pendingAmount == _amountNaira &&
      _stepUpToken != null &&
      _idempotencyKey != null;

  @override
  void dispose() {
    _amount.dispose();
    _password.dispose();
    super.dispose();
  }

  void _amountChanged(String _) {
    if (_pendingAmount != _amountNaira) {
      _pendingAmount = null;
      _stepUpToken = null;
      _idempotencyKey = null;
    }
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    final amount = _amountNaira;
    if (amount == null || amount < 100) {
      setState(() => _error = 'Enter at least ₦100.');
      return;
    }
    final wallet = ref.read(walletBalanceProvider).value;
    if (wallet != null && amount * 100 > wallet.balanceKobo) {
      setState(
        () => _error =
            'Your personal wallet does not have enough money for this transfer.',
      );
      return;
    }
    if (!_hasPendingAttempt && _password.text.isEmpty) {
      setState(() => _error = 'Enter your current Travla password.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repository = ref.read(fleetRepositoryProvider);
      if (!_hasPendingAttempt) {
        final challenge = await repository.createFundingStepUp(
          widget.organisationId,
          amountNaira: amount,
          password: _password.text,
        );
        _pendingAmount = amount;
        _stepUpToken = challenge.token;
        _idempotencyKey = _newIdempotencyKey();
        _password.clear();
      }
      final receipt = await repository.fundFuel(
        widget.organisationId,
        amountNaira: amount,
        stepUpToken: _stepUpToken!,
        idempotencyKey: _idempotencyKey!,
      );
      if (mounted) Navigator.of(context).pop(receipt);
    } on ApiFailure catch (failure) {
      if (failure.details['code'] == 'FLEET_STEP_UP_REQUIRED') {
        _pendingAmount = null;
        _stepUpToken = null;
        _idempotencyKey = null;
      }
      _password.clear();
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletBalanceProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final amount = _amountNaira;
    final walletBalance = wallet.value;
    final exceedsBalance =
        amount != null &&
        walletBalance != null &&
        amount * 100 > walletBalance.balanceKobo;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 20),
          const Text(
            'Fund fuel pool',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Move money from your personal Travla wallet into ${widget.organisationName}. This cannot be reversed in the app.',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.forest700.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.forest700.withValues(alpha: .12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _FundingBalance(
                    label: 'Personal wallet',
                    value: wallet.when(
                      data: (value) => '₦${value.balanceNaira}',
                      loading: () => 'Loading…',
                      error: (_, _) => 'Unavailable',
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.orange,
                ),
                Expanded(
                  child: _FundingBalance(
                    label: 'Fleet available',
                    value: '₦${widget.fleetAvailableNaira}',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: _amountChanged,
            decoration: const InputDecoration(
              labelText: 'Amount to transfer',
              prefixText: '₦ ',
              hintText: 'Minimum ₦100',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitting ? null : _submit(),
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: _hasPendingAttempt
                  ? 'Identity confirmed for this retry'
                  : 'Current Travla password',
              helperText: _hasPendingAttempt
                  ? 'A previous safe transfer attempt will be resumed.'
                  : 'Required to confirm this financial action.',
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _submitting ||
                      amount == null ||
                      amount < 100 ||
                      exceedsBalance ||
                      (!_hasPendingAttempt && _password.text.isEmpty)
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest700,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_outline_rounded),
              label: Text(
                _submitting
                    ? 'Transferring securely…'
                    : amount == null
                    ? 'Confirm transfer'
                    : 'Confirm ₦${amount.toString()} transfer',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FundingBalance extends StatelessWidget {
  const _FundingBalance({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 9.5),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

String _newIdempotencyKey() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class _HeroAmount extends StatelessWidget {
  const _HeroAmount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyBoundaryNotice extends StatelessWidget {
  const _MoneyBoundaryNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.forest700.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.forest700, size: 19),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'This is company Fleet fuel money, separate from your personal Travla wallet.',
              style: TextStyle(
                color: AppColors.forest700,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelScopeNotice extends StatelessWidget {
  const _FuelScopeNotice({required this.scope});

  final FleetScope scope;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.visibility_outlined,
            color: AppColors.muted,
            size: 16,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              scope.seesAllRegions
                  ? 'Pool balances and activity cover all company regions.'
                  : 'Pool balances are company-wide. Activity, cards and vehicle counts show only your assigned regions.',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelTransactionCard extends StatelessWidget {
  const _FuelTransactionCard({required this.transaction, required this.onTap});

  final FleetFuelTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _fuelStatusColor(transaction).withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_gas_station_outlined,
                  color: _fuelStatusColor(transaction),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.plateNumber ?? 'Fleet vehicle',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          transaction.displayAmountNaira == null
                              ? '—'
                              : '₦${transaction.displayAmountNaira}',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      transaction.stationName ?? 'Station unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _FuelStatusBadge(transaction: transaction),
                        const Spacer(),
                        Text(
                          _fleetDateTime(transaction.createdAt),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionHero extends StatelessWidget {
  const _TransactionHero({required this.transaction});

  final FleetFuelTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final color = _fuelStatusColor(transaction);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_gas_station_rounded, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            transaction.displayAmountNaira == null
                ? 'Amount unavailable'
                : '₦${transaction.displayAmountNaira}',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          _FuelStatusBadge(transaction: transaction),
          if (transaction.amountState == 'RESERVED') ...[
            const SizedBox(height: 8),
            const Text(
              'Reserved funds are not a final settled charge.',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _FuelStatusBadge extends StatelessWidget {
  const _FuelStatusBadge({required this.transaction});

  final FleetFuelTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final color = _fuelStatusColor(transaction);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        transaction.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: AppColors.forest700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelError extends StatelessWidget {
  const _FuelError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _FuelEmpty extends StatelessWidget {
  const _FuelEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.local_gas_station_outlined,
            color: AppColors.muted,
            size: 32,
          ),
          SizedBox(height: 10),
          Text(
            'No fuel activity matches this view.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _fuelStatusColor(FleetFuelTransaction transaction) {
  if (transaction.isComplete) return AppColors.forest700;
  if (transaction.isCancelled) return AppColors.danger;
  return AppColors.orangeDark;
}

String _fleetDateTime(DateTime? value) {
  if (value == null) return 'Unavailable';
  final local = value.toLocal();
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
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute $period';
}

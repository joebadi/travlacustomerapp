import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';
import 'package:travla_customer_app/features/insurance/presentation/insurance_widgets.dart';
import 'package:travla_customer_app/features/renewals/data/renewal_repository.dart';

/// Buy a fresh motor-insurance policy for an uninsured vehicle. Automated =
/// instant digital issue; agent = an agent procures it (delivery + shared order).
class BuyInsuranceScreen extends ConsumerStatefulWidget {
  const BuyInsuranceScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<BuyInsuranceScreen> createState() => _BuyInsuranceScreenState();
}

class _BuyInsuranceScreenState extends ConsumerState<BuyInsuranceScreen> {
  String? _coverage;
  String _method = 'DELIVERY';
  String _city = '';
  String _state = '';
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  InsuranceBuyQuote? _quote;
  bool _quoting = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _ready => _coverage != null;

  Future<void> _refreshQuote(bool automated) async {
    if (_coverage == null) {
      setState(() => _quote = null);
      return;
    }
    if (!automated && (_city.isEmpty || _state.isEmpty)) {
      setState(() => _quote = null);
      return;
    }
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final quote = await ref.read(insuranceRepositoryProvider).buyQuote(
            vehicleId: widget.vehicleId,
            coverageType: _coverage!,
            automated: automated,
            state: _state,
            deliveryMethod: _method,
            city: _city,
          );
      if (mounted) setState(() => _quote = quote);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _submit(bool automated) async {
    final quote = _quote;
    if (quote == null || !quote.available) return;
    if (!automated && _method == 'DELIVERY' && _addressController.text.trim().isEmpty) {
      setState(() => _error = 'Add the delivery address.');
      return;
    }
    if (!quote.sufficientBalance) {
      setState(
        () => _error =
            'Your wallet is short by ₦${quote.shortfallNaira}. Top up from Transactions, then try again.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final groupId = await ref.read(insuranceRepositoryProvider).buy(
            vehicleId: widget.vehicleId,
            coverageType: _coverage!,
            automated: automated,
            deliveryMethod: _method,
            city: _city,
            state: _state,
            address: _addressController.text,
            notes: _notesController.text,
          );
      ref.invalidate(vehicleInsuranceProvider(widget.vehicleId));
      ref.invalidate(expiringPoliciesProvider);
      ref.invalidate(renewalOrdersProvider);
      if (!mounted) return;
      if (groupId.isEmpty) {
        context.go('/more/insurance/${widget.vehicleId}');
      } else {
        context.go('/more/renewals/orders/$groupId');
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final automatedAsync = ref.watch(insuranceAutomatedProvider);
    final cities = ref.watch(renewalServiceCitiesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Buy insurance')),
      body: automatedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            error is ApiFailure
                ? error.message
                : 'Buying insurance is unavailable right now.',
          ),
        ),
        data: (automated) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          children: [
            Text(
              'Buy motor insurance',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              automated
                  ? 'Issued instantly as a digital certificate.'
                  : 'An agent procures the certificate and delivers it.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              InlineError(_error!),
              const SizedBox(height: 14),
            ],
            CheckoutSection(
              title: 'Choose your cover',
              child: Column(
                children: coverageTypeOptions.map((o) {
                  final selected = _coverage == o.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _coverage = o.value);
                        _refreshQuote(automated);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.forest50 : AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.forest700
                                : AppColors.border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: selected
                                  ? AppColors.forest700
                                  : AppColors.muted,
                              size: 20,
                            ),
                            const SizedBox(width: 11),
                            Text(
                              o.label,
                              style: TextStyle(
                                color: AppColors.ink,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (!automated) ...[
              const SizedBox(height: 14),
              CheckoutSection(
                title: 'How should we get it to you?',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DeliveryMethodTile(
                            label: 'Doorstep delivery',
                            helper: 'A rider brings it to you',
                            selected: _method == 'DELIVERY',
                            onTap: () {
                              setState(() => _method = 'DELIVERY');
                              _refreshQuote(automated);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DeliveryMethodTile(
                            label: 'Office pickup',
                            helper: 'Collect from the agent — free',
                            selected: _method == 'PICKUP',
                            onTap: () {
                              setState(() => _method = 'PICKUP');
                              _refreshQuote(automated);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    cities.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) =>
                          const Text('Covered cities could not be loaded.'),
                      data: (list) => DropdownButtonFormField<String>(
                        initialValue: _city.isEmpty ? null : _city,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                        items: list
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.city,
                                child: Text(
                                  '${c.city}, ${c.state}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          final match = list.firstWhere(
                            (c) => c.city == value,
                            orElse: () => list.first,
                          );
                          setState(() {
                            _city = match.city;
                            _state = match.state;
                          });
                          _refreshQuote(automated);
                        },
                      ),
                    ),
                    if (_method == 'DELIVERY') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Delivery address',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            _BuyQuoteCard(
              quote: _quote,
              quoting: _quoting,
              showDelivery: !automated && _method == 'DELIVERY',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  (_ready && _quote?.available == true && !_submitting && !_quoting)
                  ? () => _submit(automated)
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.orange,
              ),
              child: Text(
                _submitting
                    ? 'Submitting…'
                    : _quote == null
                    ? 'Choose your cover to see the price'
                    : 'Pay ₦${_quote!.totalNaira} & buy',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuyQuoteCard extends StatelessWidget {
  const _BuyQuoteCard({
    required this.quote,
    required this.quoting,
    required this.showDelivery,
  });

  final InsuranceBuyQuote? quote;
  final bool quoting;
  final bool showDelivery;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Text(
                'Payment summary',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (quoting)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (quote == null)
            const Text(
              'Choose your cover to see your total.',
              style: TextStyle(color: AppColors.muted),
            )
          else if (!quote!.available)
            InlineError(
              quote!.reason ?? 'A policy could not be quoted right now.',
            )
          else ...[
            if (quote!.providerLabel != null)
              SummaryLine(label: 'Provider', value: quote!.providerLabel!),
            SummaryLine(label: 'Premium', value: '₦${quote!.priceNaira}'),
            if (showDelivery)
              SummaryLine(
                label: 'Doorstep delivery',
                value: '₦${quote!.deliveryFeeNaira}',
              ),
            const Divider(height: 22),
            SummaryLine(
              label: 'Total',
              value: '₦${quote!.totalNaira}',
              bold: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Wallet balance',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '₦${quote!.walletBalanceNaira}',
                  style: TextStyle(
                    color: quote!.sufficientBalance
                        ? AppColors.forest700
                        : AppColors.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (!quote!.sufficientBalance) ...[
              const SizedBox(height: 8),
              InlineError(
                'Short by ₦${quote!.shortfallNaira}. Top up from Transactions, then return here.',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

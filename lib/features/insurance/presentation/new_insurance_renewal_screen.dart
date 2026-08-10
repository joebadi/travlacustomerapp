import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';
import 'package:travla_customer_app/features/insurance/presentation/insurance_widgets.dart';
import 'package:travla_customer_app/features/renewals/data/renewal_repository.dart';

/// Renew an existing motor-insurance policy. When the platform is configured for
/// an automated provider the renewal is instant/digital (no delivery); otherwise
/// an agent fulfils it and it rides the shared renewal-order machinery.
class NewInsuranceRenewalScreen extends ConsumerStatefulWidget {
  const NewInsuranceRenewalScreen({
    super.key,
    required this.vehicleId,
    required this.policyId,
  });

  final String vehicleId;
  final String policyId;

  @override
  ConsumerState<NewInsuranceRenewalScreen> createState() =>
      _NewInsuranceRenewalScreenState();
}

class _NewInsuranceRenewalScreenState
    extends ConsumerState<NewInsuranceRenewalScreen> {
  String _method = 'DELIVERY';
  String _city = '';
  String _state = '';
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  InsuranceRenewalQuote? _quote;
  bool _quoting = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _effectiveMethod(bool automated) => automated ? 'PICKUP' : _method;

  Future<void> _refreshQuote(bool automated) async {
    if (_city.isEmpty || _state.isEmpty) {
      setState(() => _quote = null);
      return;
    }
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final quote = await ref.read(insuranceRepositoryProvider).renewQuote(
            policyId: widget.policyId,
            state: _state,
            deliveryMethod: _effectiveMethod(automated),
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
    if (quote == null || !quote.eligible) return;
    final method = _effectiveMethod(automated);
    if (method == 'DELIVERY' && _addressController.text.trim().isEmpty) {
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
      final groupId = await ref.read(insuranceRepositoryProvider).renew(
            policyId: widget.policyId,
            deliveryMethod: method,
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
    final insurance = ref.watch(vehicleInsuranceProvider(widget.vehicleId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Renew insurance')),
      body: automatedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            error is ApiFailure
                ? error.message
                : 'Insurance renewal is unavailable right now.',
          ),
        ),
        data: (automated) {
          final policy = insurance.value?.policies
              .where((p) => p.id == widget.policyId)
              .firstOrNull;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              Text(
                'Renew motor insurance',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (policy != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${policy.provider ?? 'Policy'} · ${policy.coverageLabel ?? ''}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 18),
              if (_error != null) ...[
                InlineError(_error!),
                const SizedBox(height: 14),
              ],
              if (automated)
                const _AutomatedNote()
              else
                CheckoutSection(
                  title: 'How should we get the certificate to you?',
                  child: Row(
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
                ),
              const SizedBox(height: 14),
              CheckoutSection(
                title: automated ? 'Registration state' : 'Where are you?',
                child: Column(
                  children: [
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
                    if (!automated && _method == 'DELIVERY') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Delivery address',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                    ],
                    if (!automated) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _QuoteCard(
                quote: _quote,
                quoting: _quoting,
                showDelivery: !automated && _method == 'DELIVERY',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    (_quote?.eligible == true && !_submitting && !_quoting)
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
                      ? 'Choose a city to see the price'
                      : 'Pay ₦${_quote!.totalNaira} & renew',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AutomatedNote extends StatelessWidget {
  const _AutomatedNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.forest100),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt_rounded, color: AppColors.forest700),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This renewal is issued instantly as a digital certificate — no delivery needed.',
              style: TextStyle(color: AppColors.forest800, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.quoting,
    required this.showDelivery,
  });

  final InsuranceRenewalQuote? quote;
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
              'Choose a city to see your total.',
              style: TextStyle(color: AppColors.muted),
            )
          else if (!quote!.eligible)
            InlineError(quote!.reason ?? 'This policy is not eligible to renew.')
          else ...[
            SummaryLine(label: 'Insurance renewal', value: '₦${quote!.priceNaira}'),
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

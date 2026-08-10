import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/drivers_license/data/drivers_license_repository.dart';
import 'package:travla_customer_app/features/drivers_license/domain/drivers_license.dart';
import 'package:travla_customer_app/features/renewals/data/renewal_repository.dart';
import 'package:travla_customer_app/shared/widgets/travla_app_bar.dart';

class NewLicenseRenewalScreen extends ConsumerStatefulWidget {
  const NewLicenseRenewalScreen({required this.licenseId, super.key});

  final String licenseId;

  @override
  ConsumerState<NewLicenseRenewalScreen> createState() =>
      _NewLicenseRenewalScreenState();
}

class _NewLicenseRenewalScreenState
    extends ConsumerState<NewLicenseRenewalScreen> {
  String _method = 'DELIVERY';
  String _city = '';
  String _state = '';
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  LicenseRenewalQuote? _quote;
  bool _quoting = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DriversLicense? _license(List<DriversLicense> list) {
    for (final license in list) {
      if (license.id == widget.licenseId) return license;
    }
    return null;
  }

  Future<void> _refreshQuote() async {
    if (_city.isEmpty || _state.isEmpty) {
      setState(() => _quote = null);
      return;
    }
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final quote = await ref
          .read(driversLicenseRepositoryProvider)
          .quote(
            licenseId: widget.licenseId,
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

  Future<void> _submit() async {
    final quote = _quote;
    if (quote == null || !quote.eligible) return;
    if (_method == 'DELIVERY' && _addressController.text.trim().isEmpty) {
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
      final groupId = await ref
          .read(driversLicenseRepositoryProvider)
          .createRenewal(
            licenseId: widget.licenseId,
            deliveryMethod: _method,
            city: _city,
            state: _state,
            address: _addressController.text,
            notes: _notesController.text,
          );
      ref.invalidate(driversLicensesProvider);
      ref.invalidate(renewalOrdersProvider);
      if (!mounted) return;
      if (groupId.isEmpty) {
        context.go('/more/renewals');
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
    final licenses = ref.watch(driversLicensesProvider);
    final cities = ref.watch(renewalServiceCitiesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const TravlaAppBar(),
      body: licenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            error is ApiFailure ? error.message : 'Could not load the licence.',
          ),
        ),
        data: (list) {
          final license = _license(list);
          if (license == null) {
            return const Center(child: Text('Licence not found.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              Text(
                'Renew driver\'s licence',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${license.holderName} · ${license.licenseNumber}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                _ErrorBanner(_error!),
                const SizedBox(height: 14),
              ],
              _Card(
                title: 'How should we get it to you?',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MethodTile(
                            label: 'Doorstep delivery',
                            helper: 'A rider brings it to you',
                            selected: _method == 'DELIVERY',
                            onTap: () {
                              setState(() => _method = 'DELIVERY');
                              _refreshQuote();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MethodTile(
                            label: 'Office pickup',
                            helper: 'Collect from the agent — free',
                            selected: _method == 'PICKUP',
                            onTap: () {
                              setState(() => _method = 'PICKUP');
                              _refreshQuote();
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
                          _refreshQuote();
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
              const SizedBox(height: 14),
              _QuoteCard(quote: _quote, quoting: _quoting, method: _method),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    (_quote?.eligible == true &&
                        !_submitting &&
                        !_quoting)
                    ? _submit
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
                      : 'Pay ₦${_quote!.totalNaira} & submit',
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

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

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
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.label,
    required this.helper,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String helper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest700 : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.forest700 : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              helper,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: .78)
                    : AppColors.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.quoting,
    required this.method,
  });

  final LicenseRenewalQuote? quote;
  final bool quoting;
  final String method;

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
            _ErrorBanner(quote!.reason ?? 'This licence is not eligible to renew.')
          else ...[
            _Line(label: 'Licence renewal', value: '₦${quote!.priceNaira}'),
            if (method == 'DELIVERY')
              _Line(
                label: 'Doorstep delivery',
                value: '₦${quote!.deliveryFeeNaira}',
              ),
            const Divider(height: 22),
            _Line(label: 'Total', value: '₦${quote!.totalNaira}', bold: true),
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
              _ErrorBanner(
                'Short by ₦${quote!.shortfallNaira}. Top up from Transactions, then return here.',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? AppColors.ink : AppColors.muted,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
              fontSize: bold ? 15 : 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: bold ? 18 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5BBB5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

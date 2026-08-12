import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';
import 'package:travla_customer_app/features/renewals/data/renewal_repository.dart';
import 'package:travla_customer_app/features/renewals/domain/renewal_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';
import 'package:travla_customer_app/features/wallet/data/wallet_repository.dart';

class NewRenewalScreen extends ConsumerStatefulWidget {
  const NewRenewalScreen({
    this.vehicleId = '',
    this.preselectExpired = false,
    super.key,
  });

  final String vehicleId;

  /// When true (deep-linked from the Documents tab's "Renew N expired"
  /// action), every already-expired eligible paper is auto-checked once the
  /// renewable-documents list loads — mirrors the web's `preselect=expired`.
  final bool preselectExpired;

  @override
  ConsumerState<NewRenewalScreen> createState() => _NewRenewalScreenState();
}

class _NewRenewalScreenState extends ConsumerState<NewRenewalScreen> {
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final Set<String> _selectedDocuments = {};
  final Set<String> _selectedInsurancePolicies = {};

  late String _vehicleId;
  bool _preselectApplied = false;
  int _step = 1;
  String _deliveryMethod = 'DELIVERY';
  String _city = '';
  String _state = '';
  RenewalQuote? _quote;
  bool _quoting = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.vehicleId;
    _step = _vehicleId.isEmpty ? 1 : 2;
  }

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final garage = ref.watch(garageProvider);
    final cities = ref.watch(renewalServiceCitiesProvider);
    final documents = _vehicleId.isEmpty
        ? null
        : ref.watch(renewableDocumentsProvider(_vehicleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Renew vehicle papers')),
      body: garage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadFailure(
          message: error is ApiFailure
              ? error.message
              : 'Your vehicles could not be loaded.',
          onRetry: () => ref.invalidate(garageProvider),
        ),
        data: (snapshot) {
          if (snapshot.vehicles.isEmpty) return const _NoVehicleState();
          final selectedVehicle = _findVehicle(snapshot.vehicles, _vehicleId);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 36),
            children: [
              _RenewalIntro(vehicle: selectedVehicle),
              const SizedBox(height: 14),
              _StepRail(current: _step),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorPanel(message: _error!),
              ],
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: switch (_step) {
                  1 => _vehicleStep(snapshot.vehicles),
                  2 => _documentStep(documents, selectedVehicle),
                  _ => _fulfilmentStep(cities, selectedVehicle),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _vehicleStep(List<VehicleSummary> vehicles) {
    return _StageCard(
      key: const ValueKey('vehicle'),
      eyebrow: 'STEP 1',
      title: 'Choose the vehicle',
      description:
          'Travla checks every paper against this vehicle’s category and current records.',
      child: Column(
        children: [
          ...vehicles.map(
            (vehicle) => _VehicleChoice(
              vehicle: vehicle,
              selected: vehicle.id == _vehicleId,
              onTap: () => setState(() {
                _vehicleId = vehicle.id;
                _selectedDocuments.clear();
                _selectedInsurancePolicies.clear();
                _quote = null;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _vehicleId.isEmpty
                ? null
                : () => setState(() {
                    _step = 2;
                    _error = null;
                  }),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Check renewable papers'),
          ),
        ],
      ),
    );
  }

  Widget _documentStep(
    AsyncValue<List<RenewableDocumentOption>>? documents,
    VehicleSummary? vehicle,
  ) {
    if (documents == null) {
      return _LoadFailure(
        key: const ValueKey('no-document-context'),
        message: 'Choose a vehicle before selecting papers.',
        onRetry: () => setState(() => _step = 1),
      );
    }
    return documents.when(
      loading: () => const _StageCard(
        key: ValueKey('documents-loading'),
        eyebrow: 'STEP 2',
        title: 'Checking your papers',
        description: 'Travla is confirming renewal eligibility.',
        child: Padding(
          padding: EdgeInsets.all(26),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => _LoadFailure(
        key: const ValueKey('documents-error'),
        message: error is ApiFailure
            ? error.message
            : 'Renewal eligibility could not be checked.',
        onRetry: () => ref.invalidate(renewableDocumentsProvider(_vehicleId)),
      ),
      data: (items) {
        _applyExpiredPreselect(items);
        return _StageCard(
        key: const ValueKey('documents'),
        eyebrow: 'STEP 2',
        title: 'Select papers to renew',
        description:
            'Only expired papers or papers within 30 days of expiry can be selected.',
        child: Column(
          children: [
            if (items.isEmpty)
              const _EmptyDocuments()
            else
              ...items.map(
                (item) => _DocumentChoice(
                  document: item,
                  selected: _selectedDocuments.contains(item.id),
                  onChanged: item.eligible
                      ? (selected) => setState(() {
                          selected
                              ? _selectedDocuments.add(item.id)
                              : _selectedDocuments.remove(item.id);
                          _quote = null;
                          _error = null;
                        })
                      : null,
                  onUpload: item.needsUpload
                      ? () => _openVehicleDocuments(vehicle)
                      : null,
                ),
              ),
            _insuranceSection(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _step = 1;
                      _error = null;
                    }),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    // Insurance-only selections must also unlock Continue —
                    // this used to check documents alone while the label
                    // below already counted both.
                    onPressed:
                        _selectedDocuments.isEmpty &&
                            _selectedInsurancePolicies.isEmpty
                        ? null
                        : () => setState(() {
                            _step = 3;
                            _error = null;
                          }),
                    child: Text(
                      _selectedDocuments.isEmpty &&
                              _selectedInsurancePolicies.isEmpty
                          ? 'Select a paper'
                          : 'Continue with ${_selectedDocuments.length + _selectedInsurancePolicies.length}',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      },
    );
  }

  /// Auto-checks already-expired eligible papers once, when this screen was
  /// opened via a "Renew N expired" deep link. Guarded by [_preselectApplied]
  /// so it only runs once and never fights the user's own selections.
  void _applyExpiredPreselect(List<RenewableDocumentOption> items) {
    if (!widget.preselectExpired || _preselectApplied) return;
    final expiredIds = items
        .where((item) => item.eligible && (item.daysToExpiry ?? 1) < 0)
        .map((item) => item.id)
        .toSet();
    if (expiredIds.isEmpty) {
      _preselectApplied = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedDocuments.addAll(expiredIds);
        _preselectApplied = true;
      });
    });
  }

  /// Renewable insurance policies for the chosen vehicle, offered as add-ons so
  /// they ride in the same order under one delivery fee. Only shown when the
  /// insurance method is agent-fulfilled (`mergeable`) — automated insurance is
  /// instant and stays a separate action (per-policy Renew button).
  Widget _insuranceSection() {
    if (!_insuranceMergeable) return const SizedBox.shrink();
    final policies = _renewablePolicies();
    if (policies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.forest700,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_moon_outlined, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Renew insurance in the same order',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Text(
                'One delivery fee',
                style: TextStyle(color: Color(0xFFBBD8CD), fontSize: 10),
              ),
            ],
          ),
        ),
        ...policies.map(
          (policy) => _InsuranceChoice(
            policy: policy,
            selected: _selectedInsurancePolicies.contains(policy.id),
            onChanged: (selected) => setState(() {
              selected
                  ? _selectedInsurancePolicies.add(policy.id)
                  : _selectedInsurancePolicies.remove(policy.id);
              _quote = null;
              _error = null;
            }),
          ),
        ),
      ],
    );
  }

  /// True when insurance is agent-fulfilled, so a physical certificate can share
  /// the documents order's single delivery. Defaults to true while the method is
  /// loading (agent is the common default); the send guards re-check before use.
  bool get _insuranceMergeable {
    final automated = ref.watch(insuranceAutomatedProvider).asData?.value;
    return automated != true;
  }

  List<InsurancePolicy> _renewablePolicies() {
    final data = ref.watch(vehicleInsuranceProvider(_vehicleId)).asData?.value;
    if (data == null) return const [];
    return data.policies
        .where((policy) => policy.canRenew)
        .toList(growable: false);
  }

  /// Insurance ids to send, guarded so nothing rides along when the method is
  /// not mergeable (avoids a 422 from the automated-insurance path). Uses
  /// `ref.read` — invoked from async submit/quote handlers, not during build.
  List<String> _insuranceIdsToSend() {
    final automated = ref.read(insuranceAutomatedProvider).asData?.value;
    if (automated == true) return const [];
    final data = ref.read(vehicleInsuranceProvider(_vehicleId)).asData?.value;
    final renewable =
        data?.policies.where((p) => p.canRenew).map((p) => p.id).toSet() ??
        const <String>{};
    return _selectedInsurancePolicies
        .where(renewable.contains)
        .toList(growable: false);
  }

  Widget _fulfilmentStep(
    AsyncValue<List<RenewalServiceCity>> cities,
    VehicleSummary? vehicle,
  ) {
    return _StageCard(
      key: const ValueKey('fulfilment'),
      eyebrow: 'STEP 3',
      title: _quote == null ? 'Choose handover' : 'Review and pay',
      description: _quote == null
          ? 'The server adds one delivery fee for the complete order—not one fee per paper.'
          : 'Review the server-calculated breakdown before submitting.',
      child: _quote == null
          ? _fulfilmentForm(cities)
          : _quoteReview(_quote!, vehicle),
    );
  }

  Widget _fulfilmentForm(AsyncValue<List<RenewalServiceCity>> cities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MethodCard(
                icon: Icons.local_shipping_outlined,
                title: 'Door-to-door',
                detail: 'A rider delivers the complete sealed order.',
                selected: _deliveryMethod == 'DELIVERY',
                onTap: () => setState(() {
                  _deliveryMethod = 'DELIVERY';
                  _quote = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MethodCard(
                icon: Icons.storefront_outlined,
                title: 'Pickup',
                detail: 'Collect the complete order from the agent.',
                selected: _deliveryMethod == 'PICKUP',
                onTap: () => setState(() {
                  _deliveryMethod = 'PICKUP';
                  _quote = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        cities.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (error, _) => _InlineFailure(
            message: error is ApiFailure
                ? error.message
                : 'Covered cities could not be loaded.',
            onRetry: () => ref.invalidate(renewalServiceCitiesProvider),
          ),
          data: (items) => DropdownButtonFormField<String>(
            initialValue: items.any((item) => item.city == _city)
                ? _city
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Service city',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem(
                    value: item.city,
                    child: Text('${item.city}, ${item.state}'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              final match = items
                  .where((item) => item.city == value)
                  .firstOrNull;
              setState(() {
                _city = match?.city ?? '';
                _state = match?.state ?? '';
                _quote = null;
                _error = null;
              });
            },
          ),
        ),
        if (_deliveryMethod == 'DELIVERY') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Delivery address',
              prefixIcon: Icon(Icons.home_outlined),
              alignLabelWithHint: true,
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _notes,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 500,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            prefixIcon: Icon(Icons.notes_rounded),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _step = 2;
                  _error = null;
                }),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _quoting ? null : _requestQuote,
                icon: _quoting
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.receipt_long_outlined),
                label: Text(_quoting ? 'Calculating…' : 'Get exact quote'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quoteReview(RenewalQuote quote, VehicleSummary? vehicle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.forest950,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ORDER TOTAL',
                style: TextStyle(
                  color: Color(0xFFBBD8CD),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₦${_money(quote.totalNaira)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${vehicle?.displayName ?? 'Vehicle'} · ${quote.itemCount} item${quote.itemCount == 1 ? '' : 's'}',
                style: const TextStyle(color: Color(0xFFBBD8CD), fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...quote.items.map(
          (item) => _PriceLine(
            label: item.name,
            value: '₦${_money(item.priceNaira)}',
            error: item.eligible ? null : item.reason,
          ),
        ),
        ...quote.insuranceItems.map(
          (item) => _PriceLine(
            label: item.label,
            value: '₦${_money(item.priceNaira)}',
            error: item.eligible ? null : item.reason,
          ),
        ),
        _PriceLine(
          label: _deliveryMethod == 'DELIVERY'
              ? 'Door-to-door delivery'
              : 'Pickup',
          value: '₦${_money(quote.deliveryFeeNaira)}',
        ),
        const Divider(height: 22),
        _PriceLine(
          label: 'Total due',
          value: '₦${_money(quote.totalNaira)}',
          strong: true,
        ),
        _PriceLine(
          label: 'Wallet available',
          value: '₦${_money(quote.walletBalanceNaira)}',
        ),
        if (!quote.sufficientBalance) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.orangeDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your wallet is short by ₦${_money(quote.shortfallNaira)}. Fund only the shortfall, then return for a fresh quote.',
                    style: const TextStyle(
                      color: AppColors.orangeDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                        _quote = null;
                        _error = null;
                      }),
                child: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              // Gate purely on wallet balance, matching the web wizard — the
              // selection step already only lets eligible items be checked,
              // so by the quote step everything picked was eligible; the
              // backend re-validates on submit regardless.
              child: quote.sufficientBalance
                  ? FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                      ),
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.lock_outline_rounded),
                      label: Text(
                        _submitting
                            ? 'Submitting…'
                            : 'Pay ₦${_money(quote.totalNaira)}',
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _fundShortfall,
                      icon: const Icon(Icons.add_card_rounded),
                      label: Text('Fund ₦${_money(quote.shortfallNaira)}'),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _requestQuote() async {
    if (_city.isEmpty || _state.isEmpty) {
      setState(() => _error = 'Select a covered service city.');
      return;
    }
    if (_deliveryMethod == 'DELIVERY' && _address.text.trim().isEmpty) {
      setState(() => _error = 'Enter the door-to-door delivery address.');
      return;
    }
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final quote = await ref
          .read(renewalRepositoryProvider)
          .quote(
            vehicleId: _vehicleId,
            documentTypeIds: _selectedDocuments.toList(growable: false),
            state: _state,
            deliveryMethod: _deliveryMethod,
            city: _city,
            insuranceRenewPolicyIds: _insuranceIdsToSend(),
          );
      if (mounted) setState(() => _quote = quote);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(renewalRepositoryProvider)
          .create(
            vehicleId: _vehicleId,
            documentTypeIds: _selectedDocuments.toList(growable: false),
            deliveryMethod: _deliveryMethod,
            city: _city,
            state: _state,
            address: _address.text,
            notes: _notes.text,
            insuranceRenewPolicyIds: _insuranceIdsToSend(),
          );
      ref.invalidate(renewalOrdersProvider);
      ref.invalidate(garageProvider);
      ref.invalidate(walletWorkspaceProvider);
      ref.invalidate(vehicleInsuranceProvider(_vehicleId));
      if (!mounted) return;
      if (created.orderGroupId.isEmpty) {
        context.go('/more/renewals');
      } else {
        context.go('/more/renewals/orders/${created.orderGroupId}');
      }
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.message);
      if (failure.statusCode == 402 || failure.details['needs_topup'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your wallet balance changed. Fund the shortfall, then request a fresh quote.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _fundShortfall() async {
    await context.push('/more/transactions');
    if (!mounted) return;
    setState(() {
      _quote = null;
      _error = null;
    });
    await _requestQuote();
  }

  Future<void> _openVehicleDocuments(VehicleSummary? vehicle) async {
    final id = vehicle?.id ?? _vehicleId;
    if (id.isEmpty) return;
    await context.push('/vehicles/$id?tab=documents');
    ref.invalidate(renewableDocumentsProvider(id));
  }

  VehicleSummary? _findVehicle(List<VehicleSummary> vehicles, String id) {
    for (final vehicle in vehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }
}

class _RenewalIntro extends StatelessWidget {
  const _RenewalIntro({required this.vehicle});

  final VehicleSummary? vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forest950, AppColors.forest700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.event_repeat_rounded,
              color: AppColors.orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'One order. Every selected paper.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vehicle == null
                      ? 'Choose a vehicle to begin the eligibility check.'
                      : '${vehicle!.displayName} · ${vehicle!.plateNumber ?? 'No plate'}',
                  style: const TextStyle(
                    color: Color(0xFFBBD8CD),
                    fontSize: 11,
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

class _StepRail extends StatelessWidget {
  const _StepRail({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    const labels = ['Vehicle', 'Papers', 'Review'];
    return Row(
      children: List.generate(labels.length, (index) {
        final number = index + 1;
        final active = number <= current;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.forest700 : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? AppColors.forest700 : AppColors.border,
                  ),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: active ? AppColors.ink : AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (index < labels.length - 1)
                Container(
                  width: 10,
                  height: 1,
                  color: active ? AppColors.forest600 : AppColors.border,
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppColors.orange,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _VehicleChoice extends StatelessWidget {
  const _VehicleChoice({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final VehicleSummary vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: selected ? AppColors.forest50 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: selected ? AppColors.forest600 : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: selected
                      ? AppColors.forest700
                      : AppColors.forest100,
                  foregroundColor: selected
                      ? Colors.white
                      : AppColors.forest700,
                  child: const Icon(Icons.directions_car_outlined),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${vehicle.plateNumber ?? 'No plate'} · ${vehicle.statusLabel ?? 'Papers not added'}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? AppColors.forest700 : AppColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentChoice extends StatelessWidget {
  const _DocumentChoice({
    required this.document,
    required this.selected,
    required this.onChanged,
    required this.onUpload,
  });

  final RenewableDocumentOption document;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final days = document.daysToExpiry;
    final urgency = days == null
        ? 'Expiry unavailable'
        : days < 0
        ? '${days.abs()} days expired'
        : days == 0
        ? 'Expires today'
        : '$days days remaining';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.forest50
            : document.eligible
            ? Colors.white
            : const Color(0xFFF4F5F4),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected ? AppColors.forest600 : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: onChanged == null
                    ? null
                    : (value) => onChanged!(value == true),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      style: TextStyle(
                        color: document.eligible
                            ? AppColors.ink
                            : AppColors.muted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      urgency,
                      style: TextStyle(
                        color: (days ?? 1) <= 0
                            ? AppColors.danger
                            : AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'From ₦${_money(document.renewalCostNaira)}',
                style: const TextStyle(
                  color: AppColors.forest700,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (!document.eligible && document.reason != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: document.needsUpload
                    ? AppColors.orangeSoft
                    : const Color(0xFFECEFED),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.reason!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                  if (onUpload != null) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: onUpload,
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      label: const Text('Add current paper'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsuranceChoice extends StatelessWidget {
  const _InsuranceChoice({
    required this.policy,
    required this.selected,
    required this.onChanged,
  });

  final InsurancePolicy policy;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final days = policy.daysToExpiry;
    final urgency = policy.isExpired
        ? (days != null ? '${days.abs()} days expired' : 'Expired')
        : days == null
        ? 'Expiry unavailable'
        : days == 0
        ? 'Expires today'
        : '$days days remaining';
    final title = policy.provider ?? policy.coverageLabel ?? 'Insurance policy';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected ? AppColors.forest50 : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected ? AppColors.forest600 : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            onChanged: (value) => onChanged(value == true),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (policy.coverageLabel != null) ...[
                      Text(
                        policy.coverageLabel!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        '  ·  ',
                        style: TextStyle(color: AppColors.muted, fontSize: 10),
                      ),
                    ],
                    Text(
                      urgency,
                      style: TextStyle(
                        color: (days ?? 1) <= 0
                            ? AppColors.danger
                            : AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (policy.isVerified)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.verified_user_rounded,
                color: AppColors.forest700,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.forest50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: selected ? AppColors.forest600 : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.forest700 : AppColors.muted,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 9,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.error,
    this.strong = false,
  });

  final String label;
  final String value;
  final String? error;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: strong ? 13 : 11,
                    fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: strong ? AppColors.forest700 : AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (error != null)
            Text(
              error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 9),
            ),
        ],
      ),
    );
  }
}

class _NoVehicleState extends StatelessWidget {
  const _NoVehicleState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_outlined, size: 46),
            const SizedBox(height: 12),
            const Text(
              'Add a vehicle before renewing papers.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => context.go('/vehicles/add-existing'),
              child: const Text('Add vehicle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDocuments extends StatelessWidget {
  const _EmptyDocuments();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 38, color: AppColors.muted),
          SizedBox(height: 9),
          Text('No renewable paper types apply to this vehicle.'),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

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
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
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

class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

String _money(String value) {
  final raw = value.replaceAll(',', '');
  final parts = raw.split('.');
  final whole = int.tryParse(parts.first) ?? 0;
  final digits = whole.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final decimal = parts.length > 1
      ? parts[1].padRight(2, '0').substring(0, 2)
      : '00';
  return '${whole < 0 ? '-' : ''}$buffer.$decimal';
}

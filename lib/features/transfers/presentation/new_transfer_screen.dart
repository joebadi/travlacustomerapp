import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/transfers/data/transfer_repository.dart';
import 'package:travla_customer_app/features/transfers/domain/transfer_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_detail_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';

class NewTransferScreen extends ConsumerStatefulWidget {
  const NewTransferScreen({required this.vehicleId, super.key});
  final String vehicleId;
  @override
  ConsumerState<NewTransferScreen> createState() => _NewTransferScreenState();
}

class _NewTransferScreenState extends ConsumerState<NewTransferScreen> {
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nin = TextEditingController();
  final _saleValue = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  int _step = 1;
  String _basis = '';
  String _paymentMode = 'BANK_TRANSFER';
  String _delivery = 'PICKUP';
  TransferCity? _city;
  DateTime? _saleDate;
  TransferRecipientMatch? _match;
  TransferReadiness? _readiness;
  bool _lookingUp = false;
  bool _checking = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _phone,
      _email,
      _firstName,
      _lastName,
      _nin,
      _saleValue,
      _address,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(vehicleDetailProvider(widget.vehicleId));
    final setup = ref.watch(transferSetupProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer ownership')),
      body: vehicle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: error is ApiFailure
              ? error.message
              : 'The vehicle could not be loaded.',
          onRetry: () =>
              ref.invalidate(vehicleDetailProvider(widget.vehicleId)),
        ),
        data: (selected) => setup.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorView(
            message: error is ApiFailure
                ? error.message
                : 'Transfer settings could not be loaded.',
            onRetry: () => ref.invalidate(transferSetupProvider),
          ),
          data: (config) => _flow(selected, config),
        ),
      ),
    );
  }

  Widget _flow(VehicleDetail vehicle, TransferSetup setup) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 34),
    children: [
      _TransferHero(vehicle: vehicle),
      const SizedBox(height: 12),
      _TransferStepper(step: _step),
      if (_error != null) ...[
        const SizedBox(height: 12),
        _TransferAlert(message: _error!),
      ],
      const SizedBox(height: 12),
      if (_step == 1) _basisStep(vehicle),
      if (_step == 2) _recipientStep(vehicle, setup),
      if (_step == 3) _reviewStep(vehicle),
    ],
  );

  Widget _basisStep(VehicleDetail vehicle) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TransferHeading(
            number: '01',
            title: 'Why is ownership changing?',
            body:
                'The basis determines the legal documents Travla’s agent prepares. Choose deliberately; Sale is never selected by default.',
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            initialValue: _basis.isEmpty ? null : _basis,
            decoration: const InputDecoration(
              labelText: 'Reason for ownership change',
            ),
            items: const [
              DropdownMenuItem(value: 'SALE', child: Text('Sale')),
              DropdownMenuItem(value: 'GIFT', child: Text('Gift')),
              DropdownMenuItem(
                value: 'INHERITANCE',
                child: Text('Inheritance'),
              ),
              DropdownMenuItem(
                value: 'COMPANY_TRANSFER',
                child: Text('Company reassignment'),
              ),
              DropdownMenuItem(value: 'OTHER', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _basis = value ?? ''),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.forest50,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.forest700),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Travla-managed path: an agent prepares the legal pack, then a manager verifies it before the recipient receives a consent code. Entering the code completes the approved ownership move.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _basis.isEmpty
                  ? null
                  : () {
                      setState(() => _step = 2);
                      _refreshReadiness();
                    },
              child: const Text('Continue with this vehicle'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _recipientStep(VehicleDetail vehicle, TransferSetup setup) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TransferHeading(
            number: '02',
            title: 'Recipient and handover',
            body:
                'Enter the phone first. Travla checks for one matching account before other identity fields are exposed.',
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _phone,
            enabled: _match == null,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Recipient phone number',
              hintText: '0803 123 4567',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 10),
          if (_match == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _lookingUp ? null : _lookupPhone,
                icon: _lookingUp
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(
                  _lookingUp ? 'Checking Travla…' : 'Check phone number',
                ),
              ),
            ),
          if (_match != null) ...[
            const SizedBox(height: 12),
            _MatchBanner(match: _match!, onReset: _resetRecipient),
            const SizedBox(height: 12),
            if (!_match!.matched) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Recipient email'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _lookingUp ? null : _lookupEmail,
                  child: const Text('Check email and continue'),
                ),
              ),
            ] else ...[
              TextField(
                controller: _email,
                enabled: false,
                decoration: const InputDecoration(labelText: 'Recipient email'),
              ),
            ],
            if (_match!.matched || _email.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstName,
                      enabled: !_match!.matched,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      controller: _lastName,
                      enabled: !_match!.matched,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_match!.ninOnFile)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.forest50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Recipient NIN is securely on file. It remains hidden from the sender.',
                    style: TextStyle(color: AppColors.forest700, fontSize: 10),
                  ),
                )
              else
                TextField(
                  controller: _nin,
                  keyboardType: TextInputType.number,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    labelText: 'Recipient NIN · required',
                    counterText: '',
                  ),
                ),
              if (_basis == 'SALE') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickSaleDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _saleDate == null
                        ? 'Select sale date'
                        : 'Sale date: ${_date(_saleDate!)}',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _saleValue,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sale value',
                    prefixText: '₦ ',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMode,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'BANK_TRANSFER',
                      child: Text('Bank transfer'),
                    ),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'FINANCING',
                      child: Text('Financing'),
                    ),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => _paymentMode = value!),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<TransferCity>(
                initialValue: _city,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Processing jurisdiction',
                ),
                items: setup.cities
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text('${item.city}, ${item.state}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  setState(() => _city = value);
                  _refreshReadiness();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DeliveryChoice(
                      label: 'Office pickup',
                      selected: _delivery == 'PICKUP',
                      onTap: () {
                        setState(() => _delivery = 'PICKUP');
                        _refreshReadiness();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DeliveryChoice(
                      label: 'Doorstep delivery',
                      selected: _delivery == 'DELIVERY',
                      onTap: () {
                        setState(() => _delivery = 'DELIVERY');
                        _refreshReadiness();
                      },
                    ),
                  ),
                ],
              ),
              if (_delivery == 'DELIVERY') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Delivery address',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Additional context · optional',
                ),
              ),
              const SizedBox(height: 13),
              if (_checking) const LinearProgressIndicator(),
              if (_readiness != null)
                _ReadinessPanel(
                  readiness: _readiness!,
                  onDocuments: () =>
                      context.push('/vehicles/${vehicle.id}?tab=documents'),
                ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step = 1),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canReview
                          ? () => setState(() => _step = 3)
                          : null,
                      child: const Text('Review fees'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    ),
  );

  Widget _reviewStep(VehicleDetail vehicle) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TransferHeading(
            number: '03',
            title: 'Review and submit',
            body:
                'The transfer fee is paid from your Travla wallet. The recipient is contacted only after manager approval.',
          ),
          const SizedBox(height: 15),
          _ReviewLine('Vehicle', vehicle.displayName),
          _ReviewLine('Recipient', '${_firstName.text} ${_lastName.text}'),
          _ReviewLine('Basis', _pretty(_basis)),
          _ReviewLine('Jurisdiction', '${_city!.city}, ${_city!.state}'),
          _ReviewLine('Processing fee', '₦${_readiness!.processingFeeNaira}'),
          if (_readiness!.deliveryFeeNaira != '0.00')
            _ReviewLine(
              'Doorstep delivery',
              '₦${_readiness!.deliveryFeeNaira}',
            ),
          _ReviewLine('Total', '₦${_readiness!.totalFeeNaira}', strong: true),
          if (_readiness!.expiredDocuments.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_readiness!.expiredDocuments.length} expired paper(s) will transfer in their current state and remain available for renewal by the recipient.',
                style: const TextStyle(
                  color: AppColors.orangeDark,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.forest950,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Text(
              'Submitting creates the request for agent preparation and manager verification. It does not notify the recipient immediately.',
              style: TextStyle(
                color: Color(0xBBFFFFFF),
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _step = 2),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(
                    _submitting
                        ? 'Submitting…'
                        : _readiness!.totalFeeKobo == 0
                        ? 'Submit request'
                        : 'Pay & submit',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  bool get _canReview =>
      _readiness?.isReady == true &&
      _city != null &&
      _email.text.trim().contains('@') &&
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      (_match?.ninOnFile == true || RegExp(r'^\d{11}$').hasMatch(_nin.text)) &&
      (_basis != 'SALE' ||
          (_saleDate != null &&
              (double.tryParse(_saleValue.text) ?? -1) >= 0)) &&
      (_delivery != 'DELIVERY' || _address.text.trim().length >= 5);

  Future<void> _lookupPhone() async {
    if (_phone.text.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() => _error = 'Enter a valid Nigerian phone number.');
      return;
    }
    await _lookup(email: null);
  }

  Future<void> _lookupEmail() async {
    if (!_email.text.trim().contains('@')) {
      setState(() => _error = 'Enter a valid recipient email.');
      return;
    }
    await _lookup(email: _email.text);
  }

  Future<void> _lookup({String? email}) async {
    setState(() {
      _lookingUp = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(transferRepositoryProvider)
          .lookup(phone: _phone.text, email: email);
      if (!mounted) return;
      setState(() {
        _match = result;
        if (result.email.isNotEmpty) _email.text = result.email;
        if (result.phone.isNotEmpty) _phone.text = result.phone;
        if (result.matched) {
          _firstName.text = result.firstName;
          _lastName.text = result.lastName;
        }
      });
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  void _resetRecipient() {
    setState(() {
      _match = null;
      _email.clear();
      _firstName.clear();
      _lastName.clear();
      _nin.clear();
      _error = null;
    });
  }

  Future<void> _refreshReadiness() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final value = await ref
          .read(transferRepositoryProvider)
          .readiness(
            vehicleId: widget.vehicleId,
            deliveryMethod: _delivery,
            city: _city?.city ?? '',
          );
      if (mounted) setState(() => _readiness = value);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _pickSaleDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: now,
      initialDate: _saleDate ?? now,
    );
    if (value != null) setState(() => _saleDate = value);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(transferRepositoryProvider).create({
        'vehicle_id': widget.vehicleId,
        'transfer_mode': 'MANAGED',
        'transfer_basis': _basis,
        'recipient_first_name': _firstName.text.trim(),
        'recipient_last_name': _lastName.text.trim(),
        'recipient_email': _email.text.trim(),
        'recipient_phone': _phone.text.trim(),
        'recipient_nin': _match?.ninOnFile == true ? '' : _nin.text,
        'collection_city': _city!.city,
        'jurisdiction_state': _city!.state,
        if (_basis == 'SALE') 'transaction_date': _apiDate(_saleDate!),
        if (_basis == 'SALE')
          'transaction_value_naira': double.parse(_saleValue.text),
        if (_basis == 'SALE') 'payment_mode': _paymentMode,
        'delivery_method': _delivery,
        if (_delivery == 'DELIVERY') 'delivery_address': _address.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      ref.invalidate(garageProvider);
      ref.invalidate(vehicleDetailProvider(widget.vehicleId));
      if (mounted) {
        context.go('/vehicles/${widget.vehicleId}');
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.statusCode == 402
              ? '${failure.message} Fund your Travla wallet, then return and submit again.'
              : failure.message;
          _step = 3;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _TransferHero extends StatelessWidget {
  const _TransferHero({required this.vehicle});
  final VehicleDetail vehicle;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.forest950,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.white,
          child: Icon(Icons.swap_horiz_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OWNERSHIP TRANSFER',
                style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                vehicle.displayName,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                vehicle.plateNumber,
                style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TransferStepper extends StatelessWidget {
  const _TransferStepper({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(3, (index) {
      final value = index + 1;
      return Expanded(
        child: Container(
          margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: step == value ? AppColors.forest800 : AppColors.white,
            border: Border.all(
              color: step == value ? AppColors.forest800 : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            value < step ? '✓' : '$value',
            style: TextStyle(
              color: step == value
                  ? AppColors.white
                  : value < step
                  ? AppColors.forest700
                  : AppColors.muted,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }),
  );
}

class _TransferHeading extends StatelessWidget {
  const _TransferHeading({
    required this.number,
    required this.title,
    required this.body,
  });
  final String number;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'STEP $number',
        style: const TextStyle(
          color: AppColors.orangeDark,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 3),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 3),
      Text(
        body,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          height: 1.4,
        ),
      ),
    ],
  );
}

class _MatchBanner extends StatelessWidget {
  const _MatchBanner({required this.match, required this.onReset});
  final TransferRecipientMatch match;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: match.matched ? AppColors.forest50 : AppColors.orangeSoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            match.message,
            style: TextStyle(
              color: match.matched ? AppColors.forest700 : AppColors.orangeDark,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ),
        TextButton(onPressed: onReset, child: const Text('Change')),
      ],
    ),
  );
}

class _DeliveryChoice extends StatelessWidget {
  const _DeliveryChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? AppColors.forest50 : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.forest700 : AppColors.border,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? AppColors.forest700 : AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.readiness, required this.onDocuments});
  final TransferReadiness readiness;
  final VoidCallback onDocuments;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: readiness.isReady ? AppColors.forest50 : const Color(0xFFFFE9E7),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          readiness.isReady
              ? 'Vehicle is ready to transfer'
              : 'Vehicle needs attention',
          style: TextStyle(
            color: readiness.isReady ? AppColors.forest700 : AppColors.danger,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        if (readiness.isReady)
          Text(
            '${readiness.categoryLabel} processing fee · ₦${readiness.totalFeeNaira}',
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          )
        else ...[
          ...readiness.problems.map(
            (item) => Text(
              '• $item',
              style: const TextStyle(color: AppColors.danger, fontSize: 10),
            ),
          ),
          TextButton(
            onPressed: onDocuments,
            child: const Text('Open vehicle documents'),
          ),
        ],
      ],
    ),
  );
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: strong ? 14 : 11,
              fontWeight: FontWeight.w900,
              color: strong ? AppColors.orangeDark : AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TransferAlert extends StatelessWidget {
  const _TransferAlert({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE9E7),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.danger, fontSize: 10),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
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

String _pretty(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
String _apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

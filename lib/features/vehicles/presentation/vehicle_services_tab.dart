import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_service_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_service.dart';

class VehicleServicesTab extends ConsumerWidget {
  const VehicleServicesTab({required this.vehicle, super.key});

  final VehicleDetail vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(vehicleServiceWorkspaceProvider(vehicle.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: workspace.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => _ErrorCard(
          message: error is ApiFailure
              ? error.message
              : 'Vehicle services could not be loaded.',
          onRetry: () =>
              ref.invalidate(vehicleServiceWorkspaceProvider(vehicle.id)),
        ),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ServicesHero(
              vehicle: vehicle,
              serviceCount: data.catalogue.length,
              activeOrders: data.activeOrders,
            ),
            const SizedBox(height: 20),
            const _Heading(
              eyebrow: 'AVAILABLE NOW',
              title: 'Choose a service',
              subtitle: 'Pricing and requirements are shown before checkout.',
            ),
            const SizedBox(height: 11),
            if (data.catalogue.isEmpty)
              const _EmptyCard(
                icon: Icons.home_repair_service_outlined,
                title: 'No services are available',
                body: 'Travla has not enabled vehicle services yet.',
              )
            else
              ...data.catalogue.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ServiceCard(
                    service: service,
                    onTap: () => _openOrderSheet(context, ref, data, service),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _Heading(
              eyebrow: 'SERVICE HISTORY',
              title: 'Orders for this vehicle',
              subtitle: data.orders.isEmpty
                  ? 'Every request and fulfilment update will appear here.'
                  : '${data.orders.length} total · ${data.activeOrders} active',
            ),
            const SizedBox(height: 11),
            if (data.orders.isEmpty)
              const _EmptyCard(
                icon: Icons.receipt_long_outlined,
                title: 'No service orders yet',
                body:
                    'Choose a service above when this vehicle needs attention.',
              )
            else
              ...data.orders.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OrderCard(
                    order: order,
                    onPay: order.canPay
                        ? () => _pay(context, ref, order)
                        : null,
                    onCancel: order.canCancel
                        ? () => _cancel(context, ref, order)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOrderSheet(
    BuildContext context,
    WidgetRef ref,
    VehicleServiceWorkspace workspace,
    VehicleServiceCatalogueItem service,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _OrderServiceSheet(
        vehicle: vehicle,
        service: service,
        cities: workspace.cities,
      ),
    );
    if (saved == true) {
      ref.invalidate(vehicleServiceWorkspaceProvider(vehicle.id));
    }
  }

  Future<void> _pay(
    BuildContext context,
    WidgetRef ref,
    VehicleServiceOrder order,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Pay service quote?',
      body:
          '₦${order.amountDueNaira} will be charged from your Travla wallet for ${order.serviceLabel}.',
      action: 'Pay from wallet',
    );
    if (!confirmed || !context.mounted) return;
    await _runMutation(
      context,
      () => ref.read(vehicleServiceRepositoryProvider).pay(order.id),
      success: 'Service quote paid successfully.',
    );
    ref.invalidate(vehicleServiceWorkspaceProvider(vehicle.id));
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    VehicleServiceOrder order,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Cancel service request?',
      body: '${order.serviceLabel} will be removed from the active queue.',
      action: 'Cancel request',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _runMutation(
      context,
      () => ref.read(vehicleServiceRepositoryProvider).cancel(order.id),
      success: 'Service request cancelled.',
    );
    ref.invalidate(vehicleServiceWorkspaceProvider(vehicle.id));
  }
}

class _OrderServiceSheet extends ConsumerStatefulWidget {
  const _OrderServiceSheet({
    required this.vehicle,
    required this.service,
    required this.cities,
  });

  final VehicleDetail vehicle;
  final VehicleServiceCatalogueItem service;
  final List<VehicleServiceCity> cities;

  @override
  ConsumerState<_OrderServiceSheet> createState() => _OrderServiceSheetState();
}

class _OrderServiceSheetState extends ConsumerState<_OrderServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final Map<String, String> _details = {};
  String _delivery = 'PICKUP';
  VehicleServiceCity? _city;
  DateTime? _preferredDate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = _serviceFields[widget.service.value] ?? const [];
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .94,
        child: Column(
          children: [
            _SheetHeader(service: widget.service),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                  children: [
                    if (_error != null) _InlineError(_error!),
                    if (_error != null) const SizedBox(height: 12),
                    Text(
                      widget.service.isFixedPrice
                          ? 'The service fee is charged from your wallet when you submit. Doorstep delivery may add the configured city fee.'
                          : 'This amount is an estimate. Travla reviews the request and sends the final quote before payment.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                    if (widget.service.requirements.isNotEmpty) ...[
                      const SizedBox(height: 15),
                      _Requirements(items: widget.service.requirements),
                    ],
                    const SizedBox(height: 18),
                    if (widget.service.value == 'RESPRAY') ...[
                      TextFormField(
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Desired colour',
                          prefixIcon: Icon(Icons.palette_outlined),
                        ),
                        onChanged: (value) =>
                            _details['target_colour'] = value.trim(),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter the desired colour.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    ...fields.map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: _details[field.key],
                          decoration: InputDecoration(labelText: field.label),
                          items: field.options
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                  if (value != null) {
                                    _details[field.key] = value;
                                  }
                                }),
                          validator: (value) => value == null
                              ? 'Select ${field.label.toLowerCase()}.'
                              : null,
                        ),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _delivery,
                      decoration: const InputDecoration(
                        labelText: 'Document/vehicle handover',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'PICKUP',
                          child: Text('I will drop off / pick up'),
                        ),
                        DropdownMenuItem(
                          value: 'DELIVERY',
                          child: Text('Come to my address'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _delivery = value!),
                    ),
                    if (_delivery == 'DELIVERY') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        enabled: !_saving,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Collection/delivery address',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) =>
                            _delivery == 'DELIVERY' &&
                                (value == null || value.trim().length < 5)
                            ? 'Enter the full address.'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<VehicleServiceCity>(
                      initialValue: _city,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Service city',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      items: widget.cities
                          .map(
                            (city) => DropdownMenuItem(
                              value: city,
                              child: Text('${city.city}, ${city.state}'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _city = value),
                      validator: (value) => value == null
                          ? 'Select a covered service city.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _preferredDate == null
                            ? 'Choose preferred date · optional'
                            : 'Preferred: ${_date(_preferredDate!)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      enabled: !_saving,
                      maxLength: 2000,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes · optional',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        _saving ? 'Submitting…' : 'Submit service request',
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (value != null) setState(() => _preferredDate = value);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(vehicleServiceRepositoryProvider)
          .create(
            vehicleId: widget.vehicle.id,
            serviceType: widget.service.value,
            details: _details,
            deliveryMethod: _delivery,
            deliveryAddress: _address.text,
            city: _city?.city ?? '',
            state: _city?.state ?? '',
            preferredDate: _preferredDate,
            notes: _notes.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ServicesHero extends StatelessWidget {
  const _ServicesHero({
    required this.vehicle,
    required this.serviceCount,
    required this.activeOrders,
  });
  final VehicleDetail vehicle;
  final int serviceCount;
  final int activeOrders;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.forest950,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VEHICLE CARE DESK',
          style: TextStyle(
            color: AppColors.orange,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Services built around this vehicle.',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppColors.white),
        ),
        const SizedBox(height: 6),
        Text(
          'Order for ${vehicle.displayName}, understand the fee and follow fulfilment from one place.',
          style: const TextStyle(
            color: Color(0xAFFFFFFF),
            fontSize: 11,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _HeroMetric(value: serviceCount, label: 'Services'),
            const SizedBox(width: 8),
            _HeroMetric(value: activeOrders, label: 'Active orders'),
          ],
        ),
      ],
    ),
  );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0x77FFFFFF),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: AppColors.orangeDark,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
      const SizedBox(height: 3),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted, fontSize: 10),
      ),
    ],
  );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});
  final VehicleServiceCatalogueItem service;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _serviceIcon(service.value),
                color: AppColors.orangeDark,
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
                          service.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.forest50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          service.isFixedPrice ? 'FIXED' : 'QUOTED',
                          style: const TextStyle(
                            color: AppColors.forest700,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (service.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      service.description,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        service.isFixedPrice
                            ? '₦${service.estimatedPriceNaira}'
                            : 'From ₦${service.estimatedPriceNaira}',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Order',
                        style: TextStyle(
                          color: AppColors.orangeDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.orangeDark,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.onPay, this.onCancel});
  final VehicleServiceOrder order;
  final VoidCallback? onPay;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) {
    final color = order.status == 'COMPLETED'
        ? AppColors.forest700
        : order.status == 'REJECTED' || order.status == 'CANCELLED'
        ? AppColors.muted
        : AppColors.orange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.serviceLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusPill(label: order.statusLabel, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.quotedPriceNaira != null
                  ? 'Quote ₦${order.quotedPriceNaira}'
                  : '${order.isFixedPrice ? 'Fee' : 'Estimate'} ₦${order.estimatedPriceNaira}',
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
            if (order.trackingNumber != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tracking ${order.trackingNumber}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 9),
                ),
              ),
            if (order.adminNote?.isNotEmpty == true)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Travla note: ${order.adminNote}',
                  style: const TextStyle(
                    color: AppColors.orangeDark,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),
            if (onPay != null || onCancel != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                  if (onPay != null)
                    FilledButton(
                      onPressed: onPay,
                      child: Text('Pay ₦${order.amountDueNaira}'),
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

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.service});
  final VehicleServiceCatalogueItem service;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
    child: Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_serviceIcon(service.value), color: AppColors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEW SERVICE REQUEST',
                style: TextStyle(
                  color: AppColors.orangeDark,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              Text(
                service.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${service.isFixedPrice ? 'Service fee' : 'Starting estimate'} · ₦${service.estimatedPriceNaira}',
                style: const TextStyle(color: AppColors.muted, fontSize: 9),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _Requirements extends StatelessWidget {
  const _Requirements({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.forest50,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BEFORE YOU SUBMIT',
          style: TextStyle(
            color: AppColors.forest700,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 7),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.forest700,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _EmptyCard(
    icon: Icons.cloud_off_outlined,
    title: 'Services unavailable',
    body: message,
    action: onRetry,
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: action, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}

class _ServiceField {
  const _ServiceField(this.key, this.label, this.options);
  final String key;
  final String label;
  final List<String> options;
}

const _serviceFields = <String, List<_ServiceField>>{
  'PLATE_REPRINT': [
    _ServiceField('reason', 'Reason', [
      'Faded plate',
      'Damaged plate',
      'Lost/stolen plate',
      'New plate',
    ]),
    _ServiceField('plate_type', 'Plate type', ['Standard', 'Customised']),
  ],
  'RESPRAY': [
    _ServiceField('scope', 'Scope', [
      'Full body',
      'Part / panel only',
      'Touch-up',
    ]),
  ],
  'WINDOW_TINT': [
    _ServiceField('tint_level', 'Tint level', ['Light', 'Medium', 'Dark']),
    _ServiceField('windows', 'Windows', [
      'All windows',
      'Front only',
      'Rear only',
    ]),
  ],
  'TRACKER_INSTALL': [
    _ServiceField('tracker_type', 'Tracker type', [
      'Basic GPS tracker',
      'GPS + remote engine cut-off',
      'Not sure — advise me',
    ]),
  ],
};

IconData _serviceIcon(String type) => switch (type) {
  'PLATE_REPRINT' => Icons.pin_outlined,
  'RESPRAY' => Icons.format_paint_outlined,
  'WINDOW_TINT' => Icons.gradient_outlined,
  'TRACKER_INSTALL' => Icons.location_on_outlined,
  _ => Icons.home_repair_service_outlined,
};

String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Go back'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

Future<void> _runMutation(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  try {
    await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: AppColors.forest800),
      );
    }
  } on ApiFailure catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

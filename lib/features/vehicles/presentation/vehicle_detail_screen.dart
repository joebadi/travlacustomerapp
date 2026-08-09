import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_detail_repository.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_service_repository.dart';
import 'package:travla_customer_app/features/vehicles/data/vehicle_tracking_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/vehicle_detail.dart';
import 'package:travla_customer_app/features/vehicles/presentation/add_vehicle_document_sheet.dart';
import 'package:travla_customer_app/features/vehicles/presentation/edit_vehicle_sheet.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicle_services_tab.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicle_tracking_tab.dart';
import 'package:url_launcher/url_launcher.dart';

enum VehicleDetailTab { overview, documents, tracking, services }

class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({
    required this.vehicleId,
    this.initialTab = VehicleDetailTab.overview,
    super.key,
  });

  final String vehicleId;
  final VehicleDetailTab initialTab;

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  late VehicleDetailTab _tab;
  final _scrollController = ScrollController();
  final _tabContentKey = GlobalKey();
  int _imageIndex = 0;
  final Set<String> _mutatingDocuments = {};

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(vehicleDetailProvider(widget.vehicleId));
    final vehicle = detail.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle details'),
        actions: [
          if (vehicle != null)
            IconButton(
              tooltip: 'Edit vehicle',
              onPressed: () => _editVehicle(vehicle),
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: detail.when(
        loading: () => const _VehicleDetailLoading(),
        error: (error, stackTrace) => _VehicleDetailError(
          message: error is ApiFailure
              ? error.message
              : 'This vehicle could not be loaded.',
          onRetry: _refresh,
        ),
        data: (vehicle) => RefreshIndicator(
          color: AppColors.forest700,
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 38),
            children: [
              _VehicleHero(
                vehicle: vehicle,
                imageIndex: _imageIndex,
                onImageChanged: (index) => setState(() => _imageIndex = index),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _DetailTabSelector(
                  selected: _tab,
                  documentCount: vehicle.documents.length,
                  onChanged: _selectTab,
                ),
              ),
              KeyedSubtree(key: _tabContentKey, child: _activeTab(vehicle)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeTab(VehicleDetail vehicle) {
    return switch (_tab) {
      VehicleDetailTab.overview => _OverviewTab(
        key: const ValueKey('overview'),
        vehicle: vehicle,
        onOpenDocuments: () => _selectTab(VehicleDetailTab.documents),
        onSell: () =>
            context.push('/more/marketplace/list-new?vehicle=${vehicle.id}'),
        onTransfer: () =>
            context.push('/more/transfers/new?vehicle=${vehicle.id}'),
      ),
      VehicleDetailTab.documents => _DocumentsTab(
        key: const ValueKey('documents'),
        vehicle: vehicle,
        mutatingDocuments: _mutatingDocuments,
        onAdd: _addDocument,
        onView: (document) => _showDocumentDetails(vehicle, document),
        onAutoRenew: (document, enabled) => _setAutoRenew(document, enabled),
        onDelete: _deleteDocument,
      ),
      VehicleDetailTab.tracking => VehicleTrackingTab(
        key: const ValueKey('tracking'),
        vehicle: vehicle,
        onOrderTracker: () => _selectTab(VehicleDetailTab.services),
      ),
      VehicleDetailTab.services => VehicleServicesTab(
        key: const ValueKey('services'),
        vehicle: vehicle,
      ),
    };
  }

  void _selectTab(VehicleDetailTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tabContentKey.currentContext == null) return;
      Scrollable.ensureVisible(
        _tabContentKey.currentContext!,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0,
      );
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(vehicleDetailProvider(widget.vehicleId));
    ref.invalidate(availableDocumentTypesProvider(widget.vehicleId));
    ref.invalidate(vehicleServiceWorkspaceProvider(widget.vehicleId));
    ref.invalidate(vehicleTrackingWorkspaceProvider(widget.vehicleId));
    await ref.read(vehicleDetailProvider(widget.vehicleId).future);
  }

  Future<void> _editVehicle(VehicleDetail vehicle) async {
    final saved = await showEditVehicleSheet(
      context: context,
      vehicle: vehicle,
    );
    if (saved != true || !mounted) return;

    ref.invalidate(vehicleDetailProvider(widget.vehicleId));
    ref.invalidate(availableDocumentTypesProvider(widget.vehicleId));
    ref.invalidate(garageProvider);
    setState(() => _imageIndex = 0);
    _showMessage('Vehicle details updated.');
  }

  Future<void> _addDocument(DocumentTypeFilter filter) async {
    final saved = await showAddVehicleDocumentSheet(
      context: context,
      vehicleId: widget.vehicleId,
      filter: filter,
    );
    if (saved == true) {
      ref.invalidate(vehicleDetailProvider(widget.vehicleId));
      ref.invalidate(availableDocumentTypesProvider(widget.vehicleId));
      ref.invalidate(garageProvider);
    }
  }

  Future<void> _setAutoRenew(VehicleDocument document, bool enabled) async {
    setState(() => _mutatingDocuments.add(document.id));
    try {
      await ref
          .read(vehicleDetailRepositoryProvider)
          .setAutoRenew(
            vehicleId: widget.vehicleId,
            documentId: document.id,
            enabled: enabled,
          );
      ref.invalidate(vehicleDetailProvider(widget.vehicleId));
    } on ApiFailure catch (failure) {
      if (mounted) _showMessage(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _mutatingDocuments.remove(document.id));
    }
  }

  Future<void> _deleteDocument(VehicleDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove document?'),
        content: Text(
          '${document.name} and its stored file will be removed from this vehicle. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep document'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _mutatingDocuments.add(document.id));
    try {
      await ref
          .read(vehicleDetailRepositoryProvider)
          .deleteDocument(vehicleId: widget.vehicleId, documentId: document.id);
      ref.invalidate(vehicleDetailProvider(widget.vehicleId));
      ref.invalidate(availableDocumentTypesProvider(widget.vehicleId));
      ref.invalidate(garageProvider);
      if (mounted) _showMessage('${document.name} removed.');
    } on ApiFailure catch (failure) {
      if (mounted) _showMessage(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _mutatingDocuments.remove(document.id));
    }
  }

  Future<void> _showDocumentDetails(
    VehicleDetail vehicle,
    VehicleDocument document,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _DocumentDetailsSheet(
        vehicle: vehicle,
        document: document,
        onOpen: _openDocument,
      ),
    );
  }

  Future<void> _openDocument(String? url) async {
    if (url == null || url.isEmpty) {
      _showMessage('No file is attached to this document.', isError: true);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _showMessage(
        'This document link is invalid. Refresh and try again.',
        isError: true,
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage(
        'The document could not be opened. Refresh the vehicle and try again.',
        isError: true,
      );
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.forest800,
      ),
    );
  }
}

class _VehicleHero extends StatelessWidget {
  const _VehicleHero({
    required this.vehicle,
    required this.imageIndex,
    required this.onImageChanged,
  });

  final VehicleDetail vehicle;
  final int imageIndex;
  final ValueChanged<int> onImageChanged;

  @override
  Widget build(BuildContext context) {
    final status = _VehicleStatusStyle.from(vehicle.status);

    return Container(
      color: AppColors.forest950,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 216,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (vehicle.images.isEmpty)
                  const _HeroFallback()
                else
                  PageView.builder(
                    itemCount: vehicle.images.length,
                    onPageChanged: onImageChanged,
                    itemBuilder: (context, index) => Image.network(
                      vehicle.images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _HeroFallback(),
                    ),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC021B13)],
                      stops: [.38, 1],
                    ),
                  ),
                ),
                if (vehicle.images.length > 1)
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.forest950.withValues(alpha: .76),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        '${imageIndex + 1}/${vehicle.images.length}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.displayName.isEmpty
                                  ? 'Vehicle'
                                  : vehicle.displayName,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(color: AppColors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (vehicle.year != null)
                                  vehicle.year.toString(),
                                if (vehicle.color.isNotEmpty) vehicle.color,
                                vehicle.categoryLabel,
                              ].join(' · '),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .68),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: status.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          vehicle.statusLabel ?? 'Papers not added',
                          style: TextStyle(
                            color: status.foreground,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .15),
                    ),
                  ),
                  child: Text(
                    vehicle.plateNumber.isEmpty
                        ? 'PLATE NOT ASSIGNED'
                        : vehicle.plateNumber,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                const Spacer(),
                if (vehicle.isTinted)
                  const _HeroTag(icon: Icons.blur_on_rounded, label: 'Tinted'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.forest800,
      alignment: Alignment.center,
      child: Icon(
        Icons.directions_car_filled_rounded,
        color: Colors.white.withValues(alpha: .14),
        size: 94,
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTabSelector extends StatelessWidget {
  const _DetailTabSelector({
    required this.selected,
    required this.documentCount,
    required this.onChanged,
  });

  final VehicleDetailTab selected;
  final int documentCount;
  final ValueChanged<VehicleDetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _DetailTabButton(
            label: 'Overview',
            icon: Icons.dashboard_outlined,
            selected: selected == VehicleDetailTab.overview,
            onTap: () => onChanged(VehicleDetailTab.overview),
          ),
          _DetailTabButton(
            label: 'Documents · $documentCount',
            icon: Icons.folder_copy_outlined,
            selected: selected == VehicleDetailTab.documents,
            onTap: () => onChanged(VehicleDetailTab.documents),
          ),
          _DetailTabButton(
            label: 'Tracking',
            icon: Icons.near_me_outlined,
            selected: selected == VehicleDetailTab.tracking,
            onTap: () => onChanged(VehicleDetailTab.tracking),
          ),
          _DetailTabButton(
            label: 'Services',
            icon: Icons.home_repair_service_outlined,
            selected: selected == VehicleDetailTab.services,
            onTap: () => onChanged(VehicleDetailTab.services),
          ),
        ],
      ),
    );
  }
}

class _DetailTabButton extends StatelessWidget {
  const _DetailTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.forest800 : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.forest800 : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.white : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.white : AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.vehicle,
    required this.onOpenDocuments,
    required this.onSell,
    required this.onTransfer,
    super.key,
  });

  final VehicleDetail vehicle;
  final VoidCallback onOpenDocuments;
  final VoidCallback onSell;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final specs = [
      ('Category', vehicle.categoryLabel),
      ('Make', vehicle.make),
      ('Model', vehicle.model),
      ('Year', vehicle.year?.toString() ?? '—'),
      ('Colour', vehicle.color),
      ('VIN / chassis number', vehicle.chassisNumber),
      ('Engine number', vehicle.engineNumber),
      ('Licence plate', vehicle.plateNumber),
      ('Tinted', vehicle.isTinted ? 'Yes' : 'No'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReadinessCard(vehicle: vehicle, onOpenDocuments: onOpenDocuments),
          const SizedBox(height: 14),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onSell,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.orangeSoft,
                      foregroundColor: AppColors.orangeDark,
                      child: Icon(Icons.sell_outlined),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sell on Travla Marketplace',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Check transfer readiness and create a verified listing.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.orangeDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTransfer,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.forest100,
                      foregroundColor: AppColors.forest700,
                      child: Icon(Icons.swap_horiz_rounded),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transfer vehicle ownership',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Preselect this vehicle and check legal readiness.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.forest700,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'The registered identity of this vehicle.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  ...specs.map(
                    (spec) => _SpecRow(label: spec.$1, value: spec.$2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: AppColors.forest950,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onOpenDocuments,
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.folder_copy_outlined,
                        color: AppColors.orange,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Open document vault',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Review renewable papers and permanent records.',
                            style: TextStyle(
                              color: Color(0xAFFFFFFF),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.vehicle, required this.onOpenDocuments});

  final VehicleDetail vehicle;
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    final expired = vehicle.expiredDocumentsCount;
    final expiring = vehicle.expiringSoonCount;
    final valid = vehicle.documents.length - expired - expiring;
    final tone = expired > 0
        ? AppColors.danger
        : expiring > 0
        ? AppColors.orange
        : AppColors.forest700;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: .1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fact_check_outlined, color: tone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.statusLabel ?? 'Papers not added',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${vehicle.documents.length} document${vehicle.documents.length == 1 ? '' : 's'} currently in the vault',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onOpenDocuments,
                  child: const Text('View'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _ReadinessMetric(
                  value: valid.clamp(0, vehicle.documents.length),
                  label: 'Up to date',
                  color: AppColors.forest700,
                ),
                _ReadinessMetric(
                  value: expiring,
                  label: 'Expiring',
                  color: AppColors.orange,
                ),
                _ReadinessMetric(
                  value: expired,
                  label: 'Expired',
                  color: AppColors.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessMetric extends StatelessWidget {
  const _ReadinessMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({
    required this.vehicle,
    required this.mutatingDocuments,
    required this.onAdd,
    required this.onView,
    required this.onAutoRenew,
    required this.onDelete,
    super.key,
  });

  final VehicleDetail vehicle;
  final Set<String> mutatingDocuments;
  final ValueChanged<DocumentTypeFilter> onAdd;
  final ValueChanged<VehicleDocument> onView;
  final void Function(VehicleDocument, bool) onAutoRenew;
  final ValueChanged<VehicleDocument> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!vehicle.hasValidPlateNumber)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFFFC9B7)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.orangeDark),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Document management is unavailable for a dealer or temporary plate. Complete registration and receive a valid plate first.',
                      style: TextStyle(
                        color: AppColors.orangeDark,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle document vault',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Legal papers and permanent records, kept separately.',
                      style: TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (vehicle.hasValidPlateNumber)
                FilledButton.tonalIcon(
                  onPressed: () => onAdd(DocumentTypeFilter.all),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _DocumentSection(
            title: 'Renewable papers',
            description: 'Licence, insurance, permits and roadworthiness.',
            documents: vehicle.renewableDocuments,
            mutatingDocuments: mutatingDocuments,
            onAdd: vehicle.hasValidPlateNumber
                ? () => onAdd(DocumentTypeFilter.renewable)
                : null,
            onView: onView,
            onAutoRenew: onAutoRenew,
            onDelete: onDelete,
          ),
          const SizedBox(height: 14),
          _DocumentSection(
            title: 'Other documents',
            description: 'Proof of ownership and one-time records.',
            documents: vehicle.otherDocuments,
            mutatingDocuments: mutatingDocuments,
            onAdd: vehicle.hasValidPlateNumber
                ? () => onAdd(DocumentTypeFilter.other)
                : null,
            onView: onView,
            onAutoRenew: onAutoRenew,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.title,
    required this.description,
    required this.documents,
    required this.mutatingDocuments,
    required this.onAdd,
    required this.onView,
    required this.onAutoRenew,
    required this.onDelete,
  });

  final String title;
  final String description;
  final List<VehicleDocument> documents;
  final Set<String> mutatingDocuments;
  final VoidCallback? onAdd;
  final ValueChanged<VehicleDocument> onView;
  final void Function(VehicleDocument, bool) onAutoRenew;
  final ValueChanged<VehicleDocument> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 10, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.forest50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${documents.length}',
                    style: const TextStyle(
                      color: AppColors.forest700,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onAdd != null)
                  IconButton(
                    tooltip: 'Add to $title',
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (documents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                children: [
                  const Icon(
                    Icons.folder_open_outlined,
                    color: AppColors.muted,
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No ${title.toLowerCase()} added.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            ...documents.map(
              (document) => _DocumentTile(
                document: document,
                isMutating: mutatingDocuments.contains(document.id),
                onView: () => onView(document),
                onAutoRenew: (enabled) => onAutoRenew(document, enabled),
                onDelete: () => onDelete(document),
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.isMutating,
    required this.onView,
    required this.onAutoRenew,
    required this.onDelete,
  });

  final VehicleDocument document;
  final bool isMutating;
  final VoidCallback onView;
  final ValueChanged<bool> onAutoRenew;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = _DocumentStatusStyle.from(document.status);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: InkWell(
        onTap: isMutating ? null : onView,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: status.foreground,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      document.documentNumber?.isNotEmpty == true
                          ? 'No. ${document.documentNumber}'
                          : document.isRenewable
                          ? 'No document number'
                          : 'On file',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                    if (document.isRenewable) ...[
                      const SizedBox(height: 5),
                      Text(
                        _expiryText(document),
                        style: TextStyle(
                          color: status.foreground,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: isMutating
                            ? null
                            : () => onAutoRenew(!document.autoRenew),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 20,
                                child: Switch(
                                  value: document.autoRenew,
                                  onChanged: isMutating ? null : onAutoRenew,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                document.autoRenew
                                    ? 'Auto-renew on'
                                    : 'Auto-renew off',
                                style: TextStyle(
                                  color: document.autoRenew
                                      ? AppColors.forest700
                                      : AppColors.muted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isMutating)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<String>(
                  tooltip: 'Document actions',
                  onSelected: (action) {
                    if (action == 'view') onView();
                    if (action == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'view',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.visibility_outlined),
                        title: Text('View details'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger,
                        ),
                        title: Text(
                          'Remove document',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentDetailsSheet extends StatelessWidget {
  const _DocumentDetailsSheet({
    required this.vehicle,
    required this.document,
    required this.onOpen,
  });

  final VehicleDetail vehicle;
  final VehicleDocument document;
  final ValueChanged<String?> onOpen;

  @override
  Widget build(BuildContext context) {
    final versions = document.displayVersions;
    final status = _DocumentStatusStyle.from(document.status);

    return FractionallySizedBox(
      heightFactor: .9,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.forest950, AppColors.forest800],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppColors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            document.name,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${vehicle.make} ${vehicle.model} · ${vehicle.plateNumber}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .62),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: status.background,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        document.statusLabel,
                        style: TextStyle(
                          color: status.foreground,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DocumentFact(
                          label: 'Document number',
                          value: document.documentNumber,
                        ),
                        _DocumentFact(
                          label: 'Issued by',
                          value: document.issuingAuthority,
                        ),
                        _DocumentFact(
                          label: 'Issue date',
                          value: _displayApiDate(document.issuedDate),
                        ),
                        if (document.isRenewable)
                          _DocumentFact(
                            label: document.isExpired ? 'Expired' : 'Expires',
                            value: _displayApiDate(document.expiryDate),
                            valueColor: document.isExpired
                                ? AppColors.danger
                                : AppColors.ink,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'DOCUMENT HISTORY',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    Text(
                      '${versions.length} version${versions.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (versions.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.file_present_outlined,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No file has been uploaded for this document.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 204,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: versions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) => _VersionCard(
                        version: versions[index],
                        onOpen: () => onOpen(versions[index].documentUrl),
                      ),
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

class _DocumentFact extends StatelessWidget {
  const _DocumentFact({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String? value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value?.isNotEmpty == true ? value! : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? AppColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.version, required this.onOpen});

  final DocumentVersion version;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 166,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: version.isCurrent ? AppColors.forest600 : AppColors.border,
          width: version.isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.forest50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  version.mimeType?.contains('pdf') == true
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: AppColors.forest700,
                  size: 19,
                ),
              ),
              const Spacer(),
              if (version.isCurrent)
                const _VersionTag(label: 'CURRENT', color: AppColors.forest700),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            version.documentNumber?.isNotEmpty == true
                ? version.documentNumber!
                : version.originalFilename ?? 'Document file',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            version.expiryDate == null
                ? _displayApiDate(version.issuedDate)
                : 'Expires ${_displayApiDate(version.expiryDate)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 9),
          ),
          const Spacer(),
          Row(
            children: [
              if (version.isOriginal)
                const _VersionTag(label: 'ORIGINAL', color: AppColors.ink),
              const Spacer(),
              IconButton.filledTonal(
                tooltip: 'Open secure file',
                onPressed: version.documentUrl?.isNotEmpty == true
                    ? onOpen
                    : null,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VersionTag extends StatelessWidget {
  const _VersionTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VehicleDetailLoading extends StatelessWidget {
  const _VehicleDetailLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Container(height: 280, color: AppColors.forest800),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(
              3,
              (index) => Container(
                height: index == 0 ? 52 : 150,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleDetailError extends StatelessWidget {
  const _VehicleDetailError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_car_outlined,
              color: AppColors.muted,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
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

class _VehicleStatusStyle {
  const _VehicleStatusStyle(this.foreground, this.background);

  final Color foreground;
  final Color background;

  factory _VehicleStatusStyle.from(String? status) {
    return switch (status) {
      'VALID' => const _VehicleStatusStyle(
        AppColors.forest700,
        AppColors.forest100,
      ),
      'EXPIRING_SOON' => const _VehicleStatusStyle(
        AppColors.orangeDark,
        AppColors.orangeSoft,
      ),
      'EXPIRED' => const _VehicleStatusStyle(
        AppColors.danger,
        Color(0xFFFFE9E7),
      ),
      _ => const _VehicleStatusStyle(AppColors.muted, Color(0xFFEEF1F0)),
    };
  }
}

class _DocumentStatusStyle {
  const _DocumentStatusStyle(this.foreground, this.background);

  final Color foreground;
  final Color background;

  factory _DocumentStatusStyle.from(String status) {
    return switch (status) {
      'VALID' => const _DocumentStatusStyle(
        AppColors.forest700,
        AppColors.forest100,
      ),
      'EXPIRING_SOON' => const _DocumentStatusStyle(
        AppColors.orangeDark,
        AppColors.orangeSoft,
      ),
      'EXPIRED' => const _DocumentStatusStyle(
        AppColors.danger,
        Color(0xFFFFE9E7),
      ),
      _ => const _DocumentStatusStyle(AppColors.muted, Color(0xFFEEF1F0)),
    };
  }
}

String _expiryText(VehicleDocument document) {
  final days = document.daysUntilExpiry;
  if (days == null) {
    return document.expiryDate == null
        ? document.statusLabel
        : 'Expires ${_displayApiDate(document.expiryDate)}';
  }
  if (days < 0) {
    final value = days.abs();
    return 'Expired $value day${value == 1 ? '' : 's'} ago';
  }
  if (days == 0) return 'Expires today';
  return 'Expires in $days day${days == 1 ? '' : 's'}';
}

String _displayApiDate(String? value) {
  final date = parseDateOnly(value);
  if (date == null) return '—';
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

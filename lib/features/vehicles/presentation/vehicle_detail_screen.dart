import 'dart:async';

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
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/presentation/vehicle_insurance_tab.dart';
import 'package:travla_customer_app/features/checkpoint/data/checkpoint_repository.dart';
import 'package:travla_customer_app/features/checkpoint/presentation/vehicle_checkpoint_tab.dart';
import 'package:travla_customer_app/features/vehicles/presentation/document_viewer_screen.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicle_quick_actions.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicle_services_tab.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicle_tracking_tab.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';
import 'package:url_launcher/url_launcher.dart';

enum VehicleDetailTab {
  overview,
  documents,
  insurance,
  checkpoint,
  tracking,
  services,
}

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
  // A fresh GlobalKey per tab switch — never reused across the differently
  // shaped subtrees each tab renders, so there is no possibility of stale
  // element/layout state carrying over between tabs.
  GlobalKey _tabContentKey = GlobalKey();
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
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 2),
          child: TravlaLogo(width: 106),
        ),
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
              _DetailTabSelector(
                selected: _tab,
                documentCount: vehicle.documents.length,
                onChanged: _selectTab,
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
      VehicleDetailTab.insurance => VehicleInsuranceTab(
        key: const ValueKey('insurance'),
        vehicleId: vehicle.id,
      ),
      VehicleDetailTab.checkpoint => VehicleCheckpointTab(
        key: const ValueKey('checkpoint'),
        vehicleId: vehicle.id,
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
    setState(() {
      _tab = tab;
      _tabContentKey = GlobalKey();
    });
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
    ref.invalidate(vehicleInsuranceProvider(widget.vehicleId));
    ref.invalidate(checkpointProvider(widget.vehicleId));
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

  void _openDocument(DocumentVersion version) {
    final url = version.documentUrl;
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          url: url,
          title: version.originalFilename?.isNotEmpty == true
              ? version.originalFilename!
              : 'Document',
          mimeType: version.mimeType,
        ),
      ),
    );
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
                          vehicle.status == 'EXPIRED'
                              ? '${vehicle.expiredDocumentsCount} Expired'
                              : vehicle.statusLabel ?? 'Papers not added',
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _DetailTabButton(
              label: 'Overview',
              icon: Icons.dashboard_outlined,
              selected: selected == VehicleDetailTab.overview,
              onTap: () => onChanged(VehicleDetailTab.overview),
            ),
            _DetailTabButton(
              label: 'Documents',
              icon: Icons.folder_copy_outlined,
              badge: documentCount,
              selected: selected == VehicleDetailTab.documents,
              onTap: () => onChanged(VehicleDetailTab.documents),
            ),
            _DetailTabButton(
              label: 'Insurance',
              icon: Icons.shield_outlined,
              selected: selected == VehicleDetailTab.insurance,
              onTap: () => onChanged(VehicleDetailTab.insurance),
            ),
            _DetailTabButton(
              label: 'Checkpoint',
              icon: Icons.qr_code_2_rounded,
              selected: selected == VehicleDetailTab.checkpoint,
              onTap: () => onChanged(VehicleDetailTab.checkpoint),
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
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.forest700 : AppColors.muted;
    return SizedBox(
      width: 86,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.forest700 : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 20, color: color),
                  if (badge != null && badge! > 0)
                    Positioned(
                      right: -11,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.forest700
                              : AppColors.muted,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${badge!}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
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
  const _OverviewTab({required this.vehicle, super.key});

  final VehicleDetail vehicle;

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
          const SizedBox(height: 22),
          VehicleQuickActions(vehicleId: vehicle.id),
          const SizedBox(height: 16),
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

/// Documents tab — mirrors the web's `DocumentsTab`: a summary header with a
/// direct "Renew N expired" action, then Renewable / Other document sections.
/// Rebuilt with an intrinsic, unclamped tile layout so nothing can overflow
/// regardless of text length or system font scale.
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
    final expiredCount = vehicle.renewableDocuments
        .where((d) => d.isExpired)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _DocumentsSummaryCard(
            vehicleId: vehicle.id,
            hasValidPlate: vehicle.hasValidPlateNumber,
            expiredCount: expiredCount,
            onAddAny: () => onAdd(DocumentTypeFilter.renewable),
          ),
          const SizedBox(height: 14),
          if (vehicle.documents.isEmpty)
            const _EmptyAllDocuments()
          else ...[
            _DocumentSection(
              title: 'Renewable papers',
              description: 'Licence, insurance, permits and roadworthiness',
              icon: Icons.event_available_outlined,
              documents: vehicle.renewableDocuments,
              mutatingDocuments: mutatingDocuments,
              vehicleId: vehicle.id,
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
              description: 'Ownership and other permanent vehicle records',
              icon: Icons.folder_copy_outlined,
              documents: vehicle.otherDocuments,
              mutatingDocuments: mutatingDocuments,
              vehicleId: vehicle.id,
              onAdd: vehicle.hasValidPlateNumber
                  ? () => onAdd(DocumentTypeFilter.other)
                  : null,
              onView: onView,
              onAutoRenew: onAutoRenew,
              onDelete: onDelete,
            ),
          ],
          const SizedBox(height: 24),
          VehicleQuickActions(vehicleId: vehicle.id),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The header card: title/description, a direct "Renew N expired" action when
/// something has lapsed, and "Add document" — mirrors the web's top toolbar.
class _DocumentsSummaryCard extends StatelessWidget {
  const _DocumentsSummaryCard({
    required this.vehicleId,
    required this.hasValidPlate,
    required this.expiredCount,
    required this.onAddAny,
  });

  final String vehicleId;
  final bool hasValidPlate;
  final int expiredCount;
  final VoidCallback onAddAny;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title and "Add document" share one line — mirrors a compact
          // toolbar rather than stacking every action beneath the text.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Vehicle documents',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (hasValidPlate) ...[
                const SizedBox(width: 10),
                _AddDocumentButton(onTap: onAddAny),
              ],
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Manage this vehicle's legal documents and permits, organised by category.",
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          if (!hasValidPlate) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFC9B7)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Document upload unavailable',
                    style: TextStyle(
                      color: AppColors.orangeDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "This vehicle's plate number is a dealer or temporary plate and "
                    'does not qualify for document management. Update the plate '
                    'from Edit vehicle above once the permanent one is available.',
                    style: TextStyle(
                      color: AppColors.orangeDark,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (expiredCount > 0) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push(
                  '/more/renewals/new?vehicle=$vehicleId&preselect=expired',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: const Icon(Icons.autorenew_rounded, size: 17),
                label: Text(
                  'Renew $expiredCount expired',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact pill button used beside the "Vehicle documents" title, so the
/// primary add action sits on the header's own line instead of stacking
/// below the description.
class _AddDocumentButton extends StatelessWidget {
  const _AddDocumentButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forest50,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: AppColors.forest800),
              SizedBox(width: 4),
              Text(
                'Add',
                style: TextStyle(
                  color: AppColors.forest800,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAllDocuments extends StatelessWidget {
  const _EmptyAllDocuments();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: const Text(
        'No documents found for this vehicle.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, fontSize: 12.5),
      ),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.documents,
    required this.mutatingDocuments,
    required this.vehicleId,
    required this.onAdd,
    required this.onView,
    required this.onAutoRenew,
    required this.onDelete,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<VehicleDocument> documents;
  final Set<String> mutatingDocuments;
  final String vehicleId;
  final VoidCallback? onAdd;
  final ValueChanged<VehicleDocument> onView;
  final void Function(VehicleDocument, bool) onAutoRenew;
  final ValueChanged<VehicleDocument> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Green header — flush against the documents body below.
          Container(
            color: AppColors.forest700,
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .78),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${documents.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onAdd != null)
                  IconButton(
                    tooltip: 'Add to $title',
                    onPressed: onAdd,
                    icon: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
              ],
            ),
          ),
          // Documents body — no padding from the header above.
          Padding(
            padding: const EdgeInsets.all(14),
            child: documents.isEmpty
                ? _EmptyDocumentBody(title: title, onAdd: onAdd)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: documents.indexed
                        .map(
                          (entry) => Padding(
                            padding: EdgeInsets.only(
                              bottom: entry.$1 == documents.length - 1 ? 0 : 10,
                            ),
                            child: _DocumentTile(
                              document: entry.$2,
                              vehicleId: vehicleId,
                              isMutating: mutatingDocuments.contains(
                                entry.$2.id,
                              ),
                              onView: () => onView(entry.$2),
                              onAutoRenew: (enabled) =>
                                  onAutoRenew(entry.$2, enabled),
                              onDelete: () => onDelete(entry.$2),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDocumentBody extends StatelessWidget {
  const _EmptyDocumentBody({required this.title, required this.onAdd});

  final String title;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.forest50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              color: AppColors.forest700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No ${title.toLowerCase()} yet',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Add a document to keep its details and secure copy together.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add document'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single document row. The accent colour lives on the tile's own left
/// border (not a separately-sized stripe widget), so it always matches the
/// tile's real height exactly — no more height-mismatch artifacts.
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.vehicleId,
    required this.isMutating,
    required this.onView,
    required this.onAutoRenew,
    required this.onDelete,
  });

  final VehicleDocument document;
  final String vehicleId;
  final bool isMutating;
  final VoidCallback onView;
  final ValueChanged<bool> onAutoRenew;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = _DocumentStatusStyle.from(document.status);
    final verification = document.verification;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: isMutating ? null : onView,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: status.foreground, width: 4),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(11, 13, 12, 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: status.background,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        document.mimeType?.contains('pdf') == true
                            ? Icons.picture_as_pdf_outlined
                            : Icons.description_outlined,
                        color: status.foreground,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Identity block: name + status pill, doc number.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  document.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 13,
                                    height: 1.2,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: status.background,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  document.statusLabel,
                                  style: TextStyle(
                                    color: status.foreground,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            document.documentNumber?.isNotEmpty == true
                                ? 'No. ${document.documentNumber}'
                                : document.isRenewable
                                ? 'Document number not recorded'
                                : 'Permanent record on file',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                          if (verification != null) ...[
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Icon(
                                  verification.isPositive
                                      ? Icons.verified_user_outlined
                                      : verification.isNegative
                                      ? Icons.gpp_bad_outlined
                                      : Icons.manage_search_outlined,
                                  size: 14,
                                  color: _verificationColor(verification),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    verification.statusLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _verificationColor(verification),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: onView,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 28),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'See more',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // A thin rule separates identity from renewal
                          // status, so the row reads as two clear groups
                          // instead of one long stack of lines.
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              color: AppColors.border.withValues(alpha: .7),
                            ),
                          ),
                          if (document.isRenewable)
                            // Expiry and the auto-renew toggle share one
                            // line: the fact and the control that acts on it
                            // belong together, not stacked apart.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: status.foreground,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _expiryText(document),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: status.foreground,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: isMutating
                                      ? null
                                      : () => onAutoRenew(!document.autoRenew),
                                  borderRadius: BorderRadius.circular(30),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: document.autoRenew
                                          ? AppColors.forest50
                                          : AppColors.canvas,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _MiniToggle(value: document.autoRenew),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Auto-renew',
                                          style: TextStyle(
                                            color: document.autoRenew
                                                ? AppColors.forest700
                                                : AppColors.muted,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 13,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    document.hasFile
                                        ? 'Secure copy attached'
                                        : 'Details saved without a file',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFCFB),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: isMutating
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    // View + Delete sit left as plain links, Renew sits
                    // right as a filled call-to-action — matches the
                    // Insurance tab's Certificate/Edit/Renew Policy row.
                    : Row(
                        children: [
                          TextButton.icon(
                            onPressed: onView,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.forest700,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 14,
                            ),
                            label: const Text(
                              'View',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: onDelete,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Delete',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                          const Spacer(),
                          if (document.isExpired)
                            FilledButton.icon(
                              onPressed: () => context.push(
                                '/more/renewals/new?vehicle=$vehicleId&preselect=expired',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.autorenew_rounded,
                                size: 14,
                              ),
                              label: const Text(
                                'Renew',
                                style: TextStyle(fontSize: 11.5),
                              ),
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
}

/// A small themed toggle track — purely visual, the enclosing [InkWell]
/// handles the tap. Replaces the stock [Switch], whose default border ring
/// and colours don't match the app palette and read as an out-of-place
/// native control inside a custom pill.
class _MiniToggle extends StatelessWidget {
  const _MiniToggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 28,
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? AppColors.forest600 : AppColors.border,
        borderRadius: BorderRadius.circular(30),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
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
  final ValueChanged<DocumentVersion> onOpen;

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
                if (document.verification != null) ...[
                  const SizedBox(height: 14),
                  _VerificationEvidenceCard(
                    vehicleId: vehicle.id,
                    documentId: document.id,
                    fallbackVerification: document.verification!,
                  ),
                ],
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
                        onOpen: () => onOpen(versions[index]),
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

Color _verificationColor(DocumentVerificationSummary verification) {
  if (verification.isPositive) return AppColors.forest700;
  if (verification.isNegative) return AppColors.danger;
  if (verification.isPending) return const Color(0xFF1769AA);
  return AppColors.orangeDark;
}

class _VerificationEvidenceCard extends ConsumerStatefulWidget {
  const _VerificationEvidenceCard({
    required this.vehicleId,
    required this.documentId,
    required this.fallbackVerification,
  });

  final String vehicleId;
  final String documentId;
  final DocumentVerificationSummary fallbackVerification;

  @override
  ConsumerState<_VerificationEvidenceCard> createState() =>
      _VerificationEvidenceCardState();
}

class _VerificationEvidenceCardState
    extends ConsumerState<_VerificationEvidenceCard>
    with WidgetsBindingObserver {
  bool _rechecking = false;
  bool _isForeground = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    ref.invalidate(
      documentVerificationProvider((
        vehicleId: widget.vehicleId,
        documentId: widget.documentId,
      )),
    );
  }

  void _syncPolling(bool shouldPoll) {
    if (!shouldPoll || !_isForeground) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_pollTimer?.isActive == true) return;
    _pollTimer = Timer(const Duration(seconds: 4), () {
      _pollTimer = null;
      if (!mounted || !_isForeground) return;
      ref.invalidate(
        documentVerificationProvider((
          vehicleId: widget.vehicleId,
          documentId: widget.documentId,
        )),
      );
    });
  }

  Future<void> _openManualSource(
    BuildContext context,
    DocumentVerificationSummary verification,
  ) async {
    final uri = Uri.tryParse(verification.manualUrl ?? '');
    if (uri == null || uri.scheme != 'https') return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The official source could not be opened.'),
        ),
      );
    }
  }

  Future<void> _recheck() async {
    if (_rechecking) return;
    setState(() => _rechecking = true);
    try {
      await ref
          .read(vehicleDetailRepositoryProvider)
          .recheckDocument(
            vehicleId: widget.vehicleId,
            documentId: widget.documentId,
          );
      ref.invalidate(
        documentVerificationProvider((
          vehicleId: widget.vehicleId,
          documentId: widget.documentId,
        )),
      );
      ref.invalidate(vehicleDetailProvider(widget.vehicleId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document check queued.')));
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _rechecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verificationKey = (
      vehicleId: widget.vehicleId,
      documentId: widget.documentId,
    );
    final workspace = ref.watch(documentVerificationProvider(verificationKey));
    final snapshot = workspace.asData?.value;
    final detail = snapshot?.current;
    final history = snapshot?.history ?? const [];
    final verification = detail?.summary ?? widget.fallbackVerification;
    final isOfflineSnapshot = snapshot?.isFromCache == true;
    _syncPolling(verification.isPending && !isOfflineSnapshot);
    final color = _verificationColor(verification);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TRAVLA AUTHENTICITY CHECK',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      verification.statusLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (verification.isPending) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              minHeight: 3,
              color: color,
              backgroundColor: color.withValues(alpha: .1),
            ),
          ],
          if (isOfflineSnapshot) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4DD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1D49A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.orangeDark,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline snapshot saved ${_displaySnapshotTime(context, snapshot?.cachedAt)}. '
                      '${snapshot?.isStale == true ? 'It may be out of date. ' : ''}'
                      'Reconnect before relying on this result.',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 9.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      documentVerificationProvider(verificationKey),
                    ),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ],
          if (verification.message?.isNotEmpty == true) ...[
            const SizedBox(height: 11),
            Text(
              verification.message!,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _DocumentFact(
            label: 'Authority record',
            value: verification.authorityRecordStatusLabel,
          ),
          _DocumentFact(
            label: 'Evidence',
            value: verification.evidenceLevelLabel,
          ),
          _DocumentFact(
            label: 'Method',
            value: verification.verificationMethodLabel,
          ),
          _DocumentFact(label: 'Authority', value: verification.authority),
          if (verification.checkedAt != null)
            _DocumentFact(
              label: 'Checked',
              value: _displayApiDate(verification.checkedAt),
            ),
          if (detail != null) ...[
            _DocumentFact(
              label: 'Official host',
              value: detail.officialSourceHost,
            ),
            _DocumentFact(
              label: 'Next check',
              value: _displayApiDate(detail.nextCheckAt),
            ),
            if (detail.reference.isNotEmpty)
              _DocumentFact(label: 'Reference', value: detail.reference),
            if (detail.comparisons.isNotEmpty) ...[
              const Divider(height: 20),
              const Text(
                'SAFE FIELD COMPARISON',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 6),
              ...detail.comparisons.map(
                (comparison) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${comparison.label}${comparison.isCritical ? ' · required' : ''}',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      Text(
                        comparison.outcome.replaceAll('_', ' '),
                        style: TextStyle(
                          color: comparison.outcome == 'MATCH'
                              ? AppColors.forest700
                              : AppColors.danger,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          if (verification.reviewDisposition != null) ...[
            const Divider(height: 20),
            Text(
              verification.reviewDisposition!.replaceAll('_', ' '),
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (verification.reviewReason?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  verification.reviewReason!,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ),
          ],
          if (verification.manualInstructions?.isNotEmpty == true ||
              verification.manualUrl?.isNotEmpty == true) ...[
            const Divider(height: 22),
            const Text(
              'VERIFY INDEPENDENTLY',
              style: TextStyle(
                color: AppColors.forest700,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            if (verification.manualInstructions?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  verification.manualInstructions!,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
              ),
            if (verification.manualUrl?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton.icon(
                  onPressed: () => _openManualSource(context, verification),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Open official verification source'),
                ),
              ),
          ],
          if (history.isNotEmpty) ...[
            const Divider(height: 22),
            const Text(
              'CHECK HISTORY',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 6),
            ...history
                .take(5)
                .map(
                  (attempt) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 4, right: 8),
                          decoration: BoxDecoration(
                            color: _verificationColor(attempt),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${attempt.statusLabel} · ${attempt.checkedAt == null ? 'In progress' : _displayApiDate(attempt.checkedAt)}',
                            style: const TextStyle(
                              color: AppColors.ink,
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
          if (workspace.hasError) ...[
            const Divider(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Latest evidence could not refresh. The last known status is still shown.',
                    style: TextStyle(color: AppColors.muted, fontSize: 10),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(
                    documentVerificationProvider((
                      vehicleId: widget.vehicleId,
                      documentId: widget.documentId,
                    )),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  verification.isPending || _rechecking || isOfflineSnapshot
                  ? null
                  : _recheck,
              icon: _rechecking
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                _rechecking
                    ? 'Queuing check…'
                    : isOfflineSnapshot
                    ? 'Reconnect to check again'
                    : verification.isPending
                    ? 'Check in progress'
                    : 'Check again',
              ),
            ),
          ),
          const Divider(height: 22),
          Text(
            verification.disclaimer,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 9.5,
              height: 1.45,
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

String _displaySnapshotTime(BuildContext context, DateTime? value) {
  if (value == null) return 'at an unknown time';
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} at ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

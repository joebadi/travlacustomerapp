import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';

class StolenScreen extends ConsumerStatefulWidget {
  const StolenScreen({super.key});

  @override
  ConsumerState<StolenScreen> createState() => _StolenScreenState();
}

class _StolenScreenState extends ConsumerState<StolenScreen> {
  final _plateCtrl = TextEditingController();
  bool _checking = false;
  StolenCheckResult? _result;
  String? _searchError;

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final plate = _plateCtrl.text.trim();
    if (plate.isEmpty) return;
    setState(() {
      _checking = true;
      _searchError = null;
      _result = null;
    });
    try {
      final result = await ref.read(stolenRepositoryProvider).checkPlate(plate);
      if (mounted) setState(() => _result = result);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _searchError = failure.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _reportStolen() {
    final vehicles = ref.read(garageProvider).value?.vehicles ?? const [];
    if (vehicles.isEmpty) {
      _snack('Add a vehicle first, then you can report it stolen.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Text('Which vehicle was stolen?',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: vehicles
                    .map((v) => ListTile(
                          leading: const Icon(Icons.directions_car_outlined, color: AppColors.forest700),
                          title: Text(v.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: v.plateNumber?.isNotEmpty == true ? Text(v.plateNumber!) : null,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            context.push('/more/stolen/report?vehicle=${v.id}');
                          },
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myStolenReportsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Stolen registry')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.danger,
        onPressed: _reportStolen,
        icon: const Icon(Icons.report_gmailerrorred_rounded),
        label: const Text('Report stolen'),
      ),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: () async {
          ref.invalidate(myStolenReportsProvider);
          await ref.read(myStolenReportsProvider.future).catchError((_) => <StolenReport>[]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _SearchCard(
              controller: _plateCtrl,
              checking: _checking,
              onCheck: _check,
            ),
            if (_searchError != null) ...[
              const SizedBox(height: 10),
              Text(_searchError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 12),
              _CheckResultCard(
                result: _result!,
                onSighting: (id) => context.push('/more/stolen/$id/sighting'),
              ),
            ],
            const SizedBox(height: 22),
            const _Label('Your reports'),
            mine.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                error is ApiFailure ? error.message : 'Your reports could not be loaded.',
                style: const TextStyle(color: AppColors.muted),
              ),
              data: (reports) => reports.isEmpty
                  ? const _EmptyMine()
                  : Column(children: reports.map((r) => _ReportRow(report: r)).toList()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.controller, required this.checking, required this.onCheck});

  final TextEditingController controller;
  final bool checking;
  final VoidCallback onCheck;

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
          const Text('Check a plate', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 2),
          const Text('Buying used? Check if a vehicle is flagged stolen.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onCheck(),
                  decoration: const InputDecoration(
                    hintText: 'Plate number',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: checking ? null : onCheck,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.forest700),
                  child: checking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Check'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckResultCard extends StatelessWidget {
  const _CheckResultCard({required this.result, required this.onSighting});

  final StolenCheckResult result;
  final void Function(String reportId) onSighting;

  @override
  Widget build(BuildContext context) {
    if (!result.isStolen || result.report == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFDDF2E8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.forest700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${result.plate.toUpperCase()} is not flagged stolen in the registry.',
                style: const TextStyle(color: AppColors.forest800, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final report = result.report!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5BBB5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_maybe_rounded, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Flagged STOLEN',
                  style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${report.vehicle?.name ?? 'Vehicle'} · ${report.vehicle?.plateNumber ?? result.plate}',
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          if (report.lastKnownLocation != null) ...[
            const SizedBox(height: 3),
            Text('Last seen: ${report.lastKnownLocation}',
                style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
          if (report.rewardNaira != null && report.rewardNaira != '0.00') ...[
            const SizedBox(height: 3),
            Text('Reward: ₦${report.rewardNaira}',
                style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onSighting(report.id),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
              label: const Text('I have seen this vehicle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final StolenReport report;

  @override
  Widget build(BuildContext context) {
    final tone = switch (report.status) {
      'RECOVERED' => (const Color(0xFF075B40), const Color(0xFFDDF2E8)),
      'CLOSED' => (const Color(0xFF53615B), const Color(0xFFEDF0EF)),
      _ => (AppColors.danger, const Color(0xFFFFE3E1)),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => context.push('/more/stolen/${report.id}'),
        title: Text(report.vehicle?.name ?? 'Vehicle', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          [
            if (report.vehicle?.plateNumber != null) report.vehicle!.plateNumber!,
            if (report.sightingsCount != null) '${report.sightingsCount} sighting${report.sightingsCount == 1 ? '' : 's'}',
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: tone.$2, borderRadius: BorderRadius.circular(30)),
          child: Text(report.statusLabel,
              style: TextStyle(color: tone.$1, fontSize: 10, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _EmptyMine extends StatelessWidget {
  const _EmptyMine();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'You have no stolen reports. If a vehicle is stolen, report it here to alert the community.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Text(text.toUpperCase(),
          style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
    );
  }
}

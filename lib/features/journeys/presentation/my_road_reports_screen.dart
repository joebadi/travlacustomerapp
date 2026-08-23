import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/journeys/data/journey_repository.dart';
import 'package:travla_customer_app/features/journeys/domain/journey_models.dart';

/// The user's road-report contributions and where each stands (active,
/// community-confirmed, disputed, expired, removed).
class MyRoadReportsScreen extends ConsumerWidget {
  const MyRoadReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRoadReportsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('My road reports')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is ApiFailure ? error.message : 'Your reports could not be loaded.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_alert_outlined, size: 40, color: AppColors.muted),
                    SizedBox(height: 12),
                    Text(
                      "You haven't reported any road conditions yet.\nDrop a tag while recording or following a journey.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myRoadReportsProvider);
              await ref.read(myRoadReportsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ReportCard(report: reports[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final MyRoadReport report;

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone(report.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(report.typeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tone.$2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel(report.status),
                    style: TextStyle(color: tone.$1, fontSize: 9.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          if (report.description != null && report.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(report.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (report.verificationLabel != null)
                _chip(report.verificationLabel!, AppColors.forest700, AppColors.forest50),
              _chip('${report.confirmations} confirmed', AppColors.forest700, AppColors.forest50),
              _chip('${report.disputes} disputed', AppColors.orangeDark, const Color(0xFFFFE9E1)),
              if (report.media.isNotEmpty)
                _chip('${report.media.length} media', AppColors.ink, AppColors.canvas),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color fg, Color bg) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w700)),
      );

  String _statusLabel(String s) => switch (s) {
        'ACTIVE' => 'Active',
        'EXPIRED' => 'Expired',
        'REMOVED' => 'Removed',
        _ => s,
      };

  (Color, Color) _statusTone(String s) => switch (s) {
        'ACTIVE' => (AppColors.forest700, AppColors.forest50),
        'REMOVED' => (AppColors.danger, const Color(0xFFFFE3E1)),
        _ => (AppColors.muted, AppColors.canvas),
      };
}

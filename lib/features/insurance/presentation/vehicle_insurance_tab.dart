import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';
import 'package:travla_customer_app/features/insurance/presentation/insurance_widgets.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicle_quick_actions.dart';

/// The Insurance tab inside the vehicle workspace — shows this vehicle's NIID
/// verification status and saved policies, with links into the full insurance
/// workspace (verify, renew, cancel) and quick add/buy actions.
class VehicleInsuranceTab extends ConsumerWidget {
  const VehicleInsuranceTab({super.key, required this.vehicleId});

  final String vehicleId;

  Future<void> _openDoc(BuildContext context, String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vehicleInsuranceProvider(vehicleId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => InsuranceErrorState(
          message: error is ApiFailure ? error.message : 'Insurance could not be loaded.',
          onRetry: () => ref.invalidate(vehicleInsuranceProvider(vehicleId)),
        ),
        data: (data) {
          final hasActive = data.policies.any((p) => p.isActive);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VerificationChip(verification: data.verification),
              const SizedBox(height: 14),
              if (data.policies.isEmpty)
                _empty()
              else
                ...data.policies.map((p) => PolicyCard(
                      policy: p,
                      onViewDocument: () => _openDoc(context, p.documentUrl),
                      onRenew: () => context.push(
                        '/more/insurance/$vehicleId/renew/${p.id}',
                      ),
                    )),
              const SizedBox(height: 6),
              if (!hasActive)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/more/insurance/$vehicleId/buy'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.forest700,
                    ),
                    icon: const Icon(Icons.add_moderator_outlined),
                    label: const Text('Buy insurance'),
                  ),
                ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/more/insurance/$vehicleId/add'),
                      icon: const Icon(Icons.note_add_outlined, size: 18),
                      label: const Text('Add policy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.push('/more/insurance/$vehicleId'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest50,
                        foregroundColor: AppColors.forest800,
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Manage'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              VehicleQuickActions(vehicleId: vehicleId),
            ],
          );
        },
      ),
    );
  }

  Widget _empty() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No insurance recorded for this vehicle yet. Buy cover or add an existing policy below.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
      );
}

class _VerificationChip extends StatelessWidget {
  const _VerificationChip({required this.verification});

  final InsuranceVerification verification;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon, text) = switch (verification.outcome) {
      'FOUND' => (AppColors.forest700, const Color(0xFFDDF2E8), Icons.verified_user_rounded, 'Insurance found at source'),
      'NOT_FOUND' => (AppColors.danger, const Color(0xFFFFE3E1), Icons.gpp_bad_outlined, 'No insurance on record'),
      'ERROR' || 'CAPTCHA_BLOCKED' => (AppColors.orangeDark, const Color(0xFFFFE9E1), Icons.error_outline_rounded, 'Verification unavailable'),
      'PENDING' => (AppColors.muted, const Color(0xFFEDF0EF), Icons.hourglass_bottom_rounded, 'Verification pending'),
      _ => (AppColors.muted, const Color(0xFFEDF0EF), Icons.shield_outlined, 'Not verified yet'),
    };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
          const Text('Third-party (NIID)', style: TextStyle(color: AppColors.muted, fontSize: 10)),
        ],
      ),
    );
  }
}

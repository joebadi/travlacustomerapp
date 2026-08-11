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

/// The Insurance tab inside the vehicle workspace — mirrors the web layout:
/// a verification status card, a labelled "Insurance policies" section with the
/// saved/found policies, and add/buy/manage actions.
///
/// Every block is a full-width child stacked in a single [Column]; there is no
/// overlapping/stacked layout here.
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
          message: error is ApiFailure
              ? error.message
              : 'Insurance could not be loaded.',
          onRetry: () => ref.invalidate(vehicleInsuranceProvider(vehicleId)),
        ),
        data: (data) => _content(context, data),
      ),
    );
  }

  Widget _content(BuildContext context, VehicleInsurance data) {
    final hasActive = data.policies.any((p) => p.isActive);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Verification status card.
        _VerificationCard(
          verification: data.verification,
          onManage: () => context.push('/more/insurance/$vehicleId'),
        ),

        // 2. "Insurance policies" section label.
        const SizedBox(height: 20),
        _SectionHeader(count: data.policies.length),
        const SizedBox(height: 12),

        // 3. The policies (or an empty state).
        if (data.policies.isEmpty)
          _empty()
        else
          for (final policy in data.policies)
            PolicyCard(
              policy: policy,
              onViewDocument: () => _openDoc(context, policy.documentUrl),
              onRenew: () =>
                  context.push('/more/insurance/$vehicleId/renew/${policy.id}'),
            ),

        // 4. Actions.
        const SizedBox(height: 4),
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

        const SizedBox(height: 24),
        VehicleQuickActions(vehicleId: vehicleId),
      ],
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

/// Section title row for the policies list.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Insurance policies',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.forest50,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: AppColors.forest800,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Cover we found for this vehicle, plus any you add. Expiry is tracked and reminders are sent.',
          style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.35),
        ),
      ],
    );
  }
}

/// The third-party (NIID) verification status, presented as a white card that
/// mirrors the web's first insurance row.
class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.verification, required this.onManage});

  final InsuranceVerification verification;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = switch (verification.outcome) {
      'FOUND' => (
        AppColors.forest700,
        const Color(0xFFDDF2E8),
        Icons.verified_user_rounded,
      ),
      'NOT_FOUND' => (
        AppColors.danger,
        const Color(0xFFFFE3E1),
        Icons.gpp_bad_outlined,
      ),
      'ERROR' || 'CAPTCHA_BLOCKED' => (
        AppColors.orangeDark,
        const Color(0xFFFFE9E1),
        Icons.error_outline_rounded,
      ),
      'PENDING' => (
        AppColors.muted,
        const Color(0xFFEDF0EF),
        Icons.hourglass_bottom_rounded,
      ),
      _ => (AppColors.muted, const Color(0xFFEDF0EF), Icons.shield_outlined),
    };

    final title = switch (verification.outcome) {
      'FOUND' => 'Insurance found (${verification.policiesFound})',
      'NOT_FOUND' => 'No insurance on record',
      'ERROR' || 'CAPTCHA_BLOCKED' => 'Verification unavailable',
      'PENDING' => 'Verification pending',
      _ => 'Not verified yet',
    };

    final checked = _fmt(verification.checkedAt);
    final next = _fmt(verification.nextCheckAt);
    final subtitle = verification.hasRun
        ? [
            if (checked != null) 'Checked $checked',
            if (next != null) 'next auto-check $next',
          ].join(' · ')
        : 'This vehicle has not been checked at the source yet.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NIID',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onManage,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.forest700,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
            ),
            child: const Text(
              'Check now',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  static String? _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final date = DateTime.tryParse(iso);
    if (date == null) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

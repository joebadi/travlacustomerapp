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

/// The Insurance tab inside the vehicle workspace — the SINGLE place for a
/// vehicle's insurance. It is fully self-contained: verification runs inline
/// (no separate "manage" page), policies can be cancelled or renewed here, and
/// only genuine forms (add an existing policy, buy new cover, renew a policy)
/// push to their own screens.
///
/// This tab lives inside the vehicle-detail [ListView], so its ROOT is kept
/// stable — always `Padding > Column(stretch)` — and only the *children list*
/// changes between loading / error / data. That avoids swapping a short root
/// widget for a tall one inside the shared scroll view, which previously caused
/// the blocks to mis-measure and paint on top of each other.
class VehicleInsuranceTab extends ConsumerStatefulWidget {
  const VehicleInsuranceTab({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleInsuranceTab> createState() => _VehicleInsuranceTabState();
}

class _VehicleInsuranceTabState extends ConsumerState<VehicleInsuranceTab> {
  bool _checking = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    try {
      await ref.read(insuranceRepositoryProvider).verify(widget.vehicleId);
      ref.invalidate(vehicleInsuranceProvider(widget.vehicleId));
      ref.invalidate(expiringPoliciesProvider);
    } on ApiFailure catch (failure) {
      _snack(failure.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _cancel(InsurancePolicy policy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this policy?'),
        content: Text(
          'This marks ${policy.provider ?? 'the policy'} as cancelled in your '
          'records. This does not contact the insurer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel policy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(insuranceRepositoryProvider).cancelPolicy(policy.id);
      ref.invalidate(vehicleInsuranceProvider(widget.vehicleId));
      ref.invalidate(expiringPoliciesProvider);
    } on ApiFailure catch (failure) {
      _snack(failure.message);
    }
  }

  Future<void> _openDoc(String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vehicleInsuranceProvider(widget.vehicleId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: async.when(
          loading: () => const [
            SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => [
            InsuranceErrorState(
              message: error is ApiFailure
                  ? error.message
                  : 'Insurance could not be loaded.',
              onRetry: () =>
                  ref.invalidate(vehicleInsuranceProvider(widget.vehicleId)),
            ),
          ],
          data: _sections,
        ),
      ),
    );
  }

  /// The full stack of tab sections, as a flat list of Column children.
  List<Widget> _sections(VehicleInsurance data) {
    final hasActive = data.policies.any((p) => p.isActive);

    return [
      _VerificationCard(
        verification: data.verification,
        checking: _checking,
        onCheck: _checkNow,
      ),
      const SizedBox(height: 22),
      _PoliciesHeader(count: data.policies.length),
      const SizedBox(height: 12),
      if (data.policies.isEmpty)
        const _EmptyPolicies()
      else
        for (final policy in data.policies)
          PolicyCard(
            policy: policy,
            onCancel: policy.isActive ? () => _cancel(policy) : null,
            onViewDocument: () => _openDoc(policy.documentUrl),
            onRenew: () => context.push(
              '/more/insurance/${widget.vehicleId}/renew/${policy.id}',
            ),
          ),
      const SizedBox(height: 4),
      if (!hasActive) ...[
        FilledButton.icon(
          onPressed: () =>
              context.push('/more/insurance/${widget.vehicleId}/buy'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.forest700,
          ),
          icon: const Icon(Icons.add_moderator_outlined),
          label: const Text('Buy insurance for this vehicle'),
        ),
        const SizedBox(height: 10),
      ],
      OutlinedButton.icon(
        onPressed: () =>
            context.push('/more/insurance/${widget.vehicleId}/add'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        icon: const Icon(Icons.note_add_outlined, size: 18),
        label: const Text('Add an existing policy'),
      ),
      const SizedBox(height: 26),
      VehicleQuickActions(vehicleId: widget.vehicleId),
    ];
  }
}

/// Section title + count + helper line for the policies list.
class _PoliciesHeader extends StatelessWidget {
  const _PoliciesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              'Insurance policies',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
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
        const SizedBox(height: 5),
        const Text(
          'Cover we found for this vehicle, plus any you add. Expiry is tracked and reminders are sent.',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

/// Empty state when the vehicle has no saved policies.
class _EmptyPolicies extends StatelessWidget {
  const _EmptyPolicies();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 34, color: AppColors.muted),
          SizedBox(height: 10),
          Text(
            'No insurance recorded for this vehicle yet.\nBuy cover or add an existing policy below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Third-party (NIID) verification status — a white card mirroring the web.
/// The "Check now" action runs inline; nothing navigates away for this.
class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.verification,
    required this.checking,
    required this.onCheck,
  });

  final InsuranceVerification verification;
  final bool checking;
  final VoidCallback onCheck;

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const _NiidTag(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (verification.errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                verification.errorMessage!,
                style: const TextStyle(color: AppColors.orangeDark, fontSize: 11),
              ),
            ),
          ],
          if (!verification.hasValidPlate) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Add a valid plate number to this vehicle to run a third-party check.',
                style: TextStyle(color: AppColors.orangeDark, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (checking || !verification.hasValidPlate) ? null : onCheck,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest700,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(42),
              ),
              icon: checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore_rounded, size: 18),
              label: Text(checking ? 'Checking…' : 'Check now'),
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

class _NiidTag extends StatelessWidget {
  const _NiidTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }
}

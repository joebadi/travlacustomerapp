import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';
import 'package:travla_customer_app/features/insurance/presentation/insurance_widgets.dart';
import 'package:travla_customer_app/features/vehicles/presentation/document_viewer_screen.dart';
import 'package:travla_customer_app/features/vehicles/presentation/vehicle_quick_actions.dart';

/// The Insurance tab inside the vehicle workspace — the SINGLE place for a
/// vehicle's insurance (verification, saved policies, add/buy/edit/renew).
/// One unified card (banner + list + actions) rather than several stacked
/// cards, so the whole tab is a single, simply-laid-out block with no
/// independent siblings that could ever visually collide.
class VehicleInsuranceTab extends ConsumerStatefulWidget {
  const VehicleInsuranceTab({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleInsuranceTab> createState() =>
      _VehicleInsuranceTabState();
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

  void _openDoc(String? url) {
    final value = url?.trim();
    if (value == null || value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return;
    // Open the certificate INSIDE the app (native PDF/image viewer) rather
    // than handing off to the device browser.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DocumentViewerScreen(url: value, title: 'Insurance certificate'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vehicleInsuranceProvider(widget.vehicleId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: async.when(
        loading: () => const SizedBox(
          height: 260,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => InsuranceErrorState(
          message: error is ApiFailure
              ? error.message
              : 'Insurance could not be loaded.',
          onRetry: () =>
              ref.invalidate(vehicleInsuranceProvider(widget.vehicleId)),
        ),
        data: _body,
      ),
    );
  }

  Widget _body(VehicleInsurance data) {
    final hasActive = data.policies.any((p) => p.isActive);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _InsuranceCard(
          verification: data.verification,
          policies: data.policies,
          checking: _checking,
          onCheckNow: _checkNow,
          onViewDocument: _openDoc,
          onEditPolicy: (policy) => context.push(
            '/more/insurance/${widget.vehicleId}/edit/${policy.id}',
            extra: policy,
          ),
          onRenewPolicy: (policy) => context.push(
            '/more/insurance/${widget.vehicleId}/renew/${policy.id}',
          ),
        ),
        const SizedBox(height: 14),
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
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
          ),
          icon: const Icon(Icons.note_add_outlined, size: 18),
          label: const Text('Add an existing policy'),
        ),
        const SizedBox(height: 26),
        VehicleQuickActions(vehicleId: widget.vehicleId),
      ],
    );
  }
}

/// One unified card: a verification banner up top, a "Policies" sub-header,
/// then each saved policy — all inside a single bordered container so there
/// is exactly one box for the eye to parse on this tab.
class _InsuranceCard extends StatelessWidget {
  const _InsuranceCard({
    required this.verification,
    required this.policies,
    required this.checking,
    required this.onCheckNow,
    required this.onViewDocument,
    required this.onEditPolicy,
    required this.onRenewPolicy,
  });

  final InsuranceVerification verification;
  final List<InsurancePolicy> policies;
  final bool checking;
  final VoidCallback onCheckNow;
  final ValueChanged<String?> onViewDocument;
  final ValueChanged<InsurancePolicy> onEditPolicy;
  final ValueChanged<InsurancePolicy> onRenewPolicy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VerificationBanner(
            verification: verification,
            checking: checking,
            onCheckNow: onCheckNow,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Policies',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${policies.length}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                // Demarcate the "Policies" heading from the results below.
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                if (policies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'No insurance recorded for this vehicle yet. Buy cover or '
                      'add an existing policy below.',
                      style: TextStyle(
                        color: AppColors.muted,
                        height: 1.5,
                        fontSize: 12.5,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < policies.length; i++) ...[
                    if (i > 0) const Divider(height: 22),
                    _PolicyRow(
                      policy: policies[i],
                      onViewDocument: () =>
                          onViewDocument(policies[i].documentUrl),
                      // Uploading a certificate uses the same policy form
                      // (it has a file picker) as Edit.
                      onUpload: () => onEditPolicy(policies[i]),
                      onEdit: () => onEditPolicy(policies[i]),
                      onRenew: policies[i].canRenew
                          ? () => onRenewPolicy(policies[i])
                          : null,
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top strip of the unified card: the third-party (NIID) verification status
/// with an inline "Check now" action.
class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({
    required this.verification,
    required this.checking,
    required this.onCheckNow,
  });

  final InsuranceVerification verification;
  final bool checking;
  final VoidCallback onCheckNow;

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
            if (next != null) 'next $next',
          ].join(' · ')
        : 'Not checked at the source yet.';

    return Container(
      color: bg.withValues(alpha: .55),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .6),
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
          if (verification.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              verification.errorMessage!,
              style: const TextStyle(
                color: AppColors.orangeDark,
                fontSize: 10.5,
              ),
            ),
          ],
          if (!verification.hasValidPlate) ...[
            const SizedBox(height: 8),
            const Text(
              'Add a valid plate number to this vehicle to run a third-party check.',
              style: TextStyle(color: AppColors.orangeDark, fontSize: 10.5),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: (checking || !verification.hasValidPlate)
                  ? null
                  : onCheckNow,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: checking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore_rounded, size: 16),
              label: Text(
                checking ? 'Checking…' : 'Check now',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
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
}

/// A single policy inside the unified card's "Policies" list.
class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.policy,
    required this.onViewDocument,
    required this.onUpload,
    required this.onEdit,
    required this.onRenew,
  });

  final InsurancePolicy policy;
  final VoidCallback onViewDocument;
  final VoidCallback onUpload;
  final VoidCallback onEdit;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final tone = switch (policy.status) {
      'CANCELLED' => const (AppColors.muted, Color(0xFFEDF0EF)),
      _ when policy.isPending => const (
        AppColors.orangeDark,
        Color(0xFFFFE9E1),
      ),
      _ when policy.isExpired => const (AppColors.danger, Color(0xFFFFE3E1)),
      _ when (policy.daysToExpiry ?? 999) <= 30 => const (
        AppColors.orangeDark,
        Color(0xFFFFE9E1),
      ),
      _ => const (AppColors.forest700, Color(0xFFDDF2E8)),
    };
    // Drop the backend's "Verified via NIID" placeholder insurer name — the
    // "Verified" label already conveys that. Fall back to a neutral title.
    final provider = policy.provider?.trim() ?? '';
    final title = (provider.isNotEmpty && provider != 'Verified via NIID')
        ? provider
        : 'Insurance policy';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Insurer / source name on its own line.
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 6),
        // Coverage type stays on the left; the "Verified" and status
        // ("Active") labels sit together on the right of the same line.
        Row(
          children: [
            Expanded(
              child: policy.coverageLabel != null
                  ? Text(
                      policy.coverageLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            if (!policy.isPending && policy.isVerified) ...[
              _miniTag(
                'Verified',
                AppColors.forest700,
                const Color(0xFFDDF2E8),
              ),
              const SizedBox(width: 6),
            ],
            _miniTag(policy.statusLabel, tone.$1, tone.$2),
          ],
        ),
        const SizedBox(height: 10),
        if (policy.isPending)
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'An agent is procuring this policy — the certificate and dates '
              'appear here once it is issued.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          )
        else ...[
          // Details laid out as an even 2-column grid inside a light panel —
          // reads as one arranged block instead of loosely wrapped facts.
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _detail('Policy no.', policy.policyNumber ?? '—'),
                    ),
                    Expanded(child: _detail('Cover period', _period(policy))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _detail('Premium', '₦${policy.premiumNaira}'),
                    ),
                    Expanded(
                      child: _detail('Excess', '₦${policy.excessNaira}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // A Row (not Wrap) — Spacer/Expanded below require a Flex
          // ancestor, so the left links and the right Renew button can
          // still push apart on one line; wraps to two lines via Wrap
          // fallback only when space is truly too tight.
          Row(
            children: [
              if (policy.hasDocument && policy.documentUrl != null)
                TextButton.icon(
                  onPressed: onViewDocument,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.forest700,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text(
                    'Certificate',
                    style: TextStyle(fontSize: 11.5),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: onUpload,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.forest700,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.upload_file_outlined, size: 14),
                  label: const Text(
                    'Upload Certificate',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit', style: TextStyle(fontSize: 11.5)),
              ),
              const Spacer(),
              if (onRenew != null)
                FilledButton.icon(
                  onPressed: onRenew,
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
                  icon: const Icon(Icons.autorenew_rounded, size: 14),
                  label: const Text(
                    'Renew Policy',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _miniTag(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 9.5),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static String _period(InsurancePolicy p) {
    final start = _fmt(p.startDate);
    final end = _fmt(p.endDate);
    if (start == null && end == null) return '—';
    return '${start ?? '—'} → ${end ?? '—'}';
  }

  static String? _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final date = DateTime.tryParse(iso);
    if (date == null) return null;
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
}

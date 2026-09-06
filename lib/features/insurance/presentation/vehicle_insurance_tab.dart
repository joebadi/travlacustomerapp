import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';
import 'package:travla_customer_app/features/insurance/presentation/insurance_widgets.dart';
import 'package:travla_customer_app/features/vehicles/presentation/document_viewer_screen.dart';

/// Minimal insurance workspace for one vehicle.
///
/// Cover status and certificate storage are intentionally separate: an
/// external check can confirm a policy while its certificate is still absent.
/// Every certificate action is therefore attached to its own policy.
class VehicleInsuranceTab extends ConsumerStatefulWidget {
  const VehicleInsuranceTab({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleInsuranceTab> createState() =>
      _VehicleInsuranceTabState();
}

class _VehicleInsuranceTabState extends ConsumerState<VehicleInsuranceTab> {
  bool _checking = false;
  String? _removingPolicyId;
  bool _expiredExpanded = true;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkNow() async {
    if (_checking) return;
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

  void _openDocument(String? url) {
    final value = url?.trim();
    if (value == null || value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DocumentViewerScreen(url: value, title: 'Insurance certificate'),
      ),
    );
  }

  void _openPolicy(InsurancePolicy policy) {
    context.push(
      '/more/insurance/${widget.vehicleId}/edit/${policy.id}',
      extra: policy,
    );
  }

  Future<void> _removePolicy(InsurancePolicy policy) async {
    if (_removingPolicyId != null) return;
    final verified = policy.isVerified;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(verified ? 'Remove from Travla?' : 'Delete this policy?'),
        content: Text(
          verified
              ? 'This removes the saved copy and any uploaded certificate. '
                    'If a future insurance check still reports this policy, '
                    'it may appear in Travla again.'
              : 'This permanently removes the policy and its uploaded '
                    'certificate from Travla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep policy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(verified ? 'Remove' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _removingPolicyId = policy.id);
    try {
      await ref.read(insuranceRepositoryProvider).deletePolicy(policy.id);
      ref.invalidate(vehicleInsuranceProvider(widget.vehicleId));
      ref.invalidate(expiringPoliciesProvider);
      _snack(verified ? 'Policy removed from Travla.' : 'Policy deleted.');
    } on ApiFailure catch (failure) {
      _snack(failure.message);
    } finally {
      if (mounted) setState(() => _removingPolicyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insurance = ref.watch(vehicleInsuranceProvider(widget.vehicleId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: insurance.when(
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
        data: _content,
      ),
    );
  }

  Widget _content(VehicleInsurance data) {
    final active =
        data.policies
            .where(
              (policy) =>
                  policy.isPending ||
                  (policy.status == 'ACTIVE' && !policy.isExpired),
            )
            .toList(growable: false)
          ..sort(_activeSort);
    final activeIds = active.map((policy) => policy.id).toSet();
    final expired =
        data.policies
            .where((policy) => !activeIds.contains(policy.id))
            .toList(growable: false)
          ..sort(_expiredSort);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PolicySectionHeader(
          count: active.length,
          verification: data.verification,
          checking: _checking,
          onCheckNow: _checkNow,
        ),
        const SizedBox(height: 12),
        if (active.isEmpty)
          _EmptyActivePolicies(
            verification: data.verification,
            onBuy: () =>
                context.push('/more/insurance/${widget.vehicleId}/buy'),
            onAdd: () =>
                context.push('/more/insurance/${widget.vehicleId}/add'),
          )
        else ...[
          for (var i = 0; i < active.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _policyCard(active[i]),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () =>
                context.push('/more/insurance/${widget.vehicleId}/add'),
            icon: const Icon(Icons.note_add_outlined, size: 18),
            label: const Text('Add an existing policy'),
          ),
        ],
        const SizedBox(height: 30),
        _ExpiredHeader(
          count: expired.length,
          expanded: _expiredExpanded,
          onToggle: expired.isEmpty
              ? null
              : () => setState(() => _expiredExpanded = !_expiredExpanded),
        ),
        if (expired.isNotEmpty && _expiredExpanded) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < expired.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _policyCard(expired[i]),
          ],
        ] else if (expired.isEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'No expired policies.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _policyCard(InsurancePolicy policy) {
    return _PolicyCard(
      policy: policy,
      removing: _removingPolicyId == policy.id,
      onViewDocument: () => _openDocument(policy.documentUrl),
      onCertificate: () => _openPolicy(policy),
      onEdit: policy.isVerified ? null : () => _openPolicy(policy),
      onRenew: policy.canRenew
          ? () => context.push(
              '/more/insurance/${widget.vehicleId}/renew/${policy.id}',
            )
          : null,
      onRemove: () => _removePolicy(policy),
    );
  }

  static int _activeSort(InsurancePolicy a, InsurancePolicy b) {
    if (a.isPending != b.isPending) return a.isPending ? 1 : -1;
    return _date(a.endDate).compareTo(_date(b.endDate));
  }

  static int _expiredSort(InsurancePolicy a, InsurancePolicy b) =>
      _date(b.endDate).compareTo(_date(a.endDate));

  static DateTime _date(String? value) =>
      DateTime.tryParse(value ?? '') ?? DateTime(1900);
}

class _PolicySectionHeader extends StatelessWidget {
  const _PolicySectionHeader({
    required this.count,
    required this.verification,
    required this.checking,
    required this.onCheckNow,
  });

  final int count;
  final InsuranceVerification verification;
  final bool checking;
  final VoidCallback onCheckNow;

  @override
  Widget build(BuildContext context) {
    final checked = _formatDate(verification.checkedAt);
    final next = _formatDate(verification.nextCheckAt);
    final status = switch (verification.outcome) {
      'FOUND' => checked == null ? 'Insurance confirmed' : 'Checked $checked',
      'NOT_FOUND' =>
        checked == null
            ? 'No active cover found'
            : 'No active cover found · $checked',
      'ERROR' || 'CAPTCHA_BLOCKED' =>
        next == null ? 'Check unavailable' : 'Check unavailable · retry $next',
      'PENDING' => 'Insurance check pending',
      _ =>
        verification.hasValidPlate
            ? 'Not checked yet'
            : 'Add a valid plate to enable checks',
    };
    final schedule = [
      status,
      if (next != null && verification.outcome == 'FOUND') 'Next $next',
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Active Policies',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CountBadge(count: count),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                schedule,
                style: TextStyle(
                  color:
                      verification.outcome == 'ERROR' ||
                          verification.outcome == 'CAPTCHA_BLOCKED'
                      ? AppColors.orangeDark
                      : AppColors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: checking || !verification.hasValidPlate
              ? null
              : onCheckNow,
          tooltip: 'Check insurance now',
          style: IconButton.styleFrom(
            foregroundColor: AppColors.forest700,
            backgroundColor: const Color(0xFFE8F4EF),
          ),
          icon: checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 20),
        ),
      ],
    );
  }
}

class _ExpiredHeader extends StatelessWidget {
  const _ExpiredHeader({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            const Text(
              'Expired Policies',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            _CountBadge(count: count),
            const Spacer(),
            if (count > 0)
              AnimatedRotation(
                turns: expanded ? .5 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEEC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.policy,
    required this.removing,
    required this.onViewDocument,
    required this.onCertificate,
    required this.onEdit,
    required this.onRenew,
    required this.onRemove,
  });

  final InsurancePolicy policy;
  final bool removing;
  final VoidCallback onViewDocument;
  final VoidCallback onCertificate;
  final VoidCallback? onEdit;
  final VoidCallback? onRenew;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final statusTone = _statusTone(policy);
    final provider = policy.provider?.trim() ?? '';
    final showProvider = provider.isNotEmpty && provider != 'Verified via NIID';
    final money = <String>[
      if (_hasAmount(policy.premiumNaira)) 'Premium ₦${policy.premiumNaira}',
      if (_hasAmount(policy.excessNaira)) 'Excess ₦${policy.excessNaira}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: .035),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CertificateThumbnail(policy: policy, onView: onViewDocument),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            policy.coverageLabel ?? 'Insurance policy',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 13.5,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        _StatusBadge(
                          label: policy.isPending
                              ? 'Being arranged'
                              : policy.statusLabel,
                          foreground: statusTone.$1,
                          background: statusTone.$2,
                        ),
                      ],
                    ),
                    if (showProvider) ...[
                      const SizedBox(height: 5),
                      Text(
                        provider,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (policy.isPending)
                      const Text(
                        'An agent is arranging this cover. The policy details '
                        'and certificate will appear when it is issued.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      )
                    else ...[
                      _PolicyFact(
                        label: 'Policy number',
                        value: policy.policyNumber ?? '—',
                      ),
                      const SizedBox(height: 7),
                      _PolicyFact(
                        label: 'Cover period',
                        value: _period(policy),
                      ),
                      if (money.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          money.join(' · '),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!policy.isPending && policy.isVerified)
                          const _SourceBadge(),
                        if (onRenew != null)
                          _CompactAction(
                            label: 'Renew',
                            icon: Icons.autorenew_rounded,
                            color: AppColors.orangeDark,
                            onPressed: onRenew!,
                          ),
                        if (onEdit != null)
                          _CompactAction(
                            label: 'Edit',
                            icon: Icons.edit_outlined,
                            color: AppColors.forest700,
                            onPressed: onEdit!,
                          ),
                        _CompactAction(
                          label: policy.isVerified ? 'Remove' : 'Delete',
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.danger,
                          onPressed: removing ? null : onRemove,
                          loading: removing,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!policy.isPending) ...[
          const SizedBox(height: 6),
          Material(
            color: policy.hasDocument
                ? const Color(0xFFE8F4EF)
                : const Color(0xFFFFEEE8),
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              onTap: onCertificate,
              borderRadius: BorderRadius.circular(13),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      policy.hasDocument
                          ? Icons.change_circle_outlined
                          : Icons.upload_file_rounded,
                      size: 18,
                      color: policy.hasDocument
                          ? AppColors.forest700
                          : AppColors.orangeDark,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        policy.hasDocument
                            ? 'Replace certificate'
                            : 'Upload certificate',
                        style: TextStyle(
                          color: policy.hasDocument
                              ? AppColors.forest700
                              : AppColors.orangeDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: policy.hasDocument
                          ? AppColors.forest700
                          : AppColors.orangeDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static (Color, Color) _statusTone(InsurancePolicy policy) {
    if (policy.isPending) {
      return (AppColors.orangeDark, const Color(0xFFFFE9E1));
    }
    if (policy.isExpired || policy.status == 'CANCELLED') {
      return (AppColors.danger, const Color(0xFFFFE3E1));
    }
    if ((policy.daysToExpiry ?? 999) <= 30) {
      return (AppColors.orangeDark, const Color(0xFFFFE9E1));
    }
    return (AppColors.forest700, const Color(0xFFDDF2E8));
  }

  static bool _hasAmount(String value) =>
      (double.tryParse(value.replaceAll(',', '').trim()) ?? 0) > 0;

  static String _period(InsurancePolicy policy) {
    final start = _formatDate(policy.startDate);
    final end = _formatDate(policy.endDate);
    return '${start ?? '—'} – ${end ?? '—'}';
  }
}

class _CertificateThumbnail extends StatelessWidget {
  const _CertificateThumbnail({required this.policy, required this.onView});

  final InsurancePolicy policy;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final hasDocument =
        policy.hasDocument && policy.documentUrl?.isNotEmpty == true;

    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Material(
            color: const Color(0xFFF1F5F3),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: hasDocument ? onView : null,
              child: SizedBox(
                width: 78,
                height: 98,
                child: hasDocument
                    ? Image.network(
                        policy.documentUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const _DocumentPlaceholder(compact: true),
                        errorBuilder: (_, _, _) =>
                            const _DocumentPlaceholder(compact: false),
                      )
                    : const _DocumentPlaceholder(compact: true),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasDocument ? 'View certificate' : 'No certificate',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: hasDocument ? AppColors.forest700 : AppColors.muted,
              fontSize: 9,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentPlaceholder extends StatelessWidget {
  const _DocumentPlaceholder({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F8F7), Color(0xFFE7EEEA)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              compact
                  ? Icons.description_outlined
                  : Icons.picture_as_pdf_outlined,
              color: compact ? AppColors.forest700 : AppColors.danger,
              size: 27,
            ),
            const SizedBox(height: 5),
            Text(
              compact ? 'CERTIFICATE' : 'PDF',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyFact extends StatelessWidget {
  const _PolicyFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 9),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 11,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4EF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'VERIFIED',
        style: TextStyle(
          color: AppColors.forest700,
          fontSize: 8,
          letterSpacing: .4,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyActivePolicies extends StatelessWidget {
  const _EmptyActivePolicies({
    required this.verification,
    required this.onBuy,
    required this.onAdd,
  });

  final InsuranceVerification verification;
  final VoidCallback onBuy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final checkedAndMissing = verification.outcome == 'NOT_FOUND';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: checkedAndMissing
                  ? const Color(0xFFFFE9E1)
                  : const Color(0xFFE8F4EF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              checkedAndMissing
                  ? Icons.gpp_bad_outlined
                  : Icons.shield_outlined,
              color: checkedAndMissing
                  ? AppColors.orangeDark
                  : AppColors.forest700,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            checkedAndMissing
                ? 'No active insurance was found'
                : 'No active policy saved yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Buy cover through Travla or add a policy you already have.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onAdd,
                  child: const Text('Add existing'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton(
                  onPressed: onBuy,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest700,
                  ),
                  child: const Text('Buy insurance'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String? _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final date = DateTime.tryParse(iso)?.toLocal();
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

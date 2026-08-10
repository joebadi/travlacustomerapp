import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/insurance/data/insurance_repository.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';
import 'package:travla_customer_app/features/insurance/presentation/insurance_widgets.dart';

class VehicleInsuranceScreen extends ConsumerStatefulWidget {
  const VehicleInsuranceScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleInsuranceScreen> createState() =>
      _VehicleInsuranceScreenState();
}

class _VehicleInsuranceScreenState
    extends ConsumerState<VehicleInsuranceScreen> {
  bool _checking = false;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    try {
      await ref.read(insuranceRepositoryProvider).verify(widget.vehicleId);
      ref.invalidate(vehicleInsuranceProvider(widget.vehicleId));
      ref.invalidate(expiringPoliciesProvider);
    } on ApiFailure catch (failure) {
      if (mounted) _snack(failure.message);
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
          'This marks ${policy.provider ?? 'the policy'} as cancelled in your records. This does not contact the insurer.',
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
      if (mounted) _snack(failure.message);
    }
  }

  Future<void> _openDocument(String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _snack('This certificate link is invalid. Pull to refresh and try again.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _snack('The certificate could not be opened.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vehicleInsuranceProvider(widget.vehicleId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Vehicle insurance')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        onPressed: () =>
            context.push('/more/insurance/${widget.vehicleId}/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add policy'),
      ),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: () async {
          ref.invalidate(vehicleInsuranceProvider(widget.vehicleId));
          await ref.read(vehicleInsuranceProvider(widget.vehicleId).future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              InsuranceErrorState(
                message: error is ApiFailure
                    ? error.message
                    : 'Insurance details could not be loaded.',
                onRetry: () =>
                    ref.invalidate(vehicleInsuranceProvider(widget.vehicleId)),
              ),
            ],
          ),
          data: (data) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _VerificationCard(
                verification: data.verification,
                checking: _checking,
                onCheck: _checkNow,
              ),
              if (!data.policies.any((p) => p.isActive)) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push('/more/insurance/${widget.vehicleId}/buy'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.forest700,
                    ),
                    icon: const Icon(Icons.add_moderator_outlined),
                    label: const Text('Buy insurance for this vehicle'),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const _Label('Saved policies'),
              if (data.policies.isEmpty)
                const _NoPolicies()
              else
                ...data.policies.map(
                  (p) => PolicyCard(
                    policy: p,
                    onCancel: () => _cancel(p),
                    onViewDocument: () => _openDocument(p.documentUrl),
                    onRenew: p.status == 'CANCELLED'
                        ? null
                        : () => context.push(
                            '/more/insurance/${widget.vehicleId}/renew/${p.id}',
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final tone = _tone(verification.outcome);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tone.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon(verification.outcome), color: tone.fg),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Third-party verification',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        verification.hasRun
                            ? (verification.outcomeLabel ?? 'Checked')
                            : 'Not checked yet',
                        style: TextStyle(
                          color: tone.fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (verification.hasRun && verification.policiesFound > 0) ...[
              const SizedBox(height: 10),
              Text(
                '${verification.policiesFound} active ${verification.policiesFound == 1 ? 'policy' : 'policies'} on record at the source.',
                style: const TextStyle(color: AppColors.ink, fontSize: 12.5),
              ),
            ],
            if (verification.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                verification.errorMessage!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],
            if (!verification.hasValidPlate) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Add a valid plate number to this vehicle to run a third-party check.',
                  style: TextStyle(color: AppColors.orangeDark, fontSize: 11.5),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (checking || !verification.hasValidPlate)
                    ? null
                    : onCheck,
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
      ),
    );
  }

  IconData _icon(String? outcome) => switch (outcome) {
    'FOUND' => Icons.verified_user_rounded,
    'NOT_FOUND' => Icons.gpp_bad_outlined,
    'ERROR' || 'CAPTCHA_BLOCKED' => Icons.error_outline_rounded,
    'PENDING' => Icons.hourglass_bottom_rounded,
    _ => Icons.shield_outlined,
  };

  _Tone _tone(String? outcome) => switch (outcome) {
    'FOUND' => const _Tone(AppColors.forest700, Color(0xFFDDF2E8)),
    'NOT_FOUND' => const _Tone(AppColors.danger, Color(0xFFFFE3E1)),
    'ERROR' || 'CAPTCHA_BLOCKED' => const _Tone(
      AppColors.orangeDark,
      Color(0xFFFFE9E1),
    ),
    _ => const _Tone(AppColors.muted, Color(0xFFEDF0EF)),
  };
}

class _Tone {
  const _Tone(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

class _NoPolicies extends StatelessWidget {
  const _NoPolicies();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No policies recorded yet. Add a policy to keep its cover dates and certificate in one place.',
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
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

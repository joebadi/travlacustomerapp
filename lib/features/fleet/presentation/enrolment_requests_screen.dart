import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/data/enrolment_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/enrolment_models.dart';

/// Owner-facing screen for the fleet enrolment-consent flow. Shows requests
/// awaiting the owner's decision (approve / decline) and vehicles already
/// enrolled in a fleet (which the owner can revoke). Deep-linked from the
/// "Fleet enrolment request" notification.
class EnrolmentRequestsScreen extends ConsumerStatefulWidget {
  const EnrolmentRequestsScreen({super.key});

  @override
  ConsumerState<EnrolmentRequestsScreen> createState() =>
      _EnrolmentRequestsScreenState();
}

class _EnrolmentRequestsScreenState
    extends ConsumerState<EnrolmentRequestsScreen> {
  String? _busyId;

  Future<void> _run(String id, Future<void> Function() action) async {
    setState(() => _busyId = id);
    try {
      await action();
      ref.invalidate(pendingEnrolmentsProvider);
      ref.invalidate(myEnrolmentsProvider);
    } on ApiFailure catch (f) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmRevoke(VehicleEnrolment e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from fleet?'),
        content: Text(
          '${e.vehiclePlate ?? 'This vehicle'} will be removed from '
          '${e.organisationName ?? 'the fleet'}. You remain the owner either way.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(e.id, () => ref.read(enrolmentRepositoryProvider).revoke(e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingEnrolmentsProvider);
    final mine = ref.watch(myEnrolmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Fleet requests')),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: () async {
          ref.invalidate(pendingEnrolmentsProvider);
          ref.invalidate(myEnrolmentsProvider);
          await ref.read(pendingEnrolmentsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const _Intro(),
            const SizedBox(height: 16),
            const _Label('Awaiting your consent'),
            const SizedBox(height: 10),
            pending.when(
              loading: () => const _Loading(),
              error: (e, _) => _Error(
                message: e is ApiFailure ? e.message : 'Could not load requests.',
                onRetry: () => ref.invalidate(pendingEnrolmentsProvider),
              ),
              data: (list) => list.isEmpty
                  ? const _Empty('No pending requests.')
                  : Column(
                      children: [
                        for (final e in list)
                          _PendingCard(
                            enrolment: e,
                            busy: _busyId == e.id,
                            onApprove: () => _run(
                              e.id,
                              () => ref
                                  .read(enrolmentRepositoryProvider)
                                  .approve(e.id),
                            ),
                            onDecline: () => _run(
                              e.id,
                              () => ref
                                  .read(enrolmentRepositoryProvider)
                                  .decline(e.id),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 22),
            const _Label('Enrolled in a fleet'),
            const SizedBox(height: 10),
            mine.when(
              loading: () => const _Loading(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) {
                final active = list.where((e) => e.isApproved).toList();
                if (active.isEmpty) {
                  return const _Empty('None of your vehicles are in a fleet.');
                }
                return Column(
                  children: [
                    for (final e in active)
                      _ActiveCard(
                        enrolment: e,
                        busy: _busyId == e.id,
                        onRevoke: () => _confirmRevoke(e),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: AppColors.forest700, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Companies can ask to add your vehicle to their fleet. You stay the '
              'owner — approve to share fleet features, or decline. You can remove '
              'it again any time.',
              style: TextStyle(
                color: AppColors.forest800,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.enrolment,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });

  final VehicleEnrolment enrolment;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            enrolment.organisationName ?? 'A fleet company',
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'wants to add ${enrolment.vehiclePlate ?? enrolment.vehicleName ?? 'your vehicle'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          if (enrolment.message != null && enrolment.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '“${enrolment.message}”',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 11),
          _ScopeChips(scope: enrolment.scope),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: busy ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest700,
                  ),
                  child: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.enrolment,
    required this.busy,
    required this.onRevoke,
  });

  final VehicleEnrolment enrolment;
  final bool busy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enrolment.vehiclePlate ?? enrolment.vehicleName ?? 'Vehicle',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'In ${enrolment.organisationName ?? 'a fleet'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onRevoke,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _ScopeChips extends StatelessWidget {
  const _ScopeChips({required this.scope});

  final EnrolmentScope scope;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in scope.labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.forest50,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.forest800,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

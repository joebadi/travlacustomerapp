import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/claims/data/claim_repository.dart';
import 'package:travla_customer_app/features/claims/domain/claim_models.dart';
import 'package:travla_customer_app/features/claims/presentation/claim_widgets.dart';
import 'package:travla_customer_app/shared/widgets/travla_app_bar.dart';

class ClaimsScreen extends ConsumerWidget {
  const ClaimsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(claimsListProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const TravlaAppBar(),
      floatingActionButton: claims.maybeWhen(
        data: (_) => FloatingActionButton.extended(
          backgroundColor: AppColors.orange,
          onPressed: () => context.push('/more/claims/new'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('File a claim'),
        ),
        orElse: () => null,
      ),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: () async {
          ref.invalidate(claimsListProvider);
          await ref.read(claimsListProvider.future).catchError(
            (_) => <InsuranceClaim>[],
          );
        },
        child: claims.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => error is ClaimsUnavailable
              ? const ClaimsComingSoon()
              : ClaimErrorState(
                  message: error is ApiFailure
                      ? error.message
                      : 'Your claims could not be loaded.',
                  onRetry: () => ref.invalidate(claimsListProvider),
                ),
          data: (list) => list.isEmpty
              ? const _EmptyClaims()
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: list.length,
                  itemBuilder: (context, index) =>
                      _ClaimCard(claim: list[index]),
                ),
        ),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim});

  final InsuranceClaim claim;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/more/claims/${claim.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      claim.claimTypeLabel ?? 'Claim',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClaimStatusPill(
                    status: claim.status,
                    label: claim.statusLabel,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (claim.claimNumber != null) claim.claimNumber!,
                  if (claim.vehicleName != null) claim.vehicleName!,
                ].join('  ·  '),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (claim.incidentDate != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 15,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Incident ${_fmtDate(claim.incidentDate)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyClaims extends StatelessWidget {
  const _EmptyClaims();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: const BoxDecoration(
            color: AppColors.forest100,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 34,
            color: AppColors.forest700,
          ),
        ).centered(),
        const SizedBox(height: 18),
        Text(
          'No claims yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'If your insured vehicle is in an incident, file a claim here and track '
          'it from notice to settlement.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => context.push('/more/claims/new'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: AppColors.orange,
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('File a claim'),
        ),
      ],
    );
  }
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

extension on Widget {
  Widget centered() => Align(alignment: Alignment.center, child: this);
}

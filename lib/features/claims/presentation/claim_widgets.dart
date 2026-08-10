import 'package:flutter/material.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';

class ClaimTone {
  const ClaimTone(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

ClaimTone claimStatusTone(String status) => switch (status) {
  'DRAFT' => const ClaimTone(Color(0xFF53615B), Color(0xFFEDF0EF)),
  'PENDING_PAYMENT' => const ClaimTone(AppColors.orangeDark, Color(0xFFFFE9E1)),
  'SUBMITTED' || 'IN_REVIEW' || 'ASSESSMENT' => const ClaimTone(
    AppColors.forest700,
    Color(0xFFDDF2E8),
  ),
  'APPROVED' || 'SETTLED' => const ClaimTone(
    AppColors.forest700,
    Color(0xFFDDF2E8),
  ),
  'REJECTED' => const ClaimTone(AppColors.danger, Color(0xFFFFE3E1)),
  'DISPUTED' => const ClaimTone(AppColors.orangeDark, Color(0xFFFFE9E1)),
  _ => const ClaimTone(Color(0xFF53615B), Color(0xFFEDF0EF)),
};

class ClaimStatusPill extends StatelessWidget {
  const ClaimStatusPill({super.key, required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tone = claimStatusTone(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone.fg,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Staged-rollout gate — shown when the backend reports claims aren't yet
/// available for this account.
class ClaimsComingSoon extends StatelessWidget {
  const ClaimsComingSoon({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                color: AppColors.forest100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gavel_rounded,
                size: 34,
                color: AppColors.forest700,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Claims are coming soon',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Filing insurance claims in the app is being rolled out gradually. '
              'We\'ll let you know the moment it\'s available for your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class ClaimErrorState extends StatelessWidget {
  const ClaimErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A vertical status timeline for the claim lifecycle.
class ClaimTimeline extends StatelessWidget {
  const ClaimTimeline({super.key, required this.status});

  final String status;

  static const _steps = <({String key, String label})>[
    (key: 'SUBMITTED', label: 'Submitted'),
    (key: 'IN_REVIEW', label: 'In review'),
    (key: 'ASSESSMENT', label: 'Assessment'),
    (key: 'DECISION', label: 'Decision'),
    (key: 'SETTLED', label: 'Settled'),
  ];

  int get _reached {
    switch (status) {
      case 'DRAFT':
      case 'PENDING_PAYMENT':
        return -1;
      case 'SUBMITTED':
        return 0;
      case 'IN_REVIEW':
        return 1;
      case 'ASSESSMENT':
        return 2;
      case 'APPROVED':
      case 'REJECTED':
      case 'DISPUTED':
        return 3;
      case 'SETTLED':
        return 4;
      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reached = _reached;
    final rejected = status == 'REJECTED';

    return Column(
      children: List.generate(_steps.length, (i) {
        final step = _steps[i];
        final done = i <= reached;
        final isDecision = step.key == 'DECISION';
        final tone = (isDecision && rejected && i == reached)
            ? AppColors.danger
            : AppColors.forest700;
        final label = (isDecision && i == reached)
            ? (rejected ? 'Decision — declined' : 'Decision — approved')
            : step.label;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: done ? tone : AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? tone : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                  if (i != _steps.length - 1)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: i < reached ? tone : AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  label,
                  style: TextStyle(
                    color: done ? AppColors.ink : AppColors.muted,
                    fontWeight: done ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

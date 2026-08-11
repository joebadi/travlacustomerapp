import 'package:flutter/material.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/features/insurance/domain/insurance_models.dart';

/// Shared error panel for the insurance screens.
class InsuranceErrorState extends StatelessWidget {
  const InsuranceErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 38, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

/// White titled card used to group checkout inputs.
class CheckoutSection extends StatelessWidget {
  const CheckoutSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// A selectable delivery/pickup tile.
class DeliveryMethodTile extends StatelessWidget {
  const DeliveryMethodTile({
    super.key,
    required this.label,
    required this.helper,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String helper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest700 : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.forest700 : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              helper,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: .78)
                    : AppColors.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label/value line for the payment summary.
class SummaryLine extends StatelessWidget {
  const SummaryLine({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? AppColors.ink : AppColors.muted,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
              fontSize: bold ? 15 : 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: bold ? 18 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline red error/notice banner.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5BBB5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A saved insurance policy, with a status tone and optional cancel action.
class PolicyCard extends StatelessWidget {
  const PolicyCard({
    super.key,
    required this.policy,
    this.onCancel,
    this.onRenew,
    this.onViewDocument,
  });

  final InsurancePolicy policy;
  final VoidCallback? onCancel;
  final VoidCallback? onRenew;
  final VoidCallback? onViewDocument;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(policy);
    final title = policy.provider?.isNotEmpty == true
        ? policy.provider!
        : (policy.sourceLabel?.isNotEmpty == true
              ? policy.sourceLabel!
              : 'Insurance policy');
    final expiry = _expiryText(policy);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: source badge + title + policy number.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tone.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    policy.isVerified
                        ? Icons.verified_user_rounded
                        : Icons.shield_outlined,
                    color: tone.fg,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        policy.policyNumber?.isNotEmpty == true
                            ? 'Policy no. ${policy.policyNumber}'
                            : 'No policy number on record',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Badges: status + coverage + verified/source.
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _Chip(label: policy.statusLabel, tone: tone),
                if (policy.coverageLabel != null)
                  _Chip(
                    label: policy.coverageLabel!,
                    tone: const _Tone(Color(0xFF2F6FEB), Color(0xFFE7EDFB)),
                  ),
                if (policy.isVerified)
                  const _Chip(
                    label: 'Verified',
                    tone: _Tone(AppColors.forest700, Color(0xFFDDF2E8)),
                  )
                else if (policy.sourceLabel != null)
                  _Chip(
                    label: policy.sourceLabel!,
                    tone: const _Tone(AppColors.muted, Color(0xFFEDF0EF)),
                  ),
              ],
            ),
            const Divider(height: 24),
            // Details — shown in full, matching the web (premium/excess even at ₦0).
            _Line(label: 'Premium', value: '₦${policy.premiumNaira}'),
            _Line(label: 'Excess', value: '₦${policy.excessNaira}'),
            _Line(label: 'Cover period', value: _period(policy)),
            if (expiry != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tone.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: tone.fg),
                    const SizedBox(width: 6),
                    Text(
                      expiry,
                      style: TextStyle(
                        color: tone.fg,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (policy.hasDocument &&
                onViewDocument != null &&
                policy.documentUrl != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: onViewDocument,
                borderRadius: BorderRadius.circular(8),
                child: const _Tag(
                  icon: Icons.open_in_new_rounded,
                  label: 'View certificate',
                  color: AppColors.forest700,
                ),
              ),
            ],
            if ((onCancel != null && policy.isActive) ||
                (onRenew != null && policy.canRenew)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onCancel != null && policy.isActive)
                    TextButton.icon(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel'),
                    ),
                  const Spacer(),
                  if (onRenew != null && policy.canRenew)
                    FilledButton.icon(
                      onPressed: onRenew,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.autorenew_rounded, size: 18),
                      label: const Text('Renew'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Human expiry line mirroring the web ("Expires in 20 days"). Null for
  /// cancelled policies or when the expiry date is unknown.
  static String? _expiryText(InsurancePolicy p) {
    if (p.status == 'CANCELLED') return null;
    final days = p.daysToExpiry;
    if (p.isExpired) {
      return days != null ? 'Expired ${days.abs()} days ago' : 'Expired';
    }
    if (days == null) return null;
    if (days == 0) return 'Expires today';
    return 'Expires in $days day${days == 1 ? '' : 's'}';
  }

  static String _period(InsurancePolicy p) {
    final start = _fmt(p.startDate);
    final end = _fmt(p.endDate);
    if (start == null && end == null) return '—';
    return '${start ?? '—'}  →  ${end ?? '—'}';
  }

  static String? _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static _Tone _tone(InsurancePolicy p) {
    if (p.status == 'CANCELLED') {
      return const _Tone(AppColors.muted, Color(0xFFEDF0EF));
    }
    if (p.isExpired) {
      return const _Tone(AppColors.danger, Color(0xFFFFE3E1));
    }
    if ((p.daysToExpiry ?? 999) <= 30) {
      return const _Tone(AppColors.orangeDark, Color(0xFFFFE9E1));
    }
    return const _Tone(AppColors.forest700, Color(0xFFDDF2E8));
  }
}

class _Tone {
  const _Tone(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.tone});

  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
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

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/drivers_license/data/drivers_license_repository.dart';
import 'package:travla_customer_app/features/drivers_license/domain/drivers_license.dart';
import 'package:travla_customer_app/shared/widgets/travla_app_bar.dart';

class DriversLicenseScreen extends ConsumerWidget {
  const DriversLicenseScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(driversLicensesProvider);
    await ref.read(driversLicensesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenses = ref.watch(driversLicensesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const TravlaAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/more/drivers-license/add'),
        backgroundColor: AppColors.forest700,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add licence'),
      ),
      body: licenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiFailure
              ? error.message
              : 'Your driver\'s licences could not be loaded.',
          onRetry: () => ref.invalidate(driversLicensesProvider),
        ),
        data: (items) => RefreshIndicator(
          color: AppColors.forest700,
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              const _Heading(),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const _EmptyState()
              else
                ...items.map((license) => _LicenseCard(license: license)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Driver\'s licence',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Keep your licence on file and renew it before it lapses.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _LicenseCard extends StatelessWidget {
  const _LicenseCard({required this.license});

  final DriversLicense license;

  @override
  Widget build(BuildContext context) {
    final tone = _StatusTone.from(license.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest950.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(17, 16, 14, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.forest950, AppColors.forest700],
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  color: AppColors.white,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        license.holderName.isEmpty
                            ? 'Licence holder'
                            : license.holderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        license.licenseClassLabel ?? 'Driver\'s licence',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: license.statusLabel, tone: tone),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Fact(
                        label: 'Licence number',
                        value: license.licenseNumber.isEmpty
                            ? '—'
                            : license.licenseNumber,
                      ),
                    ),
                    Expanded(
                      child: _Fact(
                        label: 'Expires',
                        value: license.expiryDate ?? '—',
                        hint: _expiryHint(license),
                        hintColor: tone.foreground,
                      ),
                    ),
                  ],
                ),
                if (!license.hasDocument) ...[
                  const SizedBox(height: 12),
                  const _InlineNote(
                    'Upload a copy of this licence to be able to renew it.',
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: license.renewable
                          ? AppColors.orange
                          : AppColors.border,
                      foregroundColor: license.renewable
                          ? AppColors.white
                          : AppColors.muted,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: license.renewable
                        ? () => context.push(
                            '/more/drivers-license/${license.id}/renew',
                          )
                        : null,
                    icon: const Icon(Icons.event_repeat_rounded, size: 19),
                    label: Text(
                      license.renewable
                          ? 'Renew licence'
                          : _notRenewableReason(license),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _expiryHint(DriversLicense license) {
    final days = license.daysToExpiry;
    if (days == null) return '';
    if (days < 0) return 'Expired ${-days}d ago';
    if (days == 0) return 'Expires today';
    return 'in ${days}d';
  }

  String _notRenewableReason(DriversLicense license) {
    return switch (license.status) {
      'SUSPENDED' => 'Suspended — cannot renew',
      'REVOKED' => 'Revoked — cannot renew',
      'PENDING_RENEWAL' => 'Renewal in progress',
      _ => license.hasDocument
          ? 'Not due for renewal yet'
          : 'Add a copy to renew',
    };
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.hint,
    this.hintColor,
  });

  final String label;
  final String value;
  final String? hint;
  final Color? hintColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        if (hint != null && hint!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: TextStyle(
              color: hintColor ?? AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.orangeDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.orangeDark,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});

  final String label;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.isEmpty ? 'Unknown' : label,
        style: TextStyle(
          color: tone.foreground,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              color: AppColors.forest100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.badge_outlined,
              size: 30,
              color: AppColors.forest700,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No licence on file',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your driver\'s licence with a clear photo so you can renew it through Travla when it\'s due.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
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

class _StatusTone {
  const _StatusTone(this.foreground, this.background);

  final Color foreground;
  final Color background;

  factory _StatusTone.from(String status) {
    return switch (status) {
      'VALID' => const _StatusTone(AppColors.forest700, Color(0xFFDDF2E8)),
      'EXPIRING_SOON' => const _StatusTone(
        AppColors.orangeDark,
        Color(0xFFFFE9E1),
      ),
      'EXPIRED' ||
      'SUSPENDED' ||
      'REVOKED' => const _StatusTone(AppColors.danger, Color(0xFFFFE3E1)),
      'PENDING_RENEWAL' => const _StatusTone(
        Color(0xFF1D4ED8),
        Color(0xFFDCE7FF),
      ),
      _ => const _StatusTone(Color(0xFF53615B), Color(0xFFEDF0EF)),
    };
  }
}

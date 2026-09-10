import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
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
  String? _removingPolicyId;
  bool _expiredExpanded = true;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  Future<bool> _removePolicy(InsurancePolicy policy) async {
    if (_removingPolicyId != null) return false;
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
    if (confirmed != true || !mounted) return false;

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
    // The list rebuilds without the deleted card, so keep the Dismissible in
    // place rather than letting it run its own removal animation.
    return false;
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

    // Any live (non-pending) cover means an expired policy can no longer be
    // renewed — the user already has current insurance in force.
    final hasActiveCover = active.any((policy) => !policy.isPending);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActivePoliciesHeader(
          count: active.length,
          onAdd: () => context.push('/more/insurance/${widget.vehicleId}/add'),
          onBuy: () => context.push('/more/insurance/${widget.vehicleId}/buy'),
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
        else
          for (var i = 0; i < active.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _policyCard(active[i], allowRenew: true),
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
            _policyCard(expired[i], allowRenew: !hasActiveCover),
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

  Widget _policyCard(InsurancePolicy policy, {required bool allowRenew}) {
    final card = _PolicyCard(
      policy: policy,
      onViewDocument: () => _openDocument(policy.documentUrl),
      onCertificate: () => _openPolicy(policy),
      onEdit: policy.isVerified ? null : () => _openPolicy(policy),
      onRenew: (allowRenew && policy.canRenew)
          ? () => context.push(
              '/more/insurance/${widget.vehicleId}/renew/${policy.id}',
            )
          : null,
    );

    // Swipe left to reveal / confirm removal (replaces the inline Remove link).
    return Dismissible(
      key: ValueKey('policy-${policy.id}'),
      direction: DismissDirection.endToStart,
      background: _SwipeRemoveBackground(
        label: policy.isVerified ? 'Remove' : 'Delete',
      ),
      confirmDismiss: (_) => _removePolicy(policy),
      child: card,
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

/// Active-policies title + two icon actions (add existing / buy new). Each
/// action is icon-only; the first tap expands it to a full labelled button, and
/// a second tap runs it. Opening one collapses the other.
class _ActivePoliciesHeader extends StatefulWidget {
  const _ActivePoliciesHeader({
    required this.count,
    required this.onAdd,
    required this.onBuy,
  });

  final int count;
  final VoidCallback onAdd;
  final VoidCallback onBuy;

  @override
  State<_ActivePoliciesHeader> createState() => _ActivePoliciesHeaderState();
}

class _ActivePoliciesHeaderState extends State<_ActivePoliciesHeader> {
  int? _open; // 0 = add, 1 = buy, null = both collapsed
  Timer? _collapseTimer;

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _handle(int index, VoidCallback action) {
    if (_open == index) {
      action();
      _collapseTimer?.cancel();
      setState(() => _open = null);
      return;
    }
    setState(() => _open = index);
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _open = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
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
        _CountBadge(count: widget.count),
        const Spacer(),
        _ExpandingAction(
          icon: Icons.note_add_outlined,
          label: 'Add existing',
          color: AppColors.forest700,
          expanded: _open == 0,
          onTap: () => _handle(0, widget.onAdd),
        ),
        const SizedBox(width: 8),
        _ExpandingAction(
          icon: Icons.add_shopping_cart_rounded,
          label: 'Buy new',
          color: AppColors.orange,
          expanded: _open == 1,
          onTap: () => _handle(1, widget.onBuy),
        ),
      ],
    );
  }
}

class _ExpandingAction extends StatelessWidget {
  const _ExpandingAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: expanded ? color : color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 8,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: expanded ? Colors.white : color,
                ),
                if (expanded) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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

class _SwipeRemoveBackground extends StatelessWidget {
  const _SwipeRemoveBackground({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.policy,
    required this.onViewDocument,
    required this.onCertificate,
    required this.onEdit,
    required this.onRenew,
  });

  final InsurancePolicy policy;
  final VoidCallback onViewDocument;
  final VoidCallback onCertificate;
  final VoidCallback? onEdit;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(policy);
    final insurer = _insurerLabel(policy);
    final money = <String>[
      if (_hasAmount(policy.premiumNaira)) '₦${policy.premiumNaira}',
    ];

    return Container(
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
          _CertificateThumbnail(
            policy: policy,
            onView: onViewDocument,
            onCertificate: onCertificate,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coverage type on one line (scrolls if it overflows) + the
                // status and verified labels pinned to the top-right.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _MarqueeText(
                        text: policy.coverageLabel ?? 'Insurance policy',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    if (!policy.isPending && policy.isVerified) ...[
                      const _OpaqueBadge(
                        label: 'VERIFIED',
                        color: AppColors.forest700,
                      ),
                      const SizedBox(width: 5),
                    ],
                    _OpaqueBadge(
                      label: policy.isPending
                          ? 'Being arranged'
                          : policy.statusLabel,
                      color: statusColor,
                    ),
                  ],
                ),
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
                  _FactRow(label: 'Insurer', value: insurer),
                  const SizedBox(height: 6),
                  _FactRow(
                    label: 'Policy number',
                    value: policy.policyNumber ?? '—',
                  ),
                  const SizedBox(height: 6),
                  _FactRow(label: 'Cover period', value: _period(policy)),
                  if (money.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _FactRow(label: 'Premium', value: money.first),
                  ],
                  if (_hasAmount(policy.excessNaira)) ...[
                    const SizedBox(height: 6),
                    _FactRow(label: 'Excess', value: '₦${policy.excessNaira}'),
                  ],
                ],
                if (onRenew != null || onEdit != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
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
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(InsurancePolicy policy) {
    if (policy.isPending) return AppColors.orangeDark;
    if (policy.isExpired || policy.status == 'CANCELLED') {
      return AppColors.danger;
    }
    if ((policy.daysToExpiry ?? 999) <= 30) return AppColors.orangeDark;
    return AppColors.forest700;
  }

  static String _insurerLabel(InsurancePolicy policy) {
    final provider = policy.provider?.trim() ?? '';
    if (provider.isEmpty || provider == 'Verified via NIID') return '—';
    return provider;
  }

  static bool _hasAmount(String value) =>
      (double.tryParse(value.replaceAll(',', '').trim()) ?? 0) > 0;

  static String _period(InsurancePolicy policy) {
    final start = _formatDate(policy.startDate);
    final end = _formatDate(policy.endDate);
    return '${start ?? '—'} – ${end ?? '—'}';
  }
}

/// A single, non-wrapping line that scrolls left↔right when the text is wider
/// than the space available, so long coverage names stay on one line.
class _MarqueeText extends StatefulWidget {
  const _MarqueeText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final overflow = painter.width > constraints.maxWidth;
        if (!overflow) {
          if (_controller.isAnimating) _controller.stop();
          return Text(
            widget.text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: widget.style,
          );
        }

        final distance = painter.width - constraints.maxWidth + 8;
        _controller.duration = Duration(
          milliseconds: (distance * 45).round().clamp(2500, 12000),
        );
        if (!_controller.isAnimating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_controller.isAnimating) {
              _controller.repeat(reverse: true);
            }
          });
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(
                  -distance * Curves.easeInOut.transform(_controller.value),
                  0,
                ),
                child: Text(
                  widget.text,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: widget.style,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

const double _thumbW = 84;
const double _thumbH = 106;

class _CertificateThumbnail extends StatelessWidget {
  const _CertificateThumbnail({
    required this.policy,
    required this.onView,
    required this.onCertificate,
  });

  final InsurancePolicy policy;
  final VoidCallback onView;
  final VoidCallback onCertificate;

  @override
  Widget build(BuildContext context) {
    final hasDocument =
        policy.hasDocument && policy.documentUrl?.isNotEmpty == true;

    // The certificate action is overlaid ON the thumbnail (no caption below),
    // so it never leaves whitespace beside the policy facts. Square edges.
    return SizedBox(
      width: _thumbW,
      height: _thumbH,
      child: Material(
        color: hasDocument ? AppColors.ink : AppColors.forest50,
        clipBehavior: Clip.antiAlias,
        child: policy.isPending
            ? const _CertPreview(url: null, mime: null)
            : hasDocument
            ? Stack(
                fit: StackFit.expand,
                children: [
                  // Tap the preview to view the full certificate.
                  InkWell(
                    onTap: onView,
                    child: _CertPreview(
                      url: policy.documentUrl,
                      mime: policy.documentMime,
                    ),
                  ),
                  // A slim "Replace" action pinned to the bottom edge.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _OverlayAction(
                      icon: Icons.autorenew_rounded,
                      label: 'Replace',
                      onTap: onCertificate,
                    ),
                  ),
                ],
              )
            // No certificate yet — the whole tile is the upload action.
            : InkWell(
                onTap: onCertificate,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.file_upload_outlined,
                        color: AppColors.forest700,
                        size: 26,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Upload\nCertificate',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.forest700,
                          fontSize: 10.5,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// A slim translucent action bar overlaid on the bottom of a thumbnail.
class _OverlayAction extends StatelessWidget {
  const _OverlayAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        color: Colors.white.withValues(alpha: .92),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: AppColors.forest700),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.forest700,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders an actual preview of the stored certificate: an image straight from
/// the signed URL, or a PDF's first page rendered to a bitmap (pdfx). Falls back
/// to a neutral icon while loading or if it can't be rendered.
class _CertPreview extends ConsumerStatefulWidget {
  const _CertPreview({required this.url, required this.mime});

  final String? url;
  final String? mime;

  @override
  ConsumerState<_CertPreview> createState() => _CertPreviewState();
}

class _CertPreviewState extends ConsumerState<_CertPreview> {
  // First-page renders are cached across rebuilds (the card rebuilds often).
  static final Map<String, Uint8List> _pdfCache = {};
  Uint8List? _pdfBytes;
  bool _rendering = false;

  bool get _isPdf {
    final mime = widget.mime?.toLowerCase() ?? '';
    if (mime.contains('pdf')) return true;
    if (mime.startsWith('image/')) return false;
    return (widget.url ?? '').toLowerCase().contains('.pdf');
  }

  @override
  void initState() {
    super.initState();
    if (widget.url != null && _isPdf) _loadPdf();
  }

  @override
  void didUpdateWidget(covariant _CertPreview old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _pdfBytes = null;
      if (widget.url != null && _isPdf) _loadPdf();
    }
  }

  Future<void> _loadPdf() async {
    final url = widget.url!;
    final cached = _pdfCache[url];
    if (cached != null) {
      setState(() => _pdfBytes = cached);
      return;
    }
    if (_rendering) return;
    _rendering = true;
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final doc = await PdfDocument.openData(
        Uint8List.fromList(response.data ?? const []),
      );
      final page = await doc.getPage(1);
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      await doc.close();
      final bytes = image?.bytes;
      if (bytes != null) _pdfCache[url] = bytes;
      if (mounted) setState(() => _pdfBytes = bytes);
    } catch (_) {
      // Leave the placeholder in place.
    } finally {
      _rendering = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url == null) return const _PreviewFallback();

    if (_isPdf) {
      if (_pdfBytes != null) {
        return Image.memory(_pdfBytes!, fit: BoxFit.cover, width: _thumbW);
      }
      return const _PreviewFallback();
    }

    return Image.network(
      widget.url!,
      fit: BoxFit.cover,
      width: _thumbW,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _PreviewFallback(),
      errorBuilder: (_, _, _) => const _PreviewFallback(),
    );
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F8F7), Color(0xFFE7EEEA)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.description_outlined,
          color: AppColors.forest700,
          size: 26,
        ),
      ),
    );
  }
}

/// Label on the left, value pinned to the far right of the same line.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// A fully-opaque status/verified pill with white text.
class _OpaqueBadge extends StatelessWidget {
  const _OpaqueBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          letterSpacing: .3,
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
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

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

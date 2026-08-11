import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/data/enrolment_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/enrolment_models.dart';

/// Org-side screen: request enrolment of a vehicle by plate number, and see the
/// requests this fleet has already sent (with the ability to withdraw pending
/// ones). If the plate belongs to a member the vehicle is added immediately.
class RequestEnrolmentScreen extends ConsumerStatefulWidget {
  const RequestEnrolmentScreen({super.key, required this.organisationId});

  final String organisationId;

  @override
  ConsumerState<RequestEnrolmentScreen> createState() =>
      _RequestEnrolmentScreenState();
}

class _RequestEnrolmentScreenState
    extends ConsumerState<RequestEnrolmentScreen> {
  final _plate = TextEditingController();
  final _department = TextEditingController();
  final _message = TextEditingController();
  bool _submitting = false;
  String? _busyCancelId;

  @override
  void dispose() {
    _plate.dispose();
    _department.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final plate = _plate.text.trim();
    if (plate.isEmpty) {
      _snack('Enter the vehicle plate number.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final enrolment = await ref
          .read(enrolmentRepositoryProvider)
          .request(
            widget.organisationId,
            plateNumber: plate,
            department: _department.text,
            message: _message.text,
          );
      ref.invalidate(orgEnrolmentsProvider(widget.organisationId));
      if (!mounted) return;
      _plate.clear();
      _department.clear();
      _message.clear();
      _snack(
        enrolment.isApproved
            ? 'Vehicle added to your fleet.'
            : 'Request sent — waiting for the owner to approve.',
      );
    } on ApiFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(VehicleEnrolment e) async {
    setState(() => _busyCancelId = e.id);
    try {
      await ref
          .read(enrolmentRepositoryProvider)
          .cancel(widget.organisationId, e.id);
      ref.invalidate(orgEnrolmentsProvider(widget.organisationId));
    } on ApiFailure catch (f) {
      _snack(f.message);
    } finally {
      if (mounted) setState(() => _busyCancelId = null);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final sent = ref.watch(orgEnrolmentsProvider(widget.organisationId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Enrol a vehicle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.forest50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Enter a vehicle plate to add it to your fleet. If it belongs to '
              'someone outside your company, they get a consent request first — '
              'ownership stays with them.',
              style: TextStyle(
                color: AppColors.forest800,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _plate,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Plate number',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _department,
            decoration: const InputDecoration(
              labelText: 'Department (optional)',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _message,
            maxLines: 2,
            maxLength: 280,
            decoration: const InputDecoration(
              labelText: 'Note to the owner (optional)',
              prefixIcon: Icon(Icons.chat_bubble_outline),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: AppColors.forest700,
              ),
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Sending…' : 'Send enrolment request'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'REQUESTS SENT',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          sent.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              e is ApiFailure ? e.message : 'Could not load requests.',
              style: const TextStyle(color: AppColors.muted),
            ),
            data: (list) => list.isEmpty
                ? const Text(
                    'No requests yet.',
                    style: TextStyle(color: AppColors.muted),
                  )
                : Column(
                    children: [
                      for (final e in list)
                        _SentCard(
                          enrolment: e,
                          busy: _busyCancelId == e.id,
                          onCancel: e.isPending ? () => _cancel(e) : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard({
    required this.enrolment,
    required this.busy,
    required this.onCancel,
  });

  final VehicleEnrolment enrolment;
  final bool busy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (enrolment.status) {
      'APPROVED' => (AppColors.forest700, const Color(0xFFDDF2E8)),
      'PENDING' => (AppColors.orangeDark, const Color(0xFFFFE9E1)),
      'DECLINED' || 'REVOKED' => (AppColors.danger, const Color(0xFFFFE3E1)),
      _ => (AppColors.muted, const Color(0xFFEDF0EF)),
    };

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
                if (enrolment.ownerName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Owner: ${enrolment.ownerName}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              enrolment.statusLabel,
              style: TextStyle(
                color: fg,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (onCancel != null)
            IconButton(
              onPressed: busy ? null : onCancel,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Withdraw',
              color: AppColors.muted,
            ),
        ],
      ),
    );
  }
}

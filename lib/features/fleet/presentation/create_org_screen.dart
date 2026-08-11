import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';

class CreateOrgScreen extends ConsumerStatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  ConsumerState<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends ConsumerState<CreateOrgScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _billingCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regCtrl.dispose();
    _billingCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final id = await ref.read(fleetRepositoryProvider).createOrganisation(
            name: _nameCtrl.text,
            registrationNumber: _regCtrl.text,
            billingAddress: _billingCtrl.text,
          );
      ref.invalidate(fleetHomeProvider);
      if (!mounted) return;
      if (id.isEmpty) {
        context.pop();
      } else {
        context.pushReplacement('/more/fleet/$id');
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('New fleet company')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: AppColors.forest50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.forest100)),
              child: const Text(
                'Creating a fleet company requires a verified NIN and matching bank account on your profile.',
                style: TextStyle(color: AppColors.forest800, fontSize: 12, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: const Color(0xFFFFE3E1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Company name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the company name.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _regCtrl,
              decoration: const InputDecoration(labelText: 'RC / registration number (optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _billingCtrl,
              decoration: const InputDecoration(labelText: 'Billing address (optional)'),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppColors.forest700),
              child: Text(_submitting ? 'Creating…' : 'Create company', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

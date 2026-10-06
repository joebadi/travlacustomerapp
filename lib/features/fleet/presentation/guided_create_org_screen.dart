import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';

class GuidedCreateOrgScreen extends ConsumerStatefulWidget {
  const GuidedCreateOrgScreen({super.key});

  @override
  ConsumerState<GuidedCreateOrgScreen> createState() =>
      _GuidedCreateOrgScreenState();
}

class _GuidedCreateOrgScreenState extends ConsumerState<GuidedCreateOrgScreen> {
  final _companyForm = GlobalKey<FormState>();
  final _regionForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _registration = TextEditingController();
  final _billing = TextEditingController();
  final _regionName = TextEditingController();
  final _regionState = TextEditingController();

  int _step = 0;
  bool _addFirstRegion = true;
  bool _continueToVehicle = true;
  bool _submitting = false;
  bool _regionCreated = false;
  String? _createdOrganisationId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _registration.dispose();
    _billing.dispose();
    _regionName.dispose();
    _regionState.dispose();
    super.dispose();
  }

  void _continue() {
    setState(() => _error = null);
    if (_step == 0 && !(_companyForm.currentState?.validate() ?? false)) {
      return;
    }
    if (_step == 1 &&
        _addFirstRegion &&
        !(_regionForm.currentState?.validate() ?? false)) {
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_submitting) return;
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _finish() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      var organisationId = _createdOrganisationId;
      if (organisationId == null) {
        organisationId = await ref
            .read(fleetRepositoryProvider)
            .createOrganisation(
              name: _name.text,
              registrationNumber: _registration.text,
              billingAddress: _billing.text,
            );
        if (organisationId.isEmpty) {
          throw const ApiFailure(
            'Travla did not return the new Fleet workspace. Refresh Fleet and try again.',
          );
        }
        _createdOrganisationId = organisationId;
      }

      if (_addFirstRegion && !_regionCreated) {
        await ref
            .read(fleetRepositoryProvider)
            .addRegion(
              organisationId,
              name: _regionName.text,
              state: _regionState.text,
            );
        _regionCreated = true;
      }

      ref.invalidate(fleetHomeProvider);
      ref.invalidate(fleetOrgProvider(organisationId));
      ref.invalidate(fleetRegionsProvider(organisationId));
      if (!mounted) return;
      context.go(
        _continueToVehicle
            ? '/more/fleet/$organisationId/enrol'
            : '/more/fleet/$organisationId',
      );
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error =
            _createdOrganisationId != null && _addFirstRegion && !_regionCreated
            ? 'The company was created, but region setup did not finish. ${failure.message} Retry to continue without creating a duplicate company.'
            : failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: IconButton(
          tooltip: _step == 0 ? 'Close' : 'Back',
          onPressed: _back,
          icon: Icon(
            _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
          ),
        ),
        title: const Text('Set up Fleet company'),
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _ErrorBanner(message: _error!),
            ),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(
                  context,
                ).colorScheme.copyWith(primary: AppColors.forest700),
              ),
              child: Stepper(
                currentStep: _step,
                onStepTapped: _submitting
                    ? null
                    : (step) {
                        if (step < _step) setState(() => _step = step);
                      },
                controlsBuilder: (context, details) => Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : _continue,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: AppColors.forest700,
                          ),
                          icon: _submitting
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _step == 2
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                ),
                          label: Text(
                            _submitting
                                ? 'Creating…'
                                : _step == 2
                                ? 'Create company'
                                : 'Continue',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                steps: [
                  Step(
                    title: const Text('Company identity'),
                    subtitle: const Text('Name and business details'),
                    isActive: _step >= 0,
                    state: _step > 0 ? StepState.complete : StepState.indexed,
                    content: Form(
                      key: _companyForm,
                      child: _CompanyFields(
                        name: _name,
                        registration: _registration,
                        billing: _billing,
                      ),
                    ),
                  ),
                  Step(
                    title: const Text('First operating region'),
                    subtitle: const Text(
                      'Recommended for access and assignments',
                    ),
                    isActive: _step >= 1,
                    state: _step > 1 ? StepState.complete : StepState.indexed,
                    content: Form(
                      key: _regionForm,
                      child: _RegionFields(
                        enabled: _addFirstRegion,
                        name: _regionName,
                        state: _regionState,
                        onEnabledChanged: (value) =>
                            setState(() => _addFirstRegion = value),
                      ),
                    ),
                  ),
                  Step(
                    title: const Text('Review and launch'),
                    subtitle: const Text('Confirm the initial workspace'),
                    isActive: _step >= 2,
                    content: _Review(
                      companyName: _name.text.trim(),
                      registration: _registration.text.trim(),
                      billing: _billing.text.trim(),
                      region: _addFirstRegion ? _regionName.text.trim() : null,
                      state: _regionState.text.trim(),
                      continueToVehicle: _continueToVehicle,
                      onContinueChanged: (value) =>
                          setState(() => _continueToVehicle = value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyFields extends StatelessWidget {
  const _CompanyFields({
    required this.name,
    required this.registration,
    required this.billing,
  });

  final TextEditingController name;
  final TextEditingController registration;
  final TextEditingController billing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Notice(
          'A verified NIN and matching bank account are required. CAC/RC numbers remain marked unverified until an approved verifier is connected.',
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Legal or trading name',
            prefixIcon: Icon(Icons.business_outlined),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter the company name.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: registration,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'CAC / RC number (optional)',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: billing,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Billing address (optional)',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
      ],
    );
  }
}

class _RegionFields extends StatelessWidget {
  const _RegionFields({
    required this.enabled,
    required this.name,
    required this.state,
    required this.onEnabledChanged,
  });

  final bool enabled;
  final TextEditingController name;
  final TextEditingController state;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Notice(
          'Regions separate vehicles, drivers and manager visibility by branch, city, state or depot.',
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: onEnabledChanged,
          title: const Text(
            'Add a region now',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Region name',
              hintText: 'e.g. Lagos operations',
              prefixIcon: Icon(Icons.hub_outlined),
            ),
            validator: (value) => !enabled
                ? null
                : value == null || value.trim().isEmpty
                ? 'Enter the first region name.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: state,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'State (optional)',
              prefixIcon: Icon(Icons.map_outlined),
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'You can create regions later from Fleet web administration.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _Review extends StatelessWidget {
  const _Review({
    required this.companyName,
    required this.registration,
    required this.billing,
    required this.region,
    required this.state,
    required this.continueToVehicle,
    required this.onContinueChanged,
  });

  final String companyName;
  final String registration;
  final String billing;
  final String? region;
  final String state;
  final bool continueToVehicle;
  final ValueChanged<bool> onContinueChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReviewCard(
          icon: Icons.business_outlined,
          title: companyName,
          detail: registration.isEmpty
              ? 'CAC / RC number not provided'
              : '$registration · unverified',
        ),
        const SizedBox(height: 10),
        _ReviewCard(
          icon: Icons.hub_outlined,
          title: region ?? 'Region setup deferred',
          detail: region == null
              ? 'Configure regions later on web'
              : state.isEmpty
              ? 'State not specified'
              : state,
        ),
        if (billing.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ReviewCard(
            icon: Icons.receipt_long_outlined,
            title: 'Billing address',
            detail: billing,
          ),
        ],
        const SizedBox(height: 10),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.forest700,
          value: continueToVehicle,
          onChanged: (value) => onContinueChanged(value ?? false),
          title: const Text(
            'Continue to add the first vehicle',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text(
            'Add your vehicle or request its owner’s consent by plate.',
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.forest100),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.forest800,
          fontSize: 11.5,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.forest700),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
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
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

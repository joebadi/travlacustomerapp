import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/claims/data/claim_repository.dart';
import 'package:travla_customer_app/features/claims/domain/claim_models.dart';
import 'package:travla_customer_app/features/claims/presentation/claim_widgets.dart';
import 'package:travla_customer_app/features/vehicles/data/garage_repository.dart';
import 'package:travla_customer_app/features/vehicles/domain/garage_snapshot.dart';
import 'package:travla_customer_app/shared/widgets/travla_app_bar.dart';

/// A locally-captured piece of scene evidence, held on-device until the draft
/// exists and it can be uploaded.
class _Media {
  const _Media(this.path, this.type); // type: PHOTO | VIDEO

  final String path;
  final String type;
}

/// Guided claim filing. Built for the heat of the moment: pick the vehicle,
/// capture the scene first, then the other vehicle's cover (auto-checked on
/// NIID), an eligibility verdict, the details, and a review. Evidence is held
/// locally and uploaded when the draft is created on the final step.
class NewClaimScreen extends ConsumerStatefulWidget {
  const NewClaimScreen({super.key, this.vehicleId});

  final String? vehicleId;

  @override
  ConsumerState<NewClaimScreen> createState() => _NewClaimScreenState();
}

class _NewClaimScreenState extends ConsumerState<NewClaimScreen> {
  static const _steps = ['Scene', 'Other vehicle', 'Eligibility', 'Details', 'Review'];

  int _step = 0;

  // Scene
  String? _vehicleId;
  DateTime _incidentDate = DateTime.now();
  String? _coords;
  bool _locating = false;
  final List<_Media> _media = [];
  bool _capturing = false;

  // Other vehicle
  bool _thirdParty = false;
  String? _fault;
  final _otherPlateCtrl = TextEditingController();
  PlateCheckResult? _plateResult;
  bool _plateChecking = false;

  // Eligibility
  ClaimEligibility? _eligibility;
  bool _assessing = false;
  String? _assessError;
  bool _liabilityAccepted = false;

  // Details
  String? _claimType;
  String? _severity;
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _damageCtrl = TextEditingController();
  final _policeCtrl = TextEditingController();
  final _estimateCtrl = TextEditingController();
  final _witnessCtrl = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vehicleId = (widget.vehicleId?.isNotEmpty ?? false) ? widget.vehicleId : null;
    _captureLocation();
  }

  @override
  void dispose() {
    _otherPlateCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _damageCtrl.dispose();
    _policeCtrl.dispose();
    _estimateCtrl.dispose();
    _witnessCtrl.dispose();
    super.dispose();
  }

  bool get _otherPartyInsured => _plateResult?.found ?? false;

  // ---- Scene ---------------------------------------------------------------

  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var p = await Geolocator.checkPermission();
        if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
        if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          _coords = '${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';
        }
      }
    } catch (_) {
      // Location is a nicety, never a blocker.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _capturePhoto() => _capture(() async {
        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
        return x == null ? null : _Media(x.path, 'PHOTO');
      });

  Future<void> _captureVideo() => _capture(() async {
        final x = await ImagePicker().pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 60),
        );
        return x == null ? null : _Media(x.path, 'VIDEO');
      });

  Future<void> _pickFromGallery() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final images = await ImagePicker().pickMultiImage(imageQuality: 70);
      if (images.isNotEmpty) {
        setState(() => _media.addAll(images.map((x) => _Media(x.path, 'PHOTO'))));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _capture(Future<_Media?> Function() pick) async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final media = await pick();
      if (media != null) setState(() => _media.add(media));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_incidentDate),
    );
    setState(() {
      _incidentDate = DateTime(
        picked.year, picked.month, picked.day,
        time?.hour ?? _incidentDate.hour, time?.minute ?? _incidentDate.minute,
      );
    });
  }

  // ---- Other vehicle -------------------------------------------------------

  Future<void> _checkPlate() async {
    final plate = _otherPlateCtrl.text.trim();
    if (plate.isEmpty || _plateChecking) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _plateChecking = true;
      _plateResult = null;
    });
    try {
      final result = await ref.read(claimRepositoryProvider).plateCheck(plate);
      if (mounted) setState(() => _plateResult = result);
    } on ApiFailure catch (f) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      }
    } finally {
      if (mounted) setState(() => _plateChecking = false);
    }
  }

  // ---- Eligibility ---------------------------------------------------------

  Future<void> _assess() async {
    if (_vehicleId == null) return;
    setState(() {
      _assessing = true;
      _assessError = null;
    });
    try {
      final verdict = await ref.read(claimRepositoryProvider).eligibility(
            vehicleId: _vehicleId!,
            thirdPartyInvolved: _thirdParty,
            fault: _thirdParty ? _fault : null,
            otherPartyInsured: _thirdParty && _otherPartyInsured,
            claimType: _claimType,
          );
      if (mounted) setState(() => _eligibility = verdict);
    } on ApiFailure catch (f) {
      if (mounted) setState(() => _assessError = f.message);
    } finally {
      if (mounted) setState(() => _assessing = false);
    }
  }

  // ---- Submit --------------------------------------------------------------

  Future<void> _submit() async {
    if (_vehicleId == null || _claimType == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'claim_type': _claimType,
      'incident_date': _ymd(_incidentDate),
      'location': _locationCtrl.text.trim(),
      if (_coords != null) 'location_coordinates': _coords,
      'description': _descriptionCtrl.text.trim(),
      if (_severity != null) 'severity': _severity,
      if (_damageCtrl.text.trim().isNotEmpty) 'damage_description': _damageCtrl.text.trim(),
      if (_policeCtrl.text.trim().isNotEmpty) 'police_report_number': _policeCtrl.text.trim(),
      'third_party_involved': _thirdParty,
      if (_thirdParty && _fault != null) 'fault': _fault,
      if (_thirdParty && _otherPlateCtrl.text.trim().isNotEmpty)
        'other_vehicle_plate': _otherPlateCtrl.text.trim(),
      if (_thirdParty) 'other_vehicle_details': _otherVehicleDetails(),
      if (_liabilityAccepted) 'liability_accepted': true,
      if (_witnessCtrl.text.trim().isNotEmpty) 'witness_info': _witnessCtrl.text.trim(),
      if (_kobo(_estimateCtrl.text) != null) 'estimated_cost_kobo': _kobo(_estimateCtrl.text),
    };

    try {
      final repo = ref.read(claimRepositoryProvider);
      final claim = await repo.createDraft(vehicleId: _vehicleId!, payload: payload);
      // Upload the scene media captured earlier — best effort, so one bad file
      // never blocks the draft the user has already committed.
      for (final m in _media) {
        try {
          await repo.uploadEvidencePath(
            claimId: claim.id,
            path: m.path,
            filename: m.path.split('/').last,
            fileType: m.type,
          );
        } catch (_) {}
      }
      ref.invalidate(claimsListProvider);
      if (!mounted) return;
      context.pushReplacement('/more/claims/${claim.id}');
    } on ClaimsUnavailable {
      if (mounted) {
        setState(() {
          _error = 'The claims feature is not available for your account yet.';
          _submitting = false;
        });
      }
    } on ApiFailure catch (f) {
      if (mounted) {
        setState(() {
          _error = f.message;
          _submitting = false;
        });
      }
    }
  }

  Map<String, dynamic>? _otherVehicleDetails() {
    final insured = _plateResult?.found ?? false;
    final details = <String, dynamic>{
      if (insured)
        'insurer': _plateResult!.policies.firstOrNull?.coverageLabel ?? 'Insured (NIID)',
      if (_plateResult != null) 'niid_status': _plateResult!.outcome,
    };
    return details.isEmpty ? null : details;
  }

  // ---- Navigation ----------------------------------------------------------

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _vehicleId != null;
      case 1:
        return !_thirdParty || _fault != null;
      case 2:
        if (_eligibility?.requiresLiability ?? false) return _liabilityAccepted;
        return _eligibility != null && !_assessing;
      case 3:
        return _claimType != null &&
            _descriptionCtrl.text.trim().isNotEmpty &&
            _locationCtrl.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void _next() {
    if (_step == 0 && _vehicleId == null) {
      setState(() => _error = 'Choose the vehicle involved.');
      return;
    }
    if (_step == 3 && !_canContinue) {
      setState(() => _error = 'Add the claim type, what happened, and where.');
      return;
    }
    setState(() => _error = null);
    if (_step == _steps.length - 1) {
      _submit();
      return;
    }
    setState(() => _step++);
    if (_step == 2) _assess();
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() {
      _error = null;
      _step--;
    });
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(claimMetaProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const TravlaAppBar(),
      body: meta.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => error is ClaimsUnavailable
            ? const ClaimsComingSoon()
            : ClaimErrorState(
                message: error is ApiFailure ? error.message : 'The claim form could not be loaded.',
                onRetry: () => ref.invalidate(claimMetaProvider),
              ),
        data: (meta) => Column(
          children: [
            _StepHeader(steps: _steps, current: _step),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_error != null) ...[_Banner(_error!), const SizedBox(height: 14)],
                  ..._stepBody(meta),
                ],
              ),
            ),
            _BottomBar(
              step: _step,
              total: _steps.length,
              busy: _submitting,
              canContinue: _canContinue,
              onBack: _submitting ? null : _back,
              onNext: (_submitting || !_canContinue) ? null : _next,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _stepBody(ClaimMeta meta) {
    switch (_step) {
      case 0:
        return _sceneStep();
      case 1:
        return _otherVehicleStep();
      case 2:
        return _eligibilityStep();
      case 3:
        return _detailsStep(meta);
      default:
        return _reviewStep(meta);
    }
  }

  // ---- Step 0: Scene -------------------------------------------------------

  List<Widget> _sceneStep() {
    final garage = ref.watch(garageProvider);
    return [
      const _Label('Vehicle involved'),
      garage.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text('Vehicles could not be loaded.', style: TextStyle(color: AppColors.muted)),
        data: (snapshot) => _VehiclePicker(
          vehicles: snapshot.vehicles,
          value: _vehicleId,
          onChanged: (v) => setState(() => _vehicleId = v),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          const Expanded(child: _Label('Capture the scene')),
          if (_locating)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          else if (_coords != null)
            const _Chip(icon: Icons.my_location_rounded, label: 'Location pinned'),
        ],
      ),
      const Text(
        'Take photos and a short video now — of the damage, plates, road and signs. '
        'You can add more later.',
        style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _CaptureButton(icon: Icons.photo_camera_rounded, label: 'Photo', onTap: _capturing ? null : _capturePhoto)),
          const SizedBox(width: 10),
          Expanded(child: _CaptureButton(icon: Icons.videocam_rounded, label: 'Video', onTap: _capturing ? null : _captureVideo)),
          const SizedBox(width: 10),
          Expanded(child: _CaptureButton(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: _capturing ? null : _pickFromGallery)),
        ],
      ),
      if (_media.isNotEmpty) ...[
        const SizedBox(height: 14),
        _MediaGrid(media: _media, onRemove: (i) => setState(() => _media.removeAt(i))),
      ],
      const SizedBox(height: 20),
      const _Label('When did it happen?'),
      _DateTile(value: _incidentDate, onTap: _pickDate),
    ];
  }

  // ---- Step 1: Other vehicle ----------------------------------------------

  List<Widget> _otherVehicleStep() {
    return [
      const _Label('Another vehicle or party'),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppColors.forest700,
        title: const Text('Another vehicle was involved', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: const Text('Turn off for a single-vehicle incident (theft, fire, hit an object).',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        value: _thirdParty,
        onChanged: (v) => setState(() {
          _thirdParty = v;
          _eligibility = null; // inputs changed — re-assess later
        }),
      ),
      if (_thirdParty) ...[
        const SizedBox(height: 8),
        const _Label('Their plate number'),
        TextField(
          controller: _otherPlateCtrl,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _checkPlate(),
          decoration: InputDecoration(
            hintText: 'e.g. ABC123XY',
            prefixIcon: const Icon(Icons.pin_outlined),
            suffixIcon: TextButton(
              onPressed: _plateChecking ? null : _checkPlate,
              child: _plateChecking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Check cover'),
            ),
          ),
          onChanged: (_) => setState(() {
            _plateResult = null;
            _eligibility = null;
          }),
        ),
        if (_plateResult != null) ...[
          const SizedBox(height: 12),
          _NiidCard(result: _plateResult!),
        ],
        // NIID didn't confirm cover. Rather than hand-enter details (error-prone
        // and unverifiable), let them re-run the check — the plate above is
        // editable, so a typo can be fixed and checked again.
        if (_plateResult != null && !_plateResult!.found) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _plateChecking ? null : _checkPlate,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: AppColors.forest700,
              side: const BorderSide(color: AppColors.forest700),
            ),
            icon: _plateChecking
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            label: const Text('Check again'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Fix the plate above if it was mistyped, then check again.',
            style: TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 20),
        const _Label('Who was at fault?'),
        _FaultSelector(value: _fault, onChanged: (v) => setState(() {
          _fault = v;
          _eligibility = null;
        })),
      ],
    ];
  }

  // ---- Step 2: Eligibility -------------------------------------------------

  List<Widget> _eligibilityStep() {
    if (_assessing) {
      return const [Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))];
    }
    if (_assessError != null) {
      return [
        ClaimErrorState(message: _assessError!, onRetry: _assess),
      ];
    }
    final e = _eligibility;
    if (e == null) {
      return [
        const SizedBox(height: 20),
        Center(
          child: FilledButton(
            onPressed: _assess,
            style: FilledButton.styleFrom(backgroundColor: AppColors.forest700),
            child: const Text('Check eligibility'),
          ),
        ),
      ];
    }
    return [
      _VerdictCard(eligibility: e),
      const SizedBox(height: 14),
      _CoverageRow(eligibility: e),
      if (e.requiresLiability) ...[
        const SizedBox(height: 16),
        _LiabilityCheck(
          value: _liabilityAccepted,
          onChanged: (v) => setState(() => _liabilityAccepted = v),
        ),
      ],
      if (e.isDeadEnd) ...[
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.go('/more'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.forest700,
            side: const BorderSide(color: AppColors.forest700),
          ),
          icon: const Icon(Icons.support_agent_rounded),
          label: const Text('Get help from support'),
        ),
        const SizedBox(height: 8),
        const Text(
          'You can still continue to keep a record of the incident.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ];
  }

  // ---- Step 3: Details -----------------------------------------------------

  List<Widget> _detailsStep(ClaimMeta meta) {
    return [
      const _Label('Incident'),
      DropdownButtonFormField<String>(
        initialValue: _claimType,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Claim type'),
        items: meta.types.map((t) => DropdownMenuItem(value: t.value, child: Text(t.label))).toList(),
        onChanged: (v) => setState(() => _claimType = v),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _locationCtrl,
        decoration: const InputDecoration(
          labelText: 'Where did it happen?',
          prefixIcon: Icon(Icons.location_on_outlined),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _descriptionCtrl,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'What happened?', alignLabelWithHint: true),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: _severity,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Severity (optional)'),
        items: meta.severities.map((s) => DropdownMenuItem(value: s, child: Text(_titleCase(s)))).toList(),
        onChanged: (v) => setState(() => _severity = v),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _damageCtrl,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Damage description (optional)', alignLabelWithHint: true),
      ),
      const SizedBox(height: 18),
      const _Label('More (optional)'),
      TextField(
        controller: _policeCtrl,
        decoration: const InputDecoration(labelText: 'Police report number'),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _estimateCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: const InputDecoration(labelText: 'Estimated repair cost ₦'),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _witnessCtrl,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Witness details', alignLabelWithHint: true),
      ),
    ];
  }

  // ---- Step 4: Review ------------------------------------------------------

  List<Widget> _reviewStep(ClaimMeta meta) {
    final typeLabel = meta.types.where((t) => t.value == _claimType).map((t) => t.label).firstOrNull ?? '—';
    return [
      _ReviewTile(label: 'Claim type', value: typeLabel),
      _ReviewTile(label: 'When', value: _prettyDateTime(_incidentDate)),
      _ReviewTile(label: 'Where', value: _locationCtrl.text.trim().isEmpty ? '—' : _locationCtrl.text.trim()),
      _ReviewTile(label: 'Scene evidence', value: '${_media.length} file${_media.length == 1 ? '' : 's'}'),
      _ReviewTile(
        label: 'Other vehicle',
        value: !_thirdParty
            ? 'None (single vehicle)'
            : '${_otherPlateCtrl.text.trim().isEmpty ? 'Unknown plate' : _otherPlateCtrl.text.trim()} · '
                '${_otherPartyInsured ? 'insured' : 'no cover found'}',
      ),
      if (_thirdParty) _ReviewTile(label: 'Fault', value: _faultLabel(_fault)),
      if (_eligibility != null) _ReviewTile(label: 'Verdict', value: _eligibility!.title),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.forest50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.forest100),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.forest700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Filing saves a draft and uploads your ${_media.length} scene file${_media.length == 1 ? '' : 's'}. '
                'You pay the police-report fee (₦${meta.policeReportFeeNaira}) to submit on the next screen.',
                style: const TextStyle(color: AppColors.forest800, fontSize: 11.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int? _kobo(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', ''));
    return value == null ? null : (value * 100).round();
  }
}

String _titleCase(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _faultLabel(String? f) => switch (f) {
      'SELF' => 'I was at fault',
      'OTHER' => 'The other party',
      'SHARED' => 'Shared fault',
      'UNSURE' => 'Not sure yet',
      _ => '—',
    };

String _prettyDateTime(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour < 12 ? 'AM' : 'PM';
  return '${d.day} ${months[d.month - 1]} ${d.year}, $h:$m $ap';
}

// ===========================================================================
//  Presentational widgets
// ===========================================================================

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.steps, required this.current});

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: AppColors.white,
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length, (i) {
              final done = i < current;
              final active = i == current;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: done || active ? AppColors.forest700 : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Step ${current + 1} of ${steps.length}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
              Text(steps[current],
                  style: const TextStyle(color: AppColors.ink, fontSize: 12.5, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.total,
    required this.busy,
    required this.canContinue,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final int total;
  final bool busy;
  final bool canContinue;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = step == total - 1;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(96, 52),
                side: const BorderSide(color: AppColors.border),
                foregroundColor: AppColors.ink,
              ),
              child: Text(step == 0 ? 'Cancel' : 'Back'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.orange,
                  disabledBackgroundColor: AppColors.orange.withValues(alpha: .4),
                ),
                child: Text(
                  busy ? 'Filing…' : (isLast ? 'File claim' : 'Continue'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.forest50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.forest100),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.forest700, size: 24),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: AppColors.forest800, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.media, required this.onRemove});

  final List<_Media> media;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(media.length, (i) {
        final m = media[i];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 84,
                height: 84,
                child: m.type == 'PHOTO'
                    ? Image.file(File(m.path), fit: BoxFit.cover)
                    : Container(
                        color: AppColors.forest700,
                        child: const Icon(Icons.play_circle_fill_rounded, color: AppColors.white, size: 30),
                      ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => onRemove(i),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _NiidCard extends StatelessWidget {
  const _NiidCard({required this.result});

  final PlateCheckResult result;

  @override
  Widget build(BuildContext context) {
    final found = result.found;
    final inconclusive = result.inconclusive;
    final Color bg;
    final Color fg;
    final IconData icon;
    final String title;
    final String subtitle;

    if (found) {
      bg = AppColors.forest50;
      fg = AppColors.forest700;
      icon = Icons.verified_user_rounded;
      final cover = result.policies.firstOrNull?.coverageLabel;
      title = 'Insured on NIID';
      subtitle = cover != null
          ? 'Cover: $cover. Your claim can be filed against their insurer.'
          : 'Active cover found. Your claim can be filed against their insurer.';
    } else if (inconclusive) {
      bg = const Color(0xFFFFF3EC);
      fg = AppColors.orangeDark;
      icon = Icons.help_outline_rounded;
      title = 'Couldn\'t confirm on NIID';
      subtitle = 'The check didn\'t complete. Try again in a moment.';
    } else {
      bg = const Color(0xFFFFE3E1);
      fg = AppColors.danger;
      icon = Icons.gpp_bad_rounded;
      title = 'No cover found on NIID';
      subtitle = 'NIID has no active policy for this plate. Double-check the plate and try again.';
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: fg.withValues(alpha: .85), fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaultSelector extends StatelessWidget {
  const _FaultSelector({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('OTHER', 'The other party'),
    ('SELF', 'I was at fault'),
    ('SHARED', 'Shared fault'),
    ('UNSURE', 'Not sure yet'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _options.map((o) {
        final selected = value == o.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => onChanged(o.$1),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.forest700 : AppColors.border,
                  width: selected ? 1.6 : 1,
                ),
                color: selected ? AppColors.forest50 : AppColors.white,
              ),
              child: Row(
                children: [
                  Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      size: 20, color: selected ? AppColors.forest700 : AppColors.muted),
                  const SizedBox(width: 12),
                  Text(o.$2, style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.forest700 : AppColors.ink,
                    fontSize: 13.5,
                  )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.eligibility});

  final ClaimEligibility eligibility;

  @override
  Widget build(BuildContext context) {
    final ok = eligibility.canBenefit;
    final block = eligibility.isDeadEnd;
    final Color bg = block ? const Color(0xFFFFE3E1) : (ok ? AppColors.forest50 : const Color(0xFFFFF3EC));
    final Color fg = block ? AppColors.danger : (ok ? AppColors.forest700 : AppColors.orangeDark);
    final IconData icon = block
        ? Icons.report_gmailerrorred_rounded
        : (ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(eligibility.title, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 15))),
            ],
          ),
          const SizedBox(height: 8),
          Text(eligibility.message, style: TextStyle(color: fg.withValues(alpha: .9), fontSize: 12.5, height: 1.45)),
        ],
      ),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({required this.eligibility});

  final ClaimEligibility eligibility;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          const Text('Your cover', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const Spacer(),
          Text(
            eligibility.hasActivePolicy ? eligibility.coverageLabel : 'No active cover',
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _LiabilityCheck extends StatelessWidget {
  const _LiabilityCheck({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value ? AppColors.forest50 : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value ? AppColors.forest700 : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: value ? AppColors.forest700 : AppColors.muted, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'I accept I was at fault. My insurer will compensate the other party — my own vehicle isn\'t covered.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.forest700),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.forest700, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _VehiclePicker extends StatelessWidget {
  const _VehiclePicker({required this.vehicles, required this.value, required this.onChanged});

  final List<VehicleSummary> vehicles;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return const Text('Add an insured vehicle before filing a claim.', style: TextStyle(color: AppColors.muted));
    }
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Vehicle involved',
        prefixIcon: Icon(Icons.directions_car_outlined),
      ),
      items: vehicles
          .map((v) => DropdownMenuItem(
                value: v.id,
                child: Text(
                  v.plateNumber?.isNotEmpty == true ? '${v.displayName} · ${v.plateNumber}' : v.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.value, required this.onTap});

  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Incident date & time',
          prefixIcon: Icon(Icons.event_outlined),
        ),
        child: Text(_prettyDateTime(value),
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
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
        style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: const Color(0xFFFFE3E1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 12.5))),
        ],
      ),
    );
  }
}

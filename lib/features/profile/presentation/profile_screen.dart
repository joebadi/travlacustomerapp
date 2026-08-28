import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/auth/domain/app_user.dart';
import 'package:travla_customer_app/features/profile/data/profile_repository.dart';
import 'package:travla_customer_app/features/profile/domain/profile_models.dart';

enum _ProfileSection { identity, personal, security }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _personalKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _nin = TextEditingController();
  final _accountNumber = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  _ProfileSection _section = _ProfileSection.identity;
  String? _dateOfBirth;
  String? _state;
  String? _bankCode;
  bool _changingBank = false;
  bool _busy = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    if (user != null) _applyUser(user);
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _email,
      _phone,
      _address,
      _city,
      _nin,
      _accountNumber,
      _currentPassword,
      _newPassword,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _applyUser(AppUser user) {
    _fullName.text = user.fullName;
    _email.text = user.email;
    _phone.text = user.phone;
    _address.text = user.address ?? '';
    _city.text = user.city ?? '';
    _nin.text = user.nin ?? '';
    _accountNumber.text = user.bankAccountNumber ?? '';
    _dateOfBirth = user.dateOfBirth;
    _state = user.state;
    _bankCode = user.bankCode;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final banks = ref.watch(profileBanksProvider);
    final states = ref.watch(profileStatesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          _ProfileHeader(user: user, busy: _busy, onAvatarPressed: _pickAvatar),
          const SizedBox(height: 16),
          _SegTabs(
            selected: _section,
            enabled: !_busy,
            onSelect: (section) => setState(() {
              _section = section;
              _clearMessage();
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _MessagePanel(message: _error!, isError: true),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 14),
            _MessagePanel(message: _notice!, isError: false),
          ],
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOut,
            child: switch (_section) {
              _ProfileSection.identity => _identitySection(user, banks),
              _ProfileSection.personal => _personalSection(user, states),
              _ProfileSection.security => _securitySection(),
            },
          ),
        ],
      ),
    );
  }

  Widget _identitySection(AppUser user, AsyncValue<List<NigerianBank>> banks) {
    return Column(
      key: const ValueKey('identity'),
      children: [
        _IdentityHero(user: user),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _VerificationStatus(
                label: 'NIN identity',
                verified: user.isNinVerified,
                detail: user.isNinVerified
                    ? 'Verified against your profile'
                    : (user.nin ?? '').isNotEmpty
                    ? 'Submitted for manager review'
                    : 'Add your 11-digit NIN',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VerificationStatus(
                label: 'Bank owner',
                verified: user.isBankVerified,
                detail: user.isBankVerified
                    ? '${user.bankAccountName ?? 'Verified'} · ${user.bankName ?? 'Bank'}'
                    : 'Verify through Paystack',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!user.isNinVerified)
          _NinAction(
            hasNin: (user.nin ?? '').isNotEmpty,
            onPressed: () => setState(() {
              _section = _ProfileSection.personal;
              _clearMessage();
            }),
          ),
        if (!user.isNinVerified) const SizedBox(height: 12),
        _SectionCard(
          title: user.isBankVerified && !_changingBank
              ? 'Verified bank account'
              : 'Verify bank ownership',
          subtitle:
              'Paystack resolves the account name. Its first and last name must match this profile.',
          icon: Icons.account_balance_outlined,
          child: user.isBankVerified && !_changingBank
              ? _VerifiedBank(
                  user: user,
                  onChange: () => setState(() => _changingBank = true),
                )
              : banks.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => _InlineFailure(
                    message: error is ApiFailure
                        ? error.message
                        : 'The bank directory could not be loaded.',
                    onRetry: () => ref.invalidate(profileBanksProvider),
                  ),
                  data: (items) => _BankForm(
                    banks: items,
                    selectedCode: items.any((item) => item.code == _bankCode)
                        ? _bankCode
                        : null,
                    accountNumber: _accountNumber,
                    busy: _busy,
                    canCancel: user.isBankVerified,
                    onBankChanged: (value) => setState(() => _bankCode = value),
                    onSubmit: _verifyBank,
                    onCancel: () => setState(() {
                      _changingBank = false;
                      _bankCode = user.bankCode;
                      _accountNumber.text = user.bankAccountNumber ?? '';
                    }),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        const _PrivacyNote(),
      ],
    );
  }

  Widget _personalSection(AppUser user, AsyncValue<List<String>> states) {
    return _SectionCard(
      key: const ValueKey('personal'),
      title: 'Personal details',
      subtitle:
          'Keep the information Travla uses for vehicle records and delivery accurate.',
      icon: Icons.badge_outlined,
      child: Form(
        key: _personalKey,
        child: Column(
          children: [
            TextFormField(
              controller: _fullName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) =>
                  (value ?? '').trim().split(RegExp(r'\s+')).length < 2
                  ? 'Enter your first and last name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                final email = (value ?? '').trim();
                return !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                    ? 'Enter a valid email address.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+2348012345678',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) =>
                  !RegExp(r'^\+234[0-9]{10}$').hasMatch((value ?? '').trim())
                  ? 'Use the format +2348012345678.'
                  : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _busy ? null : _pickDateOfBirth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                child: Text(
                  _dateOfBirth == null || _dateOfBirth!.isEmpty
                      ? 'Select date'
                      : _friendlyDate(_dateOfBirth!),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            const SizedBox(height: 12),
            states.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, _) => TextFormField(
                initialValue: _state,
                decoration: const InputDecoration(labelText: 'State'),
                onChanged: (value) => _state = value,
              ),
              data: (items) => DropdownButtonFormField<String>(
                initialValue: items.contains(_state) ? _state : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'State',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: items
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(growable: false),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _state = value),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nin,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: InputDecoration(
                labelText: 'National Identification Number (NIN)',
                prefixIcon: const Icon(Icons.fingerprint_rounded),
                helperText: user.isNinVerified
                    ? 'Verified. Changing it requires another review.'
                    : 'Exactly 11 digits. Verification is completed by Travla.',
              ),
              validator: (value) {
                final nin = (value ?? '').trim();
                return nin.isNotEmpty && nin.length != 11
                    ? 'NIN must contain exactly 11 digits.'
                    : null;
              },
            ),
            if (user.isBankVerified) ...[
              const SizedBox(height: 14),
              const _ChangeWarning(
                text:
                    'Changing your full name removes bank verification until Paystack confirms the new name.',
              ),
            ],
            const SizedBox(height: 20),
            _PrimaryButton(
              busy: _busy,
              onPressed: _busy ? null : _saveProfile,
              icon: Icons.save_outlined,
              label: 'Save changes',
              busyLabel: 'Saving changes…',
            ),
          ],
        ),
      ),
    );
  }

  Widget _securitySection() {
    return _SectionCard(
      key: const ValueKey('security'),
      title: 'Change password',
      subtitle:
          'Use at least eight characters and avoid a password used on another service.',
      icon: Icons.lock_outline_rounded,
      child: Form(
        key: _passwordKey,
        child: Column(
          children: [
            TextFormField(
              controller: _currentPassword,
              obscureText: !_showCurrentPassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Current password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _showCurrentPassword = !_showCurrentPassword,
                  ),
                  icon: Icon(
                    _showCurrentPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Enter your current password.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPassword,
              obscureText: !_showNewPassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'New password',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                  icon: Icon(
                    _showNewPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) => (value ?? '').length < 8
                  ? 'Use at least eight characters.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassword,
              obscureText: !_showNewPassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: Icon(Icons.key_rounded),
              ),
              validator: (value) => value != _newPassword.text
                  ? 'The new passwords do not match.'
                  : null,
            ),
            const SizedBox(height: 20),
            _PrimaryButton(
              busy: _busy,
              onPressed: _busy ? null : _changePassword,
              icon: Icons.security_rounded,
              label: 'Update password',
              busyLabel: 'Updating password…',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    if (_busy) return;
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: false,
    );
    if (!mounted || selection == null || selection.files.isEmpty) return;
    final file = selection.files.single;
    if (file.path == null || file.path!.isEmpty) {
      setState(() => _error = 'That image could not be opened.');
      return;
    }
    if (file.size > 4 * 1024 * 1024) {
      setState(() => _error = 'Profile images must be 4 MB or smaller.');
      return;
    }
    await _mutate(
      action: () => ref
          .read(profileRepositoryProvider)
          .uploadAvatar(path: file.path!, name: file.name),
      success: 'Profile photo updated.',
    );
  }

  Future<void> _saveProfile() async {
    if (!(_personalKey.currentState?.validate() ?? false)) return;
    await _mutate(
      action: () => ref
          .read(profileRepositoryProvider)
          .update(
            ProfileUpdate(
              fullName: _fullName.text,
              email: _email.text,
              phone: _phone.text,
              dateOfBirth: _dateOfBirth,
              address: _address.text,
              city: _city.text,
              state: _state,
              nin: _nin.text,
            ),
          ),
      success:
          'Profile saved. Changed contact or identity details may require verification again.',
    );
  }

  Future<void> _verifyBank() async {
    final account = _accountNumber.text.trim();
    if (_bankCode == null || _bankCode!.isEmpty) {
      setState(() => _error = 'Select your Nigerian bank.');
      return;
    }
    if (account.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit account number.');
      return;
    }
    await _mutate(
      action: () => ref
          .read(profileRepositoryProvider)
          .verifyBank(bankCode: _bankCode!, accountNumber: account),
      success: 'Bank ownership verified with Paystack.',
      after: () => _changingBank = false,
    );
  }

  Future<void> _changePassword() async {
    if (!(_passwordKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _clearMessage();
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(
            currentPassword: _currentPassword.text,
            password: _newPassword.text,
            confirmation: _confirmPassword.text,
          );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (mounted) setState(() => _notice = 'Password updated securely.');
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mutate({
    required Future<AppUser> Function() action,
    required String success,
    VoidCallback? after,
  }) async {
    setState(() {
      _busy = true;
      _clearMessage();
    });
    try {
      final user = await action();
      ref.read(authControllerProvider.notifier).replaceUser(user);
      if (!mounted) return;
      _applyUser(user);
      after?.call();
      if (mounted) setState(() => _notice = success);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDateOfBirth() async {
    final parsed = DateTime.tryParse(_dateOfBirth ?? '');
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day - 1),
      initialDate: parsed ?? DateTime(now.year - 25),
    );
    if (selected != null && mounted) {
      setState(() => _dateOfBirth = _apiDate(selected));
    }
  }

  void _clearMessage() {
    _error = null;
    _notice = null;
  }
}

/// A premium, flat identity header: a deep-forest panel with a centred avatar,
/// name, email and trust chips.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.busy,
    required this.onAvatarPressed,
  });

  final AppUser user;
  final bool busy;
  final VoidCallback onAvatarPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.forest900,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _Avatar(user: user, radius: 42),
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: AppColors.orange,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.forest900, width: 2.5),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: busy ? null : onAvatarPressed,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: busy
                          ? const SizedBox.square(
                              dimension: 13,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.photo_camera_outlined,
                              size: 15,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFAECBBF), fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              _HeaderPill(label: user.roleLabel),
              _HeaderPill(
                label: user.isFinancialIdentityVerified
                    ? 'Verified'
                    : 'Action required',
                orange: !user.isFinancialIdentityVerified,
                icon: user.isFinancialIdentityVerified
                    ? Icons.verified_rounded
                    : Icons.error_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A flat, branded three-way segmented control (Identity · Details · Security).
class _SegTabs extends StatelessWidget {
  const _SegTabs({
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final _ProfileSection selected;
  final bool enabled;
  final ValueChanged<_ProfileSection> onSelect;

  static const _items = [
    (_ProfileSection.identity, 'Identity', Icons.verified_user_outlined),
    (_ProfileSection.personal, 'Details', Icons.person_outline_rounded),
    (_ProfileSection.security, 'Security', Icons.lock_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: _items
            .map((item) {
              final active = item.$1 == selected;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: active,
                  label: item.$2,
                  child: Material(
                    color: active ? AppColors.forest700 : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: enabled ? () => onSelect(item.$1) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.$3,
                              size: 16,
                              color: active ? Colors.white : AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _IdentityHero extends StatelessWidget {
  const _IdentityHero({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final verified = user.isFinancialIdentityVerified;
    final accent = verified ? AppColors.forest700 : AppColors.orange;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: verified ? AppColors.forest50 : AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: verified ? const Color(0xFFC4E3D6) : const Color(0xFFF5C5B5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              verified ? Icons.verified_rounded : Icons.shield_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verified
                      ? 'Protected services unlocked'
                      : 'Unlock protected payments and fleets',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  verified
                      ? 'Your NIN and matching bank account are verified.'
                      : 'Travla requires both a verified NIN and a matching Nigerian bank account for higher-trust services.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.45,
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

class _VerificationStatus extends StatelessWidget {
  const _VerificationStatus({
    required this.label,
    required this.verified,
    required this.detail,
  });

  final String label;
  final bool verified;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final accent = verified ? AppColors.forest600 : AppColors.orange;
    return Container(
      constraints: const BoxConstraints(minHeight: 122),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: accent,
                size: 22,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: verified ? AppColors.forest50 : AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  verified ? 'Verified' : 'Action',
                  style: TextStyle(
                    color: verified
                        ? AppColors.forest700
                        : AppColors.orangeDark,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

/// A flat, bordered content card with an icon-chip header. Replaces the earlier
/// elevated Material Card for a cleaner, premium look.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.forest50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.forest700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// A full-width flat primary action button in the brand's forest tone.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.busy,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.busyLabel,
  });

  final bool busy;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest700,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Icon(icon, size: 19),
      label: Text(busy ? busyLabel : label),
    );
  }
}

class _BankForm extends StatelessWidget {
  const _BankForm({
    required this.banks,
    required this.selectedCode,
    required this.accountNumber,
    required this.busy,
    required this.canCancel,
    required this.onBankChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  final List<NigerianBank> banks;
  final String? selectedCode;
  final TextEditingController accountNumber;
  final bool busy;
  final bool canCancel;
  final ValueChanged<String?> onBankChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedCode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Nigerian bank',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
          items: banks
              .map(
                (bank) => DropdownMenuItem(
                  value: bank.code,
                  child: Text(bank.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: busy ? null : onBankChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: accountNumber,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: const InputDecoration(
            labelText: '10-digit account number',
            prefixIcon: Icon(Icons.numbers_rounded),
          ),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          busy: busy,
          onPressed: busy ? null : onSubmit,
          icon: Icons.verified_outlined,
          label: 'Verify bank account',
          busyLabel: 'Verifying with Paystack…',
        ),
        if (canCancel)
          TextButton(
            onPressed: busy ? null : onCancel,
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Keep current bank'),
          ),
      ],
    );
  }
}

class _VerifiedBank extends StatelessWidget {
  const _VerifiedBank({required this.user, required this.onChange});

  final AppUser user;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC4E3D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.forest600,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  user.bankAccountName ?? 'Verified account',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: Text(
              '${user.bankName ?? 'Bank'} · ${_maskAccount(user.bankAccountNumber)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onChange,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.forest700,
              side: const BorderSide(color: Color(0xFFC4E3D6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Use another account'),
          ),
        ],
      ),
    );
  }
}

class _NinAction extends StatelessWidget {
  const _NinAction({required this.hasNin, required this.onPressed});

  final bool hasNin;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: AppColors.orange,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasNin ? 'NIN awaiting verification' : 'Add your NIN',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasNin
                          ? 'You can update it from Details if it is incorrect.'
                          : 'Enter the 11 digits from your NIN record.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_person_outlined, size: 17, color: AppColors.muted),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Travla does not show your NIN or bank details to marketplace buyers, sellers, agents or riders.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeWarning extends StatelessWidget {
  const _ChangeWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.orangeDark,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.orangeDark, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFE9E6) : AppColors.forest50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError ? const Color(0xFFF0C6C2) : const Color(0xFFC4E3D6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? AppColors.danger : AppColors.forest700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: isError ? AppColors.danger : AppColors.forest800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.radius});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = user.profileImageUrl?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.forest100,
      foregroundImage: url.isEmpty ? null : NetworkImage(url),
      child: url.isEmpty
          ? Text(
              _initials(user.fullName),
              style: TextStyle(
                color: AppColors.forest800,
                fontSize: radius * .62,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.label, this.orange = false, this.icon});

  final String label;
  final bool orange;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = orange ? const Color(0xFFFFC3AF) : const Color(0xFFCDE6DC);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: orange
            ? AppColors.orange.withValues(alpha: .18)
            : Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: orange
              ? AppColors.orange.withValues(alpha: .45)
              : Colors.white.withValues(alpha: .16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();

String _maskAccount(String? account) {
  final value = account ?? '';
  if (value.length < 4) return 'Verified';
  return '••••••${value.substring(value.length - 4)}';
}

String _apiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _friendlyDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

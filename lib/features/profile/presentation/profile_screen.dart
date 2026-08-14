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
      appBar: AppBar(title: const Text('Profile & security')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 36),
        children: [
          _ProfileHeader(user: user, busy: _busy, onAvatarPressed: _pickAvatar),
          const SizedBox(height: 14),
          SegmentedButton<_ProfileSection>(
            segments: const [
              ButtonSegment(
                value: _ProfileSection.identity,
                icon: Icon(Icons.verified_user_outlined),
                label: Text('Identity'),
              ),
              ButtonSegment(
                value: _ProfileSection.personal,
                icon: Icon(Icons.person_outline_rounded),
                label: Text('Details'),
              ),
              ButtonSegment(
                value: _ProfileSection.security,
                icon: Icon(Icons.lock_outline_rounded),
                label: Text('Security'),
              ),
            ],
            selected: {_section},
            showSelectedIcon: false,
            onSelectionChanged: _busy
                ? null
                : (selection) => setState(() {
                    _section = selection.first;
                    _clearMessage();
                  }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _MessagePanel(message: _error!, isError: true),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _MessagePanel(message: _notice!, isError: false),
          ],
          const SizedBox(height: 14),
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
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
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
              const SizedBox(height: 12),
              const _ChangeWarning(
                text:
                    'Changing your full name removes bank verification until Paystack confirms the new name.',
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _saveProfile,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_busy ? 'Saving changes…' : 'Save changes'),
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
      icon: Icons.password_rounded,
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
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
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
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _changePassword,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.security_rounded),
              label: Text(_busy ? 'Updating password…' : 'Update password'),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forest950, AppColors.forest700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _Avatar(user: user, radius: 34),
              Positioned(
                right: -3,
                bottom: -3,
                child: Material(
                  color: AppColors.orange,
                  shape: const CircleBorder(),
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
                              size: 14,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFBBD8CD),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _HeaderPill(label: user.roleLabel),
                    _HeaderPill(
                      label: user.isFinancialIdentityVerified
                          ? 'Financially verified'
                          : 'Identity action required',
                      orange: !user.isFinancialIdentityVerified,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: verified ? AppColors.forest50 : AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: verified ? const Color(0xFFB9DECF) : const Color(0xFFF5C5B5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: verified ? AppColors.forest700 : AppColors.orange,
            foregroundColor: Colors.white,
            child: Icon(
              verified ? Icons.verified_rounded : Icons.shield_outlined,
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
                  style: const TextStyle(fontWeight: FontWeight.w900),
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
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            verified ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: verified ? AppColors.forest600 : AppColors.orange,
            size: 23,
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.forest100,
                  foregroundColor: AppColors.forest700,
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
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
      ),
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
        const SizedBox(height: 10),
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
        const SizedBox(height: 15),
        FilledButton.icon(
          onPressed: busy ? null : onSubmit,
          icon: busy
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.verified_outlined),
          label: Text(
            busy ? 'Verifying with Paystack…' : 'Verify bank account',
          ),
        ),
        if (canCancel)
          TextButton(
            onPressed: busy ? null : onCancel,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.forest50,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.bankAccountName ?? 'Verified account',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${user.bankName ?? 'Bank'} · ${_maskAccount(user.bankAccountNumber)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onChange,
            icon: const Icon(Icons.edit_outlined),
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
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: const Icon(
          Icons.fingerprint_rounded,
          color: AppColors.forest700,
        ),
        title: Text(
          hasNin ? 'NIN awaiting verification' : 'Add your NIN',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          hasNin
              ? 'You can update it from Personal details if it is incorrect.'
              : 'Enter the 11 digits from your NIN record.',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onPressed,
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_person_outlined, size: 17, color: AppColors.muted),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Travla does not show your NIN or bank details to marketplace buyers, sellers, agents or riders.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.orangeDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFE9E6) : AppColors.forest50,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isError ? const Color(0xFFF0C6C2) : const Color(0xFFB9DECF),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? AppColors.danger : AppColors.forest700,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
  const _HeaderPill({required this.label, this.orange = false});

  final String label;
  final bool orange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: orange
            ? AppColors.orange.withValues(alpha: .2)
            : Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: orange
              ? AppColors.orange.withValues(alpha: .5)
              : Colors.white.withValues(alpha: .15),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: orange ? const Color(0xFFFFB59E) : const Color(0xFFD4E7E0),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
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

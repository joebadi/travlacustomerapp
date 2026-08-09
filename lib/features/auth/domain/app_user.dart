class AppWallet {
  const AppWallet({
    required this.balanceKobo,
    required this.balanceNaira,
    required this.currency,
  });

  final int balanceKobo;
  final String balanceNaira;
  final String currency;

  factory AppWallet.fromJson(Map<String, dynamic> json) {
    return AppWallet(
      balanceKobo: (json['balance_kobo'] as num?)?.toInt() ?? 0,
      balanceNaira: json['balance_naira']?.toString() ?? '0.00',
      currency: json['currency']?.toString() ?? 'NGN',
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.systemRole,
    required this.isVerified,
    required this.isFinancialIdentityVerified,
    required this.hasFleet,
    required this.claimsAvailable,
    this.roleLabel = 'Customer',
    this.isNinVerified = false,
    this.isBankVerified = false,
    this.wallet,
    this.profileImageUrl,
    this.bankName,
    this.bankCode,
    this.bankAccountNumber,
    this.bankAccountName,
    this.dateOfBirth,
    this.address,
    this.city,
    this.state,
    this.nin,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String systemRole;
  final bool isVerified;
  final bool isFinancialIdentityVerified;
  final bool hasFleet;
  final bool claimsAvailable;
  final String roleLabel;
  final bool isNinVerified;
  final bool isBankVerified;
  final AppWallet? wallet;
  final String? profileImageUrl;
  final String? bankName;
  final String? bankCode;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final String? dateOfBirth;
  final String? address;
  final String? city;
  final String? state;
  final String? nin;
  final DateTime? createdAt;

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'there' : parts.first;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final walletJson = json['wallet'];
    return AppUser(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      systemRole: json['system_role']?.toString() ?? '',
      isVerified: json['is_verified'] == true,
      isFinancialIdentityVerified:
          json['is_financial_identity_verified'] == true,
      hasFleet: json['has_fleet'] == true,
      claimsAvailable: json['claims_available'] == true,
      roleLabel: json['role_label']?.toString() ?? 'Customer',
      isNinVerified: json['is_nin_verified'] == true,
      isBankVerified: json['is_bank_verified'] == true,
      wallet: walletJson is Map<String, dynamic>
          ? AppWallet.fromJson(walletJson)
          : null,
      profileImageUrl: json['profile_image_url']?.toString(),
      bankName: json['bank_name']?.toString(),
      bankCode: json['bank_code']?.toString(),
      bankAccountNumber: json['bank_account_number']?.toString(),
      bankAccountName: json['bank_account_name']?.toString(),
      dateOfBirth: json['date_of_birth']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      nin: json['nin']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

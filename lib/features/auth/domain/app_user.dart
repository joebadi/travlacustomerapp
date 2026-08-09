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
    this.wallet,
    this.profileImageUrl,
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
  final AppWallet? wallet;
  final String? profileImageUrl;

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
      wallet: walletJson is Map<String, dynamic>
          ? AppWallet.fromJson(walletJson)
          : null,
      profileImageUrl: json['profile_image_url']?.toString(),
    );
  }
}

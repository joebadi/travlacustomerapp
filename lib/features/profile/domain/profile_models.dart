class NigerianBank {
  const NigerianBank({required this.name, required this.code});

  final String name;
  final String code;

  factory NigerianBank.fromJson(Map<String, dynamic> json) {
    return NigerianBank(
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
    );
  }
}

class ProfileUpdate {
  const ProfileUpdate({
    required this.fullName,
    required this.email,
    required this.phone,
    this.dateOfBirth,
    this.address,
    this.city,
    this.state,
    this.nin,
  });

  final String fullName;
  final String email;
  final String phone;
  final String? dateOfBirth;
  final String? address;
  final String? city;
  final String? state;
  final String? nin;

  Map<String, dynamic> toJson() => {
    'full_name': fullName.trim(),
    'email': email.trim().toLowerCase(),
    'phone': phone.trim(),
    'date_of_birth': _emptyToNull(dateOfBirth),
    'address': _emptyToNull(address),
    'city': _emptyToNull(city),
    'state': _emptyToNull(state),
    'nin': _emptyToNull(nin),
  };
}

String? _emptyToNull(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

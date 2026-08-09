class RegistrationConfig {
  const RegistrationConfig({
    required this.registrationsEnabled,
    required this.invitationRegistrationEnabled,
    required this.recaptchaEnabled,
    this.recaptchaChallengeUrl,
  });

  final bool registrationsEnabled;
  final bool invitationRegistrationEnabled;
  final bool recaptchaEnabled;
  final String? recaptchaChallengeUrl;

  factory RegistrationConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['recaptcha'];
    final recaptcha = raw is Map<String, dynamic>
        ? raw
        : const <String, dynamic>{};
    return RegistrationConfig(
      registrationsEnabled: json['registrations_enabled'] == true,
      invitationRegistrationEnabled:
          json['invitation_registration_enabled'] == true,
      recaptchaEnabled: recaptcha['enabled'] == true,
      recaptchaChallengeUrl: recaptcha['challenge_url']?.toString(),
    );
  }
}

class RegistrationStart {
  const RegistrationStart({
    required this.message,
    required this.phone,
    required this.deliveryChannel,
    required this.destinationHint,
  });

  final String message;
  final String phone;
  final String deliveryChannel;
  final String destinationHint;

  factory RegistrationStart.fromJson(Map<String, dynamic> json) {
    return RegistrationStart(
      message: json['message']?.toString() ?? 'Account created.',
      phone: json['phone']?.toString() ?? '',
      deliveryChannel: json['delivery_channel']?.toString() ?? 'sms',
      destinationHint: json['destination_hint']?.toString() ?? '',
    );
  }
}

class TransferInvitationPrefill {
  const TransferInvitationPrefill({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.vehicle,
    required this.plateNumber,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String vehicle;
  final String plateNumber;

  factory TransferInvitationPrefill.fromJson(Map<String, dynamic> json) {
    return TransferInvitationPrefill(
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      vehicle: json['vehicle']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString() ?? '',
    );
  }
}

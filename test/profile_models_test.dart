import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/auth/domain/app_user.dart';
import 'package:travla_customer_app/features/profile/domain/profile_models.dart';

void main() {
  test('app user retains financial identity and profile fields', () {
    final user = AppUser.fromJson({
      'id': 'user-1',
      'full_name': 'Marcus Jackson',
      'email': 'marcus@example.com',
      'phone': '+2348012345678',
      'system_role': 'USER',
      'role_label': 'Vehicle owner',
      'is_verified': true,
      'is_nin_verified': true,
      'is_bank_verified': true,
      'is_financial_identity_verified': true,
      'has_fleet': false,
      'claims_available': false,
      'bank_name': 'Test Bank',
      'bank_code': '999',
      'bank_account_number': '0123456789',
      'bank_account_name': 'MARCUS JACKSON',
      'date_of_birth': '1990-05-06',
      'address': '1 Travla Street',
      'city': 'Lagos',
      'state': 'Lagos',
      'nin': '12345678901',
      'created_at': '2026-08-10T08:00:00Z',
    });

    expect(user.isFinancialIdentityVerified, isTrue);
    expect(user.isNinVerified, isTrue);
    expect(user.isBankVerified, isTrue);
    expect(user.bankAccountName, 'MARCUS JACKSON');
    expect(user.state, 'Lagos');
    expect(user.createdAt, isNotNull);
  });

  test('profile update normalizes email and empty optional fields', () {
    const update = ProfileUpdate(
      fullName: ' Marcus Jackson ',
      email: ' MARCUS@EXAMPLE.COM ',
      phone: '+2348012345678',
      address: ' ',
      nin: '12345678901',
    );

    final json = update.toJson();
    expect(json['full_name'], 'Marcus Jackson');
    expect(json['email'], 'marcus@example.com');
    expect(json['address'], isNull);
    expect(json['nin'], '12345678901');
  });
}

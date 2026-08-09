import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/core/auth/auth_controller.dart';
import 'package:travla_customer_app/features/auth/domain/registration.dart';

final registrationConfigProvider =
    FutureProvider.autoDispose<RegistrationConfig>((ref) {
      return ref.watch(authRepositoryProvider).registrationConfig();
    });

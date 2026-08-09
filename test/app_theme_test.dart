import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/app/theme/app_theme.dart';

void main() {
  test('Travla theme keeps the approved orange and green brand colours', () {
    expect(AppColors.orange, const Color(0xFFFA4710));
    expect(AppTheme.light.colorScheme.primary, AppColors.forest700);
    expect(AppTheme.light.colorScheme.secondary, AppColors.orange);
  });
}

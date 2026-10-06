import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/fleet/presentation/guided_create_org_screen.dart';

void main() {
  testWidgets(
    'guided Fleet onboarding validates identity before region setup',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: GuidedCreateOrgScreen())),
      );

      expect(find.text('Company identity'), findsOneWidget);
      expect(
        find.textContaining('CAC/RC numbers remain marked unverified'),
        findsOneWidget,
      );

      Finder activeContinueButton() => find.text('Continue').hitTestable();

      expect(activeContinueButton(), findsOneWidget);
      await tester.ensureVisible(activeContinueButton());
      await tester.tap(activeContinueButton());
      await tester.pump();
      expect(find.text('Enter the company name.'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).hitTestable().first,
        'Example Logistics Limited',
      );
      await tester.ensureVisible(activeContinueButton());
      await tester.tap(activeContinueButton());
      await tester.pumpAndSettle();

      expect(find.text('First operating region'), findsOneWidget);
      expect(find.text('Add a region now'), findsOneWidget);
    },
  );
}

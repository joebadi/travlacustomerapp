import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/auth/presentation/splash_screen.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

void main() {
  testWidgets('splash presents the Travla mark and wordmark as one lockup', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/brand/travla-mark-white.png',
      ),
      findsOneWidget,
    );
    expect(find.byType(TravlaLogo), findsOneWidget);
    expect(find.text('YOUR VEHICLE. ONE ACCOUNT.'), findsOneWidget);
    expect(find.byIcon(Icons.alt_route_rounded), findsNothing);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/features/auth/presentation/splash_screen.dart';
import 'package:travla_customer_app/shared/widgets/travla_logo.dart';

void main() {
  testWidgets('splash presents the Travla mark and wordmark as one lockup', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    final mark = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/brand/travla-mark-white.png',
    );
    expect(mark, findsOneWidget);
    // The mark is already present on Android's native launch frame. Keeping it
    // outside a fade/scale transition prevents a disappear-and-reappear flash
    // when Flutter draws its first frame.
    var splashFadesTheMark = false;
    tester.element(mark).visitAncestorElements((element) {
      if (element.widget is SplashScreen) return false;
      if (element.widget is FadeTransition) splashFadesTheMark = true;
      return true;
    });
    expect(splashFadesTheMark, isFalse);
    expect(find.byType(TravlaLogo), findsOneWidget);
    expect(find.text('YOUR VEHICLE. ONE ACCOUNT.'), findsOneWidget);
    expect(find.byIcon(Icons.alt_route_rounded), findsNothing);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.takeException(), isNull);
  });
}

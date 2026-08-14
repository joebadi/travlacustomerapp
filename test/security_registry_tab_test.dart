import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/core/auth/secure_token_store.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/features/news/presentation/car_talk_screen.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';
import 'package:travla_customer_app/features/stolen/presentation/reports_tab.dart';

void main() {
  testWidgets('security tab separates the public registry and personal cases', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stolenRepositoryProvider.overrideWithValue(_FakeStolenRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: ReportsFeedTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vehicle Reports'), findsOneWidget);
    expect(find.text('Is this vehicle reported?'), findsOneWidget);
    expect(find.text('Reported vehicles'), findsOneWidget);
    expect(find.text('Report stolen'), findsOneWidget);

    await tester.tap(find.text('My reports (0)'));
    await tester.pumpAndSettle();

    expect(find.text('Your vehicle reports'), findsOneWidget);
    expect(find.text('No reports created'), findsOneWidget);
  });

  testWidgets('Reports renders inside the real compact Car Talk screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stolenRepositoryProvider.overrideWithValue(_FakeStolenRepository()),
        ],
        child: const MaterialApp(home: CarTalkScreen()),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Vehicle Reports'), findsOneWidget);
    expect(find.text('Is this vehicle reported?'), findsOneWidget);
  });
}

class _FakeStolenRepository extends StolenRepository {
  _FakeStolenRepository()
    : super(ApiClient(SecureTokenStore(const FlutterSecureStorage())));

  @override
  Future<StolenDirectoryPage> directory({
    StolenDirectoryFilters filters = const StolenDirectoryFilters(),
    int page = 1,
  }) async {
    return StolenDirectoryPage(
      items: const [],
      page: page,
      lastPage: page,
      total: 0,
    );
  }

  @override
  Future<List<StolenReport>> mine() async => const [];

  @override
  Future<StolenStats> stats() async => const StolenStats(
    currentlyStolen: 0,
    recovered: 0,
    recoveryRate: 0,
    totalSightings: 0,
    recentSightings: 0,
  );

  @override
  Future<StolenCheckResult> checkPlate(String plate) async =>
      StolenCheckResult(plate: plate, isStolen: false, report: null);
}

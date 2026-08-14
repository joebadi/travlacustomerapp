import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travla_customer_app/core/auth/secure_token_store.dart';
import 'package:travla_customer_app/core/network/api_client.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/news/presentation/car_talk_screen.dart';
import 'package:travla_customer_app/features/stolen/data/stolen_repository.dart';
import 'package:travla_customer_app/features/stolen/domain/stolen_models.dart';
import 'package:travla_customer_app/features/stolen/presentation/vehicle_reports_page.dart';

void main() {
  testWidgets('security tab separates the public registry and personal cases', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stolenRepositoryProvider.overrideWithValue(_FakeStolenRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: VehicleReportsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vehicle Security'), findsOneWidget);
    expect(find.text('Instant plate check'), findsOneWidget);
    expect(find.text('Reported stolen vehicles'), findsOneWidget);
    expect(find.text('Report stolen'), findsOneWidget);

    await tester.tap(find.text('My reports').first);
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
    expect(find.text('Vehicle Security'), findsOneWidget);
    expect(find.text('Instant plate check'), findsOneWidget);
  });

  testWidgets('Reports never blanks when every request fails', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stolenRepositoryProvider.overrideWithValue(
            _FailingStolenRepository(),
          ),
        ],
        child: const MaterialApp(home: CarTalkScreen(initialIndex: 2)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vehicle-reports-page')), findsOneWidget);
    expect(find.text('Vehicle Security'), findsOneWidget);
    expect(find.text('Instant plate check'), findsOneWidget);

    await tester.tap(find.text('My reports').first);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('vehicle-reports-scroll')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(find.text('Personal reports unavailable for test.'), findsOneWidget);
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

class _FailingStolenRepository extends StolenRepository {
  _FailingStolenRepository()
    : super(ApiClient(SecureTokenStore(const FlutterSecureStorage())));

  @override
  Future<StolenDirectoryPage> directory({
    StolenDirectoryFilters filters = const StolenDirectoryFilters(),
    int page = 1,
  }) => throw const ApiFailure('Registry unavailable for test.');

  @override
  Future<List<StolenReport>> mine() =>
      throw const ApiFailure('Personal reports unavailable for test.');

  @override
  Future<StolenStats> stats() =>
      throw const ApiFailure('Statistics unavailable for test.');
}

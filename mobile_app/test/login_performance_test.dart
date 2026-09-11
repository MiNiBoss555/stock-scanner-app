import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/main.dart";

class PerformanceTestApiService extends StockApiService {
  int getMovementsCallCount = 0;
  int getSummaryCallCount = 0;
  int getProductsCallCount = 0;
  int getOrdersCallCount = 0;
  int registerDeviceTokenCallCount = 0;
  int loginCallCount = 0;

  Completer<void>? pushCompleter;

  @override
  Future<LoginSession> login({required String userId, required String pin}) async {
    loginCallCount++;
    return LoginSession(
      accessToken: "test-token",
      tokenType: "bearer",
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      user: AppUser(
        userId: userId,
        userName: "Test User",
        role: "admin",
        active: true,
      ),
    );
  }

  @override
  Future<List<MovementRecord>> getMovements({int limit = 30, String? reference}) async {
    getMovementsCallCount++;
    return [];
  }

  @override
  Future<StockSummary> getSummary() async {
    getSummaryCallCount++;
    return StockSummary(
      totalProducts: 100,
      totalUnits: 500,
      lowStockCount: 5,
      lowStockItems: [],
    );
  }

  @override
  Future<List<Product>> getProducts({bool lowStockOnly = false, bool includeInactive = false}) async {
    getProductsCallCount++;
    return [];
  }

  @override
  Future<List<DeliveryOrder>> getOrders({
    required String requesterId,
    bool assignedOnly = false,
    bool mineOnly = false,
    int limit = 300,
  }) async {
    getOrdersCallCount++;
    return [];
  }

  @override
  Future<void> registerDeviceToken({
    required String requesterId,
    required String platform,
    required String token,
  }) async {
    registerDeviceTokenCallCount++;
    if (pushCompleter != null) {
      await pushCompleter!.future;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Login does not trigger getMovements immediately and lazy loads History tab", (tester) async {
    final api = PerformanceTestApiService();
    final user = AppUser(
      userId: "U1",
      userName: "Test User",
      role: "admin",
      active: true,
    );

    // Build StockHomePage directly
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StockHomePage(
          api: api,
          currentUser: user,
          onLogout: () async {},
          onRefreshSession: () async {},
        ),
      ),
    ));
    await tester.pump();

    // DashboardPage is at index 0 and should load
    expect(api.getSummaryCallCount, 1);
    expect(api.getProductsCallCount, 1);
    expect(api.getOrdersCallCount, 1);

    // HistoryPage at index 2 should NOT have loaded yet
    expect(api.getMovementsCallCount, 0);

    // Tap History tab (index 2)
    final historyTabFinder = find.byIcon(Icons.history_outlined).first;
    await tester.tap(historyTabFinder);
    await tester.pumpAndSettle();

    // Now movements should be fetched
    expect(api.getMovementsCallCount, 1);
  });
}

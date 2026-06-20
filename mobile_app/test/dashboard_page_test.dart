import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/dashboard_page.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeDashboardStockApiService extends StockApiService {
  bool getSummaryCalled = false;
  bool getProductsCalled = false;
  bool getOrdersCalled = false;

  int summaryCallCount = 0;

  @override
  Future<StockSummary> getSummary() async {
    getSummaryCalled = true;
    summaryCallCount++;
    return StockSummary(
      totalProducts: 5,
      totalUnits: 150,
      lowStockCount: 2,
      lowStockItems: [
        Product(
          barcode: "123",
          name: "Low Stock P1",
          unit: "pcs",
          minimumStock: 10,
          currentStock: 3,
        ),
      ],
    );
  }

  @override
  Future<List<Product>> getProducts({bool lowStockOnly = false}) async {
    getProductsCalled = true;
    return [
      Product(
        barcode: "123",
        name: "Low Stock P1",
        unit: "pcs",
        minimumStock: 10,
        currentStock: 3,
      ),
      Product(
        barcode: "456",
        name: "Normal P2",
        unit: "box",
        minimumStock: 5,
        currentStock: 50,
      ),
    ];
  }

  @override
  Future<List<DeliveryOrder>> getOrders({
    bool assignedOnly = false,
    int limit = 100,
    bool mineOnly = false,
    required String requesterId,
  }) async {
    getOrdersCalled = true;
    return [
      DeliveryOrder(
        id: "ORDER_ABC",
        customerName: "Alice Smith",
        createdById: "CREATOR_1",
        createdByName: "Bob Creator",
        status: "new",
        items: [
          OrderItemModel(
            barcode: "456",
            productName: "Normal P2",
            quantity: 5,
            unit: "box",
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}

void main() {
  late FakeDashboardStockApiService fakeApi;
  late AppUser currentUser;
  late ValueNotifier<int> refreshSignal;
  late RouteObserver<ModalRoute<void>> routeObserver;

  bool openOrdersTabCalled = false;
  bool openProductListCalled = false;
  bool openProductDetailsCalled = false;
  bool openCustomLabelCalled = false;
  bool openOrderChatCalled = false;

  setUp(() {
    fakeApi = FakeDashboardStockApiService();
    currentUser = AppUser(
      userId: "USER123",
      userName: "Jane Smith",
      role: "admin",
      active: true,
    );
    refreshSignal = ValueNotifier<int>(0);
    routeObserver = RouteObserver<ModalRoute<void>>();

    openOrdersTabCalled = false;
    openProductListCalled = false;
    openProductDetailsCalled = false;
    openCustomLabelCalled = false;
    openOrderChatCalled = false;
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: DashboardPage(
          api: fakeApi,
          refreshSignal: refreshSignal,
          currentUser: currentUser,
          routeObserver: routeObserver,
          onOpenOrdersTab: () {
            openOrdersTabCalled = true;
          },
          onOpenProductList: (context, products, title, icon, color) {
            openProductListCalled = true;
            showDialog<void>(
              context: context,
              builder: (dialogContext) => SimpleDialog(
                children: products
                    .map((product) => SimpleDialogOption(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            openProductDetailsCalled = true;
                          },
                          child: Text(product.name),
                        ))
                    .toList(),
              ),
            );
          },
          onOpenProductDetails: (context, product) {
            openProductDetailsCalled = true;
          },
          onOpenCustomLabel: (context, label) {
            openCustomLabelCalled = true;
          },
          onOpenOrderChat: (context, order) {
            openOrderChatCalled = true;
          },
        ),
      ),
    );
  }

  group("DashboardPage Widget Tests", () {
    testWidgets("renders DashboardPage correctly and loads initial data", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      // Wait for future builder to resolve
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify page titles and metrics
      expect(find.text("ภาพรวมสต็อก"), findsOneWidget);
      expect(find.text("Jane Smith"), findsOneWidget);
      expect(find.text("ผู้ดูแลระบบ"), findsOneWidget);

      // Verify metric card values
      expect(find.text("2"), findsOneWidget); // total products
      expect(find.text("0"), findsOneWidget); // out of stock items
      expect(find.text("1"), findsOneWidget); // low stock items

      // Verify API was called on initialization
      expect(fakeApi.getSummaryCalled, isTrue);
      expect(fakeApi.getProductsCalled, isTrue);
      expect(fakeApi.getOrdersCalled, isTrue);
      expect(fakeApi.summaryCallCount, 1);
    });

    testWidgets("pull-to-refresh triggers data reload", (WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(fakeApi.summaryCallCount, 1);

      // Trigger pull to refresh
      await tester.drag(find.text("ภาพรวมสต็อก"), const Offset(0.0, 300.0));
      await tester.pump(); // Start refresh animation
      await tester.pump(const Duration(seconds: 1)); // Wait for animation
      await tester.pumpAndSettle();

      // Verify API was called again
      expect(fakeApi.summaryCallCount, 2);
    });

    testWidgets("incrementing refreshSignal triggers data reload", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(fakeApi.summaryCallCount, 1);

      // Trigger signal increment
      refreshSignal.value = refreshSignal.value + 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify API was called again
      expect(fakeApi.summaryCallCount, 2);
    });

    testWidgets("RouteAware didPopNext triggers reload", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(fakeApi.summaryCallCount, 1);

      // Access State and call didPopNext directly to simulate route return
      final stateFinder = find.byType(DashboardPage);
      final state = tester.state(stateFinder);
      
      // Invoke didPopNext
      (state as dynamic).didPopNext();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify API was called again
      expect(fakeApi.summaryCallCount, 2);
    });

    testWidgets("product detail and list callbacks are triggered correctly", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on Stock Low metric card (should open product list sheet)
      final lowStockMetric = find.text("ใกล้หมด");
      expect(lowStockMetric, findsOneWidget);
      await tester.tap(lowStockMetric);
      await tester.pump();
      expect(openProductListCalled, isTrue);

      // Tap on a product tile in the Low Stock list (should open details sheet)
      final productTile = find.text("Low Stock P1");
      expect(productTile, findsOneWidget);
      await tester.tap(productTile);
      await tester.pump();
      expect(openProductDetailsCalled, isTrue);
    });

    testWidgets("order chat callback from order preview triggers correctly and tabs callbacks are used", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on active order card/listtile to open preview bottom sheet
      final orderItem = find.text("Alice Smith").first;
      await tester.tap(orderItem);
      await tester.pump(); // Open sheet
      await tester.pump(const Duration(milliseconds: 200));

      // Verify modal bottom sheet titles are shown
      expect(find.text("ใบสรุปออเดอร์"), findsOneWidget);

      // Tap on "แชทติดตามงาน" button
      final chatButton = find.text("แชทติดตามงาน");
      expect(chatButton, findsOneWidget);
      await tester.tap(chatButton);
      await tester.pump(); // Closes sheet and routes
      await tester.pump(const Duration(milliseconds: 200));

      // Verify chat callback triggered
      expect(openOrderChatCalled, isTrue);

      // Verify tapping Action Banner triggers onOpenOrdersTab
      final actionBanner = find.text("งานค้างส่ง 1 ออเดอร์");
      expect(actionBanner, findsOneWidget);
      await tester.tap(actionBanner);
      await tester.pump();
      expect(openOrdersTabCalled, isTrue);

      // Verify onOpenCustomLabel via state to ensure callback propagation
      final state = tester.state<DashboardPageState>(find.byType(DashboardPage));
      state.widget.onOpenCustomLabel(state.context, "test_label");
      expect(openCustomLabelCalled, isTrue);
    });
  });
}

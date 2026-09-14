import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/orders_page.dart";
import "package:stock_scanner_mobile/widgets/orders_status_tabs.dart";

class FakeOrdersApi extends StockApiService {
  FakeOrdersApi({required this.orders});

  final List<DeliveryOrder> orders;

  @override
  Future<List<DeliveryOrder>> getOrders({
    required String requesterId,
    bool assignedOnly = false,
    bool mineOnly = false,
    int limit = 300,
  }) async {
    return orders;
  }

  @override
  Future<List<AppUser>> getUsers({bool activeOnly = true}) async => [];

  @override
  Future<List<Product>> getProducts({
    bool lowStockOnly = false,
    bool includeInactive = false,
  }) async =>
      [];

  @override
  Future<List<String>> getOrderProofPhotos({
    required String requesterId,
    required String orderId,
  }) async =>
      [];

  @override
  String orderPrintUrl({required String orderId, required String requesterId}) =>
      "https://example.com/print/$orderId";

  @override
  String orderPackingSlipUrl({
    required String orderId,
    required String requesterId,
  }) =>
      "https://example.com/packing/$orderId";

  @override
  String orderPdfUrl({required String orderId, required String requesterId}) =>
      "https://example.com/pdf/$orderId";
}

DeliveryOrder buildOrder({
  required String id,
  required String customerName,
  String? customerPhone,
  required String status,
  required String createdByName,
}) {
  return DeliveryOrder(
    id: id,
    customerName: customerName,
    customerPhone: customerPhone,
    createdById: "creator-id",
    createdByName: createdByName,
    status: status,
    items: const [],
    createdAt: DateTime(2026, 6, 26, 9, 0),
    updatedAt: DateTime(2026, 6, 26, 9, 0),
  );
}

Widget createTestWidget(FakeOrdersApi api) {
  final user = AppUser(
    userId: "tester",
    userName: "Tester",
    role: "admin",
    active: true,
  );
  return MaterialApp(
    home: Scaffold(
      body: OrdersPage(api: api, currentUser: user),
    ),
  );
}

Finder get searchField => find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              "ค้นหาชื่อลูกค้า เบอร์โทร เลขออเดอร์...",
    );

Finder get horizontalScrollable => find.descendant(
      of: find.byKey(const Key("orders_status_tabs_scroll")),
      matching: find.byType(Scrollable),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("OrdersStatusTabs widget and all tabs render", (tester) async {
    final api = FakeOrdersApi(
      orders: [
        buildOrder(id: "1", customerName: "Alice", status: "pending", createdByName: "Creator"),
      ],
    );
    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    expect(find.byType(OrdersStatusTabs), findsOneWidget);

    for (final tab in visibleOrderStatusTabs) {
      final tabLabelFinder = find.byKey(Key("tab_${tab.label}"));
      if (tester.any(tabLabelFinder)) {
        expect(tabLabelFinder, findsOneWidget);
      } else {
        // Scroll to make sure it exists/renders
        await tester.scrollUntilVisible(
          tabLabelFinder,
          100,
          scrollable: horizontalScrollable,
        );
        expect(tabLabelFinder, findsOneWidget);
      }
    }
  });

  testWidgets("badge counts render and display correctly", (tester) async {
    final api = FakeOrdersApi(
      orders: [
        buildOrder(id: "1", customerName: "Alice", status: "pending", createdByName: "Creator"),
        buildOrder(id: "2", customerName: "Bob", status: "preparing", createdByName: "Creator"),
        buildOrder(id: "3", customerName: "Charlie", status: "preparing", createdByName: "Creator"),
        buildOrder(id: "4", customerName: "Dave", status: "delivered", createdByName: "Creator"),
      ],
    );

    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    // Check counts
    // ทั้งหมด = 4
    // รอดำเนินการ = 1 (pending)
    // รอจัดส่ง = 2 (preparing)
    // จัดส่งแล้ว = 1 (delivered)
    expect(find.text("4"), findsOneWidget); // ใน badge ทั้งหมด
    expect(find.text("1"), findsAtLeast(2)); // ใน badge รอดำเนินการ (และจัดส่งแล้ว)

    // Scroll to see "รอจัดส่ง"
    await tester.scrollUntilVisible(
      find.byKey(const Key("tab_รอจัดส่ง")),
      100,
      scrollable: horizontalScrollable,
    );
    await tester.pump();
    expect(find.text("2"), findsOneWidget); // ใน badge รอจัดส่ง
  });

  testWidgets("tapping รอจัดส่ง and จัดส่งแล้ว filters list", (tester) async {
    final api = FakeOrdersApi(
      orders: [
        buildOrder(id: "1", customerName: "Alice", status: "pending", createdByName: "Creator"),
        buildOrder(id: "2", customerName: "Bob", status: "preparing", createdByName: "Creator"),
        buildOrder(id: "3", customerName: "Charlie", status: "delivered", createdByName: "Creator"),
      ],
    );

    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    // Default "ทั้งหมด" shows all active
    expect(find.text("Alice"), findsOneWidget);
    expect(find.text("Bob"), findsOneWidget);
    expect(find.text("Charlie"), findsOneWidget);

    // Tap "รอจัดส่ง"
    final shippingTab = find.byKey(const Key("tab_รอจัดส่ง"));
    await tester.scrollUntilVisible(
      shippingTab,
      100,
      scrollable: horizontalScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(shippingTab);
    await tester.pumpAndSettle();

    expect(find.text("Bob"), findsOneWidget);
    expect(find.text("Alice"), findsNothing);
    expect(find.text("Charlie"), findsNothing);

    // Tap "จัดส่งแล้ว"
    final deliveredTab = find.byKey(const Key("tab_จัดส่งแล้ว"));
    await tester.scrollUntilVisible(
      deliveredTab,
      100,
      scrollable: horizontalScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(deliveredTab);
    await tester.pumpAndSettle();

    expect(find.text("Charlie"), findsOneWidget);
    expect(find.text("Alice"), findsNothing);
    expect(find.text("Bob"), findsNothing);
  });

  testWidgets("tab counts respect search query", (tester) async {
    final api = FakeOrdersApi(
      orders: [
        buildOrder(id: "1", customerName: "สมชาย รักดี", status: "pending", createdByName: "Creator"),
        buildOrder(id: "2", customerName: "สมชาย รักสงบ", status: "preparing", createdByName: "Creator"),
        buildOrder(id: "3", customerName: "สมจิตใจดี", status: "preparing", createdByName: "Creator"),
      ],
    );

    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    // Type "สมชาย"
    await tester.enterText(searchField, "สมชาย");
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // ตอนนี้มีแค่ 2 ออเดอร์ที่ตรงการค้นหา
    // ทั้งหมด = 2
    // รอดำเนินการ = 1 (pending)
    // รอจัดส่ง = 1 (preparing) (เพราะ สมจิต ไม่นับ)
    expect(find.text("2"), findsOneWidget); // ทั้งหมด

    await tester.scrollUntilVisible(
      find.byKey(const Key("tab_รอจัดส่ง")),
      100,
      scrollable: horizontalScrollable,
    );
    await tester.pump();
    expect(find.text("1"), findsAtLeast(2)); // รอดำเนินการ และ รอจัดส่ง
  });

  testWidgets("empty state appears when search + tab has no result", (tester) async {
    final api = FakeOrdersApi(
      orders: [
        buildOrder(id: "1", customerName: "Alice", status: "pending", createdByName: "Creator"),
      ],
    );

    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    // Tap "จัดส่งแล้ว"
    final deliveredTab = find.byKey(const Key("tab_จัดส่งแล้ว"));
    await tester.scrollUntilVisible(
      deliveredTab,
      100,
      scrollable: horizontalScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(deliveredTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("empty_search_state")), findsOneWidget);
    expect(find.text("ไม่พบออเดอร์"), findsOneWidget);
  });
}

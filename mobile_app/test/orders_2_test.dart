import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/orders_page.dart";
import "package:stock_scanner_mobile/loading_state.dart";

class FakeOrdersApi extends StockApiService {
  FakeOrdersApi({required this.orders, this.shouldDelay = false});

  final List<DeliveryOrder> orders;
  final bool shouldDelay;

  @override
  Future<List<DeliveryOrder>> getOrders({
    required String requesterId,
    bool assignedOnly = false,
    bool mineOnly = false,
    int limit = 300,
  }) async {
    if (shouldDelay) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
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
  String? trackingNumber,
  required String status,
  required String createdByName,
  String? assignedToName,
  String? productionUserName,
  String? qcUserName,
  String? deliveryUserName,
}) {
  return DeliveryOrder(
    id: id,
    customerName: customerName,
    customerPhone: customerPhone,
    trackingNumber: trackingNumber,
    createdById: "creator-id",
    createdByName: createdByName,
    status: status,
    assignedToName: assignedToName,
    productionUserName: productionUserName,
    qcUserName: qcUserName,
    deliveryUserName: deliveryUserName,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("OrdersPage builds successfully", (tester) async {
    final api = FakeOrdersApi(orders: []);
    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    expect(find.byType(OrdersPage), findsOneWidget);
    expect(find.text("รายการออเดอร์"), findsOneWidget);
  });

  testWidgets("Search bar exists", (tester) async {
    final api = FakeOrdersApi(
      orders: [
        buildOrder(id: "1", customerName: "Alice", status: "pending", createdByName: "Creator"),
      ],
    );
    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    expect(searchField, findsOneWidget);
  });

  testWidgets("Loading state works", (tester) async {
    final api = FakeOrdersApi(orders: [], shouldDelay: true);
    await tester.pumpWidget(createTestWidget(api));
    await tester.pump(); // Start building

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text("กำลังโหลดข้อมูลออเดอร์..."), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2)); // Let it complete loading
  });

  testWidgets("Search integration does not crash", (tester) async {
    final api = FakeOrdersApi(
      orders: [
        buildOrder(
          id: "order-1",
          customerName: "Alice Wonderland",
          status: "pending",
          createdByName: "Creator",
        ),
      ],
    );

    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    // Type query to filter
    await tester.enterText(searchField, "Alice");
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text("Alice Wonderland"), findsOneWidget);
  });
}

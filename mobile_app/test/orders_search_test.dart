import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/orders_page.dart";

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

  testWidgets("search by customer name", (tester) async {
    final api = FakeOrdersApi(
      orders: [
        buildOrder(
          id: "order-1",
          customerName: "Alice Wonderland",
          status: "pending",
          createdByName: "Creator",
        ),
        buildOrder(
          id: "order-2",
          customerName: "Bob Builder",
          status: "pending",
          createdByName: "Creator",
        ),
      ],
    );

    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    await tester.enterText(searchField, "Alice");
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text("Alice Wonderland"), findsOneWidget);
    expect(find.text("Bob Builder"), findsNothing);
  });

  testWidgets("search by phone", (tester) async {
    final api = FakeOrdersApi(
      orders: [
        buildOrder(
          id: "ORD-1",
          customerName: "Customer One",
          customerPhone: "0899999999",
          status: "pending",
          createdByName: "Creator",
        ),
        buildOrder(
          id: "ORD-2",
          customerName: "Customer Two",
          customerPhone: "0811111111",
          status: "pending",
          createdByName: "Creator",
        ),
      ],
    );

    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    await tester.enterText(searchField, "0899");
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text("Customer One"), findsOneWidget);
    expect(find.text("Customer Two"), findsNothing);
  });

  testWidgets("clear button", (tester) async {
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

    await tester.enterText(searchField, "Alice");
    await tester.pumpAndSettle();

    final clearBtn = find.byKey(const Key("clear_search_button"));
    expect(clearBtn, findsOneWidget);

    await tester.tap(clearBtn);
    await tester.pumpAndSettle();

    expect(searchField, findsOneWidget);
    final textWidget = tester.widget<TextField>(searchField);
    expect(textWidget.controller?.text, isEmpty);
  });

  testWidgets("empty search result", (tester) async {
    final api = FakeOrdersApi(
      orders: [
        buildOrder(
          id: "order-1",
          customerName: "Alpha",
          status: "pending",
          createdByName: "Creator",
        ),
      ],
    );

    await tester.pumpWidget(createTestWidget(api));
    await tester.pumpAndSettle();

    await tester.enterText(searchField, "no-match");
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("empty_search_state")), findsOneWidget);
  });
}

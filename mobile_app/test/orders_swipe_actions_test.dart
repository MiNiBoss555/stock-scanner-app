import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/orders_page.dart";

class FakeOrdersApi extends StockApiService {
  FakeOrdersApi({required this.orders});

  final List<DeliveryOrder> orders;
  String? cancelledOrderId;

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
  Future<DeliveryOrder> updateOrderStatus({
    required String requesterId,
    required String orderId,
    required String status,
  }) async {
    if (status == "cancelled") {
      cancelledOrderId = orderId;
    }
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final old = orders[idx];
      orders[idx] = DeliveryOrder(
        id: old.id,
        customerName: old.customerName,
        customerPhone: old.customerPhone,
        customerAddress: old.customerAddress,
        trackingNumber: old.trackingNumber,
        createdById: old.createdById,
        createdByName: old.createdByName,
        status: status,
        items: old.items,
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
      );
    }
    return orders.firstWhere((o) => o.id == orderId);
  }

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
  required String status,
  required String createdByName,
}) {
  return DeliveryOrder(
    id: id,
    customerName: customerName,
    createdById: "creator-id",
    createdByName: createdByName,
    status: status,
    items: const [],
    createdAt: DateTime(2026, 6, 26, 9, 0),
    updatedAt: DateTime(2026, 6, 26, 9, 0),
  );
}

Widget createTestWidget(FakeOrdersApi api, {required AppUser user}) {
  return MaterialApp(
    home: Scaffold(
      body: OrdersPage(api: api, currentUser: user),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final binding = TestWidgetsFlutterBinding.instance;
    final view = binding.platformDispatcher.views.first as TestFlutterView;
    view.physicalSize = const Size(800, 2000);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    final view = binding.platformDispatcher.views.first as TestFlutterView;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  final adminUser = AppUser(
    userId: "tester-admin",
    userName: "Admin User",
    role: "admin",
    active: true,
  );

  final staffUser = AppUser(
    userId: "tester-staff",
    userName: "Staff User",
    role: "staff",
    active: true,
  );

  testWidgets("right swipe opens order details and card remains visible", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", status: "pending", createdByName: "Creator");
    final api = FakeOrdersApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: adminUser));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    expect(cardFinder, findsOneWidget);

    // Swipe right (start to end)
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    // Verify order details (preview) opens
    expect(find.text("ใบสรุปออเดอร์"), findsOneWidget);
    // Verify card is still visible (confirmDismiss returned false)
    expect(cardFinder, findsOneWidget);
  });

  testWidgets("left swipe opens action menu and cancel dialog acts correctly", (tester) async {
    final order = buildOrder(id: "order-2", customerName: "Bob", status: "pending", createdByName: "Creator");
    final api = FakeOrdersApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: adminUser));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const Key("dismissible_order-2"));
    expect(cardFinder, findsOneWidget);

    // Swipe left (end to start)
    await tester.drag(cardFinder, const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Verify bottom sheet action menu opens
    final actionSheet = find.byKey(const Key("order_action_sheet_order-2"));
    expect(actionSheet, findsOneWidget);

    // Tap cancel action
    final cancelTile = find.byKey(const Key("order_action_cancel_order-2"));
    expect(cancelTile, findsOneWidget);
    await tester.tap(cancelTile);
    await tester.pumpAndSettle();

    // Verify cancel confirmation dialog opens
    expect(find.text("ยืนยันการยกเลิกออเดอร์"), findsOneWidget);
    expect(find.text("คุณต้องการยกเลิกออเดอร์นี้ใช่หรือไม่?"), findsOneWidget);

    // Tap "ไม่" first
    final cancelNoBtn = find.widgetWithText(TextButton, "ไม่");
    expect(cancelNoBtn, findsOneWidget);
    await tester.tap(cancelNoBtn);
    await tester.pumpAndSettle();

    // Check that order is NOT cancelled
    expect(api.cancelledOrderId, isNull);

    // Swipe left again to open menu
    await tester.drag(cardFinder, const Offset(-500, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("order_action_cancel_order-2")));
    await tester.pumpAndSettle();

    // Tap "ยืนยัน"
    final cancelYesBtn = find.widgetWithText(FilledButton, "ยืนยัน");
    expect(cancelYesBtn, findsOneWidget);
    await tester.tap(cancelYesBtn);
    await tester.pumpAndSettle();

    // Check that order IS cancelled
    expect(api.cancelledOrderId, "order-2");
  });

  testWidgets("staff without permission does not see cancel action in menu", (tester) async {
    // A non-creator staff order (creator-id is Creator)
    final order = buildOrder(id: "order-3", customerName: "Charlie", status: "pending", createdByName: "Creator");
    final api = FakeOrdersApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: staffUser));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const Key("dismissible_order-3"));
    expect(cardFinder, findsOneWidget);

    // Swipe left
    await tester.drag(cardFinder, const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Verify bottom sheet action menu opens
    final actionSheet = find.byKey(const Key("order_action_sheet_order-3"));
    expect(actionSheet, findsOneWidget);

    // Verify "ยกเลิกออเดอร์" list tile is not visible
    final cancelTile = find.byKey(const Key("order_action_cancel_order-3"));
    expect(cancelTile, findsNothing);
  });
}

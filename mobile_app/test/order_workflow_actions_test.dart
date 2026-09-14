import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/orders_page.dart";

class FakeWorkflowApi extends StockApiService {
  FakeWorkflowApi({required this.orders});

  final List<DeliveryOrder> orders;
  String? lastActionCalled;
  String? lastNoteCalled;
  String? lastOrderIdCalled;
  int getOrdersCallCount = 0;

  @override
  Future<List<DeliveryOrder>> getOrders({
    required String requesterId,
    bool assignedOnly = false,
    bool mineOnly = false,
    int limit = 300,
  }) async {
    getOrdersCallCount++;
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
  Future<DeliveryOrder> updateOrderWorkflow(String orderId, String action, String? note) async {
    lastActionCalled = action;
    lastNoteCalled = note;
    lastOrderIdCalled = orderId;

    // update order status locally
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final old = orders[idx];

      String nextWorkflowStatus = "pending_board";
      if (action == "send_to_qc") nextWorkflowStatus = "pending_qc";
      else if (action == "send_to_robot") nextWorkflowStatus = "pending_robot";
      else if (action == "send_to_delivery") nextWorkflowStatus = "pending_delivery";
      else if (action == "wait_for_board") nextWorkflowStatus = "waiting_board";
      else if (action == "assembling") nextWorkflowStatus = "assembling";
      else if (action == "qc_pass") nextWorkflowStatus = "pending_delivery";
      else if (action == "reject_to_board") nextWorkflowStatus = "rejected_board";
      else if (action == "reject_to_robot") nextWorkflowStatus = "rejected_robot";
      else if (action == "wait_delivery") nextWorkflowStatus = "pending_delivery";
      else if (action == "delivered") nextWorkflowStatus = "delivered";

      orders[idx] = DeliveryOrder(
        id: old.id,
        customerName: old.customerName,
        createdById: old.createdById,
        createdByName: old.createdByName,
        status: old.status,
        items: old.items,
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
        orderWorkflowStatus: nextWorkflowStatus,
        orderWorkflowNote: note,
      );
    }

    return orders.firstWhere((o) => o.id == orderId);
  }
}

DeliveryOrder buildOrder({
  required String id,
  required String customerName,
  required String workflowStatus,
}) {
  return DeliveryOrder(
    id: id,
    customerName: customerName,
    createdById: "creator-id",
    createdByName: "Creator",
    status: "pending",
    items: const [],
    createdAt: DateTime(2026, 6, 26, 9, 0),
    updatedAt: DateTime(2026, 6, 26, 9, 0),
    orderWorkflowStatus: workflowStatus,
  );
}

Widget createTestWidget(FakeWorkflowApi api, {required AppUser user}) {
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

  final boardUser = AppUser(
    userId: "tester-board",
    userName: "Board User",
    role: "staff",
    position: "ฝ่ายผลิตบอร์ด",
    active: true,
  );

  final robotUser = AppUser(
    userId: "tester-robot",
    userName: "Robot User",
    role: "staff",
    position: "ฝ่ายผลิตหุ่นยนต์",
    active: true,
  );

  final qcUser = AppUser(
    userId: "tester-qc",
    userName: "QC User",
    role: "qc",
    active: true,
  );

  final deliveryUser = AppUser(
    userId: "tester-delivery",
    userName: "Delivery User",
    role: "delivery",
    active: true,
  );

  final genericStaff = AppUser(
    userId: "tester-generic",
    userName: "Generic User",
    role: "staff",
    position: "ทั่วไป",
    active: true,
  );

  testWidgets("Board user sees board buttons when status is pending_board", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", workflowStatus: "pending_board");
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: boardUser));
    await tester.pumpAndSettle();

    // Swipe right to open preview bottom sheet
    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    // Verify preview opens
    expect(find.text("ใบสรุปออเดอร์"), findsOneWidget);

    // Verify board action buttons are visible
    expect(find.byKey(const Key("workflow_action_send_to_qc")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_send_to_robot")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_send_to_delivery")), findsOneWidget);
  });

  testWidgets("Robot user sees robot buttons when status is pending_robot", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", workflowStatus: "pending_robot");
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: robotUser));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("workflow_action_wait_for_board")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_assembling")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_send_to_qc")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_send_to_delivery")), findsOneWidget);
  });

  testWidgets("QC user sees QC buttons when status is pending_qc", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", workflowStatus: "pending_qc");
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: qcUser));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("workflow_action_qc_pass")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_reject_to_board")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_reject_to_robot")), findsOneWidget);
  });

  testWidgets("Delivery user sees delivery buttons when status is pending_delivery", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", workflowStatus: "pending_delivery");
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: deliveryUser));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("workflow_action_wait_delivery")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_delivered")), findsOneWidget);
  });

  testWidgets("Generic staff (no permission) does not see unrelated buttons", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", workflowStatus: "pending_qc");
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: genericStaff));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("workflow_action_qc_pass")), findsNothing);
  });

  testWidgets("Reject button opens dialog and handles empty/valid notes", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", workflowStatus: "pending_qc");
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: qcUser));
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    final rejectBtn = find.byKey(const Key("workflow_action_reject_to_board"));
    await tester.tap(rejectBtn);
    await tester.pumpAndSettle();

    // Verify dialog opens with correct title
    expect(find.text("ระบุเหตุผลที่ต้องแก้ไข"), findsOneWidget);

    // Tap OK with empty note (triggers validation SnackBar)
    await tester.tap(find.text("ตกลง"));
    await tester.pumpAndSettle();

    // Verify update API was NOT called yet
    expect(api.lastActionCalled, isNull);

    // Fill in note and submit
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      "Board is cracked",
    );
    await tester.tap(find.text("ตกลง"));
    await tester.pumpAndSettle();

    // Verify update API was called
    expect(api.lastActionCalled, "reject_to_board");
    expect(api.lastNoteCalled, "Board is cracked");
    expect(api.lastOrderIdCalled, "order-1");

    // Verify bottom sheet closed and page refreshed
    expect(find.text("ใบสรุปออเดอร์"), findsNothing);
    expect(api.getOrdersCallCount, greaterThan(1));
  });
}

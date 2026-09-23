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
  String? lastStatusCalled;
  String? lastStatusOrderIdCalled;
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
  Future<DeliveryOrder> updateOrderStatus({
    required String requesterId,
    required String orderId,
    required String status,
  }) async {
    lastStatusCalled = status;
    lastStatusOrderIdCalled = orderId;
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final old = orders[idx];
      orders[idx] = DeliveryOrder(
        id: old.id,
        customerName: old.customerName,
        createdById: old.createdById,
        createdByName: old.createdByName,
        status: status,
        items: old.items,
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
        orderWorkflowStatus: status == "delivered" ? "delivered" : old.orderWorkflowStatus,
        orderWorkflowNote: old.orderWorkflowNote,
        boardProductionUserId: old.boardProductionUserId,
        robotProductionUserId: old.robotProductionUserId,
        qcUserId: old.qcUserId,
        deliveryUserId: old.deliveryUserId,
      );
      return orders[idx];
    }
    return orders.firstWhere((o) => o.id == orderId);
  }

  @override
  Future<DeliveryOrder> updateOrderWorkflow(String orderId, String action, String? note) async {
    lastActionCalled = action;
    lastNoteCalled = note;
    lastOrderIdCalled = orderId;

    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final old = orders[idx];

      String nextWorkflowStatus = old.orderWorkflowStatus;
      String nextStatus = old.status;
      if (action == "send_to_robot") {
        nextWorkflowStatus = "pending_robot";
        nextStatus = "in_production";
      } else if (action == "send_to_qc") {
        nextWorkflowStatus = "pending_qc";
        nextStatus = "qc_pending";
      } else if (action == "qc_pass") {
        nextWorkflowStatus = "pending_delivery";
        nextStatus = "qc_passed";
      } else if (action == "reject_to_board") {
        nextWorkflowStatus = "rejected_board";
        nextStatus = "rework_required";
      } else if (action == "reject_to_robot") {
        nextWorkflowStatus = "rejected_robot";
        nextStatus = "rework_required";
      }

      orders[idx] = DeliveryOrder(
        id: old.id,
        customerName: old.customerName,
        createdById: old.createdById,
        createdByName: old.createdByName,
        status: nextStatus,
        items: old.items,
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
        orderWorkflowStatus: nextWorkflowStatus,
        orderWorkflowNote: note,
        boardProductionUserId: old.boardProductionUserId,
        robotProductionUserId: old.robotProductionUserId,
        qcUserId: old.qcUserId,
        deliveryUserId: old.deliveryUserId,
      );
      return orders[idx];
    }

    return orders.firstWhere((o) => o.id == orderId);
  }
}

DeliveryOrder buildOrder({
  required String id,
  required String customerName,
  required String workflowStatus,
  String status = "new",
  String? boardUserId,
  String? robotUserId,
  String? qcUserId,
  String? deliveryUserId,
}) {
  return DeliveryOrder(
    id: id,
    customerName: customerName,
    createdById: "creator-id",
    createdByName: "Creator",
    status: status,
    items: const [],
    createdAt: DateTime(2026, 6, 26, 9, 0),
    updatedAt: DateTime(2026, 6, 26, 9, 0),
    orderWorkflowStatus: workflowStatus,
    boardProductionUserId: boardUserId,
    robotProductionUserId: robotUserId,
    qcUserId: qcUserId,
    deliveryUserId: deliveryUserId,
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
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(800, 2000);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    final view = binding.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  final boardUser = AppUser(
    userId: "tester-board",
    userName: "Board User",
    role: "staff",
    position: "ฝ่ายผลิตบอร์ด",
    active: true,
  );

  final otherBoardUser = AppUser(
    userId: "tester-board-2",
    userName: "Other Board User",
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

  testWidgets("Board user sees only board buttons when status is pending_board", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", workflowStatus: "pending_board");
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: boardUser));
    await tester.pumpAndSettle();

    // In card tile:
    expect(find.text("ส่งให้ฝ่ายผลิตหุ่นยนต์"), findsOneWidget);
    expect(find.text("เริ่มผลิต"), findsNothing);
    expect(find.text("ส่ง QC"), findsNothing);

    // Swipe right to open preview bottom sheet
    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    // Verify preview opens
    expect(find.text("ใบสรุปออเดอร์"), findsOneWidget);

    // Verify only board action button is visible (no skip to QC or Delivery)
    expect(find.byKey(const Key("workflow_action_send_to_robot")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_send_to_qc")), findsNothing);
    expect(find.byKey(const Key("workflow_action_send_to_delivery")), findsNothing);
  });

  testWidgets("Robot user sees only robot buttons when status is pending_robot", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", workflowStatus: "pending_robot");
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: robotUser));
    await tester.pumpAndSettle();

    // In card tile:
    expect(find.text("ส่งให้ QC"), findsOneWidget);

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("workflow_action_send_to_qc")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_wait_for_board")), findsNothing);
    expect(find.byKey(const Key("workflow_action_assembling")), findsNothing);
    expect(find.byKey(const Key("workflow_action_send_to_delivery")), findsNothing);
  });

  testWidgets("QC user sees QC pass and reject buttons when status is pending_qc", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", workflowStatus: "pending_qc");
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: qcUser));
    await tester.pumpAndSettle();

    // In card tile:
    expect(find.text("ผ่าน"), findsOneWidget);
    expect(find.text("ไม่ผ่าน ส่งกลับฝ่ายผลิตบอร์ด"), findsOneWidget);
    expect(find.text("ไม่ผ่าน ส่งกลับฝ่ายผลิตหุ่นยนต์"), findsOneWidget);

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("workflow_action_qc_pass")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_reject_to_board")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_reject_to_robot")), findsOneWidget);
  });

  testWidgets("Delivery user sees status-based delivery buttons when pending_delivery", (tester) async {
    final order = buildOrder(
      id: "order-1",
      customerName: "Alice",
      workflowStatus: "pending_delivery",
      status: "qc_passed",
    );
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: deliveryUser));
    await tester.pumpAndSettle();

    // In card tile:
    expect(find.text("เริ่มจัดสินค้า"), findsOneWidget);

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    // In preview sheet: uses status_action_preparing, not workflow_action_wait_delivery
    expect(find.byKey(const Key("status_action_preparing")), findsOneWidget);
    expect(find.byKey(const Key("workflow_action_wait_delivery")), findsNothing);
    expect(find.byKey(const Key("workflow_action_delivered")), findsNothing);

    // Tap preparing button
    await tester.tap(find.byKey(const Key("status_action_preparing")));
    await tester.pumpAndSettle();

    // Verify updateOrderStatus was called, NOT updateOrderWorkflow
    expect(api.lastStatusCalled, "preparing");
    expect(api.lastActionCalled, isNull);
  });

  testWidgets("Delivery user does not see buttons during board, robot, or qc stages", (tester) async {
    final order = buildOrder(id: "order-1", customerName: "Alice", workflowStatus: "pending_board");
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: deliveryUser));
    await tester.pumpAndSettle();

    expect(find.text("เริ่มจัดสินค้า"), findsNothing);
    expect(find.text("ออกจัดส่ง"), findsNothing);
    expect(find.text("ส่งสำเร็จ"), findsNothing);

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("status_action_preparing")), findsNothing);
    expect(find.byKey(const Key("status_action_out_for_delivery")), findsNothing);
    expect(find.byKey(const Key("status_action_delivered")), findsNothing);
  });

  testWidgets("Exact assignment permission: other board staff blocked when exact board user is assigned", (tester) async {
    final order = buildOrder(
      id: "order-1",
      customerName: "Alice",
      workflowStatus: "pending_board",
      boardUserId: "tester-board",
    );
    final api = FakeWorkflowApi(orders: [order]);

    await tester.pumpWidget(createTestWidget(api, user: otherBoardUser));
    await tester.pumpAndSettle();

    expect(find.text("ส่งให้ฝ่ายผลิตหุ่นยนต์"), findsNothing);

    final cardFinder = find.byKey(const Key("dismissible_order-1"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("workflow_action_send_to_robot")), findsNothing);
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

  testWidgets("Delivery button state drift guard: pending_delivery with status new hides start delivery", (tester) async {
    final order = buildOrder(
      id: "order-drift-new",
      customerName: "Drift New",
      workflowStatus: "pending_delivery",
      status: "new",
      deliveryUserId: "tester-delivery",
    );
    final api = FakeWorkflowApi(orders: [order]);
    await tester.pumpWidget(createTestWidget(api, user: deliveryUser));
    await tester.pumpAndSettle();

    expect(find.text("เริ่มจัดสินค้า"), findsNothing);

    final cardFinder = find.byKey(const Key("dismissible_order-drift-new"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("status_action_preparing")), findsNothing);
  });

  testWidgets("Delivery button state drift guard: pending_delivery with status assigned hides start delivery", (tester) async {
    final order = buildOrder(
      id: "order-drift-assigned",
      customerName: "Drift Assigned",
      workflowStatus: "pending_delivery",
      status: "assigned",
      deliveryUserId: "tester-delivery",
    );
    final api = FakeWorkflowApi(orders: [order]);
    await tester.pumpWidget(createTestWidget(api, user: deliveryUser));
    await tester.pumpAndSettle();

    expect(find.text("เริ่มจัดสินค้า"), findsNothing);

    final cardFinder = find.byKey(const Key("dismissible_order-drift-assigned"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("status_action_preparing")), findsNothing);
  });

  testWidgets("Delivery button state drift guard: pending_delivery with status qc_passed shows start delivery", (tester) async {
    final order = buildOrder(
      id: "order-drift-ok",
      customerName: "Drift Ok",
      workflowStatus: "pending_delivery",
      status: "qc_passed",
      deliveryUserId: "tester-delivery",
    );
    final api = FakeWorkflowApi(orders: [order]);
    await tester.pumpWidget(createTestWidget(api, user: deliveryUser));
    await tester.pumpAndSettle();

    expect(find.text("เริ่มจัดสินค้า"), findsOneWidget);

    final cardFinder = find.byKey(const Key("dismissible_order-drift-ok"));
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("status_action_preparing")), findsOneWidget);
  });
}

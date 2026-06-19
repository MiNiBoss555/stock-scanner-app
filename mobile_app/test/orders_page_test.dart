import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/orders_page.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeStockApiService extends StockApiService {
  List<DeliveryOrder> ordersList = [];
  List<AppUser> usersList = [];
  List<Product> productsList = [];
  List<String> proofPhotosList = [];
  bool getOrdersShouldFail = false;

  @override
  Future<List<DeliveryOrder>> getOrders({
    required String requesterId,
    bool assignedOnly = false,
    bool mineOnly = false,
    int limit = 300,
  }) async {
    if (getOrdersShouldFail) {
      throw Exception("Failed to load orders");
    }
    return ordersList;
  }

  @override
  Future<List<AppUser>> getUsers({bool activeOnly = true}) async {
    return usersList;
  }

  @override
  Future<List<Product>> getProducts({bool lowStockOnly = false}) async {
    return productsList;
  }

  @override
  Future<List<String>> getOrderProofPhotos({
    required String requesterId,
    required String orderId,
  }) async {
    return proofPhotosList;
  }

  @override
  Future<DeliveryOrder> createOrder({
    required String requesterId,
    required String customerName,
    String? customerPhone,
    String? customerAddress,
    String? note,
    String? assignedToId,
    String? productionUserId,
    String? qcUserId,
    String? deliveryUserId,
    DateTime? scheduledDeliveryAt,
    required List<Map<String, dynamic>> items,
  }) async {
    return DeliveryOrder(
      id: "created_order_id",
      customerName: customerName,
      createdById: requesterId,
      createdByName: "Creator",
      status: "pending",
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      customerPhone: customerPhone,
      customerAddress: customerAddress,
    );
  }

  @override
  Future<DeliveryOrder> updateOrderStatus({
    required String requesterId,
    required String orderId,
    required String status,
  }) async {
    return ordersList.firstWhere(
      (o) => o.id == orderId,
      orElse: () => DeliveryOrder(
        id: orderId,
        customerName: "Dummy",
        createdById: requesterId,
        createdByName: "Creator",
        status: status,
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  String orderPrintUrl({required String orderId, required String requesterId}) {
    return "http://print/$orderId";
  }

  @override
  String orderPackingSlipUrl({required String orderId, required String requesterId}) {
    return "http://pack/$orderId";
  }

  @override
  String orderPdfUrl({required String orderId, required String requesterId}) {
    return "http://pdf/$orderId";
  }

  @override
  Future<DeliveryOrder> deliverOrderPartial({
    required String requesterId,
    required String orderId,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    return ordersList.firstWhere((o) => o.id == orderId);
  }

  @override
  Future<DeliveryOrder> resolveBackorder({
    required String requesterId,
    required String orderId,
  }) async {
    return ordersList.firstWhere(
      (o) => o.id == orderId,
      orElse: () => DeliveryOrder(
        id: orderId,
        customerName: "Dummy",
        createdById: requesterId,
        createdByName: "Creator",
        status: "delivered",
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<DeliveryOrder> assignOrderTeam({
    required String requesterId,
    required String orderId,
    String? productionUserId,
    String? qcUserId,
    String? deliveryUserId,
  }) async {
    return ordersList.firstWhere(
      (o) => o.id == orderId,
      orElse: () => DeliveryOrder(
        id: orderId,
        customerName: "Dummy",
        createdById: requesterId,
        createdByName: "Creator",
        status: "assigned",
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }
}

void main() {
  late FakeStockApiService fakeApi;
  late AppUser testUser;
  late Product testProduct;
  late DeliveryOrder testOrder;

  setUp(() {
    fakeApi = FakeStockApiService();
    testUser = AppUser(
      userId: "test_user_id",
      userName: "Test User",
      role: "admin",
      active: true,
    );
    testProduct = Product(
      barcode: "barcode1",
      name: "Product 1",
      unit: "pcs",
      minimumStock: 2,
      currentStock: 10,
    );
    testOrder = DeliveryOrder(
      id: "order_id_123456",
      customerName: "John Doe",
      createdById: "creator_id",
      createdByName: "Creator Name",
      status: "assigned",
      items: [
        OrderItemModel(
          barcode: "barcode1",
          productName: "Product 1",
          quantity: 5,
          unit: "pcs",
          deliveredQuantity: 2,
        )
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      customerPhone: "0812345678",
      customerAddress: "123 Main St",
    );

    fakeApi.usersList = [testUser];
    fakeApi.productsList = [testProduct];
    fakeApi.ordersList = [testOrder];
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group("OrdersPage Widget Tests", () {
    // Test 1: ตรวจสอบว่า OrdersPage เปิดได้โดยไม่เกิด Exception
    testWidgets("OrdersPage opens and renders without exception", (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(OrdersPage), findsOneWidget);
    });

    // Test 2: ตรวจสอบว่า Navigation ไปยัง OrdersPage ทำงานปกติ
    testWidgets("Navigation to OrdersPage works correctly", (WidgetTester tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrdersPage(api: fakeApi, currentUser: testUser),
                ),
              );
            },
            child: const Text("Go"),
          ),
        ),
      ));

      await tester.tap(find.text("Go"));
      await tester.pumpAndSettle();

      expect(find.byType(OrdersPage), findsOneWidget);
    });

    // Test 3: ทดสอบการแสดงผลรายการออเดอร์เมื่อมีข้อมูล
    testWidgets("OrdersPage renders orders list when data is available", (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      // Customer name John Doe should be displayed in the list
      expect(find.text("John Doe"), findsOneWidget);
    });

    // Test 4: ทดสอบ Empty State เมื่อไม่มีออเดอร์
    testWidgets("OrdersPage renders Empty State when there are no orders", (WidgetTester tester) async {
      fakeApi.ordersList = [];

      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      expect(find.text("ยังไม่มีออเดอร์ในระบบ"), findsOneWidget);
    });

    // Test 5: ทดสอบ Error State เมื่อโหลดข้อมูลล้มเหลว
    testWidgets("OrdersPage renders Error State when loading fails", (WidgetTester tester) async {
      fakeApi.getOrdersShouldFail = true;

      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      expect(find.text("เชื่อมต่อ API ไม่สำเร็จ"), findsOneWidget);
    });

    // Test 6: ทดสอบการเปิด BackorderReportSheet
    testWidgets("OrdersPage opens BackorderReportSheet full report", (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      // Tap full report button
      final btn = find.text("เปิดรายงานแบบเต็ม");
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Should show sheet title
      expect(find.text("รายงานค้างจ่าย"), findsWidgets);
    });

    // Test 7: ทดสอบ DeliverySuccessOverlay
    testWidgets("OrdersPage shows DeliverySuccessOverlay when marked delivered", (WidgetTester tester) async {
      // Set larger viewport to avoid off-screen button issues
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeApi.proofPhotosList = ["http://proof.photo/1.jpg"]; // Mock proof photo to enable "ส่งแล้ว" button
      
      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      // Find and tap the "ส่งแล้ว" button
      final deliveredBtn = find.widgetWithText(FilledButton, "ส่งแล้ว");
      expect(deliveredBtn, findsOneWidget);
      await tester.ensureVisible(deliveredBtn);
      await tester.pumpAndSettle();
      await tester.tap(deliveredBtn);
      
      // Pump for general dialog animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // DeliverySuccessOverlay should display the success text
      expect(find.text("ส่งสินค้าเรียบร้อย!"), findsOneWidget);

      // Advance time by 5 seconds to trigger the auto-dismiss timer and wait for animations to settle
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/dashboard_home.dart";
import "package:stock_scanner_mobile/models.dart";

void main() {
  // Setup sample test data
  final testUser = AppUser(
    userId: "USER123",
    userName: "Test Username",
    role: "admin",
    active: true,
  );

  final product1 = Product(
    barcode: "111111",
    name: "Normal Product",
    unit: "pcs",
    minimumStock: 5,
    currentStock: 10,
  );

  final productOutOfStock = Product(
    barcode: "222222",
    name: "Out of Stock Product",
    unit: "pcs",
    minimumStock: 5,
    currentStock: 0,
  );

  final productLowStock = Product(
    barcode: "333333",
    name: "Low Stock Product",
    unit: "pcs",
    minimumStock: 5,
    currentStock: 2,
  );

  final order1 = DeliveryOrder(
    id: "ORDER1",
    customerName: "Customer One",
    createdById: "USER123",
    createdByName: "Creator Name",
    status: "new",
    items: [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final order2 = DeliveryOrder(
    id: "ORDER2",
    customerName: "Customer Two",
    createdById: "USER123",
    createdByName: "Creator Name",
    status: "qc_pending",
    items: [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testSummary = StockSummary(
    totalProducts: 3,
    totalUnits: 12,
    lowStockCount: 1,
    lowStockItems: [productLowStock],
  );

  final testData = DashboardData(
    summary: testSummary,
    products: [product1, productOutOfStock, productLowStock],
    activeOrders: [order1],
    todayUpdatedOrders: [order2],
  );

  group("MobileDashboardHome Widget Tests", () {
    testWidgets("renders user details, summary numbers, and order lists", (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileDashboardHome(
              data: testData,
              currentUser: testUser,
              onOpenOrdersTab: () {},
              onOpenOrderPreview: (_) async {},
              onOpenProductList: (_, __, ___, ____, _____) {},
            ),
          ),
        ),
      );

      // Verify header texts
      expect(find.text("ภาพรวมสต็อก"), findsOneWidget);
      expect(find.text("Test Username"), findsOneWidget);
      expect(find.text("ผู้ดูแลระบบ"), findsOneWidget);

      // Verify health stats counts
      expect(find.text("3"), findsOneWidget); // Total
      expect(find.text("1"), findsNWidgets(2)); // Both "หมดสต็อก" and "ใกล้หมด" have count 1

      // Verify Action banner for active orders
      expect(find.text("งานค้างส่ง 1 ออเดอร์"), findsOneWidget);

      // Verify latest orders and realtime feed
      expect(find.text("Customer One"), findsOneWidget);
      expect(find.text("Customer Two"), findsOneWidget);
    });

    testWidgets("triggers callbacks when interaction happens", (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool productListCalled = false;
      bool orderPreviewCalled = false;
      bool ordersTabCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileDashboardHome(
              data: testData,
              currentUser: testUser,
              onOpenOrdersTab: () {
                ordersTabCalled = true;
              },
              onOpenOrderPreview: (order) async {
                if (order.id == "ORDER1") {
                  orderPreviewCalled = true;
                }
              },
              onOpenProductList: (context, products, title, icon, color) {
                if (title == "สินค้าหมด" && products.first.barcode == "222222") {
                  productListCalled = true;
                }
              },
            ),
          ),
        ),
      );

      // Tap on "หมดสต็อก" card (triggers productList callback)
      await tester.tap(find.text("หมดสต็อก"));
      await tester.pump();
      expect(productListCalled, isTrue);

      // Tap on Action Banner (triggers ordersTab callback)
      await tester.tap(find.text("งานค้างส่ง 1 ออเดอร์"));
      await tester.pump();
      expect(ordersTabCalled, isTrue);

      // Tap on Customer One card (triggers orderPreview callback)
      await tester.tap(find.text("Customer One"));
      await tester.pump();
      expect(orderPreviewCalled, isTrue);
    });
  });

  group("WebDashboardHome Widget Tests", () {
    testWidgets("renders web dashboard with stats and headers", (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebDashboardHome(
              data: testData,
              onOpenOrdersTab: () {},
              productSearchController: searchController,
              productSearch: "",
              onProductSearchChanged: (_) {},
              onClearProductSearch: () {},
              matchedProducts: [product1],
              onOpenAssistant: () {},
              onOpenOrders: () {},
              onOpenStock: () {},
              onOpenProductList: (_, __, ___, ____, _____) {},
              onOpenProductDetails: (_, __) {},
            ),
          ),
        ),
      );

      // Wait for animations and timers in _HeroReveal to settle
      await tester.pumpAndSettle();

      // Verify section headers
      expect(find.text("งานค้างส่ง"), findsOneWidget);
      expect(find.text("ภาพรวมด่วน"), findsOneWidget);
      expect(find.text("ต้องดูต่อ"), findsOneWidget);

      // Verify stat cards
      expect(find.text("สินค้าใกล้หมด"), findsOneWidget);
      expect(find.text("ออเดอร์ค้างส่ง"), findsOneWidget);
      expect(find.text("สินค้าทั้งหมด"), findsOneWidget);

      // Verify the low stock focus card renders details
      expect(find.text("Low Stock Product"), findsOneWidget);
    });

    testWidgets("triggers web callbacks correctly", (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool assistantCalled = false;
      bool ordersTabCalled = false;
      bool productDetailsCalled = false;
      bool productListCalled = false;

      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WebDashboardHome(
              data: testData,
              onOpenOrdersTab: () {
                ordersTabCalled = true;
              },
              productSearchController: searchController,
              productSearch: "",
              onProductSearchChanged: (_) {},
              onClearProductSearch: () {},
              matchedProducts: [product1],
              onOpenAssistant: () {
                assistantCalled = true;
              },
              onOpenOrders: () {},
              onOpenStock: () {},
              onOpenProductList: (context, products, title, icon, color) {
                productListCalled = true;
              },
              onOpenProductDetails: (context, product) {
                if (product.barcode == "333333") {
                  productDetailsCalled = true;
                }
              },
            ),
          ),
        ),
      );

      // Wait for animations and timers in _HeroReveal to settle
      await tester.pumpAndSettle();

      // Tap on chatbot button (AI Assistant) inside WebDashboardHero
      await tester.tap(find.byIcon(Icons.smart_toy_rounded));
      await tester.pump();
      expect(assistantCalled, isTrue);

      // Tap on "สินค้าหมด: 1 รายการ" button
      await tester.tap(find.text("สินค้าหมด: 1 รายการ"));
      await tester.pump();
      expect(productListCalled, isTrue);

      // Tap on low stock focus card
      await tester.tap(find.text("Low Stock Product"));
      await tester.pump();
      expect(productDetailsCalled, isTrue);

      // Tap on QuickStatCard "ออเดอร์ค้างส่ง"
      await tester.tap(find.text("ออเดอร์ค้างส่ง"));
      await tester.pump();
      expect(ordersTabCalled, isTrue);
    });
  });
}

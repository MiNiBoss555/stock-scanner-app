import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/main.dart" as app;
import "package:stock_scanner_mobile/help_center_page.dart";
import "package:stock_scanner_mobile/product_search_page.dart";

class FakeStockApiService extends StockApiService {
  List<Product> mockProducts = [];
  List<ProductTimelineItem> mockTimeline = [];

  @override
  Future<List<Product>> getProducts({bool lowStockOnly = false, bool includeInactive = false}) async {
    return mockProducts;
  }

  @override
  Future<List<ProductTimelineItem>> getProductTimeline({
    required String barcode,
    required String requesterId,
    int limit = 100,
  }) async {
    return mockTimeline;
  }
}

void main() {
  late FakeStockApiService fakeApi;
  late AppUser testUser;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeApi = FakeStockApiService();
    testUser = AppUser(
      userId: "STF001",
      userName: "Staff User",
      role: "staff",
      active: true,
    );
    fakeApi.mockProducts = [
      Product(
        barcode: "123456",
        name: "Test Item A",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 10,
      )
    ];
  });

  testWidgets("1. HelpCenterPage renders all sections correctly", (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
    await tester.pumpAndSettle();

    expect(find.text("วิธีใช้งาน"), findsOneWidget);
    expect(find.text("เริ่มต้นใช้งาน"), findsOneWidget);
    expect(find.text("เพิ่มสินค้า"), findsOneWidget);

    final finder = find.byType(Scrollable);

    await tester.scrollUntilVisible(find.text("รับสินค้าเข้า"), 100, scrollable: finder);
    expect(find.text("รับสินค้าเข้า"), findsOneWidget);

    await tester.scrollUntilVisible(find.text("เบิกสินค้าออก"), 100, scrollable: finder);
    expect(find.text("เบิกสินค้าออก"), findsOneWidget);

    await tester.scrollUntilVisible(find.text("ออเดอร์"), 100, scrollable: finder);
    expect(find.text("ออเดอร์"), findsOneWidget);

    await tester.scrollUntilVisible(find.text("สแกนใบปะหน้า"), 100, scrollable: finder);
    expect(find.text("สแกนใบปะหน้า"), findsOneWidget);

    await tester.scrollUntilVisible(find.text("ถังขยะสินค้า"), 100, scrollable: finder);
    expect(find.text("ถังขยะสินค้า"), findsOneWidget);

    await tester.scrollUntilVisible(find.text("ไทม์ไลน์สินค้า"), 100, scrollable: finder);
    expect(find.text("ไทม์ไลน์สินค้า"), findsOneWidget);
  });

  testWidgets("2. MorePage renders 'วิธีใช้งาน' menu item and navigates to HelpCenterPage", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: app.MorePage(
            api: fakeApi,
            currentUser: testUser,
            onLogout: () async {},
            onRefreshSession: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("วิธีใช้งาน"), findsOneWidget);
    expect(find.text("เรียนรู้การใช้งานแบบสั้น ๆ"), findsOneWidget);

    await tester.tap(find.text("วิธีใช้งาน"));
    await tester.pumpAndSettle();

    // Verify it pushed HelpCenterPage
    expect(find.byType(HelpCenterPage), findsOneWidget);
  });

  testWidgets("3. ProductSearchPage first-time tip appears and can be dismissed", (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({}); // No key is set, meaning first-time

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductSearchPage(
            api: fakeApi,
            currentUser: testUser,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Search tip should appear
    expect(find.text("เริ่มต้นที่นี่"), findsOneWidget);
    expect(find.text("ค้นหาสินค้า แล้วใช้ + เพื่อรับเข้า หรือ - เพื่อเบิกออก"), findsOneWidget);

    // Tap understood button
    final dismissBtn = find.byKey(const Key("dismiss_search_tip"));
    expect(dismissBtn, findsOneWidget);
    await tester.tap(dismissBtn);
    await tester.pumpAndSettle();

    // Search tip should be gone
    expect(find.text("เริ่มต้นที่นี่"), findsNothing);

    // Verify SharedPreferences updated
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool("product_search_tip_seen"), isTrue);
  });

  testWidgets("4. ProductSearchPage does not show tip if already seen", (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({"product_search_tip_seen": true});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductSearchPage(
            api: fakeApi,
            currentUser: testUser,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tip should not render
    expect(find.text("เริ่มต้นที่นี่"), findsNothing);
  });

  testWidgets("5. Timeline first-time dialog appears and registers on SharedPreferences", (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({}); // No keys set

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductSearchPage(
            api: fakeApi,
            currentUser: testUser,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Search for product to display search results list
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, "Test");
    await tester.pumpAndSettle();

    // Verify timeline button is present
    final timelineBtn = find.byKey(const Key("timeline_123456"));
    expect(timelineBtn, findsOneWidget);

    // Tap timeline button
    await tester.tap(timelineBtn);
    await tester.pumpAndSettle();

    // Verify tip dialog is shown
    expect(find.text("ไทม์ไลน์สินค้า"), findsOneWidget);
    expect(find.text("ใช้ดูประวัติของสินค้านี้ เช่น รับเข้า เบิกออก ซ่อน และกู้คืน"), findsOneWidget);

    // Dismiss dialog
    final dismissDialogBtn = find.byKey(const Key("dismiss_timeline_tip"));
    expect(dismissDialogBtn, findsOneWidget);
    await tester.tap(dismissDialogBtn);
    await tester.pumpAndSettle();

    // Dialog should be gone
    expect(find.text("ใช้ดูประวัติของสินค้านี้ เช่น รับเข้า เบิกออก ซ่อน และกู้คืน"), findsNothing);

    // Verify preference is saved
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool("timeline_tip_seen"), isTrue);
  });
}

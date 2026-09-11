import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/help_center_page.dart";
import "package:stock_scanner_mobile/product_search_page.dart";
import "package:stock_scanner_mobile/product_recycle_bin_page.dart";

class FakeStockApiService extends StockApiService {
  List<Product> mockProducts = [];

  @override
  Future<List<Product>> getProducts({bool lowStockOnly = false, bool includeInactive = false}) async {
    return mockProducts;
  }
}

void main() {
  late FakeStockApiService fakeApi;
  late AppUser adminUser;
  late AppUser staffUser;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeApi = FakeStockApiService();
    adminUser = AppUser(
      userId: "ADM01",
      userName: "Admin User",
      role: "admin",
      active: true,
    );
    staffUser = AppUser(
      userId: "STF01",
      userName: "Staff User",
      role: "staff",
      active: true,
    );
  });

  testWidgets("1. HelpCenterPage shows 'ลองทำเลย' buttons", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HelpCenterPage(
          api: fakeApi,
          currentUser: staffUser,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);

    // Scroll and check for each try button
    final keys = [
      "try_เพิ่มสินค้า",
      "try_รับสินค้าเข้า",
      "try_เบิกสินค้าออก",
      "try_ออเดอร์",
      "try_สแกนใบปะหน้า",
      "try_ถังขยะสินค้า",
      "try_ไทม์ไลน์สินค้า",
    ];

    for (final key in keys) {
      final btn = find.byKey(Key(key));
      await tester.scrollUntilVisible(btn, 100, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(btn, findsOneWidget);
    }
  });

  testWidgets("2. stock-in guide opens ProductSearchPage with stockIn guidance", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HelpCenterPage(
          api: fakeApi,
          currentUser: staffUser,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);
    final tryBtn = find.byKey(const Key("try_รับสินค้าเข้า"));
    await tester.scrollUntilVisible(tryBtn, 100, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(tryBtn);
    await tester.pumpAndSettle();

    // Verify ProductSearchPage is opened
    expect(find.byType(ProductSearchPage), findsOneWidget);

    // Verify stockIn guidance tip is displayed
    expect(find.text("คำแนะนำการใช้งาน"), findsOneWidget);
    expect(find.text("ค้นหาสินค้า แล้วกด + รับเข้า เพื่อเพิ่มจำนวนสินค้า"), findsOneWidget);

    // Verify understood button dismisses it
    final dismissBtn = find.byKey(const Key("dismiss_guidance_tip"));
    expect(dismissBtn, findsOneWidget);
    await tester.tap(dismissBtn);
    await tester.pumpAndSettle();

    expect(find.text("คำแนะนำการใช้งาน"), findsNothing);
  });

  testWidgets("3. stock-out guide opens ProductSearchPage with stockOut guidance", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HelpCenterPage(
          api: fakeApi,
          currentUser: staffUser,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);
    final tryBtn = find.byKey(const Key("try_เบิกสินค้าออก"));
    await tester.scrollUntilVisible(tryBtn, 100, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(tryBtn);
    await tester.pumpAndSettle();

    expect(find.byType(ProductSearchPage), findsOneWidget);
    expect(find.text("คำแนะนำการใช้งาน"), findsOneWidget);
    expect(find.text("ค้นหาสินค้า แล้วกด - เบิกออก เพื่อลดจำนวนสินค้า"), findsOneWidget);
  });

  testWidgets("4. timeline guide opens ProductSearchPage with timeline guidance", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HelpCenterPage(
          api: fakeApi,
          currentUser: staffUser,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);
    final tryBtn = find.byKey(const Key("try_ไทม์ไลน์สินค้า"));
    await tester.scrollUntilVisible(tryBtn, 100, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(tryBtn);
    await tester.pumpAndSettle();

    expect(find.byType(ProductSearchPage), findsOneWidget);
    expect(find.text("คำแนะนำการใช้งาน"), findsOneWidget);
    expect(find.text("ค้นหาสินค้า แล้วกด ไทม์ไลน์ เพื่อดูประวัติสินค้า"), findsOneWidget);
  });

  testWidgets("5. Staff tapping Recycle Bin guide shows admin-only dialog", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HelpCenterPage(
          api: fakeApi,
          currentUser: staffUser,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);
    final tryBtn = find.byKey(const Key("try_ถังขยะสินค้า"));
    await tester.scrollUntilVisible(tryBtn, 100, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(tryBtn);
    await tester.pumpAndSettle();

    // Verify admin-only warning dialog appears
    expect(find.text("สิทธิ์การเข้าถึง"), findsOneWidget);
    expect(find.text("เมนูนี้ใช้ได้เฉพาะผู้ดูแลระบบ"), findsOneWidget);

    // Close dialog
    await tester.tap(find.text("ตกลง"));
    await tester.pumpAndSettle();

    expect(find.text("เมนูนี้ใช้ได้เฉพาะผู้ดูแลระบบ"), findsNothing);
  });

  testWidgets("6. Admin tapping Recycle Bin guide opens ProductRecycleBinPage", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HelpCenterPage(
          api: fakeApi,
          currentUser: adminUser,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);
    final tryBtn = find.byKey(const Key("try_ถังขยะสินค้า"));
    await tester.scrollUntilVisible(tryBtn, 100, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(tryBtn);
    await tester.pumpAndSettle();

    // Verify ProductRecycleBinPage is opened
    expect(find.byType(ProductRecycleBinPage), findsOneWidget);
  });
}

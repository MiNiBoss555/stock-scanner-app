import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/empty_state.dart";
import "package:stock_scanner_mobile/loading_state.dart";
import "package:stock_scanner_mobile/product_timeline_page.dart";
import "package:stock_scanner_mobile/product_recycle_bin_page.dart";
import "package:stock_scanner_mobile/product_activity_log_page.dart";

class FakeStockApiService extends StockApiService {
  List<Product> mockProducts = [];
  List<ProductTimelineItem> mockTimeline = [];
  List<ProductActivityLog> mockLogs = [];

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

  @override
  Future<List<ProductActivityLog>> getProductActivityLogs({
    String? barcode,
    String? action,
    int? limit,
    String? requesterId,
  }) async {
    return mockLogs;
  }
}

void main() {
  late FakeStockApiService fakeApi;
  late AppUser adminUser;

  setUp(() {
    fakeApi = FakeStockApiService();
    adminUser = AppUser(
      userId: "ADM01",
      userName: "Admin User",
      role: "admin",
      active: true,
    );
  });

  testWidgets("1. EmptyState renders correctly with action button", (WidgetTester tester) async {
    bool actionTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.info,
            title: "หัวข้อทดสอบ",
            message: "คำอธิบายรายละเอียดการทดสอบ",
            actionLabel: "ปุ่มกด",
            onAction: () {
              actionTapped = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.info), findsOneWidget);
    expect(find.text("หัวข้อทดสอบ"), findsOneWidget);
    expect(find.text("คำอธิบายรายละเอียดการทดสอบ"), findsOneWidget);
    expect(find.text("ปุ่มกด"), findsOneWidget);

    await tester.tap(find.text("ปุ่มกด"));
    expect(actionTapped, isTrue);
  });

  testWidgets("2. LoadingState renders correctly with message", (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingState(message: "กำลังโหลดอย่างงดงาม..."),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("กำลังโหลดอย่างงดงาม..."), findsOneWidget);
  });

  testWidgets("3. ProductTimelinePage empty state works", (WidgetTester tester) async {
    fakeApi.mockTimeline = [];
    await tester.pumpWidget(
      MaterialApp(
        home: ProductTimelinePage(
          api: fakeApi,
          currentUser: adminUser,
          barcode: "885000",
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text("ยังไม่มีประวัติสำหรับสินค้านี้"), findsOneWidget);
    expect(find.text("เมื่อมีการรับเข้า เบิกออก ซ่อน หรือกู้คืน Timeline จะแสดงที่นี่"), findsOneWidget);
  });

  testWidgets("4. ProductRecycleBinPage no inactive products state works", (WidgetTester tester) async {
    fakeApi.mockProducts = []; // No inactive products returned
    await tester.pumpWidget(
      MaterialApp(
        home: ProductRecycleBinPage(
          api: fakeApi,
          currentUser: adminUser,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text("ยังไม่มีสินค้าในถังขยะ"), findsOneWidget);
  });

  testWidgets("5. ProductRecycleBinPage search no result state works", (WidgetTester tester) async {
    fakeApi.mockProducts = [
      Product(
        barcode: "111222",
        name: "สินค้าขยะ A",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 10,
        active: false,
      )
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: ProductRecycleBinPage(
          api: fakeApi,
          currentUser: adminUser,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Type query that won't match "สินค้าขยะ A"
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, "ไม่มีทางเจอ");
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text("ไม่พบสินค้าที่ตรงกับคำค้นหา"), findsOneWidget);
  });

  testWidgets("6. ProductActivityLogPage empty state works", (WidgetTester tester) async {
    fakeApi.mockLogs = [];
    await tester.pumpWidget(
      MaterialApp(
        home: ProductActivityLogPage(
          api: fakeApi,
          currentUser: adminUser,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text("ยังไม่มีกิจกรรมสินค้า"), findsOneWidget);
  });
}

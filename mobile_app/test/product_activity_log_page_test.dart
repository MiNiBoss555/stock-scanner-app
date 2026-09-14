import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/product_activity_log_page.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeStockApiService extends StockApiService {
  List<ProductActivityLog> mockLogs = [];
  bool getProductActivityLogsCalled = false;
  String? lastBarcodeParam;
  String? lastActionParam;
  int? lastLimitParam;
  String? lastRequesterIdParam;

  @override
  Future<List<ProductActivityLog>> getProductActivityLogs({
    String? barcode,
    String? action,
    int? limit,
    String? requesterId,
  }) async {
    getProductActivityLogsCalled = true;
    lastBarcodeParam = barcode;
    lastActionParam = action;
    lastLimitParam = limit;
    lastRequesterIdParam = requesterId;
    return mockLogs;
  }
}

void main() {
  late FakeStockApiService fakeApi;
  late AppUser adminUser;
  late AppUser staffUser;

  setUp(() {
    fakeApi = FakeStockApiService();
    adminUser = AppUser(
      userId: "admin01",
      userName: "Admin Name",
      role: "admin",
      active: true,
    );
    staffUser = AppUser(
      userId: "staff01",
      userName: "Staff Name",
      role: "staff",
      active: true,
    );
  });

  Widget createWidget({required AppUser user}) {
    return MaterialApp(
      home: ProductActivityLogPage(
        api: fakeApi,
        currentUser: user,
      ),
    );
  }

  testWidgets("1. Staff cannot access page", (tester) async {
    await tester.pumpWidget(createWidget(user: staffUser));
    await tester.pump();

    expect(find.text("ปฏิเสธการเข้าถึง: เฉพาะผู้ดูแลระบบเท่านั้น"), findsOneWidget);
    expect(fakeApi.getProductActivityLogsCalled, isFalse);
  });

  testWidgets("2. Admin can view activity logs list", (tester) async {
    fakeApi.mockLogs = [
      ProductActivityLog(
        id: "log01",
        barcode: "12345",
        productName: "Test Product A",
        action: "archive",
        actorId: "admin01",
        actorName: "Admin Name",
        note: "ปิดใช้งานแล้ว",
        createdAt: DateTime.parse("2026-06-25T12:00:00Z"),
      ),
      ProductActivityLog(
        id: "log02",
        barcode: "67890",
        productName: "Test Product B",
        action: "restore",
        actorId: "admin01",
        actorName: "Admin Name",
        note: "กู้คืนแล้ว",
        createdAt: DateTime.parse("2026-06-25T13:00:00Z"),
      ),
    ];

    await tester.pumpWidget(createWidget(user: adminUser));
    await tester.pump();
    await tester.pump();

    expect(fakeApi.getProductActivityLogsCalled, isTrue);
    expect(find.text("Test Product A"), findsOneWidget);
    expect(find.text("Test Product B"), findsOneWidget);
    expect(find.text("บาร์โค้ด: 12345"), findsOneWidget);
    expect(find.text("บาร์โค้ด: 67890"), findsOneWidget);
    expect(find.text("ปิดใช้งานแล้ว"), findsOneWidget);
    expect(find.text("กู้คืนแล้ว"), findsOneWidget);
  });

  testWidgets("3. Filtering by barcode", (tester) async {
    fakeApi.mockLogs = [];
    await tester.pumpWidget(createWidget(user: adminUser));
    await tester.pump();

    // Type a barcode
    await tester.enterText(find.byType(TextField), "12345");
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(fakeApi.lastBarcodeParam, "12345");
  });

  testWidgets("4. Selecting action chips triggers reload", (tester) async {
    fakeApi.mockLogs = [];
    await tester.pumpWidget(createWidget(user: adminUser));
    await tester.pump();

    // Find and tap ChoiceChip for archive
    await tester.tap(find.text("ปิดใช้งานสินค้า"));
    await tester.pump();

    expect(fakeApi.lastActionParam, "archive");
  });
}

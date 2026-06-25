import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/product_timeline_page.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeStockApiService extends StockApiService {
  List<ProductTimelineItem> mockItems = [];
  bool getProductTimelineCalled = false;
  String? lastBarcodeParam;
  String? lastRequesterIdParam;
  int? lastLimitParam;

  @override
  Future<List<ProductTimelineItem>> getProductTimeline({
    required String barcode,
    required String requesterId,
    int limit = 100,
  }) async {
    getProductTimelineCalled = true;
    lastBarcodeParam = barcode;
    lastRequesterIdParam = requesterId;
    lastLimitParam = limit;
    return mockItems;
  }
}

void main() {
  late FakeStockApiService fakeApi;
  late AppUser testUser;

  setUp(() {
    fakeApi = FakeStockApiService();
    testUser = AppUser(
      userId: "EMP001",
      userName: "Nok",
      role: "staff",
      active: true,
    );
  });

  Widget createWidget({required String barcode, String? productName}) {
    return MaterialApp(
      home: ProductTimelinePage(
        api: fakeApi,
        currentUser: testUser,
        barcode: barcode,
        productName: productName,
      ),
    );
  }

  testWidgets("1. Loads and renders product info header", (tester) async {
    await tester.pumpWidget(createWidget(barcode: "8850001110012", productName: "Mama Noodle"));
    await tester.pump();

    expect(find.text("Mama Noodle"), findsOneWidget);
    expect(find.text("8850001110012"), findsOneWidget);
    expect(fakeApi.getProductTimelineCalled, isTrue);
    expect(fakeApi.lastBarcodeParam, "8850001110012");
    expect(fakeApi.lastRequesterIdParam, "EMP001");
  });

  testWidgets("2. Renders timeline items correctly", (tester) async {
    fakeApi.mockItems = [
      ProductTimelineItem(
        id: "m1",
        type: "movement",
        barcode: "8850001110012",
        productName: "Mama Noodle",
        title: "นำเข้าสินค้า",
        description: "ทดสอบการนำเข้า",
        actorId: "EMP001",
        actorName: "Nok",
        quantity: 10,
        beforeStock: 0,
        afterStock: 10,
        action: "in",
        createdAt: DateTime.parse("2026-06-25T12:00:00Z"),
      ),
      ProductTimelineItem(
        id: "a1",
        type: "activity",
        barcode: "8850001110012",
        productName: "Mama Noodle",
        title: "ปิดใช้งานสินค้า",
        description: "ต้องการซ่อน",
        actorId: "EMP001",
        actorName: "Nok",
        action: "archive",
        createdAt: DateTime.parse("2026-06-25T13:00:00Z"),
      ),
    ];

    await tester.pumpWidget(createWidget(barcode: "8850001110012"));
    await tester.pump();
    await tester.pump();

    // Verify title and description
    expect(find.text("นำเข้าสินค้า"), findsOneWidget);
    expect(find.text("ปิดใช้งานสินค้า"), findsOneWidget);
    expect(find.text("ทดสอบการนำเข้า"), findsOneWidget);
    expect(find.text("ต้องการซ่อน"), findsOneWidget);

    // Verify movement details
    expect(find.text("+10"), findsOneWidget);
    expect(find.text("คงเหลือ: 0 → 10"), findsOneWidget);
    expect(find.text("ผู้บันทึก: Nok (EMP001)"), findsNWidgets(2));
  });

  testWidgets("3. Shows empty state when no timeline history", (tester) async {
    fakeApi.mockItems = [];

    await tester.pumpWidget(createWidget(barcode: "8850001110012"));
    await tester.pump();
    await tester.pump();

    expect(find.text("ยังไม่มีประวัติสำหรับสินค้านี้"), findsOneWidget);
    expect(find.text("เมื่อมีการรับเข้า เบิกออก ซ่อน หรือกู้คืน Timeline จะแสดงที่นี่"), findsOneWidget);
  });
}

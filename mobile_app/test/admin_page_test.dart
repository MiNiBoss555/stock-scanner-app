import "dart:typed_data";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/admin_page.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeAdminStockApiService extends StockApiService {
  bool syncProductsCalled = false;
  bool syncUsersCalled = false;
  bool syncStocksCalled = false;
  bool appendTestCalled = false;
  bool downloadBackupCalled = false;
  bool restoreBackupCalled = false;
  bool importProductsExcelCalled = false;
  bool getOrdersCalled = false;
  bool createExportLinkCalled = false;

  @override
  Future<String> syncProducts({required String requesterId}) async {
    syncProductsCalled = true;
    return "Products synced";
  }

  @override
  Future<String> syncUsers({required String requesterId}) async {
    syncUsersCalled = true;
    return "Users synced";
  }

  @override
  Future<String> syncStocks({required String requesterId}) async {
    syncStocksCalled = true;
    return "Stocks updated";
  }

  @override
  Future<String> appendTest({required String requesterId}) async {
    appendTestCalled = true;
    return "Test row appended";
  }

  @override
  Future<ExportLink> createExportLink({
    required String exportName,
    required String requesterId,
    int movementLimit = 5000,
    String? barcode,
    String? actorId,
  }) async {
    createExportLinkCalled = true;
    return ExportLink(
      url: "https://test-export.com/$exportName",
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<Uint8List> downloadBackup(String requesterId) async {
    downloadBackupCalled = true;
    return Uint8List.fromList([1, 2, 3, 4]);
  }

  @override
  Future<String> restoreBackup({
    required String requesterId,
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    restoreBackupCalled = true;
    return "Restore successful";
  }

  @override
  Future<String> importProductsExcel({
    required String requesterId,
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    importProductsExcelCalled = true;
    return "Excel imported successfully";
  }

  @override
  Future<List<DeliveryOrder>> getOrders({
    required String requesterId,
    bool assignedOnly = false,
    bool mineOnly = false,
    int limit = 300,
  }) async {
    getOrdersCalled = true;
    return [];
  }
}

void main() {
  late FakeAdminStockApiService fakeApi;
  late AppUser adminUser;
  late AppUser staffUser;

  setUp(() {
    fakeApi = FakeAdminStockApiService();
    adminUser = AppUser(
      userId: "ADMIN123",
      userName: "Admin User",
      role: "admin",
      active: true,
    );
    staffUser = AppUser(
      userId: "STAFF123",
      userName: "Staff User",
      role: "staff",
      active: true,
    );
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildTestWidget(AppUser user) {
    return MaterialApp(
      home: Scaffold(
        body: AdminPage(
          api: fakeApi,
          currentUser: user,
        ),
      ),
    );
  }

  group("AdminPage Widget Tests", () {
    testWidgets("renders AdminPage correctly for admin user", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget(adminUser));
      await tester.pumpAndSettle();

      // Verify page title and subtitle
      expect(find.text("ผู้ดูแลระบบ"), findsOneWidget);
      expect(find.text("งาน sync ข้อมูลและลิงก์ export สำหรับผู้ดูแลระบบ"), findsOneWidget);

      // Verify Google Sheets action buttons presence
      expect(find.text("ซิงก์สินค้า"), findsOneWidget);
      expect(find.text("นำเข้า Excel สินค้า"), findsOneWidget);
      expect(find.text("ซิงก์ผู้ใช้"), findsOneWidget);
      expect(find.text("อัปเดตยอดคงเหลือ"), findsOneWidget);
      expect(find.text("ทดสอบเพิ่มแถว"), findsOneWidget);
      expect(find.text("ส่งออกรายงานออเดอร์/งานค้างส่ง (CSV)"), findsOneWidget);
      expect(find.text("Download Backup (ZIP)"), findsOneWidget);
      expect(find.text("Restore Backup (ZIP)"), findsOneWidget);
    });

    testWidgets("sync buttons trigger appropriate API calls", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget(adminUser));
      await tester.pumpAndSettle();

      // Tap 'ซิงก์สินค้า'
      await tester.tap(find.text("ซิงก์สินค้า"));
      await tester.pump();
      expect(fakeApi.syncProductsCalled, isTrue);

      // Tap 'ซิงก์ผู้ใช้'
      await tester.tap(find.text("ซิงก์ผู้ใช้"));
      await tester.pump();
      expect(fakeApi.syncUsersCalled, isTrue);

      // Tap 'อัปเดตยอดคงเหลือ'
      await tester.tap(find.text("อัปเดตยอดคงเหลือ"));
      await tester.pump();
      expect(fakeApi.syncStocksCalled, isTrue);

      // Tap 'ทดสอบเพิ่มแถว'
      await tester.tap(find.text("ทดสอบเพิ่มแถว"));
      await tester.pump();
      expect(fakeApi.appendTestCalled, isTrue);
    });

    testWidgets("renders empty/restricted state for non-admin user", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget(staffUser));
      await tester.pumpAndSettle();

      // Verify restricted state messages are shown
      expect(find.text("บัญชีนี้ไม่มีสิทธิ์ใช้งานฟังก์ชัน admin"), findsOneWidget);
      expect(find.text("หน้านี้สำหรับผู้ดูแลระบบเท่านั้น"), findsOneWidget);

      // Verify sheets action buttons are NOT present
      expect(find.text("ซิงก์สินค้า"), findsNothing);
      expect(find.text("ซิงก์ผู้ใช้"), findsNothing);
    });

    testWidgets("search and segment filters operate correctly on export links", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget(adminUser));
      await tester.pumpAndSettle();

      // Verify export sections
      expect(find.text("ไฟล์ CSV"), findsNWidgets(2));
      expect(find.text("ไฟล์ Excel"), findsNWidgets(2));

      // Verify file item links
      expect(find.text("สินค้า CSV"), findsNWidgets(2));
      expect(find.text("ผู้ใช้ CSV"), findsNWidgets(2));
      expect(find.text("ประวัติ CSV"), findsNWidgets(2));
      expect(find.text("ไฟล์ Excel ทั้งหมด"), findsNWidgets(2));

      // Type "ผู้ใช้" in the search field to filter links
      await tester.enterText(find.byType(TextField), "ผู้ใช้");
      await tester.pump();

      // Verify filtering works (only 'ผู้ใช้ CSV' should remain)
      expect(find.text("สินค้า CSV"), findsNothing);
      expect(find.text("ผู้ใช้ CSV"), findsNWidgets(2));
      expect(find.text("ประวัติ CSV"), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), "");
      await tester.pump();

      // Switch SegmentedButton to 'excel' only
      await tester.tap(find.text("Excel"));
      await tester.pump();

      // Verify only 'ไฟล์ Excel' section shows
      expect(find.text("ไฟล์ CSV"), findsNothing);
      expect(find.text("ไฟล์ Excel"), findsNWidgets(2));

      // Switch SegmentedButton to 'csv' only
      await tester.tap(find.text("CSV"));
      await tester.pump();

      expect(find.text("ไฟล์ CSV"), findsNWidgets(2));
      expect(find.text("ไฟล์ Excel"), findsNothing);
    });

    testWidgets("search showing empty state operates correctly", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget(adminUser));
      await tester.pumpAndSettle();

      // Type non-matching query in search field
      await tester.enterText(find.byType(TextField), "NonMatchingQueryXYZ");
      await tester.pump();

      // Verify empty state is displayed (for both permanent and temporary sections)
      expect(find.text("ไม่พบไฟล์ที่ค้นหา ลองพิมพ์คำว่า Excel, CSV, สินค้า หรือ ประวัติ"), findsNWidgets(2));
    });
  });
}

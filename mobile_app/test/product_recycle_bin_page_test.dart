import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/product_recycle_bin_page.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeStockApiService extends StockApiService {
  List<Product> mockProducts = [];
  bool getProductsCalled = false;
  bool restoreProductCalled = false;
  String? lastRestoredBarcode;

  @override
  Future<List<Product>> getProducts({
    bool lowStockOnly = false,
    bool includeInactive = false,
  }) async {
    getProductsCalled = true;
    return mockProducts;
  }

  @override
  Future<String> restoreProduct({
    required String requesterId,
    required String barcode,
  }) async {
    restoreProductCalled = true;
    lastRestoredBarcode = barcode;

    // Simulate active status changing
    mockProducts = mockProducts.map((p) {
      if (p.barcode == barcode) {
        return Product(
          barcode: p.barcode,
          name: p.name,
          unit: p.unit,
          minimumStock: p.minimumStock,
          currentStock: p.currentStock,
          sku: p.sku,
          category: p.category,
          location: p.location,
          active: true,
        );
      }
      return p;
    }).toList();

    return "กู้คืนสินค้าเรียบร้อยแล้ว";
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
      home: ProductRecycleBinPage(
        api: fakeApi,
        currentUser: user,
      ),
    );
  }

  testWidgets("1. Shows inactive products in recycle bin", (tester) async {
    fakeApi.mockProducts = [
      Product(
        barcode: "111",
        name: "Active Product",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 10,
        active: true,
      ),
      Product(
        barcode: "222",
        name: "Inactive Product 1",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 2,
        active: false,
      ),
    ];

    await tester.pumpWidget(createWidget(user: adminUser));
    await tester.pump();
    await tester.pump();

    expect(find.text("Inactive Product 1"), findsOneWidget);
    expect(find.text("Active Product"), findsNothing);
  });

  testWidgets("2. Dialog confirmation and calls restoreProduct", (tester) async {
    fakeApi.mockProducts = [
      Product(
        barcode: "222",
        name: "Inactive Product 1",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 2,
        active: false,
      ),
    ];

    await tester.pumpWidget(createWidget(user: adminUser));
    await tester.pump();
    await tester.pump();

    // Click "กู้คืน" button in ListTile
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text("กู้คืน")));
    await tester.pumpAndSettle();

    // Dialog contents
    expect(find.text("ยืนยันการกู้คืน"), findsOneWidget);
    expect(find.text("ต้องการกู้คืนสินค้านี้ใช่หรือไม่?"), findsOneWidget);

    // Click cancel first
    await tester.tap(find.text("ยกเลิก"));
    await tester.pumpAndSettle();
    expect(fakeApi.restoreProductCalled, isFalse);

    // Tap restore again
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text("กู้คืน")));
    await tester.pumpAndSettle();

    // Confirm restore (tap dialog button)
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text("กู้คืน")));
    await tester.pump();
    await tester.pump();

    expect(fakeApi.restoreProductCalled, isTrue);
    expect(fakeApi.lastRestoredBarcode, "222");
  });

  testWidgets("3. Restored item disappears", (tester) async {
    fakeApi.mockProducts = [
      Product(
        barcode: "222",
        name: "Inactive Product 1",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 2,
        active: false,
      ),
    ];

    await tester.pumpWidget(createWidget(user: adminUser));
    await tester.pump();
    await tester.pump();

    expect(find.text("Inactive Product 1"), findsOneWidget);

    // Tap restore and confirm
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text("กู้คืน")));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text("กู้คืน")));
    await tester.pump();
    await tester.pump();

    expect(find.text("Inactive Product 1"), findsNothing);
  });

  testWidgets("4. Staff cannot access page", (tester) async {
    await tester.pumpWidget(createWidget(user: staffUser));
    await tester.pump();

    expect(find.text("ปฏิเสธการเข้าถึง: เฉพาะผู้ดูแลระบบเท่านั้น"), findsOneWidget);
    expect(fakeApi.getProductsCalled, isFalse);
  });

  testWidgets("5. Search field filters products by name, barcode, sku, or category", (tester) async {
    fakeApi.mockProducts = [
      Product(
        barcode: "1001",
        name: "Banana Yellow",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 2,
        sku: "BANANA-01",
        category: "Fruit",
        active: false,
      ),
      Product(
        barcode: "2002",
        name: "Red Apple",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 2,
        sku: "APPLE-02",
        category: "Fruit",
        active: false,
      ),
      Product(
        barcode: "3003",
        name: "Carrot Orange",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 2,
        sku: "CARROT-03",
        category: "Veggie",
        active: false,
      ),
    ];

    await tester.pumpWidget(createWidget(user: adminUser));
    await tester.pump();
    await tester.pump();

    // Verify all 3 are shown initially
    expect(find.text("Banana Yellow"), findsOneWidget);
    expect(find.text("Red Apple"), findsOneWidget);
    expect(find.text("Carrot Orange"), findsOneWidget);

    // Search by Name "apple"
    await tester.enterText(find.byType(TextField), "apple");
    await tester.pump();
    expect(find.text("Red Apple"), findsOneWidget);
    expect(find.text("Banana Yellow"), findsNothing);
    expect(find.text("Carrot Orange"), findsNothing);

    // Search by Barcode "3003"
    await tester.enterText(find.byType(TextField), "3003");
    await tester.pump();
    expect(find.text("Carrot Orange"), findsOneWidget);
    expect(find.text("Red Apple"), findsNothing);

    // Search by SKU "BANANA"
    await tester.enterText(find.byType(TextField), "BANANA");
    await tester.pump();
    expect(find.text("Banana Yellow"), findsOneWidget);
    expect(find.text("Carrot Orange"), findsNothing);

    // Search by Category "Veggie"
    await tester.enterText(find.byType(TextField), "Veggie");
    await tester.pump();
    expect(find.text("Carrot Orange"), findsOneWidget);
    expect(find.text("Banana Yellow"), findsNothing);
  });

  testWidgets("6. Empty state: Shows 'ยังไม่มีสินค้าในถังขยะ' when no inactive products", (tester) async {
    fakeApi.mockProducts = [];

    await tester.pumpWidget(createWidget(user: adminUser));
    await tester.pump();
    await tester.pump();

    expect(find.text("ยังไม่มีสินค้าในถังขยะ"), findsOneWidget);
  });

  testWidgets("7. Empty state: Shows 'ไม่พบสินค้าที่ตรงกับคำค้นหา' when query has no match", (tester) async {
    fakeApi.mockProducts = [
      Product(
        barcode: "222",
        name: "Inactive Product 1",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 2,
        active: false,
      ),
    ];

    await tester.pumpWidget(createWidget(user: adminUser));
    await tester.pump();
    await tester.pump();

    // Enter query that does not match
    await tester.enterText(find.byType(TextField), "xyzabc");
    await tester.pump();

    expect(find.text("ไม่พบสินค้าที่ตรงกับคำค้นหา"), findsOneWidget);
  });
}

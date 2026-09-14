import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/product_search_page.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeSearchStockApiService extends StockApiService {
  List<Product> mockProducts = [];
  bool getProductsCalled = false;

  bool submitScanCalled = false;
  String? lastBarcode;
  String? lastAction;
  int? lastQuantity;
  String? lastActorId;
  String? lastActorName;
  String? lastNote;

  bool deleteProductCalled = false;
  String? lastDeleteBarcode;
  String? lastDeleteRequesterId;

  @override
  Future<List<Product>> getProducts({bool lowStockOnly = false, bool includeInactive = false}) async {
    getProductsCalled = true;
    return mockProducts;
  }

  @override
  Future<ScanResult> submitScan({
    required String barcode,
    required String action,
    required int quantity,
    required String actorId,
    required String actorName,
    String? note,
    String? reference,
    bool autoCreateProduct = false,
    String? productName,
    String productUnit = "pcs",
    int productMinimumStock = 0,
    String? productCategory,
    String? productLocation,
    String? productSku,
  }) async {
    submitScanCalled = true;
    lastBarcode = barcode;
    lastAction = action;
    lastQuantity = quantity;
    lastActorId = actorId;
    lastActorName = actorName;
    lastNote = note;
    return ScanResult(
      lowStock: false,
      product: Product(
        barcode: barcode,
        name: "Mock Product",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 10,
      ),
      movement: MovementRecord(
        id: "1",
        barcode: barcode,
        productName: "Mock Product",
        action: action,
        quantity: quantity,
        beforeStock: 10,
        afterStock: 10,
        actorId: actorId,
        actorName: actorName,
        createdAt: DateTime.now(),
      ),
      notification: AppNotification(
        title: "Test",
        message: "Test message",
        movementId: "1",
        barcode: barcode,
        createdAt: DateTime.now(),
      ),
      productCreated: false,
    );
  }

  @override
  Future<String> deleteProduct({
    required String requesterId,
    required String barcode,
  }) async {
    deleteProductCalled = true;
    lastDeleteBarcode = barcode;
    lastDeleteRequesterId = requesterId;
    return "Product deleted successfully.";
  }
}

void main() {
  late FakeSearchStockApiService fakeApi;
  late AppUser adminUser;
  late AppUser staffUser;
  late List<Product> testProducts;

  setUp(() {
    fakeApi = FakeSearchStockApiService();
    adminUser = AppUser(
      userId: "ADM001",
      userName: "Admin User",
      role: "admin",
      active: true,
    );
    staffUser = AppUser(
      userId: "STF001",
      userName: "Staff User",
      role: "staff",
      active: true,
    );
    testProducts = [
      Product(
        barcode: "1234567890",
        name: "Test Item",
        unit: "pcs",
        minimumStock: 5,
        currentStock: 10,
      ),
    ];
    fakeApi.mockProducts = testProducts;
  });

  Widget buildTestableWidget({required AppUser currentUser}) {
    return MaterialApp(
      home: Scaffold(
        body: ProductSearchPage(
          api: fakeApi,
          currentUser: currentUser,
        ),
      ),
    );
  }

  testWidgets("stock in calls submitScan with action in", (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(currentUser: staffUser));
    await tester.pumpAndSettle();

    // Search to display product
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, "Test");
    await tester.pumpAndSettle();

    // Verify product shows
    expect(find.text("Test Item"), findsOneWidget);

    // Tap stock in button
    final stockInBtn = find.byKey(const Key("stock_in_1234567890"));
    expect(stockInBtn, findsOneWidget);
    await tester.tap(stockInBtn);
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text("เพิ่มสต็อก (Test Item)"), findsOneWidget);

    // Reset getProductsCalled tracker
    fakeApi.getProductsCalled = false;

    // Enter valid quantity and press ตกลง
    final qtyField = find.byType(TextFormField);
    await tester.enterText(qtyField, "5");
    await tester.tap(find.text("ตกลง"));
    await tester.pumpAndSettle();

    // Verify submitScan parameters
    expect(fakeApi.submitScanCalled, isTrue);
    expect(fakeApi.lastAction, equals("in"));
    expect(fakeApi.lastQuantity, equals(5));
    expect(fakeApi.lastBarcode, equals("1234567890"));
    expect(fakeApi.lastActorId, equals("STF001"));
    expect(fakeApi.lastNote, equals("ปรับจากหน้าค้นหาสินค้า"));
    expect(fakeApi.getProductsCalled, isTrue); // refreshed
  });

  testWidgets("stock out calls submitScan with action out", (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(currentUser: staffUser));
    await tester.pumpAndSettle();

    // Search to display product
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, "Test");
    await tester.pumpAndSettle();

    // Tap stock out button
    final stockOutBtn = find.byKey(const Key("stock_out_1234567890"));
    expect(stockOutBtn, findsOneWidget);
    await tester.tap(stockOutBtn);
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text("ลดสต็อก (Test Item)"), findsOneWidget);

    // Reset getProductsCalled tracker
    fakeApi.getProductsCalled = false;

    // Enter valid quantity and press ตกลง
    final qtyField = find.byType(TextFormField);
    await tester.enterText(qtyField, "3");
    await tester.tap(find.text("ตกลง"));
    await tester.pumpAndSettle();

    // Verify submitScan parameters
    expect(fakeApi.submitScanCalled, isTrue);
    expect(fakeApi.lastAction, equals("out"));
    expect(fakeApi.lastQuantity, equals(3));
    expect(fakeApi.lastBarcode, equals("1234567890"));
    expect(fakeApi.lastActorId, equals("STF001"));
    expect(fakeApi.getProductsCalled, isTrue); // refreshed
  });

  testWidgets("invalid quantity is rejected by validation", (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(currentUser: staffUser));
    await tester.pumpAndSettle();

    // Search
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, "Test");
    await tester.pumpAndSettle();

    // Tap stock in button
    final stockInBtn = find.byKey(const Key("stock_in_1234567890"));
    await tester.tap(stockInBtn);
    await tester.pumpAndSettle();

    // Verify dialog is open, input invalid quantity (e.g. 0)
    final qtyField = find.byType(TextFormField);
    await tester.enterText(qtyField, "0");
    await tester.tap(find.text("ตกลง"));
    await tester.pumpAndSettle();

    // Validation error text should be visible, submitScan NOT called
    expect(find.text("จำนวนต้องมากกว่า 0"), findsOneWidget);
    expect(fakeApi.submitScanCalled, isFalse);

    // Clear and leave empty
    await tester.enterText(qtyField, "");
    await tester.tap(find.text("ตกลง"));
    await tester.pumpAndSettle();

    expect(find.text("กรุณากรอกจำนวน"), findsOneWidget);
    expect(fakeApi.submitScanCalled, isFalse);
  });

  testWidgets("delete button hidden for staff and visible for admin", (WidgetTester tester) async {
    // 1. Staff User
    await tester.pumpWidget(buildTestableWidget(currentUser: staffUser));
    await tester.pumpAndSettle();

    final searchField1 = find.byType(TextField);
    await tester.enterText(searchField1, "Test");
    await tester.pumpAndSettle();

    // Delete button key should not exist or be hidden
    final deleteBtnStaff = find.byKey(const Key("delete_1234567890"));
    expect(deleteBtnStaff, findsNothing);

    // 2. Admin User
    await tester.pumpWidget(buildTestableWidget(currentUser: adminUser));
    await tester.pumpAndSettle();

    final searchField2 = find.byType(TextField);
    await tester.enterText(searchField2, "Test");
    await tester.pumpAndSettle();

    // Delete button key should be visible
    final deleteBtnAdmin = find.byKey(const Key("delete_1234567890"));
    expect(deleteBtnAdmin, findsOneWidget);
  });

  testWidgets("delete confirmation calls deleteProduct API", (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(currentUser: adminUser));
    await tester.pumpAndSettle();

    // Search
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, "Test");
    await tester.pumpAndSettle();

    // Tap delete button
    final deleteBtn = find.byKey(const Key("delete_1234567890"));
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();

    // Verify delete confirmation dialog appears
    expect(find.text("ต้องการซ่อนสินค้านี้ใช่หรือไม่?"), findsOneWidget);

    // Reset getProductsCalled tracker
    fakeApi.getProductsCalled = false;

    // Tap confirmation button "ซ่อนสินค้า"
    await tester.tap(find.text("ซ่อนสินค้า").last);
    await tester.pumpAndSettle();

    // Verify API called
    expect(fakeApi.deleteProductCalled, isTrue);
    expect(fakeApi.lastDeleteBarcode, equals("1234567890"));
    expect(fakeApi.lastDeleteRequesterId, equals("ADM001"));
    expect(fakeApi.getProductsCalled, isTrue); // refreshed
  });
}

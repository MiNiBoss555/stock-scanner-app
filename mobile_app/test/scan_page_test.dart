import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/scan_page.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeScanStockApiService extends StockApiService {
  bool getNextBarcodeCalled = false;
  bool submitScanCalled = false;
  
  String nextBarcode = "STK999";
  ScanResult? mockSubmitResult;
  
  String? lastBarcode;
  String? lastAction;
  int? lastQuantity;
  String? lastActorId;
  String? lastActorName;
  String? lastNote;
  String? lastReference;
  bool? lastAutoCreateProduct;
  String? lastProductName;
  String? lastProductUnit;
  int? lastProductMinimumStock;
  String? lastProductCategory;
  String? lastProductLocation;
  String? lastProductSku;

  @override
  Future<String> getNextBarcode() async {
    getNextBarcodeCalled = true;
    return nextBarcode;
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
    lastReference = reference;
    lastAutoCreateProduct = autoCreateProduct;
    lastProductName = productName;
    lastProductUnit = productUnit;
    lastProductMinimumStock = productMinimumStock;
    lastProductCategory = productCategory;
    lastProductLocation = productLocation;
    lastProductSku = productSku;

    final mockProduct = Product(
      barcode: barcode,
      name: productName ?? "Test Product",
      sku: productSku ?? "TEST-SKU",
      unit: productUnit,
      minimumStock: productMinimumStock,
      currentStock: 10,
      category: productCategory,
      location: productLocation,
    );

    return mockSubmitResult ?? ScanResult(
      productCreated: autoCreateProduct,
      lowStock: false,
      product: mockProduct,
      movement: MovementRecord(
        id: "1",
        barcode: barcode,
        productName: productName ?? "Test Product",
        action: action,
        quantity: quantity,
        beforeStock: 5,
        afterStock: 10,
        actorId: actorId,
        actorName: actorName,
        createdAt: DateTime.now(),
        note: note,
        reference: reference,
      ),
      notification: AppNotification(
        title: "Test Title",
        message: "Test Message",
        movementId: "1",
        barcode: barcode,
        createdAt: DateTime.now(),
      ),
    );
  }
}

void main() {
  late FakeScanStockApiService fakeApi;
  late AppUser currentUser;
  Product? detailsOpenedProduct;

  setUp(() {
    fakeApi = FakeScanStockApiService();
    currentUser = AppUser(
      userId: "USER001",
      userName: "John Doe",
      role: "staff",
      active: true,
    );
    detailsOpenedProduct = null;
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: ScanPage(
          api: fakeApi,
          currentUser: currentUser,
          onOpenProductDetails: (context, product) {
            detailsOpenedProduct = product;
          },
        ),
      ),
    );
  }

  group("ScanPage Widget Tests", () {
    testWidgets("renders ScanPage correctly in initial Scan mode", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      expect(find.text("สแกนและบันทึก"), findsOneWidget);
      expect(find.text("สแกนเข้า/ออก"), findsOneWidget);
      expect(find.text("สินค้าใหม่"), findsOneWidget);
      expect(find.text("Barcode"), findsOneWidget);
      expect(find.text("จำนวน"), findsOneWidget);
      expect(find.text("เลขความปลอดภัย/อ้างอิง"), findsOneWidget);
      expect(find.text("หมายเหตุ"), findsOneWidget);
      expect(find.text("บันทึกรายการ"), findsOneWidget);

      // Verify that extra New Product fields are NOT visible initially
      expect(find.text("ชื่อสินค้า"), findsNothing);
      expect(find.text("SKU"), findsNothing);
    });

    testWidgets("switching to New Product mode shows additional fields and loads auto-barcode", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      // Tap on "สินค้าใหม่" segmented button
      await tester.tap(find.text("สินค้าใหม่"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // wait for future/setState

      // Verify New Product extra fields are now displayed
      expect(find.text("ชื่อสินค้า"), findsOneWidget);
      expect(find.text("SKU"), findsOneWidget);
      expect(find.text("หน่วย"), findsOneWidget);
      expect(find.text("หมวดหมู่"), findsOneWidget);
      expect(find.text("ตำแหน่งจัดเก็บ"), findsOneWidget);
      expect(find.text("สร้างสินค้าใหม่และรับเข้า"), findsOneWidget);

      // Verify that getNextBarcode was automatically called to populate the barcode field
      expect(fakeApi.getNextBarcodeCalled, isTrue);
      final barcodeField = tester.widget<TextField>(find.widgetWithText(TextField, "Barcode"));
      expect(barcodeField.controller?.text, "STK999");
    });

    testWidgets("generates auto-SKU correctly from product name and barcode", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      // Go to New Product mode
      await tester.tap(find.text("สินค้าใหม่"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter Product Name
      await tester.enterText(find.widgetWithText(TextField, "ชื่อสินค้า"), "Test Product");
      // Barcode is already populated with STK999 (tail is K999)
      await tester.pump();

      // Verify automatically generated SKU: "TES-PRO-K999"
      final skuField = tester.widget<TextField>(find.widgetWithText(TextField, "SKU"));
      expect(skuField.controller?.text, "TES-PRO-K999");
    });

    testWidgets("submitting a normal scan calls submitScan and displays ScanResultCard", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      // Populate scanner inputs
      await tester.enterText(find.widgetWithText(TextField, "Barcode"), "STK123");
      await tester.enterText(find.widgetWithText(TextField, "จำนวน"), "5");
      await tester.enterText(find.widgetWithText(TextField, "เลขความปลอดภัย/อ้างอิง"), "REF111");
      await tester.enterText(find.widgetWithText(TextField, "หมายเหตุ"), "Some note here");

      // Verify action segmented buttons and tap Out (จ่ายออก)
      await tester.tap(find.text("จ่ายออก"));
      await tester.pump();

      // Tap submit button
      await tester.tap(find.widgetWithText(FilledButton, "บันทึกรายการ"));
      await tester.pump(); // Start submission

      // Wait for submission future to complete
      await tester.pump(const Duration(milliseconds: 100));

      // Verify API was called with correct parameters
      expect(fakeApi.submitScanCalled, isTrue);
      expect(fakeApi.lastBarcode, "STK123");
      expect(fakeApi.lastQuantity, 5);
      expect(fakeApi.lastAction, "out");
      expect(fakeApi.lastReference, "REF111");
      expect(fakeApi.lastNote, "Some note here");
      expect(fakeApi.lastAutoCreateProduct, isFalse);

      // Verify ScanResultCard renders with scan info
      expect(find.text("บันทึกสำเร็จ"), findsOneWidget);
      expect(find.text("บาร์โค้ด: STK123"), findsOneWidget);
      expect(find.text("คงเหลือ: 10 pcs"), findsOneWidget);
      expect(find.text("ผู้ทำรายการ: John Doe"), findsOneWidget);
    });

    testWidgets("tapping 'ดู barcode / QR' in ScanResultCard invokes onOpenProductDetails callback", (WidgetTester tester) async {
      configureViewport(tester);
      await tester.pumpWidget(buildTestWidget());

      // Set up values and submit scan
      await tester.enterText(find.widgetWithText(TextField, "Barcode"), "STK555");
      await tester.tap(find.widgetWithText(FilledButton, "บันทึกรายการ"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify "ดู barcode / QR" button is shown and tap it
      final viewCodeButton = find.widgetWithText(OutlinedButton, "ดู barcode / QR");
      expect(viewCodeButton, findsOneWidget);
      await tester.tap(viewCodeButton);
      await tester.pump();

      // Verify the callback was triggered and detailsOpenedProduct is set
      expect(detailsOpenedProduct, isNotNull);
      expect(detailsOpenedProduct!.barcode, "STK555");
      expect(detailsOpenedProduct!.name, "Test Product");
    });
  });
}

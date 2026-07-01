import "dart:io";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/orders_page.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:image/image.dart" as img;


class FakeStockApiService extends StockApiService {
  List<DeliveryOrder> ordersList = [];
  List<AppUser> usersList = [];
  List<Product> productsList = [];
  List<String> proofPhotosList = [];
  bool getOrdersShouldFail = false;

  @override
  Future<List<DeliveryOrder>> getOrders({
    required String requesterId,
    bool assignedOnly = false,
    bool mineOnly = false,
    int limit = 300,
  }) async {
    if (getOrdersShouldFail) {
      throw Exception("Failed to load orders");
    }
    return ordersList;
  }

  @override
  Future<List<AppUser>> getUsers({bool activeOnly = true}) async {
    return usersList;
  }

  @override
  Future<List<Product>> getProducts({bool lowStockOnly = false, bool includeInactive = false}) async {
    return productsList;
  }

  @override
  Future<List<String>> getOrderProofPhotos({
    required String requesterId,
    required String orderId,
  }) async {
    return proofPhotosList;
  }

  @override
  Future<DeliveryOrder> createOrder({
    required String requesterId,
    required String customerName,
    String? customerPhone,
    String? customerAddress,
    String? note,
    String? assignedToId,
    String? productionUserId,
    String? boardProductionUserId,
    String? robotProductionUserId,
    String? qcUserId,
    String? deliveryUserId,
    DateTime? scheduledDeliveryAt,
    required List<Map<String, dynamic>> items,
  }) async {
    return DeliveryOrder(
      id: "created_order_id",
      customerName: customerName,
      createdById: requesterId,
      createdByName: "Creator",
      status: "pending",
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      customerPhone: customerPhone,
      customerAddress: customerAddress,
    );
  }

  @override
  Future<DeliveryOrder> updateOrderStatus({
    required String requesterId,
    required String orderId,
    required String status,
  }) async {
    return ordersList.firstWhere(
      (o) => o.id == orderId,
      orElse: () => DeliveryOrder(
        id: orderId,
        customerName: "Dummy",
        createdById: requesterId,
        createdByName: "Creator",
        status: status,
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  String orderPrintUrl({required String orderId, required String requesterId}) {
    return "http://print/$orderId";
  }

  @override
  String orderPackingSlipUrl({required String orderId, required String requesterId}) {
    return "http://pack/$orderId";
  }

  @override
  String orderPdfUrl({required String orderId, required String requesterId}) {
    return "http://pdf/$orderId";
  }

  @override
  Future<DeliveryOrder> deliverOrderPartial({
    required String requesterId,
    required String orderId,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    return ordersList.firstWhere((o) => o.id == orderId);
  }

  @override
  Future<DeliveryOrder> resolveBackorder({
    required String requesterId,
    required String orderId,
  }) async {
    return ordersList.firstWhere(
      (o) => o.id == orderId,
      orElse: () => DeliveryOrder(
        id: orderId,
        customerName: "Dummy",
        createdById: requesterId,
        createdByName: "Creator",
        status: "delivered",
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<DeliveryOrder> assignOrderTeam({
    required String requesterId,
    required String orderId,
    String? productionUserId,
    String? boardProductionUserId,
    String? robotProductionUserId,
    String? qcUserId,
    String? deliveryUserId,
  }) async {
    return ordersList.firstWhere(
      (o) => o.id == orderId,
      orElse: () => DeliveryOrder(
        id: orderId,
        customerName: "Dummy",
        createdById: requesterId,
        createdByName: "Creator",
        status: "assigned",
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  bool ocrShouldFail = false;
  Map<String, String> mockOcrResponse = {};
  String? lastOcrFilePath;

  @override
  Future<Map<String, String>> ocrShippingLabel({
    required String requesterId,
    String? filePath,
  }) async {
    lastOcrFilePath = filePath;
    if (ocrShouldFail) {
      throw Exception("OCR failed");
    }
    return mockOcrResponse;
  }
}


void main() {
  late FakeStockApiService fakeApi;
  late AppUser testUser;
  late Product testProduct;
  late DeliveryOrder testOrder;

  setUp(() {
    fakeApi = FakeStockApiService();
    testUser = AppUser(
      userId: "test_user_id",
      userName: "Test User",
      role: "admin",
      active: true,
    );
    testProduct = Product(
      barcode: "barcode1",
      name: "Product 1",
      unit: "pcs",
      minimumStock: 2,
      currentStock: 10,
    );
    testOrder = DeliveryOrder(
      id: "order_id_123456",
      customerName: "John Doe",
      createdById: "creator_id",
      createdByName: "Creator Name",
      status: "assigned",
      items: [
        OrderItemModel(
          barcode: "barcode1",
          productName: "Product 1",
          quantity: 5,
          unit: "pcs",
          deliveredQuantity: 2,
        )
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      customerPhone: "0812345678",
      customerAddress: "123 Main St",
    );

    fakeApi.usersList = [testUser];
    fakeApi.productsList = [testProduct];
    fakeApi.ordersList = [testOrder];
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group("OrdersPage Widget Tests", () {
    // Test 1: ตรวจสอบว่า OrdersPage เปิดได้โดยไม่เกิด Exception
    testWidgets("OrdersPage opens and renders without exception", (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(OrdersPage), findsOneWidget);
    });

    testWidgets("Create order team assignment shows board and robot production and not legacy production", (WidgetTester tester) async {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.window.physicalSizeTestValue = const Size(800, 2000);
      binding.window.devicePixelRatioTestValue = 1.0;

      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      // Tap on "กำหนด" to show advanced team options
      final configureButton = find.text("กำหนด");
      expect(configureButton, findsOneWidget);
      await tester.ensureVisible(configureButton);
      await tester.tap(configureButton);
      await tester.pumpAndSettle();

      // Assert board/robot production are visible
      expect(find.text("ฝ่ายผลิตบอร์ด"), findsOneWidget);
      expect(find.text("ฝ่ายผลิตหุ่นยนต์"), findsOneWidget);

      // Assert old standalone "ฝ่ายผลิต" dropdown label is not visible
      expect(find.text("ฝ่ายผลิต"), findsNothing);

      // Reset values
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    // Test 2: ตรวจสอบว่า Navigation ไปยัง OrdersPage ทำงานปกติ
    testWidgets("Navigation to OrdersPage works correctly", (WidgetTester tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Material(child: OrdersPage(api: fakeApi, currentUser: testUser)),
                ),
              );
            },
            child: const Text("Go"),
          ),
        ),
      ));

      await tester.tap(find.text("Go"));
      await tester.pumpAndSettle();

      expect(find.byType(OrdersPage), findsOneWidget);
    });

    // Test 3: ทดสอบการแสดงผลรายการออเดอร์เมื่อมีข้อมูล
    testWidgets("OrdersPage renders orders list when data is available", (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      // Customer name John Doe should be displayed in the list
      expect(find.text("John Doe"), findsOneWidget);
    });

    // Test 4: ทดสอบ Empty State เมื่อไม่มีออเดอร์
    testWidgets("OrdersPage renders Empty State when there are no orders", (WidgetTester tester) async {
      fakeApi.ordersList = [];

      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      expect(find.text("ยังไม่มีออเดอร์ในระบบ"), findsOneWidget);
    });

    // Test 5: ทดสอบ Error State เมื่อโหลดข้อมูลล้มเหลว
    testWidgets("OrdersPage renders Error State when loading fails", (WidgetTester tester) async {
      fakeApi.getOrdersShouldFail = true;

      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      expect(find.text("เชื่อมต่อ API ไม่สำเร็จ"), findsOneWidget);
    });

    // Test 6: ทดสอบการเปิด BackorderReportSheet
    testWidgets("OrdersPage opens BackorderReportSheet full report", (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      // Tap full report button
      final btn = find.text("เปิดรายงานแบบเต็ม");
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      // Should show sheet title
      expect(find.text("รายงานค้างจ่าย"), findsWidgets);
    });

    // Test 7: ทดสอบ DeliverySuccessOverlay
    testWidgets("OrdersPage shows DeliverySuccessOverlay when marked delivered", (WidgetTester tester) async {
      // Set larger viewport to avoid off-screen button issues
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeApi.proofPhotosList = ["http://proof.photo/1.jpg"]; // Mock proof photo to enable "ส่งแล้ว" button
      
      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      // Find and tap the "ส่งแล้ว" button
      final deliveredBtn = find.widgetWithText(FilledButton, "ส่งแล้ว");
      expect(deliveredBtn, findsOneWidget);
      await tester.ensureVisible(deliveredBtn);
      await tester.pumpAndSettle();
      await tester.tap(deliveredBtn);
      
      // Pump for general dialog animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // DeliverySuccessOverlay should display the success text
      expect(find.text("ส่งสินค้าเรียบร้อย!"), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });

    group("OrdersPage OCR Phase 2, 3, 4 Tests", () {
      bool cropShouldFail = false;
      bool cropShouldCancel = false;
      bool textRecognizerShouldReturnBlocks = false;
      bool documentScannerShouldFail = false;
      late Directory tempDir;
      late File testImageFile;

      setUp(() {
        final binding = TestWidgetsFlutterBinding.instance;
        binding.window.physicalSizeTestValue = const Size(800, 2000);
        binding.window.devicePixelRatioTestValue = 1.0;

        cropShouldFail = false;
        cropShouldCancel = false;
        textRecognizerShouldReturnBlocks = false;
        documentScannerShouldFail = false;
        tempDir = Directory.systemTemp.createTempSync();

        // Create a valid tiny PNG image so that package:image can decode it
        final image = img.Image(width: 100, height: 100);
        final pngBytes = img.encodePng(image);
        testImageFile = File("${tempDir.path}/test_image.png")..writeAsBytesSync(pngBytes);

        // Mock ImagePicker
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel("plugins.flutter.io/image_picker"),
          (MethodCall methodCall) async {
            if (methodCall.method == "pickImage") {
              return testImageFile.path;
            }
            return null;
          },
        );

        // Mock ImageCropper
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel("plugins.hunghd.vn/image_cropper"),
          (MethodCall methodCall) async {
            if (methodCall.method == "cropImage") {
              if (cropShouldFail) {
                throw PlatformException(code: "CROP_FAILED", message: "Cropping failed");
              }
              if (cropShouldCancel) {
                return null;
              }
              return "/mocked/path/to/cropped_image.png";
            }
            return null;
          },
        );

        // Mock DocumentScanner
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel("google_mlkit_document_scanner"),
          (MethodCall methodCall) async {
            if (methodCall.method == "vision#startDocumentScanner") {
              if (documentScannerShouldFail) {
                throw PlatformException(code: "SCAN_FAILED", message: "Document scanning failed");
              }
              return {
                "images": ["/mocked/path/to/scanned_document.png"],
                "pdf": null
              };
            }
            if (methodCall.method == "vision#closeDocumentScanner") {
              return null;
            }
            return null;
          },
        );

        // Mock TextRecognizer
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel("google_mlkit_text_recognizer"),
          (MethodCall methodCall) async {
            if (methodCall.method == "vision#startTextRecognizer") {
              if (textRecognizerShouldReturnBlocks) {
                return {
                  "text": "ชื่อผู้รับ: นายสมรัก คำไทย\nเบอร์โทร: 082-999-8888\nที่อยู่: 9/9 ต.ท่าทราย อ.เมือง จ.นนทบุรี 11000",
                  "blocks": [
                    {
                      "text": "นายสมรัก คำไทย",
                      "rect": {
                        "left": 10.0,
                        "top": 10.0,
                        "right": 100.0,
                        "bottom": 30.0
                      },
                      "recognizedLanguages": [],
                      "points": [],
                      "lines": []
                    }
                  ],
                };
              }
              return {
                "text": "ชื่อผู้รับ: นายสมรัก คำไทย\nเบอร์โทร: 082-999-8888\nที่อยู่: 9/9 ต.ท่าทราย อ.เมือง จ.นนทบุรี 11000",
                "blocks": [],
              };
            }
            if (methodCall.method == "vision#closeTextRecognizer") {
              return null;
            }
            return null;
          },
        );
      });

      tearDown(() {
        final binding = TestWidgetsFlutterBinding.instance;
        binding.window.clearPhysicalSizeTestValue();
        binding.window.clearDevicePixelRatioTestValue();

        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel("plugins.flutter.io/image_picker"),
          null,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel("plugins.hunghd.vn/image_cropper"),
          null,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel("google_mlkit_document_scanner"),
          null,
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel("google_mlkit_text_recognizer"),
          null,
        );
      });

      Future<void> triggerOcrFlowGallery(WidgetTester tester, {bool expectPreview = false, bool tapProceed = true}) async {
        final scanBtn = find.widgetWithText(OutlinedButton, "สแกนข้อมูลลูกค้า");
        expect(scanBtn, findsOneWidget);
        await tester.tap(scanBtn);
        await tester.pumpAndSettle();

        final galleryTile = find.text("เลือกจากคลังภาพ");
        expect(galleryTile, findsOneWidget);
        await tester.tap(galleryTile);

        // Allow ImagePicker method channel to complete, gallery pre-scan to finish, and preview to show
        for (int i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 50));
          });
          if (expectPreview) {
            if (find.text("ตรวจพบเอกสาร/ใบปะหน้า").evaluate().isNotEmpty) {
              break;
            }
          } else {
            if (find.text("ยืนยันข้อมูลที่สแกนได้").evaluate().isNotEmpty) {
              break;
            }
          }
        }
        await tester.pump(const Duration(milliseconds: 100));

        if (expectPreview) {
          expect(find.text("ตรวจพบเอกสาร/ใบปะหน้า"), findsOneWidget);
          if (tapProceed) {
            final proceedBtn = find.text("ดำเนินการต่อ");
            expect(proceedBtn, findsOneWidget);
            await tester.tap(proceedBtn);
          } else {
            final manualBtn = find.text("ปรับแต่งเอง");
            expect(manualBtn, findsOneWidget);
            await tester.tap(manualBtn);
          }
          // Now wait for OCR and showDialog confirmation
          for (int i = 0; i < 15; i++) {
            await tester.pump(const Duration(milliseconds: 50));
            await tester.runAsync(() async {
              await Future.delayed(const Duration(milliseconds: 50));
            });
            if (find.text("ยืนยันข้อมูลที่สแกนได้").evaluate().isNotEmpty) {
              break;
            }
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> triggerOcrFlowCamera(WidgetTester tester) async {
        final scanBtn = find.widgetWithText(OutlinedButton, "สแกนข้อมูลลูกค้า");
        expect(scanBtn, findsOneWidget);
        await tester.tap(scanBtn);
        await tester.pumpAndSettle();

        final cameraTile = find.text("ถ่ายรูป (สแกนอัตโนมัติ)");
        expect(cameraTile, findsOneWidget);
        await tester.tap(cameraTile);

        // Allow native document scanner activity and OCR to complete
        for (int i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          await tester.runAsync(() async {
            await Future.delayed(const Duration(milliseconds: 50));
          });
          if (find.text("ยืนยันข้อมูลที่สแกนได้").evaluate().isNotEmpty) {
            break;
          }
        }
        await tester.pump(const Duration(milliseconds: 100));
      }

      testWidgets("Gemini success: returns complete fields, phone normalized, form fields populated", (WidgetTester tester) async {
        fakeApi.ocrShouldFail = false;
        fakeApi.mockOcrResponse = {
          "name": "คุณอลิสา ใจดี",
          "phone": "+66 85 555 1234",
          "address": "456 ต.ในเมือง อ.เมือง จ.เชียงใหม่ 50000",
        };

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        await triggerOcrFlowGallery(tester);

        expect(find.text("ยืนยันข้อมูลที่สแกนได้"), findsOneWidget);
        expect(find.text("ชื่อ: คุณอลิสา ใจดี"), findsOneWidget);
        expect(find.text("เบอร์โทร: 0855551234"), findsOneWidget);
        expect(find.text("ที่อยู่: 456 ต.ในเมือง อ.เมือง จ.เชียงใหม่ 50000"), findsOneWidget);

        await tester.tap(find.text("ใช้ข้อมูลนี้"));
        await tester.pumpAndSettle();
      });

      testWidgets("Gemini failure: falls back to local ML Kit OCR", (WidgetTester tester) async {
        fakeApi.ocrShouldFail = true;

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        await triggerOcrFlowGallery(tester);

        expect(find.text("ยืนยันข้อมูลที่สแกนได้"), findsOneWidget);
        expect(find.text("ชื่อ: นายสมรัก คำไทย"), findsOneWidget);
        expect(find.text("เบอร์โทร: 0829998888"), findsOneWidget);
        expect(find.text("ที่อยู่: 9/9 ต.ท่าทราย อ.เมือง จ.นนทบุรี 11000"), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, "ยกเลิก"));
        await tester.pumpAndSettle();
      });

      testWidgets("Gallery auto-crop success proceed uses auto-cropped path", (WidgetTester tester) async {
        textRecognizerShouldReturnBlocks = true;
        fakeApi.ocrShouldFail = false;
        fakeApi.mockOcrResponse = {
          "name": "ทดสอบ ออโต้ครอป",
          "phone": "0891112222",
          "address": "ที่อยู่ออโต้",
        };
        fakeApi.lastOcrFilePath = null;

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        // Trigger gallery with preview, choose Proceed
        await triggerOcrFlowGallery(tester, expectPreview: true, tapProceed: true);

        // Verify OCR ran with auto-cropped image path
        expect(fakeApi.lastOcrFilePath, contains("autocropped_"));
        expect(find.text("ยืนยันข้อมูลที่สแกนได้"), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, "ยกเลิก"));
        await tester.pumpAndSettle();
      });

      testWidgets("Gallery auto-crop manual fallback opens manual ImageCropper", (WidgetTester tester) async {
        textRecognizerShouldReturnBlocks = true;
        fakeApi.ocrShouldFail = false;
        fakeApi.mockOcrResponse = {
          "name": "ทดสอบ เมนวลครอป",
          "phone": "0891112222",
          "address": "ที่อยู่เมนวล",
        };
        fakeApi.lastOcrFilePath = null;

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        // Trigger gallery with preview, choose Manual Crop
        await triggerOcrFlowGallery(tester, expectPreview: true, tapProceed: false);

        // Verify OCR ran with manual crop path
        expect(fakeApi.lastOcrFilePath, "/mocked/path/to/cropped_image.png");
        expect(find.text("ยืนยันข้อมูลที่สแกนได้"), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, "ยกเลิก"));
        await tester.pumpAndSettle();
      });

      testWidgets("Auto-crop failure (no text) bypasses preview and opens manual ImageCropper", (WidgetTester tester) async {
        textRecognizerShouldReturnBlocks = false; // No text -> Low confidence auto-crop failure
        fakeApi.ocrShouldFail = false;
        fakeApi.mockOcrResponse = {
          "name": "ทดสอบ ล้มเหลว",
          "phone": "0891112222",
          "address": "ที่อยู่ล้มเหลว",
        };
        fakeApi.lastOcrFilePath = null;

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        // Trigger gallery (should bypass preview directly to manual crop)
        await triggerOcrFlowGallery(tester, expectPreview: false);

        expect(fakeApi.lastOcrFilePath, "/mocked/path/to/cropped_image.png");
        expect(find.text("ยืนยันข้อมูลที่สแกนได้"), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, "ยกเลิก"));
        await tester.pumpAndSettle();
      });

      testWidgets("Camera document scanner success runs OCR on scanned path", (WidgetTester tester) async {
        documentScannerShouldFail = false;
        fakeApi.ocrShouldFail = false;
        fakeApi.mockOcrResponse = {
          "name": "กล้อง สำเร็จ",
          "phone": "0893334444",
          "address": "ที่อยู่กล้อง",
        };
        fakeApi.lastOcrFilePath = null;

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        await triggerOcrFlowCamera(tester);

        expect(fakeApi.lastOcrFilePath, "/mocked/path/to/scanned_document.png");
        expect(find.text("ยืนยันข้อมูลที่สแกนได้"), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, "ยกเลิก"));
        await tester.pumpAndSettle();
      });
    });
  });
}

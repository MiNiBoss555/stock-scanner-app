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

  int getOrderProofPhotosCallCount = 0;
  Map<String, int> proofPhotosCallsByOrderId = {};

  @override
  Future<List<String>> getOrderProofPhotos({
    required String requesterId,
    required String orderId,
  }) async {
    getOrderProofPhotosCallCount++;
    proofPhotosCallsByOrderId[orderId] =
        (proofPhotosCallsByOrderId[orderId] ?? 0) + 1;
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
    final idx = ordersList.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final old = ordersList[idx];
      ordersList[idx] = DeliveryOrder(
        id: old.id,
        customerName: old.customerName,
        createdById: old.createdById,
        createdByName: old.createdByName,
        status: status,
        items: old.items,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
        customerPhone: old.customerPhone,
        customerAddress: old.customerAddress,
        note: old.note,
        assignedToId: old.assignedToId,
        assignedToName: old.assignedToName,
      );
      return ordersList[idx];
    }
    return DeliveryOrder(
      id: orderId,
      customerName: "Dummy",
      createdById: requesterId,
      createdByName: "Creator",
      status: status,
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;

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
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
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

      testOrder = DeliveryOrder(
        id: testOrder.id,
        customerName: testOrder.customerName,
        createdById: testOrder.createdById,
        createdByName: testOrder.createdByName,
        status: "out_for_delivery",
        items: testOrder.items,
        createdAt: testOrder.createdAt,
        updatedAt: testOrder.updatedAt,
      );
      fakeApi.ordersList = [testOrder];
      fakeApi.proofPhotosList = ["http://proof.photo/1.jpg"];
      
      await tester.pumpWidget(createTestWidget(OrdersPage(
        api: fakeApi,
        currentUser: testUser,
      )));
      await tester.pumpAndSettle();

      // Find and tap the "ส่งสำเร็จ" button
      final deliveredBtn = find.widgetWithText(FilledButton, "ส่งสำเร็จ");
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
        final view = binding.platformDispatcher.views.first;
        view.physicalSize = const Size(800, 2000);
        view.devicePixelRatio = 1.0;

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
        final view = binding.platformDispatcher.views.first;
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();

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
        expect(find.text("เบอร์โทร: 0829998888"), findsOneWidget);

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

    group("Cancelled Orders Active-View Regression Tests", () {
      testWidgets("Cancelled order with remaining quantity does not appear in backorder report while active does", (WidgetTester tester) async {
        final activeOrder = DeliveryOrder(
          id: "active_backorder_1",
          customerName: "Active Backorder Customer",
          createdById: "creator_id",
          createdByName: "Creator",
          status: "assigned",
          items: [
            OrderItemModel(
              barcode: "b1",
              productName: "Active Item",
              quantity: 5,
              unit: "pcs",
              deliveredQuantity: 2,
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final cancelledOrder = DeliveryOrder(
          id: "cancelled_backorder_1",
          customerName: "Cancelled Backorder Customer",
          createdById: "creator_id",
          createdByName: "Creator",
          status: "cancelled",
          items: [
            OrderItemModel(
              barcode: "b2",
              productName: "Cancelled Item",
              quantity: 5,
              unit: "pcs",
              deliveredQuantity: 1,
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        fakeApi.ordersList = [activeOrder, cancelledOrder];

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        // Open backorder report
        final btn = find.text("เปิดรายงานแบบเต็ม");
        expect(btn, findsOneWidget);
        await tester.tap(btn);
        await tester.pumpAndSettle();

        // Active order appears in report, cancelled order does NOT
        expect(find.descendant(of: find.byType(BottomSheet), matching: find.text("Active Backorder Customer")), findsOneWidget);
        expect(find.descendant(of: find.byType(BottomSheet), matching: find.text("Cancelled Backorder Customer")), findsNothing);
      });

      testWidgets("Cancelled order does not appear in active order picker", (WidgetTester tester) async {
        final activeOrder = DeliveryOrder(
          id: "active_picker_1",
          customerName: "Active Picker Customer",
          createdById: "creator_id",
          createdByName: "Creator",
          status: "pending",
          items: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final cancelledOrder = DeliveryOrder(
          id: "cancelled_picker_1",
          customerName: "Cancelled Picker Customer",
          createdById: "creator_id",
          createdByName: "Creator",
          status: "cancelled",
          items: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        fakeApi.ordersList = [activeOrder, cancelledOrder];

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        expect(find.byType(DropdownMenu<String>), findsOneWidget);
        final dropdown = tester.widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>));
        final entryValues = dropdown.dropdownMenuEntries.map((e) => e.value).toList();
        expect(entryValues, contains("active_picker_1"));
        expect(entryValues, isNot(contains("cancelled_picker_1")));
      });

      testWidgets("Cancelling currently selected order clears stale picker selection", (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final order1 = DeliveryOrder(
          id: "order_to_cancel_id",
          customerName: "Order To Cancel Name",
          createdById: testUser.userId,
          createdByName: testUser.userName,
          status: "pending",
          items: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final order2 = DeliveryOrder(
          id: "order_active_id",
          customerName: "Order Active Name",
          createdById: testUser.userId,
          createdByName: testUser.userName,
          status: "pending",
          items: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        fakeApi.ordersList = [order1, order2];

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        // Left swipe on order_to_cancel_id card to open action menu
        final dismissible = find.byKey(const Key("dismissible_order_to_cancel_id"));
        expect(dismissible, findsOneWidget);
        await tester.drag(dismissible, const Offset(-500, 0));
        await tester.pumpAndSettle();

        // Tap cancel order action
        final cancelTile = find.byKey(const Key("order_action_cancel_order_to_cancel_id"));
        expect(cancelTile, findsOneWidget);
        await tester.tap(cancelTile);
        await tester.pumpAndSettle();

        // Confirm cancel dialog
        final confirmBtn = find.widgetWithText(FilledButton, "ยืนยัน");
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Check that dropdown selection is not pointing to cancelled order
        final dropdown = tester.widget<DropdownMenu<String>>(find.byType(DropdownMenu<String>));
        expect(dropdown.initialSelection, isNull);
      });

      testWidgets("Cancelled orders are read-only and expose no operational controls for admin", (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final cancelledOrder = DeliveryOrder(
          id: "cancelled_order_readonly_id",
          customerName: "Cancelled Customer",
          createdById: testUser.userId,
          createdByName: testUser.userName,
          status: "cancelled",
          orderWorkflowStatus: "pending_board",
          note: "มีค้างจ่าย",
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
        );

        fakeApi.ordersList = [cancelledOrder];

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        // Switch to "ยกเลิก" tab
        final horizontalScrollable = find.descendant(
          of: find.byKey(const Key("orders_status_tabs_scroll")),
          matching: find.byType(Scrollable),
        );
        final cancelledTab = find.byKey(const Key("tab_ยกเลิก"));
        await tester.scrollUntilVisible(
          cancelledTab,
          100,
          scrollable: horizontalScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(cancelledTab);
        await tester.pumpAndSettle();

        // Cancelled order tile is shown
        expect(find.text("Cancelled Customer"), findsOneWidget);

        // Verify operational controls are NOT present
        expect(find.text("ส่งบางส่วน"), findsNothing);
        expect(find.text("แก้ไขจำนวนส่ง"), findsNothing);
        expect(find.text("ปิดค้างจ่าย"), findsNothing);
        expect(find.text("ยกเลิกออเดอร์"), findsNothing);
        expect(find.text("เริ่มผลิต"), findsNothing);
        expect(find.text("ส่งให้ฝ่ายผลิตหุ่นยนต์"), findsNothing);
        expect(find.text("ส่งให้ QC"), findsNothing);
        expect(find.text("ผ่าน"), findsNothing);
        expect(find.text("เริ่มจัดสินค้า"), findsNothing);
        expect(find.text("ออกจัดส่ง"), findsNothing);
        expect(find.text("ส่งสำเร็จ"), findsNothing);
        expect(find.text("ถ่ายรูปหลักฐาน"), findsNothing);

        // Left swipe action menu is disabled (secondaryBackground is null)
        expect(find.byKey(const Key("order_swipe_menu_cancelled_order_readonly_id")), findsNothing);

        // Safe read-only controls ARE present
        expect(find.text("พิมพ์เอกสาร"), findsOneWidget);
        expect(find.text("แชตติดตามงาน"), findsOneWidget);
        expect(find.textContaining("รูปหลักฐาน"), findsOneWidget);

        // Right swipe to open details preview
        final dismissible = find.byKey(const Key("dismissible_cancelled_order_readonly_id"));
        expect(dismissible, findsOneWidget);
        await tester.drag(dismissible, const Offset(500, 0));
        await tester.pumpAndSettle();

        // In preview sheet: customer details visible, but no workflow or status buttons
        expect(find.text("ใบสรุปออเดอร์"), findsOneWidget);
        expect(find.text("เปิดออเดอร์นี้"), findsNothing);
        expect(find.text("จัดการขั้นตอนงาน"), findsNothing);
        expect(find.byKey(const Key("workflow_action_send_to_robot")), findsNothing);
        expect(find.byKey(const Key("workflow_action_send_to_qc")), findsNothing);
        expect(find.byKey(const Key("workflow_action_qc_pass")), findsNothing);
        expect(find.byKey(const Key("status_action_preparing")), findsNothing);
        expect(find.byKey(const Key("status_action_out_for_delivery")), findsNothing);
        expect(find.byKey(const Key("status_action_delivered")), findsNothing);
      });

      testWidgets("Proof photo lazy-loading race prevention on cancelled orders", (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final cancelledOrder = DeliveryOrder(
          id: "cancelled_proof_order_id",
          customerName: "Proof Customer",
          createdById: testUser.userId,
          createdByName: testUser.userName,
          status: "cancelled",
          items: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final activeOrder = DeliveryOrder(
          id: "active_proof_order_id",
          customerName: "Active Customer",
          createdById: testUser.userId,
          createdByName: testUser.userName,
          status: "pending",
          items: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        fakeApi.ordersList = [activeOrder, cancelledOrder];
        fakeApi.proofPhotosList = ["https://example.com/proof1.jpg"];

        await tester.pumpWidget(createTestWidget(OrdersPage(
          api: fakeApi,
          currentUser: testUser,
        )));
        await tester.pumpAndSettle();

        // 1. Startup / list rendering: 0 proof photo requests for cancelled order
        expect(fakeApi.proofPhotosCallsByOrderId["cancelled_proof_order_id"] ?? 0, 0);

        // 2. Switch to 'ยกเลิก' tab: still 0 proof requests
        final horizontalScrollable = find.descendant(
          of: find.byKey(const Key("orders_status_tabs_scroll")),
          matching: find.byType(Scrollable),
        );
        final cancelledTab = find.byKey(const Key("tab_ยกเลิก"));
        await tester.scrollUntilVisible(
          cancelledTab,
          100,
          scrollable: horizontalScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(cancelledTab);
        await tester.pumpAndSettle();
        expect(fakeApi.proofPhotosCallsByOrderId["cancelled_proof_order_id"] ?? 0, 0);

        // 3. Open proof gallery for cancelled order: exactly 1 request and sheet opens with photo
        final proofButton = find.widgetWithText(OutlinedButton, "รูปหลักฐาน (0)");
        expect(proofButton, findsOneWidget);
        await tester.tap(proofButton);
        await tester.pumpAndSettle();

        expect(fakeApi.proofPhotosCallsByOrderId["cancelled_proof_order_id"], 1);
        expect(find.text("รูปหลักฐานการส่ง"), findsOneWidget);

        // Close the sheet
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // 4. Reopen the gallery for the same order: cached, 0 additional requests
        final proofButtonReopen = find.byIcon(Icons.photo_library_outlined);
        expect(proofButtonReopen, findsOneWidget);
        await tester.tap(proofButtonReopen);
        await tester.pumpAndSettle();

        expect(fakeApi.proofPhotosCallsByOrderId["cancelled_proof_order_id"], 1);
      });
    });
  });
}

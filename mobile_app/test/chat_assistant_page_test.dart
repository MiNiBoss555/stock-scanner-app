import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/chat_assistant_page.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeChatStockApiService extends StockApiService {
  bool assistantAvailable = true;
  String expectedReply = "สวัสดีครับ มีอะไรให้ช่วยไหม";
  List<Product> mockProducts = [];
  ChatAssistantAction? mockAction;
  ExportLink? mockDownloadLink;
  bool askAssistantCalled = false;
  String? lastMessageSent;

  @override
  Future<bool> isAssistantAvailable() async {
    return assistantAvailable;
  }

  @override
  Future<List<Product>> getProducts({bool lowStockOnly = false}) async {
    return mockProducts;
  }

  @override
  Future<ChatAssistantResult> askAssistant({required String message}) async {
    askAssistantCalled = true;
    lastMessageSent = message;
    return ChatAssistantResult(
      message: expectedReply,
      matchedProducts: mockProducts,
      aiEnabled: true,
      usedAi: true,
      action: mockAction,
      downloadLink: mockDownloadLink,
    );
  }
}

void main() {
  late FakeChatStockApiService fakeApi;
  late ValueNotifier<int> refreshSignal;

  setUp(() {
    fakeApi = FakeChatStockApiService();
    refreshSignal = ValueNotifier<int>(0);
  });

  Widget buildTestableWidget({
    void Function(BuildContext, Product)? onOpenProductDetails,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ChatAssistantPage(
          api: fakeApi,
          refreshSignal: refreshSignal,
          onOpenProductDetails: onOpenProductDetails,
        ),
      ),
    );
  }

  testWidgets("ChatAssistantPage renders correctly", (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Check title rendering
    expect(find.text("แชทผู้ช่วยสต๊อก"), findsOneWidget);

    // Check suggestion chips
    expect(find.text("อะไรใกล้หมดบ้าง"), findsOneWidget);
    expect(find.text("ขอไฟล์ Excel"), findsOneWidget);
    expect(find.text("เบิกสินค้า"), findsOneWidget);

    // Check message input field
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets("ChatAssistantPage submits messages and receives bot reply", (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Enter message
    final textField = find.byType(TextField);
    await tester.enterText(textField, "เช็กสต็อกสินค้าหน่อย");
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(); // Start request

    expect(fakeApi.askAssistantCalled, isTrue);
    expect(fakeApi.lastMessageSent, equals("เช็กสต็อกสินค้าหน่อย"));

    await tester.pumpAndSettle(); // Resolve request

    // Verify user message and bot reply render
    expect(find.text("เช็กสต็อกสินค้าหน่อย"), findsOneWidget);
    expect(find.text("สวัสดีครับ มีอะไรให้ช่วยไหม"), findsOneWidget);
  });

  testWidgets("ChatAssistantPage detects pending action and shows confirmation dialog", (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // "เบิก 10 ชิ้น" should trigger action detection
    final textField = find.byType(TextField);
    await tester.enterText(textField, "เบิก 10 8851234567890");
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    // Confirmation dialog should appear
    expect(find.text("ยืนยันคำสั่งสต็อก"), findsOneWidget);
    expect(find.text("ปรับ/แก้ไขสต็อก จำนวน 10 สำหรับ \"สินค้าที่ระบุ\""), findsOneWidget);

    // Click confirm
    await tester.tap(find.text("ยืนยัน"));
    await tester.pumpAndSettle();

    // Message should be sent
    expect(fakeApi.askAssistantCalled, isTrue);
    expect(fakeApi.lastMessageSent, equals("เบิก 10 8851234567890"));
  });

  testWidgets("ChatAssistantPage renders matched product results", (WidgetTester tester) async {
    // Add mock products to the reply
    fakeApi.mockProducts = [
      Product(
        barcode: "8850000000001",
        name: "น้ำดื่มตราสิงห์",
        currentStock: 25,
        minimumStock: 10,
        unit: "ขวด",
      )
    ];

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, "หาน้ำดื่ม");
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    // Verify that the product tile is rendered
    expect(find.text("น้ำดื่มตราสิงห์"), findsOneWidget);
    expect(find.text("8850000000001 · ไม่ระบุตำแหน่ง"), findsOneWidget);
  });

  testWidgets("ChatAssistantPage triggers product details callback on tap", (WidgetTester tester) async {
    final mockProduct = Product(
      barcode: "8850000000001",
      name: "น้ำดื่มตราสิงห์",
      currentStock: 25,
      minimumStock: 10,
      unit: "ขวด",
    );
    fakeApi.mockProducts = [mockProduct];

    Product? tappedProduct;
    await tester.pumpWidget(buildTestableWidget(
      onOpenProductDetails: (context, product) {
        tappedProduct = product;
      },
    ));
    await tester.pumpAndSettle();

    // Send search message
    final textField = find.byType(TextField);
    await tester.enterText(textField, "หาน้ำดื่ม");
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    // Tap on the product tile
    await tester.tap(find.text("น้ำดื่มตราสิงห์"));
    await tester.pumpAndSettle();

    // Check that callback was triggered
    expect(tappedProduct, isNotNull);
    expect(tappedProduct!.barcode, equals("8850000000001"));
  });

  testWidgets("ChatAssistantPage renders export link and can click it", (WidgetTester tester) async {
    fakeApi.mockDownloadLink = ExportLink(
      url: "http://example.com/report.xlsx",
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, "ขอรายงาน");
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    // Verify export link UI components render
    expect(find.text("ดาวน์โหลดไฟล์"), findsOneWidget);
    expect(find.text("http://example.com/report.xlsx"), findsOneWidget);
    expect(find.text("ดาวน์โหลดเลย"), findsOneWidget);
  });
}

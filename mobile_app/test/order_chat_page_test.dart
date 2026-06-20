import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";
import "package:stock_scanner_mobile/order_chat_page.dart";

class FakeOrderChatStockApiService extends StockApiService {
  List<OrderMessageModel> messages = [];
  int getOrderMessagesCount = 0;
  int markReadCount = 0;
  int postOrderMessageCount = 0;
  String? postedMessage;
  bool throwOnPost = false;

  @override
  Future<List<OrderMessageModel>> getOrderMessages({
    required String requesterId,
    required String orderId,
  }) async {
    getOrderMessagesCount++;
    return messages;
  }

  @override
  Future<OrderMessageModel> postOrderMessage({
    required String requesterId,
    required String orderId,
    required String message,
  }) async {
    postOrderMessageCount++;
    postedMessage = message;
    if (throwOnPost) {
      throw Exception("Send failed");
    }
    final item = OrderMessageModel(
      id: "posted_$postOrderMessageCount",
      orderId: orderId,
      userId: requesterId,
      userName: "Current User",
      message: message,
      createdAt: DateTime(2026, 1, 1, 10, postOrderMessageCount),
    );
    messages = [...messages, item];
    return item;
  }

  @override
  Future<void> markOrderMessagesRead({
    required String requesterId,
    required String orderId,
  }) async {
    markReadCount++;
  }
}

void main() {
  late FakeOrderChatStockApiService fakeApi;
  late AppUser currentUser;
  late DeliveryOrder order;

  setUp(() {
    fakeApi = FakeOrderChatStockApiService();
    currentUser = AppUser(
      userId: "USER1",
      userName: "Current User",
      role: "staff",
      active: true,
    );
    order = DeliveryOrder(
      id: "ORDER1",
      customerName: "Alice Customer",
      createdById: "CREATOR1",
      createdByName: "Creator",
      status: "new",
      items: const [],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  });

  Widget buildPage() {
    return MaterialApp(
      home: OrderChatPage(
        api: fakeApi,
        currentUser: currentUser,
        order: order,
      ),
    );
  }

  testWidgets("renders page and loads initial messages", (tester) async {
    fakeApi.messages = [
      OrderMessageModel(
        id: "msg1",
        orderId: order.id,
        userId: "OTHER",
        userName: "Other User",
        message: "Initial message",
        createdAt: DateTime(2026, 1, 1, 9),
      ),
    ];

    await tester.pumpWidget(buildPage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining("Alice Customer"), findsOneWidget);
    expect(find.text("Other User"), findsOneWidget);
    expect(find.text("Initial message"), findsOneWidget);
    expect(fakeApi.getOrderMessagesCount, 1);
    expect(fakeApi.markReadCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("sends a message and refreshes messages", (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), "Hello order");
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(fakeApi.postOrderMessageCount, 1);
    expect(fakeApi.postedMessage, "Hello order");
    expect(fakeApi.getOrderMessagesCount, 2);
    expect(find.text("Hello order"), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("shows snackbar when sending fails", (tester) async {
    fakeApi.throwOnPost = true;

    await tester.pumpWidget(buildPage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField), "Failing message");
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();

    expect(fakeApi.postOrderMessageCount, 1);
    expect(find.text("Send failed"), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("polling refreshes messages", (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fakeApi.getOrderMessagesCount, 1);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeApi.getOrderMessagesCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

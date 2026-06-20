import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/login_page.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeLoginStockApiService extends StockApiService {
  bool loginCalled = false;
  String? loginUserId;
  String? loginPin;
  bool shouldFail = false;
  bool shouldTimeout = false;
  bool isInactive = false;
  Completer<LoginSession>? completer;

  @override
  Future<LoginSession> login({
    required String userId,
    required String pin,
  }) async {
    loginCalled = true;
    loginUserId = userId;
    loginPin = pin;

    if (completer != null) {
      return completer!.future;
    }

    if (shouldTimeout) {
      await Future.delayed(const Duration(seconds: 30));
    }

    if (shouldFail) {
      throw Exception("Invalid user id or PIN");
    }

    if (isInactive) {
      throw Exception("inactive");
    }

    return LoginSession(
      accessToken: "TEST_TOKEN",
      tokenType: "bearer",
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      user: AppUser(
        userId: userId,
        userName: "Test User",
        role: "staff",
        active: true,
      ),
    );
  }
}

void main() {
  late FakeLoginStockApiService fakeApi;

  setUp(() {
    fakeApi = FakeLoginStockApiService();
  });

  group("LoginPage Widget Tests", () {
    testWidgets("renders LoginPage correctly with initial state", (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            api: fakeApi,
            onLogin: (_) async {},
          ),
        ),
      );

      // Verify title/button texts are present (there are 2 texts of "เข้าสู่ระบบ" when not loading)
      expect(find.text("เข้าสู่ระบบ"), findsNWidgets(2));
      expect(find.text("เข้าสู่ระบบด้วยรหัสผู้ใช้และ PIN"), findsOneWidget);
      expect(find.text("User ID"), findsOneWidget);
      expect(find.text("PIN"), findsOneWidget);
      expect(find.text("ใช้อักษรและตัวเลขของรหัสพนักงาน"), findsOneWidget);
    });

    testWidgets("validates empty User ID and shows error", (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            api: fakeApi,
            onLogin: (_) async {},
          ),
        ),
      );

      // Tap on login button specifically
      await tester.tap(find.widgetWithText(FilledButton, "เข้าสู่ระบบ"));
      await tester.pump();

      // Verify User ID error message displays
      expect(find.text("กรุณากรอก User ID"), findsOneWidget);
      expect(fakeApi.loginCalled, isFalse);
    });

    testWidgets("validates empty PIN and shows error", (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            api: fakeApi,
            onLogin: (_) async {},
          ),
        ),
      );

      // Enter User ID but leave PIN empty
      await tester.enterText(find.widgetWithText(TextField, "User ID"), "STAFF1");
      await tester.tap(find.widgetWithText(FilledButton, "เข้าสู่ระบบ"));
      await tester.pump();

      // Verify PIN error message displays
      expect(find.text("กรุณากรอก PIN"), findsOneWidget);
      expect(fakeApi.loginCalled, isFalse);
    });

    testWidgets("validates short PIN and shows error", (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            api: fakeApi,
            onLogin: (_) async {},
          ),
        ),
      );

      // Enter User ID and a short 3-digit PIN
      await tester.enterText(find.widgetWithText(TextField, "User ID"), "STAFF1");
      await tester.enterText(find.widgetWithText(TextField, "PIN"), "123");
      await tester.tap(find.widgetWithText(FilledButton, "เข้าสู่ระบบ"));
      await tester.pump();

      // Verify short PIN error message displays
      expect(find.text("PIN ต้องมีอย่างน้อย 4 หลัก"), findsOneWidget);
      expect(fakeApi.loginCalled, isFalse);
    });

    testWidgets("displays error snackbar when login fails with Invalid credentials", (WidgetTester tester) async {
      fakeApi.shouldFail = true;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            api: fakeApi,
            onLogin: (_) async {},
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, "User ID"), "STAFF1");
      await tester.enterText(find.widgetWithText(TextField, "PIN"), "1234");
      await tester.tap(find.widgetWithText(FilledButton, "เข้าสู่ระบบ"));
      await tester.pump(); // Start request

      // Let any microtasks run (like the API call futures)
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeApi.loginCalled, isTrue);
      expect(find.text("ไม่พบ User ID นี้ หรือ PIN ไม่ถูกต้อง"), findsOneWidget);
      expect(find.text("ตรวจสอบ PIN แล้วลองอีกครั้ง"), findsOneWidget);
    });

    testWidgets("displays error snackbar when login fails with inactive account", (WidgetTester tester) async {
      fakeApi.isInactive = true;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            api: fakeApi,
            onLogin: (_) async {},
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, "User ID"), "STAFF1");
      await tester.enterText(find.widgetWithText(TextField, "PIN"), "1234");
      await tester.tap(find.widgetWithText(FilledButton, "เข้าสู่ระบบ"));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeApi.loginCalled, isTrue);
      expect(find.text("บัญชีนี้ถูกปิดการใช้งาน"), findsOneWidget);
    });

    testWidgets("triggers success callback on successful login", (WidgetTester tester) async {
      LoginSession? loggedSession;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            api: fakeApi,
            onLogin: (session) async {
              loggedSession = session;
            },
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, "User ID"), "staff2");
      await tester.enterText(find.widgetWithText(TextField, "PIN"), "5678");
      await tester.tap(find.widgetWithText(FilledButton, "เข้าสู่ระบบ"));
      await tester.pump();

      // Wait for login future resolution
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeApi.loginCalled, isTrue);
      expect(fakeApi.loginUserId, "STAFF2"); // Verifies normalization/uppercase text formatting
      expect(fakeApi.loginPin, "5678");
      expect(loggedSession, isNotNull);
      expect(loggedSession!.accessToken, "TEST_TOKEN");
    });

    testWidgets("shows circular progress indicator when login is in progress", (WidgetTester tester) async {
      final completer = Completer<LoginSession>();
      fakeApi.completer = completer;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            api: fakeApi,
            onLogin: (_) async {},
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, "User ID"), "STAFF1");
      await tester.enterText(find.widgetWithText(TextField, "PIN"), "1234");
      await tester.tap(find.widgetWithText(FilledButton, "เข้าสู่ระบบ"));
      await tester.pump(); // Trigger setState for loading

      // Verify the loading indicator is shown and button displays loading label
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text("กำลังเข้าสู่ระบบ..."), findsNWidgets(2));

      // Clean up: complete the completer to dismiss loading and cancel timeout timer
      completer.complete(LoginSession(
        accessToken: "TEST_TOKEN",
        tokenType: "bearer",
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: AppUser(
          userId: "STAFF1",
          userName: "Test User",
          role: "staff",
          active: true,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // allow any final microtasks/handlers to run
    });
  });
}

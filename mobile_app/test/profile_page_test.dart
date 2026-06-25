import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:stock_scanner_mobile/profile_page.dart";
import "package:stock_scanner_mobile/api_service.dart";
import "package:stock_scanner_mobile/models.dart";

class FakeProfileStockApiService extends StockApiService {
  List<AppUser> mockUsers = [];
  AppUser? mockCurrentUser;
  bool updateMyProfileCalled = false;
  String? updatedUserName;
  bool changePinCalled = false;
  String? changePinCurrent;
  String? changePinNew;
  bool upsertUserCalled = false;
  bool deleteUserCalled = false;
  bool uploadProfileImageCalled = false;

  @override
  Future<List<AppUser>> getUsers({bool activeOnly = false}) async {
    return mockUsers;
  }

  @override
  Future<AppUser> getCurrentUser() async {
    return mockCurrentUser ??
        AppUser(
          userId: "STAFF1",
          userName: "Staff One",
          role: "staff",
          active: true,
        );
  }

  @override
  Future<AppUser> updateMyProfile({String? userName}) async {
    updateMyProfileCalled = true;
    updatedUserName = userName;
    return AppUser(
      userId: mockCurrentUser?.userId ?? "STAFF1",
      userName: userName ?? "Staff One",
      role: mockCurrentUser?.role ?? "staff",
      active: true,
    );
  }

  @override
  Future<String> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    changePinCalled = true;
    changePinCurrent = currentPin;
    changePinNew = newPin;
    return "เปลี่ยน PIN สำเร็จ";
  }

  @override
  Future<AppUser> upsertUser({
    required String requesterId,
    required String userId,
    required String userName,
    String role = "staff",
    String? position,
    bool active = true,
    String? pin,
    String? profileImageUrl,
  }) async {
    upsertUserCalled = true;
    return AppUser(
      userId: userId,
      userName: userName,
      role: role,
      active: active,
      position: position,
      profileImageUrl: profileImageUrl,
    );
  }

  @override
  Future<String> deleteUser({
    required String requesterId,
    required String userId,
    bool deleteMovements = false,
  }) async {
    deleteUserCalled = true;
    return "ลบผู้ใช้สำเร็จ";
  }

  @override
  Future<AppUser> uploadProfileImage({
    required String requesterId,
    required String targetUserId,
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    uploadProfileImageCalled = true;
    return AppUser(
      userId: targetUserId,
      userName: "Mock User",
      role: "staff",
      active: true,
    );
  }

  @override
  String resolveAssetUrl(String? path) {
    return path ?? "";
  }
}

void main() {
  late FakeProfileStockApiService fakeApi;
  late AppUser staffUser;
  late AppUser adminUser;
  bool logoutCalled = false;

  setUp(() {
    fakeApi = FakeProfileStockApiService();
    staffUser = AppUser(
      userId: "STAFF1",
      userName: "สมชาย มีสุข",
      role: "staff",
      active: true,
    );
    adminUser = AppUser(
      userId: "ADMIN1",
      userName: "ผู้ดูแล ระบบ",
      role: "admin",
      active: true,
    );
    logoutCalled = false;
  });

  Widget buildTestableWidget({
    required AppUser user,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ProfilePage(
          currentUser: user,
          api: fakeApi,
          onLogout: () async {
            logoutCalled = true;
          },
          onRefreshSession: () async {},
        ),
      ),
    );
  }

  void setupLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets("ProfilePage renders correctly for staff (non-admin)", (WidgetTester tester) async {
    setupLargeViewport(tester);
    await tester.pumpWidget(buildTestableWidget(user: staffUser));
    await tester.pumpAndSettle();

    // Verify staff name and role label
    expect(find.text("สมชาย มีสุข"), findsWidgets); // Avatar text & Display Name
    expect(find.text("พนักงาน"), findsWidgets);

    // Verify that the user management forms are hidden for staff
    expect(find.text("เพิ่มผู้ใช้งาน"), findsNothing);
    expect(find.text("รายชื่อผู้ใช้งาน"), findsNothing);
  });

  testWidgets("ProfilePage renders admin section for admin users", (WidgetTester tester) async {
    setupLargeViewport(tester);
    fakeApi.mockUsers = [staffUser, adminUser];
    await tester.pumpWidget(buildTestableWidget(user: adminUser));
    await tester.pumpAndSettle();

    // Verify admin name and role label
    expect(find.text("ผู้ดูแล ระบบ"), findsWidgets);
    expect(find.text("ผู้ดูแลระบบ"), findsWidgets);

    // Verify admin-only section headers
    expect(find.text("เพิ่มผู้ใช้งาน"), findsOneWidget);
    expect(find.text("รายชื่อผู้ใช้งาน"), findsOneWidget);

    // Verify both users are displayed in the list
    expect(find.text("สมชาย มีสุข"), findsWidgets);
  });

  testWidgets("ProfilePage triggers logout callback", (WidgetTester tester) async {
    setupLargeViewport(tester);
    await tester.pumpWidget(buildTestableWidget(user: staffUser));
    await tester.pumpAndSettle();

    // Find and tap logout button
    final logoutButton = find.text("ออกจากระบบ");
    expect(logoutButton, findsOneWidget);
    await tester.tap(logoutButton);
    await tester.pump();

    expect(logoutCalled, isTrue);
  });

  testWidgets("ProfilePage validates PIN mismatch", (WidgetTester tester) async {
    setupLargeViewport(tester);
    await tester.pumpWidget(buildTestableWidget(user: staffUser));
    await tester.pumpAndSettle();

    // Use indices for TextFields:
    // 0: current PIN, 1: new PIN, 2: confirm PIN
    final currentPinField = find.byType(TextField).at(0);
    final newPinField = find.byType(TextField).at(1);
    final confirmPinField = find.byType(TextField).at(2);

    await tester.enterText(currentPinField, "1234");
    await tester.enterText(newPinField, "5678");
    await tester.enterText(confirmPinField, "5679"); // mismatch
    await tester.pump();

    // Tap submit PIN
    final submitButton = find.text("บันทึก PIN ใหม่");
    await tester.tap(submitButton);
    await tester.pump();

    // Verify mismatch error message displayed via snackbar
    expect(find.text("PIN ใหม่และการยืนยัน PIN ไม่ตรงกัน"), findsOneWidget);
  });

  testWidgets("ProfilePage User ID field automatically formats input to uppercase", (WidgetTester tester) async {
    setupLargeViewport(tester);
    await tester.pumpWidget(buildTestableWidget(user: adminUser));
    await tester.pumpAndSettle();

    // In admin view:
    // 0: current PIN, 1: new PIN, 2: confirm PIN, 3: user id
    final userIdField = find.byType(TextField).at(3);

    await tester.enterText(userIdField, "staff-02_xyz");
    await tester.pump();

    // Verify the text is uppercase staff-02_xyz -> STAFF-02_XYZ
    final TextField textFieldWidget = tester.widget(userIdField);
    expect(textFieldWidget.controller?.text, equals("STAFF-02_XYZ"));
  });

  testWidgets("UserAvatar fallback logic tests", (WidgetTester tester) async {
    // 1. Empty/null imageUrl shows initials
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            imageUrl: null,
            name: "John Doe",
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("J"), findsOneWidget);

    // 2. Failed imageUrl falls back to initials
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            imageUrl: "https://example.com/invalid_avatar.jpg",
            name: "Alice Smith",
          ),
        ),
      ),
    );
    // Let image loading fail in widget test environment, triggering error boundary
    await tester.pump();
    await tester.pumpAndSettle();
    
    expect(find.text("A"), findsOneWidget);
  });
}

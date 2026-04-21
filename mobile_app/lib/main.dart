import "dart:io";
import "dart:typed_data";
import "dart:ui" as ui;

import "package:barcode_widget/barcode_widget.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:mobile_scanner/mobile_scanner.dart" hide Barcode;
import "package:path_provider/path_provider.dart";
import "package:qr_flutter/qr_flutter.dart";
import "package:share_plus/share_plus.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

import "api_service.dart";
import "models.dart";

const _sessionUserIdKey = "session_user_id";
const _sessionPinKey = "session_pin";
const _sessionAccessTokenKey = "session_access_token";
const _brandPrimary = Color(0xFF01579B);
const _brandSurface = Color(0xFFE0F7FA);
const _brandSurfaceStrong = Color(0xFFB2EBF2);
const _brandTextOnLight = Color(0xFF0D2A3A);
const _brandDeep = Color(0xFF003C6C);
const _brandInk = Color(0xFF12384D);
const _brandCard = Color(0xFFF4FDFF);

void main() {
  runApp(const StockScannerApp());
}

class StockScannerApp extends StatefulWidget {
  const StockScannerApp({super.key});

  @override
  State<StockScannerApp> createState() => _StockScannerAppState();
}

class _StockScannerAppState extends State<StockScannerApp> {
  final StockApiService _api = StockApiService();
  AppUser? _currentUser;
  bool _isRestoring = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_sessionAccessTokenKey);
    final savedUserId = prefs.getString(_sessionUserIdKey);
    final savedPin = prefs.getString(_sessionPinKey);

    if (savedToken != null && savedToken.isNotEmpty) {
      try {
        _api.setAccessToken(savedToken);
        final user = await _api.getCurrentUser();
        if (mounted) {
          setState(() {
            _currentUser = user;
            _isRestoring = false;
          });
          return;
        }
      } catch (_) {
        _api.clearAccessToken();
        await prefs.remove(_sessionAccessTokenKey);
      }
    }

    if (savedUserId != null && savedPin != null) {
      try {
        final session = await _api.login(userId: savedUserId, pin: savedPin);
        await prefs.setString(_sessionAccessTokenKey, session.accessToken);
        await prefs.remove(_sessionPinKey);
        if (mounted) {
          setState(() {
            _currentUser = session.user;
            _isRestoring = false;
          });
          return;
        }
      } catch (_) {
        _api.clearAccessToken();
        await prefs.remove(_sessionAccessTokenKey);
        await prefs.remove(_sessionUserIdKey);
        await prefs.remove(_sessionPinKey);
      }
    }

    if (mounted) {
      setState(() {
        _isRestoring = false;
      });
    }
  }

  Future<void> _handleLogin(LoginSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserIdKey, session.user.userId);
    await prefs.setString(_sessionAccessTokenKey, session.accessToken);
    await prefs.remove(_sessionPinKey);
    if (mounted) {
      setState(() {
        _currentUser = session.user;
      });
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _api.logout();
    } catch (_) {
      _api.clearAccessToken();
    }
    await prefs.remove(_sessionAccessTokenKey);
    await prefs.remove(_sessionUserIdKey);
    await prefs.remove(_sessionPinKey);
    if (mounted) {
      setState(() {
        _currentUser = null;
      });
    }
  }

  Future<void> _refreshSession() async {
    if (_currentUser == null) {
      return;
    }
    final refreshed = await _api.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = refreshed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "แอปสต๊อกสินค้า",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandPrimary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: _brandSurface,
        textTheme: ThemeData.light().textTheme.copyWith(
              headlineSmall: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _brandDeep,
                letterSpacing: -0.4,
              ),
              titleMedium: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _brandDeep,
              ),
              bodyMedium: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: _brandInk,
              ),
            ),
        cardTheme: CardThemeData(
          color: _brandCard,
          elevation: 0,
          shadowColor: _brandPrimary.withOpacity(0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: _brandPrimary.withOpacity(0.10)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _brandCard,
          indicatorColor: _brandSurfaceStrong.withOpacity(0.75),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected) ? _brandPrimary : _brandInk,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.82),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: _brandPrimary.withOpacity(0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: _brandPrimary.withOpacity(0.12)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            borderSide: BorderSide(color: _brandPrimary, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _brandPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _brandPrimary,
            side: const BorderSide(color: _brandPrimary),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: _isRestoring
          ? const _SplashScreen()
          : _currentUser == null
              ? LoginPage(api: _api, onLogin: _handleLogin)
              : StockHomePage(
                  api: _api,
                  currentUser: _currentUser!,
                  onLogout: _handleLogout,
                  onRefreshSession: _refreshSession,
                ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.api,
    required this.onLogin,
  });

  final StockApiService api;
  final Future<void> Function(LoginSession session) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _userIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final userId = _userIdController.text.trim();
    final pin = _pinController.text.trim();
    if (userId.isEmpty || pin.length < 4) {
      _showSnack("กรอก user id และ PIN ให้ครบ");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final session = await widget.api.login(userId: userId, pin: pin);
      await widget.onLogin(session);
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("เข้าสู่ระบบ", style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text("เข้าสู่ระบบด้วยรหัสผู้ใช้และ PIN"),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        labelText: "รหัสผู้ใช้",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "PIN",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePin = !_obscurePin;
                            });
                          },
                          icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _login,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text("เข้าสู่ระบบ"),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "ตัวอย่างทดสอบ: EMP001 / 1234",
                      style: TextStyle(color: _brandPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StockHomePage extends StatefulWidget {
  const StockHomePage({
    super.key,
    required this.api,
    required this.currentUser,
    required this.onLogout,
    required this.onRefreshSession,
  });

  final StockApiService api;
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefreshSession;

  @override
  State<StockHomePage> createState() => _StockHomePageState();
}

class _StockHomePageState extends State<StockHomePage> {
  int _currentIndex = 0;

  Future<void> _openMorePage(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MorePage(
          api: widget.api,
          currentUser: widget.currentUser,
          onLogout: widget.onLogout,
          onRefreshSession: widget.onRefreshSession,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(api: widget.api),
      ScanPage(api: widget.api, currentUser: widget.currentUser),
      HistoryPage(api: widget.api),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 104),
              child: pages[_currentIndex],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: IconButton.filledTonal(
                  onPressed: () => _openMorePage(context),
                  icon: const Icon(Icons.grid_view_rounded),
                  tooltip: "เพิ่มเติม",
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: _brandCard.withOpacity(0.96),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _brandPrimary.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: _brandPrimary.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: NavigationBar(
            height: 72,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _currentIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: "ภาพรวม",
              ),
              NavigationDestination(
                icon: Icon(Icons.qr_code_scanner_outlined),
                selectedIcon: Icon(Icons.qr_code_scanner),
                label: "สแกน",
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: "ประวัติ",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.currentUser,
    required this.api,
    required this.onLogout,
    required this.onRefreshSession,
  });

  final AppUser currentUser;
  final StockApiService api;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefreshSession;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<List<AppUser>> _usersFuture;
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _profileImageUrlController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _role = "staff";
  bool _active = true;
  bool _isSaving = false;
  bool _isUploadingProfileImage = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = widget.api.getUsers(activeOnly: false);
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _userNameController.dispose();
    _pinController.dispose();
    _profileImageUrlController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _usersFuture = widget.api.getUsers(activeOnly: false);
    });
    await _usersFuture;
    await widget.onRefreshSession();
  }

  Future<void> _saveUser() async {
    final userId = _userIdController.text.trim();
    final userName = _userNameController.text.trim();
    if (userId.isEmpty || userName.isEmpty) {
      _showSnack("กรอกรหัสผู้ใช้และชื่อผู้ใช้ให้ครบ");
      return;
    }
    if (_pinController.text.trim().length < 4) {
      _showSnack("PIN ต้องมีอย่างน้อย 4 หลัก");
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.api.upsertUser(
        requesterId: widget.currentUser.userId,
        userId: userId,
        userName: userName,
        role: _role,
        active: _active,
        pin: _pinController.text.trim(),
        profileImageUrl: _profileImageUrlController.text.trim().isEmpty
            ? null
            : _profileImageUrlController.text.trim(),
      );
      _userIdController.clear();
      _userNameController.clear();
      _pinController.clear();
      _profileImageUrlController.clear();
      setState(() {
        _role = "staff";
        _active = true;
      });
      await _reload();
      _showSnack("บันทึกผู้ใช้งานเรียบร้อย");
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _toggleUser(AppUser user) async {
    try {
      await widget.api.upsertUser(
        requesterId: widget.currentUser.userId,
        userId: user.userId,
        userName: user.userName,
        role: user.role,
        active: !user.active,
      );
      await _reload();
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _pickAndUploadProfileImage(AppUser targetUser) async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) {
        return;
      }

      setState(() {
        _isUploadingProfileImage = true;
      });

      await widget.api.uploadProfileImage(
        requesterId: widget.currentUser.userId,
        targetUserId: targetUser.userId,
        filePath: file.path,
      );
      await _reload();
      _showSnack("อัปโหลดรูปโปรไฟล์เรียบร้อย");
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProfileImage = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<AppUser>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          final users = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PageHeader(
                title: widget.currentUser.isAdmin ? "โปรไฟล์และผู้ใช้" : "โปรไฟล์",
                subtitle: widget.currentUser.isAdmin
                    ? "ดูข้อมูลของคุณและจัดการผู้ใช้งานได้"
                    : "ดูข้อมูลของคุณและออกจากระบบ",
                showBackButton: true,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _UserAvatar(
                            imageUrl: widget.api.resolveAssetUrl(
                              widget.currentUser.profileImageUrl,
                            ),
                            name: widget.currentUser.userName,
                            radius: 34,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              "ผู้ใช้ปัจจุบัน",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text("ชื่อ: ${widget.currentUser.userName}"),
                      Text("รหัส: ${widget.currentUser.userId}"),
                      Text("สิทธิ์: ${widget.currentUser.role}"),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isUploadingProfileImage
                            ? null
                            : () => _pickAndUploadProfileImage(widget.currentUser),
                        icon: _isUploadingProfileImage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_a_photo_outlined),
                        label: const Text("อัปโหลดรูปโปรไฟล์จากมือถือ"),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: widget.onLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text("ออกจากระบบ"),
                      ),
                    ],
                  ),
                ),
              ),
              if (!widget.currentUser.isAdmin) ...[
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("บัญชีนี้ไม่มีสิทธิ์จัดการผู้ใช้"),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("เพิ่มผู้ใช้งาน", style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _userIdController,
                          decoration: const InputDecoration(
                            labelText: "รหัสผู้ใช้",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _userNameController,
                          decoration: const InputDecoration(
                            labelText: "ชื่อผู้ใช้",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "PIN",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _profileImageUrlController,
                          decoration: const InputDecoration(
                            labelText: "Profile Image URL",
                            hintText: "https://example.com/avatar.png",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _role,
                          decoration: const InputDecoration(
                            labelText: "สิทธิ์",
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: "staff", child: Text("พนักงาน")),
                            DropdownMenuItem(value: "admin", child: Text("ผู้ดูแล")),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _role = value;
                              });
                            }
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("เปิดใช้งาน"),
                          value: _active,
                          onChanged: (value) {
                            setState(() {
                              _active = value;
                            });
                          },
                        ),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveUser,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: const Text("บันทึกผู้ใช้งาน"),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text("รายชื่อผู้ใช้งาน", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (users.isEmpty)
                  const _EmptyTile(message: "ยังไม่มีผู้ใช้ในระบบ")
                else
                  ...users.map(
                    (user) => Card(
                      child: ListTile(
                        leading: _UserAvatar(
                          imageUrl: widget.api.resolveAssetUrl(user.profileImageUrl),
                          name: user.userName,
                          radius: 22,
                        ),
                        title: Text(user.userName),
                        subtitle: Text("${user.userId} • ${user.role}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: "อัปโหลดรูป",
                              onPressed: _isUploadingProfileImage
                                  ? null
                                  : () => _pickAndUploadProfileImage(user),
                              icon: const Icon(Icons.add_photo_alternate_outlined),
                            ),
                            Switch(
                              value: user.active,
                              onChanged: user.userId == widget.currentUser.userId
                                  ? null
                                  : (_) => _toggleUser(user),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.api});

  final StockApiService api;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardData> _load() async {
    final results = await Future.wait([
      widget.api.getSummary(),
      widget.api.getProducts(),
      widget.api.getNotifications(limit: 5),
    ]);
    return DashboardData(
      summary: results[0] as StockSummary,
      products: results[1] as List<Product>,
      notifications: results[2] as List<AppNotification>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _future = _load();
        });
        await _future;
      },
      child: FutureBuilder<DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _PageHeader(
                title: "ภาพรวมสต๊อก",
                subtitle: "ภาพรวมสต๊อกและรายการที่ต้องดูแล",
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    title: "สินค้า",
                    value: "${data.summary.totalProducts}",
                    icon: Icons.inventory_2_outlined,
                  ),
                  _MetricCard(
                    title: "จำนวนรวม",
                    value: "${data.summary.totalUnits}",
                    icon: Icons.layers_outlined,
                  ),
                  _MetricCard(
                    title: "สต๊อกต่ำ",
                    value: "${data.summary.lowStockCount}",
                    icon: Icons.warning_amber_outlined,
                    tone: _brandPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text("สินค้าสต๊อกต่ำ", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (data.summary.lowStockItems.isEmpty)
                const _EmptyTile(message: "ยังไม่มีสินค้าที่ต่ำกว่าจุดเตือน")
              else
                ...data.summary.lowStockItems.map(
                  (item) => _ProductTile(
                    product: item,
                    onOpenCode: () => _showProductCodeSheet(context, item),
                  ),
                ),
              const SizedBox(height: 20),
              Text("แจ้งเตือนล่าสุด", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (data.notifications.isEmpty)
                const _EmptyTile(message: "ยังไม่มีประวัติการยิงรายการ")
              else
                ...data.notifications.map(
                  (item) => _NotificationTile(notification: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.api,
    required this.currentUser,
  });

  final StockApiService api;
  final AppUser currentUser;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: "1");
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productSkuController = TextEditingController();
  final TextEditingController _productUnitController = TextEditingController(text: "pcs");
  final TextEditingController _productCategoryController = TextEditingController();
  final TextEditingController _productLocationController = TextEditingController();

  String _action = "in";
  bool _newProductMode = false;
  bool _isSubmitting = false;
  bool _isGeneratingBarcode = false;
  bool _scannerEnabled = true;
  ScanResult? _lastResult;

  @override
  void dispose() {
    _barcodeController.dispose();
    _qtyController.dispose();
    _noteController.dispose();
    _referenceController.dispose();
    _productNameController.dispose();
    _productSkuController.dispose();
    _productUnitController.dispose();
    _productCategoryController.dispose();
    _productLocationController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _generateBarcode({bool silent = false}) async {
    try {
      setState(() {
        _isGeneratingBarcode = true;
      });
      final barcode = await widget.api.getNextBarcode();
      if (!mounted) {
        return;
      }
      setState(() {
        _barcodeController.text = barcode;
      });
      if (!silent) {
        _showSnack("สร้าง barcode ใหม่แล้ว");
      }
    } catch (error) {
      if (!silent) {
        _showSnack(error.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingBarcode = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final quantity = int.tryParse(_qtyController.text.trim());
    final shouldCreateProduct = _newProductMode && widget.currentUser.isAdmin;

    if (_barcodeController.text.trim().isEmpty || quantity == null || quantity <= 0) {
      _showSnack("กรอก barcode และจำนวนให้ครบ");
      return;
    }
    if (_newProductMode && !widget.currentUser.isAdmin) {
      _showSnack("เฉพาะ admin เท่านั้นที่สร้างสินค้าใหม่ได้");
      return;
    }
    if (shouldCreateProduct && _productNameController.text.trim().isEmpty) {
      _showSnack("กรอกชื่อสินค้าเมื่อเปิดโหมดสินค้าใหม่");
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await widget.api.submitScan(
        barcode: _barcodeController.text.trim(),
        action: shouldCreateProduct ? "in" : _action,
        quantity: quantity,
        actorId: widget.currentUser.userId,
        actorName: widget.currentUser.userName,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        autoCreateProduct: shouldCreateProduct,
        productName: _productNameController.text.trim().isEmpty ? null : _productNameController.text.trim(),
        productUnit: _productUnitController.text.trim().isEmpty ? "pcs" : _productUnitController.text.trim(),
        productCategory: _productCategoryController.text.trim().isEmpty ? null : _productCategoryController.text.trim(),
        productLocation: _productLocationController.text.trim().isEmpty ? null : _productLocationController.text.trim(),
        productSku: _productSkuController.text.trim().isEmpty ? null : _productSkuController.text.trim(),
      );
      setState(() {
        _lastResult = result;
      });
      if (result.productCreated) {
        _showSnack("สร้างสินค้าใหม่และบันทึกรายการเรียบร้อย");
      } else if (result.lowStock) {
        _showSnack("บันทึกแล้ว และสินค้านี้อยู่ในระดับเตือน");
      } else {
        _showSnack("บันทึกรายการเรียบร้อย");
      }
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PageHeader(
          title: "สแกนและบันทึก",
          subtitle: widget.currentUser.isAdmin
              ? "คุณใช้ได้ทั้งโหมดสแกนปกติและโหมดสินค้าใหม่"
              : "บัญชีนี้สแกนรับเข้า จ่ายออก และเบิกใช้ได้",
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text("สแกนเข้า/ออก"), icon: Icon(Icons.qr_code_scanner)),
            ButtonSegment(value: true, label: Text("สินค้าใหม่"), icon: Icon(Icons.add_box_outlined)),
          ],
          selected: {_newProductMode},
          onSelectionChanged: (selection) {
            final wantsNewMode = selection.first;
            if (wantsNewMode && !widget.currentUser.isAdmin) {
              _showSnack("เฉพาะ admin เท่านั้นที่เปิดโหมดสินค้าใหม่ได้");
              return;
            }
            setState(() {
              _newProductMode = wantsNewMode;
            });
            if (wantsNewMode && _barcodeController.text.trim().isEmpty) {
              _generateBarcode(silent: true);
            }
          },
        ),
        if (!widget.currentUser.isAdmin) ...[
          const SizedBox(height: 8),
          const Text("บัญชีนี้ไม่มีสิทธิ์สร้างสินค้าใหม่"),
        ],
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 250,
            child: MobileScanner(
              controller: MobileScannerController(
                detectionSpeed: DetectionSpeed.noDuplicates,
                returnImage: false,
              ),
              onDetect: (capture) {
                if (!_scannerEnabled) {
                  return;
                }
                final value = capture.barcodes.first.rawValue;
                if (value == null || value.isEmpty) {
                  return;
                }
                setState(() {
                  _barcodeController.text = value;
                  _scannerEnabled = false;
                });
                Future<void>.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    setState(() {
                      _scannerEnabled = true;
                    });
                  }
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _barcodeController,
          decoration: InputDecoration(
            labelText: "Barcode",
            border: const OutlineInputBorder(),
            suffixIcon: _newProductMode
                ? IconButton(
                    onPressed: _isGeneratingBarcode ? null : _generateBarcode,
                    icon: _isGeneratingBarcode
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    tooltip: "สร้าง barcode อัตโนมัติ",
                  )
                : null,
          ),
        ),
        if (_newProductMode) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _isGeneratingBarcode ? null : _generateBarcode,
              icon: const Icon(Icons.qr_code_2_outlined),
              label: const Text("สร้าง barcode สินค้าใหม่อัตโนมัติ"),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!_newProductMode) ...[
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "in", label: Text("รับเข้า"), icon: Icon(Icons.call_received)),
              ButtonSegment(value: "out", label: Text("จ่ายออก"), icon: Icon(Icons.call_made)),
              ButtonSegment(value: "issue", label: Text("เบิกใช้"), icon: Icon(Icons.assignment_turned_in_outlined)),
            ],
            selected: {_action},
            onSelectionChanged: (selection) {
              setState(() {
                _action = selection.first;
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "จำนวน",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: "เลขอ้างอิง",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: "หมายเหตุ",
            border: OutlineInputBorder(),
          ),
        ),
        if (_newProductMode) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _productNameController,
            decoration: const InputDecoration(
              labelText: "ชื่อสินค้า",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _productSkuController,
                  decoration: const InputDecoration(
                    labelText: "SKU",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _productUnitController,
                  decoration: const InputDecoration(
                    labelText: "หน่วย",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _productCategoryController,
            decoration: const InputDecoration(
              labelText: "หมวดหมู่",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _productLocationController,
            decoration: const InputDecoration(
              labelText: "ตำแหน่งจัดเก็บ",
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(_newProductMode ? "สร้างสินค้าใหม่และรับเข้า" : "บันทึกรายการ"),
        ),
        if (_lastResult != null) ...[
          const SizedBox(height: 20),
          _ScanResultCard(
            result: _lastResult!,
            onOpenCode: () => _showProductCodeSheet(
              context,
              _lastResult!.product,
            ),
          ),
        ],
      ],
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.api});

  final StockApiService api;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<MovementRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getMovements();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _future = widget.api.getMovements();
        });
        await _future;
      },
      child: FutureBuilder<List<MovementRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }
          final items = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _PageHeader(
                title: "ประวัติการเคลื่อนไหว",
                subtitle: "ดูว่าใครเป็นคนยิงสินค้าเข้า ออก หรือเบิกใช้",
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const _EmptyTile(message: "ยังไม่มี movement ในระบบ")
              else
                ...items.map((item) => _MovementTile(item: item)),
            ],
          );
        },
      ),
    );
  }
}

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.api,
    required this.currentUser,
    required this.onLogout,
    required this.onRefreshSession,
  });

  final StockApiService api;
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefreshSession;

  Future<void> _openPage(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <_MoreAction>[
      _MoreAction(
        title: "โปรไฟล์",
        subtitle: "ดูข้อมูลผู้ใช้ อัปโหลดรูป และออกจากระบบ",
        icon: Icons.person_outline,
        onTap: () => _openPage(
          context,
          ProfilePage(
            currentUser: currentUser,
            api: api,
            onLogout: onLogout,
            onRefreshSession: onRefreshSession,
          ),
        ),
      ),
      _MoreAction(
        title: "แจ้งเตือน",
        subtitle: "ดูรายการแจ้งเตือนล่าสุดจากการยิงสินค้า",
        icon: Icons.notifications_none_outlined,
        onTap: () => _openPage(
          context,
          NotificationsPage(api: api),
        ),
      ),
    ];

    if (currentUser.isAdmin) {
      items.add(
        _MoreAction(
          title: "ผู้ดูแลระบบ",
          subtitle: "ซิงก์ Google Sheets และส่งออกข้อมูล",
          icon: Icons.admin_panel_settings_outlined,
          onTap: () => _openPage(
            context,
            AdminPage(api: api, currentUser: currentUser),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageHeader(
          title: "เพิ่มเติม",
          subtitle: "รวมเมนูที่ใช้ไม่บ่อยไว้ในหน้าเดียว เพื่อให้แถบล่างดูสบายตาขึ้น",
          showBackButton: true,
        ),
        const SizedBox(height: 16),
        ...items.map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: _brandSurfaceStrong,
                child: Icon(item.icon, color: _brandPrimary),
              ),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: item.onTap,
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreAction {
  const _MoreAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.api});

  final StockApiService api;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _future = widget.api.getNotifications();
        });
        await _future;
      },
      child: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }
          final items = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _PageHeader(
                title: "การแจ้งเตือน",
                subtitle: "ฟีดแจ้งเตือนจากการยิงสินค้าแต่ละรายการ",
                showBackButton: true,
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const _EmptyTile(message: "ยังไม่มี notification")
              else
                ...items.map((item) => _NotificationTile(notification: item)),
            ],
          );
        },
      ),
    );
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    required this.api,
    required this.currentUser,
  });

  final StockApiService api;
  final AppUser currentUser;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _isRunning = false;
  String? _lastMessage;
  late Future<Map<String, ExportLink>> _exportLinksFuture;

  @override
  void initState() {
    super.initState();
    _exportLinksFuture = _loadExportLinks();
  }

  Future<Map<String, ExportLink>> _loadExportLinks() async {
    final requesterId = widget.currentUser.userId;
    final results = await Future.wait([
      widget.api.createExportLink(exportName: "products_csv", requesterId: requesterId),
      widget.api.createExportLink(exportName: "users_csv", requesterId: requesterId),
      widget.api.createExportLink(
        exportName: "movements_csv",
        requesterId: requesterId,
        movementLimit: 500,
      ),
      widget.api.createExportLink(
        exportName: "all_xlsx",
        requesterId: requesterId,
        movementLimit: 5000,
      ),
    ]);
    return {
      "products": results[0],
      "users": results[1],
      "movements": results[2],
      "excel": results[3],
    };
  }

  void _refreshExportLinks() {
    setState(() {
      _exportLinksFuture = _loadExportLinks();
    });
  }

  Future<void> _runAction(Future<String> Function() action) async {
    if (!widget.currentUser.isAdmin) {
      _showSnack("เฉพาะ admin เท่านั้นที่ใช้งานหน้านี้ได้");
      return;
    }

    setState(() {
      _isRunning = true;
    });
    try {
      final message = await action();
      setState(() {
        _lastMessage = message;
      });
      _showSnack(message);
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.isAdmin) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _PageHeader(
            title: "ผู้ดูแลระบบ",
            subtitle: "หน้านี้สำหรับผู้ดูแลระบบเท่านั้น",
            showBackButton: true,
          ),
          SizedBox(height: 16),
          _EmptyTile(message: "บัญชีนี้ไม่มีสิทธิ์ใช้งานฟังก์ชัน admin"),
        ],
      );
    }

    final requesterId = widget.currentUser.userId;
    final productExport = widget.api.exportUrl(
      path: "/exports/products.csv",
      requesterId: requesterId,
    );
    final userExport = widget.api.exportUrl(
      path: "/exports/users.csv",
      requesterId: requesterId,
    );
    final movementExport = widget.api.exportUrl(
      path: "/exports/movements.csv",
      requesterId: requesterId,
    );
    final excelExport = widget.api.exportUrl(
      path: "/exports/all.xlsx",
      requesterId: requesterId,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageHeader(
          title: "ผู้ดูแลระบบ",
          subtitle: "งาน sync ข้อมูลและลิงก์ export สำหรับผู้ดูแลระบบ",
          showBackButton: true,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("คำสั่ง Google Sheets", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runAction(
                            () => widget.api.syncProducts(requesterId: requesterId),
                          ),
                  child: const Text("ซิงก์สินค้า"),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runAction(
                            () => widget.api.syncUsers(requesterId: requesterId),
                          ),
                  child: const Text("ซิงก์ผู้ใช้"),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runAction(
                            () => widget.api.syncStocks(requesterId: requesterId),
                          ),
                  child: const Text("อัปเดตยอดคงเหลือ"),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runAction(
                            () => widget.api.appendTest(requesterId: requesterId),
                          ),
                  child: const Text("ทดสอบเพิ่มแถว"),
                ),
                if (_lastMessage != null) ...[
                  const SizedBox(height: 12),
                  Text("ล่าสุด: $_lastMessage"),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ลิงก์ส่งออกข้อมูล", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const Text("เปิดลิงก์เหล่านี้ในเบราว์เซอร์ที่เข้าถึง backend ได้"),
                const SizedBox(height: 12),
                _SelectableUrl(label: "สินค้า CSV", url: productExport),
                _SelectableUrl(label: "ผู้ใช้ CSV", url: userExport),
                _SelectableUrl(label: "ประวัติ CSV", url: movementExport),
                _SelectableUrl(label: "ไฟล์ Excel ทั้งหมด", url: excelExport),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ลิงก์ชั่วคราวแบบปลอดภัย", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const Text("ลิงก์ชุดนี้ซ่อน requester_id และใช้ได้ช่วงสั้น ๆ"),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _refreshExportLinks,
                    icon: const Icon(Icons.refresh),
                    label: const Text("สร้างลิงก์ใหม่"),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<Map<String, ExportLink>>(
                  future: _exportLinksFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return _EmptyTile(
                        message: snapshot.error == null
                            ? "ไม่สามารถสร้างลิงก์ชั่วคราวได้"
                            : snapshot.error.toString().replaceFirst("Exception: ", ""),
                      );
                    }

                    final links = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SelectableUrl(
                          label: "สินค้า CSV",
                          url: links["products"]!.url,
                          expiresAt: links["products"]!.expiresAt,
                        ),
                        _SelectableUrl(
                          label: "ผู้ใช้ CSV",
                          url: links["users"]!.url,
                          expiresAt: links["users"]!.expiresAt,
                        ),
                        _SelectableUrl(
                          label: "ประวัติ CSV",
                          url: links["movements"]!.url,
                          expiresAt: links["movements"]!.expiresAt,
                        ),
                        _SelectableUrl(
                          label: "ไฟล์ Excel ทั้งหมด",
                          url: links["excel"]!.url,
                          expiresAt: links["excel"]!.expiresAt,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DashboardData {
  DashboardData({
    required this.summary,
    required this.products,
    required this.notifications,
  });

  final StockSummary summary;
  final List<Product> products;
  final List<AppNotification> notifications;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.showBackButton = false,
  });

  final String title;
  final String subtitle;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brandPrimary, _brandDeep],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _brandPrimary.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackButton) ...[
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.12),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.86),
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.tone = _brandPrimary,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.95),
            _brandSurfaceStrong.withOpacity(0.80),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tone.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: tone.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _brandDeep,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

ImageProvider<Object>? _networkImageProvider(String? imageUrl) {
  if (imageUrl == null || imageUrl.trim().isEmpty) {
    return null;
  }
  return NetworkImage(imageUrl);
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.imageUrl,
    required this.name,
    this.radius = 22,
  });

  final String? imageUrl;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imageProvider = _networkImageProvider(imageUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _brandSurfaceStrong,
      backgroundImage: imageProvider,
      child: imageProvider == null ? Text(name.isEmpty ? "?" : name[0]) : null,
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    this.onOpenCode,
  });

  final Product product;
  final VoidCallback? onOpenCode;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onOpenCode,
        title: Text(product.name),
        subtitle: Text("${product.barcode} • ${product.location ?? "ไม่ระบุตำแหน่ง"}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${product.currentStock} ${product.unit}"),
                Text(
                  "min ${product.minimumStock}",
                  style: TextStyle(
                    color: product.isLowStock ? _brandPrimary : _brandTextOnLight,
                  ),
                ),
              ],
            ),
            if (onOpenCode != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onOpenCode,
                icon: const Icon(Icons.qr_code_2_outlined),
                tooltip: "ดู barcode",
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.item});

  final MovementRecord item;

  Color _tone() {
    switch (item.action) {
      case "in":
        return _brandPrimary;
      case "out":
        return const Color(0xFF0277BD);
      default:
        return const Color(0xFF0288D1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _tone().withOpacity(0.14),
          child: Icon(Icons.swap_horiz, color: _tone()),
        ),
        title: Text("${item.productName} x${item.quantity}"),
        subtitle: Text(
          "${item.actorName} (${item.actorId}) • ${item.action} • ${_formatDateTime(item.createdAt)}",
        ),
        trailing: Text("${item.beforeStock} -> ${item.afterStock}"),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.notifications_active_outlined),
        title: Text(notification.title),
        subtitle: Text(notification.message),
        trailing: Text(_formatDateTime(notification.createdAt)),
      ),
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({
    required this.result,
    this.onOpenCode,
  });

  final ScanResult result;
  final VoidCallback? onOpenCode;

  @override
  Widget build(BuildContext context) {
    final tone = result.lowStock ? _brandPrimary : const Color(0xFF0277BD);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.95),
            _brandSurfaceStrong.withOpacity(0.70),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tone.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: tone.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.productCreated
                ? "สร้างสินค้าใหม่และบันทึกรายการสำเร็จ"
                : result.lowStock
                    ? "บันทึกแล้ว: สินค้าอยู่ในระดับเตือน"
                    : "บันทึกสำเร็จ",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: tone),
          ),
          const SizedBox(height: 8),
          Text(result.product.name),
          Text("บาร์โค้ด: ${result.product.barcode}"),
          Text("คงเหลือ: ${result.product.currentStock} ${result.product.unit}"),
          Text("ผู้ทำรายการ: ${result.movement.actorName}"),
          if (onOpenCode != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenCode,
              icon: const Icon(Icons.qr_code_2_outlined),
              label: const Text("ดู barcode / QR"),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showProductCodeSheet(BuildContext context, Product product) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProductCodeSheet(product: product),
  );
}

class _ProductCodeSheet extends StatefulWidget {
  const _ProductCodeSheet({required this.product});

  final Product product;

  @override
  State<_ProductCodeSheet> createState() => _ProductCodeSheetState();
}

class _ProductCodeSheetState extends State<_ProductCodeSheet> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareLabel() async {
    try {
      setState(() {
        _isSharing = true;
      });

      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("ไม่พบภาพสำหรับส่งออก");
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        throw Exception("สร้างไฟล์ภาพไม่สำเร็จ");
      }

      final tempDir = await getTemporaryDirectory();
      final file = File("${tempDir.path}/${widget.product.barcode}-label.png");
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: "${widget.product.name} (${widget.product.barcode})",
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst("Exception: ", ""))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: _brandCard,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Barcode และ QR สินค้า",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RepaintBoundary(
                  key: _captureKey,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _brandPrimary.withOpacity(0.10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          product.name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product.barcode,
                          style: const TextStyle(
                            color: _brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: product.barcode,
                          width: 280,
                          height: 90,
                          drawText: true,
                        ),
                        const SizedBox(height: 20),
                        QrImageView(
                          data: product.barcode,
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "สแกนได้ทั้ง Barcode และ QR",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSharing ? null : _shareLabel,
                        icon: _isSharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.ios_share_outlined),
                        label: const Text("แชร์ / ส่งออกป้าย"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: product.barcode));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("คัดลอก barcode แล้ว")),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      tooltip: "คัดลอกรหัส",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectableUrl extends StatelessWidget {
  const _SelectableUrl({
    required this.label,
    required this.url,
    this.expiresAt,
  });

  final String label;
  final String url;
  final DateTime? expiresAt;

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ลิงก์ไม่ถูกต้อง")),
      );
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ไม่สามารถเปิดลิงก์ดาวน์โหลดได้")),
      );
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("คัดลอกลิงก์แล้ว")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _brandPrimary.withOpacity(0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            if (expiresAt != null) ...[
              const SizedBox(height: 4),
              Text(
                "หมดอายุ ${_formatDateTime(expiresAt!)}",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _openUrl(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  url,
                  style: const TextStyle(
                    color: _brandPrimary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openUrl(context),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text("ดาวน์โหลดเลย"),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _copyUrl(context),
                  icon: const Icon(Icons.copy_all_outlined),
                  tooltip: "คัดลอกลิงก์",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.90),
            _brandSurfaceStrong.withOpacity(0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _brandPrimary.withOpacity(0.08)),
      ),
      child: Text(message),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off, size: 48, color: Colors.red.shade400),
        const SizedBox(height: 12),
        Text(
          "เชื่อมต่อ API ไม่สำเร็จ",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message.replaceFirst("Exception: ", ""),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  final date = "${value.day.toString().padLeft(2, "0")}/"
      "${value.month.toString().padLeft(2, "0")}/"
      "${value.year}";
  final time = "${value.hour.toString().padLeft(2, "0")}:"
      "${value.minute.toString().padLeft(2, "0")}";
  return "$date $time";
}

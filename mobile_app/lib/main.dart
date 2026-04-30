import "dart:async";
import "dart:io";
import "dart:typed_data";
import "dart:ui" as ui;

import "package:barcode_widget/barcode_widget.dart";
import "package:flutter/foundation.dart";
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
const _brandLogoAsset = "assets/branding/scan_product_logo.png";
const _brandPrimary = Color(0xFF8A5A3C);
const _brandSurface = Color(0xFFE8D8C3);
const _brandSurfaceStrong = Color(0xFFB48A61);
const _brandTextOnLight = Color(0xFF3F2B1D);
const _brandDeep = Color(0xFF3F2B1D);
const _brandInk = Color(0xFF3F2B1D);
const _brandCard = Color(0xFFF3E7D8);
const _profileTeal = Color(0xFF7D6852);
const _profileAccent = Color(0xFFD1AA7C);
const double _spaceXs = 8;
const double _spaceSm = 12;
const double _spaceMd = 16;
const double _spaceLg = 20;
const double _spaceXl = 24;
const double _radiusSm = 12;
const double _radiusMd = 18;
const double _radiusLg = 24;
const double _radiusXl = 28;
const _pagePadding = EdgeInsets.all(_spaceMd);
const _cardPadding = EdgeInsets.all(_spaceMd);

class _BrandLogoIcon extends StatelessWidget {
  const _BrandLogoIcon({this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        _brandLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

BoxDecoration _softPanelDecoration({
  Color tone = _brandPrimary,
  double surfaceStrength = 0.55,
  double radius = _radiusLg,
}) {
  final tint = (surfaceStrength * 0.17).clamp(0.08, 0.20);
  final panelColor = Color.lerp(_brandSurface, tone, tint)!;
  final borderColor = Color.lerp(panelColor, tone, 0.30)!.withOpacity(0.70);
  return BoxDecoration(
    color: panelColor,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor),
    boxShadow: [
      BoxShadow(
        color: tone.withOpacity(0.06),
        blurRadius: 16,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

String _normalizeFeedbackMessage(String message) {
  final cleaned = message.replaceFirst("Exception: ", "").trim();
  if (cleaned.isEmpty) {
    return "เกิดข้อผิดพลาดบางอย่าง กรุณาลองใหม่อีกครั้ง";
  }

  final lowered = cleaned.toLowerCase();
  if (cleaned.contains("เน€") ||
      lowered.contains("server is taking longer") ||
      lowered.contains("responding more slowly") ||
      lowered.contains("timeout") ||
      lowered.contains("backend")) {
    return "เซิร์ฟเวอร์อาจกำลังเริ่มทำงานอยู่ กรุณารอสักครู่แล้วลองใหม่";
  }
  if (lowered.contains("current pin is incorrect")) {
    return "PIN ปัจจุบันไม่ถูกต้อง";
  }
  if (lowered.contains("new pin must be different")) {
    return "PIN ใหม่ต้องไม่ซ้ำกับ PIN เดิม";
  }
  if (lowered.contains("invalid user id or pin")) {
    return "User ID หรือ PIN ไม่ถูกต้อง";
  }
  if (lowered.contains("user is inactive")) {
    return "บัญชีนี้ถูกปิดการใช้งาน";
  }
  if (lowered.contains("authentication required")) {
    return "กรุณาเข้าสู่ระบบใหม่อีกครั้ง";
  }
  if (lowered.contains("backend ยังไม่รองรับฟีเจอร์แชท")) {
    return "เซิร์ฟเวอร์ยังไม่อัปเดตฟีเจอร์แชท กรุณา deploy backend เวอร์ชันล่าสุดก่อน";
  }
  if (lowered.contains("not found")) {
    return "ไม่พบปลายทางที่ต้องการบนเซิร์ฟเวอร์ อาจเป็นเพราะ backend ยังไม่อัปเดต";
  }

  return cleaned;
}

void _showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final displayMessage = _normalizeFeedbackMessage(message);
  final messenger = ScaffoldMessenger.of(context);
  final backgroundColor = isError ? _brandInk : _brandDeep;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(_spaceMd, 0, _spaceMd, _spaceMd),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

String _roleLabel(String role) {
  return role.trim().toLowerCase() == "admin" ? "ผู้ดูแลระบบ" : "พนักงาน";
}

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
        }
        return;
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
        }
        return;
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
      title: "\u0e41\u0e2d\u0e1b\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32",
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
              titleSmall: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _brandDeep,
              ),
              bodyMedium: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: _brandInk,
              ),
              bodySmall: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: _brandInk.withOpacity(0.72),
              ),
            ),
        cardTheme: CardThemeData(
          color: _brandCard,
          elevation: 0,
          shadowColor: _brandPrimary.withOpacity(0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusLg),
            side: BorderSide(color: _brandPrimary.withOpacity(0.10)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _brandDeep,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.35,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _brandCard,
          indicatorColor: Color.lerp(_brandSurface, _brandSurfaceStrong, 0.70)!.withOpacity(0.90),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected) ? _brandDeep : _brandInk,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color.lerp(_brandSurface, Colors.white, 0.58)!,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
            borderSide: BorderSide(color: _brandPrimary.withOpacity(0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
            borderSide: BorderSide(color: _brandPrimary.withOpacity(0.12)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(_radiusMd)),
            borderSide: BorderSide(color: _brandPrimary, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: _spaceMd,
            vertical: _spaceMd,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _brandPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radiusMd),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _brandPrimary,
            side: const BorderSide(color: _brandPrimary),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radiusMd),
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
  String? _userIdError;
  String? _pinError;

  void _handleUserIdChanged(String value) {
    final normalized = value.toUpperCase().replaceAll(" ", "");
    if (normalized != value) {
      _userIdController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    if (_userIdError != null) {
      setState(() {
        _userIdError = null;
      });
    }
  }

  void _handlePinChanged(String value) {
    if (_pinError != null) {
      setState(() {
        _pinError = null;
      });
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final userId = _userIdController.text.trim().toUpperCase();
    final pin = _pinController.text.trim();

    setState(() {
      _userIdError = null;
      _pinError = null;
    });

    if (userId.isEmpty) {
      setState(() {
        _userIdError = "\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01 User ID";
      });
      return;
    }
    if (pin.isEmpty) {
      setState(() {
        _pinError = "\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01 PIN";
      });
      return;
    }
    if (pin.length < 4) {
      setState(() {
        _pinError = "PIN \u0e15\u0e49\u0e2d\u0e07\u0e21\u0e35\u0e2d\u0e22\u0e48\u0e32\u0e07\u0e19\u0e49\u0e2d\u0e22 4 \u0e2b\u0e25\u0e31\u0e01";
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final session = await widget.api.login(userId: userId, pin: pin);
      await widget.onLogin(session);
    } catch (error) {
      final message = error.toString().replaceFirst("Exception: ", "");
      if (message.contains("Invalid user id or PIN")) {
        setState(() {
          _userIdError =
              "\u0e44\u0e21\u0e48\u0e1e\u0e1a User ID \u0e19\u0e35\u0e49 \u0e2b\u0e23\u0e37\u0e2d PIN \u0e44\u0e21\u0e48\u0e16\u0e39\u0e01\u0e15\u0e49\u0e2d\u0e07";
          _pinError =
              "\u0e15\u0e23\u0e27\u0e08\u0e2a\u0e2d\u0e1a PIN \u0e41\u0e25\u0e49\u0e27\u0e25\u0e2d\u0e07\u0e2d\u0e35\u0e01\u0e04\u0e23\u0e31\u0e49\u0e07";
        });
      } else if (message.contains("inactive")) {
        setState(() {
          _userIdError =
              "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e19\u0e35\u0e49\u0e16\u0e39\u0e01\u0e1b\u0e34\u0e14\u0e01\u0e32\u0e23\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19";
        });
      } else {
        _showSnack(message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    _showAppSnack(context, message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final keyboardBottom = viewInsets.bottom;

    if (false) return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + safeBottom + keyboardBottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("เน€เธโฌเน€เธยเน€เธยเน€เธเธ’เน€เธเธเน€เธเธเน€เธยเน€เธเธเน€เธเธเน€เธยเน€เธย", style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            const Text("เน€เธโฌเน€เธยเน€เธยเน€เธเธ’เน€เธเธเน€เธเธเน€เธยเน€เธเธเน€เธเธเน€เธยเน€เธยเน€เธโ€เน€เธยเน€เธเธเน€เธเธเน€เธเธเน€เธเธเน€เธเธ‘เน€เธเธเน€เธยเน€เธเธเน€เธยเน€เธยเน€เธยเน€เธยเน€เธยเน€เธเธ…เน€เธเธ PIN"),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _userIdController,
                              decoration: const InputDecoration(
                                labelText: "เน€เธเธเน€เธเธเน€เธเธ‘เน€เธเธเน€เธยเน€เธเธเน€เธยเน€เธยเน€เธยเน€เธย",
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
                              label: const Text("เน€เธโฌเน€เธยเน€เธยเน€เธเธ’เน€เธเธเน€เธเธเน€เธยเน€เธเธเน€เธเธเน€เธยเน€เธย"),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "เน€เธโ€ขเน€เธเธ‘เน€เธเธเน€เธเธเน€เธเธเน€เธยเน€เธเธ’เน€เธยเน€เธโ€”เน€เธโ€เน€เธเธเน€เธเธเน€เธย: EMP001 / 1234",
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
          },
        ),
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + safeBottom),
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + safeBottom),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("\u0e40\u0e02\u0e49\u0e32\u0e2a\u0e39\u0e48\u0e23\u0e30\u0e1a\u0e1a", style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text("\u0e40\u0e02\u0e49\u0e32\u0e2a\u0e39\u0e48\u0e23\u0e30\u0e1a\u0e1a\u0e14\u0e49\u0e27\u0e22\u0e23\u0e2b\u0e31\u0e2a\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e41\u0e25\u0e30 PIN"),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _userIdController,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: _handleUserIdChanged,
                      decoration: InputDecoration(
                        labelText: "User ID",
                        hintText: "EMP001",
                        helperText: _userIdError == null
                            ? "ใช้ตัวอักษรและตัวเลข เช่น EMP001"
                            : null,
                        errorText: _userIdError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      onChanged: _handlePinChanged,
                      decoration: InputDecoration(
                        labelText: "PIN",
                        errorText: _pinError,
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
                      label: Text(
                        _isLoading
                            ? "\u0e01\u0e33\u0e25\u0e31\u0e07\u0e40\u0e02\u0e49\u0e32\u0e2a\u0e39\u0e48\u0e23\u0e30\u0e1a\u0e1a..."
                            : "\u0e40\u0e02\u0e49\u0e32\u0e2a\u0e39\u0e48\u0e23\u0e30\u0e1a\u0e1a",
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "\u0e15\u0e31\u0e27\u0e2d\u0e22\u0e48\u0e32\u0e07\u0e17\u0e14\u0e2a\u0e2d\u0e1a: EMP001 / 1234",
                      style: TextStyle(color: _brandPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "\u0e16\u0e49\u0e32\u0e40\u0e0a\u0e34\u0e23\u0e4c\u0e1f\u0e40\u0e27\u0e2d\u0e23\u0e4c\u0e40\u0e1e\u0e34\u0e48\u0e07\u0e15\u0e37\u0e48\u0e19 \u0e04\u0e23\u0e31\u0e49\u0e07\u0e41\u0e23\u0e01\u0e2d\u0e32\u0e08\u0e43\u0e0a\u0e49\u0e40\u0e27\u0e25\u0e32 10-20 \u0e27\u0e34\u0e19\u0e32\u0e17\u0e35",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                      ),
                    ),
                  ),
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
  final ValueNotifier<int> _realtimeRevision = ValueNotifier<int>(0);
  WebSocket? _realtimeSocket;
  Timer? _realtimeReconnectTimer;
  bool _realtimeShouldReconnect = true;

  @override
  void initState() {
    super.initState();
    _connectRealtime();
  }

  @override
  void dispose() {
    _realtimeShouldReconnect = false;
    _realtimeReconnectTimer?.cancel();
    _realtimeSocket?.close();
    _realtimeRevision.dispose();
    super.dispose();
  }

  Future<void> _connectRealtime() async {
    final token = widget.api.accessToken;
    if (!_realtimeShouldReconnect || token == null || token.isEmpty) {
      return;
    }

    try {
      final socket = await WebSocket.connect(
        widget.api
            .websocketUri("/ws/realtime", {"token": token})
            .toString(),
      );
      if (!mounted || !_realtimeShouldReconnect) {
        await socket.close();
        return;
      }

      _realtimeSocket = socket;
      socket.listen(
        (dynamic _) {
          if (!mounted) {
            return;
          }
          _realtimeRevision.value = _realtimeRevision.value + 1;
        },
        onDone: _scheduleRealtimeReconnect,
        onError: (_, __) => _scheduleRealtimeReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRealtimeReconnect();
    }
  }

  void _scheduleRealtimeReconnect() {
    _realtimeSocket = null;
    if (!_realtimeShouldReconnect || !mounted) {
      return;
    }
    _realtimeReconnectTimer?.cancel();
    _realtimeReconnectTimer = Timer(
      const Duration(seconds: 3),
      _connectRealtime,
    );
  }

  Future<void> _openMorePage(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MorePage(
          api: widget.api,
          currentUser: widget.currentUser,
          onLogout: widget.onLogout,
          onRefreshSession: widget.onRefreshSession,
          refreshSignal: _realtimeRevision,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(
        api: widget.api,
        refreshSignal: _realtimeRevision,
        currentUser: widget.currentUser,
      ),
      ScanPage(api: widget.api, currentUser: widget.currentUser),
      HistoryPage(api: widget.api, refreshSignal: _realtimeRevision),
      ChatAssistantPage(
        api: widget.api,
        refreshSignal: _realtimeRevision,
      ),
    ];

    return Scaffold(
      extendBody: false,
      body: Stack(
        children: [
          SafeArea(
            child: pages[_currentIndex],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: IconButton.filledTonal(
                  onPressed: () => _openMorePage(context),
                  icon: const _BrandLogoIcon(size: 24),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.92),
                    foregroundColor: _brandDeep,
                    side: BorderSide(color: _brandPrimary.withOpacity(0.12)),
                  ),
                  tooltip: "\u0e40\u0e1e\u0e34\u0e48\u0e21\u0e40\u0e15\u0e34\u0e21",
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _brandPrimary.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: _brandPrimary.withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: NavigationBar(
            height: 58,
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
                label: "\u0e20\u0e32\u0e1e\u0e23\u0e27\u0e21",
              ),
              NavigationDestination(
                icon: Icon(Icons.qr_code_scanner_outlined),
                selectedIcon: Icon(Icons.qr_code_scanner),
                label: "\u0e2a\u0e41\u0e01\u0e19",
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: "\u0e1b\u0e23\u0e30\u0e27\u0e31\u0e15\u0e34",
              ),
              NavigationDestination(
                icon: Icon(Icons.smart_toy_outlined),
                selectedIcon: Icon(Icons.smart_toy),
                label: "\u0e1c\u0e39\u0e49\u0e0a\u0e48\u0e27\u0e22",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatAssistantPage extends StatefulWidget {
  const ChatAssistantPage({
    super.key,
    required this.api,
    required this.refreshSignal,
  });

  final StockApiService api;
  final ValueListenable<int> refreshSignal;

  @override
  State<ChatAssistantPage> createState() => _ChatAssistantPageState();
}

class _ChatAssistantPageState extends State<ChatAssistantPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<_ChatMessage> _messages;
  bool _isSending = false;
  bool? _assistantAvailable;

  @override
  void initState() {
    super.initState();
    _messages = [
      _ChatMessage.bot(
        "ถามข้อมูลสต๊อก, ให้ AI ช่วยตอบ, หรือสั่งงานได้เลย เช่น \"โค้กเหลือกี่ชิ้น\", \"อะไรใกล้หมดบ้าง\", \"เบิก 2 8851234567890\"",
      ),
    ];
    widget.refreshSignal.addListener(_handleRealtimeRefresh);
    _checkAssistantAvailability();
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_handleRealtimeRefresh);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleRealtimeRefresh() {
    if (!mounted) {
      return;
    }
    setState(() {
      _messages = [
        ..._messages,
        _ChatMessage.bot("ข้อมูลสต๊อกมีการอัปเดตแล้ว ถามใหม่ได้เลยเพื่อดูตัวเลขล่าสุด"),
      ];
    });
    _scrollToBottom();
  }

  Future<void> _checkAssistantAvailability() async {
    final available = await widget.api.isAssistantAvailable();
    if (!mounted) {
      return;
    }
    setState(() {
      _assistantAvailable = available;
      if (!available) {
        _messages = [
          _messages.first,
          _ChatMessage.bot(
            "เซิร์ฟเวอร์ที่เชื่อมต่ออยู่ยังไม่รองรับฟีเจอร์แชท กรุณาอัปเดต backend แล้วลองใหม่",
          ),
        ];
      }
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    final pendingAction = _detectPendingChatAction(text);
    if (pendingAction != null) {
      final confirmed = await _confirmChatAction(pendingAction);
      if (confirmed != true) {
        return;
      }
    }

    FocusScope.of(context).unfocus();
    _messageController.clear();
    setState(() {
      _isSending = true;
      _messages = [
        ..._messages,
        _ChatMessage.user(text),
      ];
    });
    _scrollToBottom();

    try {
      final reply = await widget.api.askAssistant(message: text);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [
          ..._messages,
          _ChatMessage.bot(
            reply.message,
            products: reply.matchedProducts,
            usedAi: reply.usedAi,
            action: reply.action,
            downloadLink: reply.downloadLink,
          ),
        ];
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = [
          ..._messages,
          _ChatMessage.bot(
            "ยังดึงข้อมูลสต๊อกไม่ได้: ${_normalizeFeedbackMessage(error.toString())}",
          ),
        ];
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<bool?> _confirmChatAction(_PendingChatAction action) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("ยืนยันคำสั่งสต๊อก"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(action.summary),
              const SizedBox(height: 8),
              Text(
                "คำสั่งนี้จะบันทึกลงสต๊อกจริงทันที",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("ยกเลิก"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("ยืนยัน"),
            ),
          ],
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      "อะไรใกล้หมดบ้าง",
      "สินค้าทั้งหมดมีกี่รายการ",
      "มีน้ำดื่มเหลือเท่าไหร่",
      "เบิก 1 8850001110012",
      "ขั้นต่ำของน้ำดื่มเท่าไหร่",
      "ขอไฟล์ Excel",
      "ขอไฟล์ CSV สินค้า",
      "ขอไฟล์ CSV ประวัติ",
    ];

    return ColoredBox(
      color: _brandSurface,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _PageHeader(
                title: "\u0e41\u0e0a\u0e17\u0e1c\u0e39\u0e49\u0e0a\u0e48\u0e27\u0e22\u0e2a\u0e15\u0e4a\u0e2d\u0e01",
                subtitle: "\u0e16\u0e32\u0e21\u0e08\u0e33\u0e19\u0e27\u0e19\u0e04\u0e07\u0e40\u0e2b\u0e25\u0e37\u0e2d \u0e14\u0e39\u0e02\u0e2d\u0e07\u0e43\u0e01\u0e25\u0e49\u0e2b\u0e21\u0e14 \u0e2b\u0e23\u0e37\u0e2d\u0e2a\u0e31\u0e48\u0e07\u0e40\u0e1e\u0e34\u0e48\u0e21-\u0e15\u0e31\u0e14\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e41\u0e0a\u0e17\u0e44\u0e14\u0e49\u0e40\u0e25\u0e22",
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ActionChip(
                      label: Text(suggestion),
                      onPressed: _isSending ? null : () => _sendMessage(suggestion),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _ChatBubble(
                    message: message,
                    onOpenProduct: (product) => _showProductCodeSheet(context, product),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 3,
                      enabled: _assistantAvailable != false,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: "\u0e1e\u0e34\u0e21\u0e1e\u0e4c\u0e04\u0e33\u0e16\u0e32\u0e21\u0e40\u0e01\u0e35\u0e48\u0e22\u0e27\u0e01\u0e31\u0e1a\u0e2a\u0e15\u0e4a\u0e2d\u0e01...",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _isSending || _assistantAvailable == false ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
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
  late AppUser _profileUser;
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _profileImageUrlController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _role = "staff";
  bool _active = true;
  bool _isSaving = false;
  bool _isChangingPin = false;
  bool _isUploadingProfileImage = false;
  bool _isEditingDisplayName = false;
  bool _isUpdatingDisplayName = false;
  bool _obscureCurrentPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  String? _displayNameError;

  @override
  void initState() {
    super.initState();
    _profileUser = widget.currentUser;
    _displayNameController.text = _profileUser.userName;
    _usersFuture = widget.api.getUsers(activeOnly: false);
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.userId != widget.currentUser.userId ||
        oldWidget.currentUser.userName != widget.currentUser.userName ||
        oldWidget.currentUser.profileImageUrl != widget.currentUser.profileImageUrl ||
        oldWidget.currentUser.role != widget.currentUser.role ||
        oldWidget.currentUser.active != widget.currentUser.active) {
      _profileUser = widget.currentUser;
      if (!_isEditingDisplayName) {
        _displayNameController.text = _profileUser.userName;
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _userIdController.dispose();
    _userNameController.dispose();
    _pinController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    _profileImageUrlController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _usersFuture = widget.api.getUsers(activeOnly: false);
    });
    await _usersFuture;
    final refreshedUser = await widget.api.getCurrentUser();
    if (mounted) {
      setState(() {
        _profileUser = refreshedUser;
      });
    }
    await widget.onRefreshSession();
  }

  void _startDisplayNameEditing() {
    setState(() {
      _isEditingDisplayName = true;
      _displayNameError = null;
      _displayNameController.text = _profileUser.userName;
      _displayNameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _displayNameController.text.length,
      );
    });
  }

  void _cancelDisplayNameEditing() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isEditingDisplayName = false;
      _displayNameError = null;
      _displayNameController.text = _profileUser.userName;
    });
  }

  Future<void> _saveDisplayName() async {
    FocusScope.of(context).unfocus();
    final userName = _displayNameController.text.trim();

    if (userName.isEmpty) {
      setState(() {
        _displayNameError = "กรุณากรอกชื่อที่แสดง";
      });
      return;
    }

    if (userName == _profileUser.userName) {
      _cancelDisplayNameEditing();
      return;
    }

    setState(() {
      _isUpdatingDisplayName = true;
      _displayNameError = null;
    });

    try {
      final updatedUser = await widget.api.updateMyProfile(userName: userName);
      if (!mounted) {
        return;
      }
      setState(() {
        _profileUser = updatedUser;
        _isEditingDisplayName = false;
        _displayNameController.text = updatedUser.userName;
      });
      await widget.onRefreshSession();
      if (mounted) {
        _showSnack("บันทึกชื่อเรียบร้อย");
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _displayNameError = _normalizeFeedbackMessage(
            error.toString().replaceFirst("Exception: ", ""),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDisplayName = false;
        });
      }
    }
  }

  Future<void> _changePin() async {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (currentPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
      _showSnack("กรุณากรอก PIN ให้ครบทุกช่อง");
      return;
    }
    if (newPin.length < 4) {
      _showSnack("PIN ใหม่ต้องมีอย่างน้อย 4 หลัก");
      return;
    }
    if (newPin != confirmPin) {
      _showSnack("PIN ใหม่และการยืนยัน PIN ไม่ตรงกัน");
      return;
    }

    setState(() {
      _isChangingPin = true;
    });

    try {
      final message = await widget.api.changePin(
        currentPin: currentPin,
        newPin: newPin,
      );
      _currentPinController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
      _showSnack(message);
    } catch (error) {
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPin = false;
        });
      }
    }
  }

  Future<void> _saveUser() async {
    final userId = _userIdController.text.trim();
    final userName = _userNameController.text.trim();
    if (userId.isEmpty || userName.isEmpty) {
      _showSnack("\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01\u0e23\u0e2b\u0e31\u0e2a\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e41\u0e25\u0e30\u0e0a\u0e37\u0e48\u0e2d\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e43\u0e2b\u0e49\u0e04\u0e23\u0e1a");
      return;
    }
    if (_pinController.text.trim().length < 4) {
      _showSnack("PIN \u0e15\u0e49\u0e2d\u0e07\u0e21\u0e35\u0e2d\u0e22\u0e48\u0e32\u0e07\u0e19\u0e49\u0e2d\u0e22 4 \u0e2b\u0e25\u0e31\u0e01");
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
      _showSnack("\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e40\u0e23\u0e35\u0e22\u0e1a\u0e23\u0e49\u0e2d\u0e22");
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
    if (user.userId == widget.currentUser.userId) {
      _showSnack("\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2d\u0e22\u0e39\u0e48\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e1b\u0e34\u0e14\u0e44\u0e14\u0e49");
      return;
    }
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

  Future<void> _deleteUser(AppUser user) async {
    if (user.userId == widget.currentUser.userId) {
      _showSnack("\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e25\u0e1a\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2d\u0e22\u0e39\u0e48\u0e44\u0e14\u0e49");
      return;
    }

    bool deleteMovements = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("\u0e25\u0e1a\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19 ${user.userName}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("\u0e15\u0e49\u0e2d\u0e07\u0e01\u0e32\u0e23\u0e25\u0e1a\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e02\u0e2d\u0e07 ${user.userId} \u0e2d\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e23\u0e30\u0e1a\u0e1a\u0e2b\u0e23\u0e37\u0e2d\u0e44\u0e21\u0e48"),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: deleteMovements,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text("\u0e25\u0e1a\u0e1b\u0e23\u0e30\u0e27\u0e31\u0e15\u0e34\u0e01\u0e32\u0e23\u0e17\u0e33\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e02\u0e2d\u0e07\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19\u0e04\u0e19\u0e19\u0e35\u0e49\u0e14\u0e49\u0e27\u0e22"),
                    subtitle: const Text("\u0e40\u0e2b\u0e21\u0e32\u0e30\u0e2a\u0e33\u0e2b\u0e23\u0e31\u0e1a\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19\u0e40\u0e01\u0e48\u0e32\u0e17\u0e35\u0e48\u0e44\u0e21\u0e48\u0e15\u0e49\u0e2d\u0e07\u0e40\u0e01\u0e47\u0e1a\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e22\u0e49\u0e2d\u0e19\u0e2b\u0e25\u0e31\u0e07"),
                    onChanged: (value) {
                      setDialogState(() {
                        deleteMovements = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text("\u0e22\u0e01\u0e40\u0e25\u0e34\u0e01"),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text("\u0e25\u0e1a\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25"),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final message = await widget.api.deleteUser(
        requesterId: widget.currentUser.userId,
        userId: user.userId,
        deleteMovements: deleteMovements,
      );
      await _reload();
      _showSnack(message);
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
      _showSnack("\u0e2d\u0e31\u0e1b\u0e42\u0e2b\u0e25\u0e14\u0e23\u0e39\u0e1b\u0e42\u0e1b\u0e23\u0e44\u0e1f\u0e25\u0e4c\u0e40\u0e23\u0e35\u0e22\u0e1a\u0e23\u0e49\u0e2d\u0e22");
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
    _showAppSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: _brandSurface,
        child: RefreshIndicator(
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
              final displayRole = _roleLabel(_profileUser.role);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
              _PageHeader(
                title: _profileUser.isAdmin ? "\u0e42\u0e1b\u0e23\u0e44\u0e1f\u0e25\u0e4c\u0e41\u0e25\u0e30\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49" : "\u0e42\u0e1b\u0e23\u0e44\u0e1f\u0e25\u0e4c",
                subtitle: _profileUser.isAdmin
                    ? "\u0e14\u0e39\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e02\u0e2d\u0e07\u0e04\u0e38\u0e13\u0e41\u0e25\u0e30\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e44\u0e14\u0e49"
                    : "\u0e14\u0e39\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e02\u0e2d\u0e07\u0e04\u0e38\u0e13\u0e41\u0e25\u0e30\u0e2d\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e23\u0e30\u0e1a\u0e1a",
                showBackButton: true,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Color.lerp(_brandSurface, _profileAccent, 0.18)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(_radiusXl),
                  border: Border.all(color: _profileTeal.withOpacity(0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: _profileTeal.withOpacity(0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: _profileAccent.withOpacity(0.10),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 170,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _profileTeal.withOpacity(0.92),
                                _brandPrimary.withOpacity(0.88),
                                _profileTeal.withOpacity(0.96),
                              ],
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(_radiusXl),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 28,
                          right: 28,
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.34),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(999),
                                bottomRight: Radius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 18,
                          right: 22,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 38,
                          left: 26,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: _brandPrimary.withOpacity(0.42),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 98,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _profileAccent.withOpacity(0.95),
                                        _profileAccent.withOpacity(0.72),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 168),
                              Expanded(
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _profileAccent.withOpacity(0.72),
                                        _profileAccent.withOpacity(0.95),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: -66,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _brandPrimary,
                                  _profileAccent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _profileTeal.withOpacity(0.18),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: _profileTeal.withOpacity(0.08)),
                              ),
                              child: _UserAvatar(
                                imageUrl: widget.api.resolveAssetUrl(
                                  _profileUser.profileImageUrl,
                                ),
                                name: _profileUser.userName,
                                radius: 58,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 78, 20, 24),
                      child: Column(
                        children: [
                          Text(
                            _profileUser.userName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: _brandDeep,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  _brandPrimary,
                                  _profileAccent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: _brandPrimary.withOpacity(0.22),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Text(
                              displayRole,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: _brandDeep,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            color: _profileTeal.withOpacity(0.08),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: _profileAccent.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: _brandPrimary.withOpacity(0.28),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: _profileAccent.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isUpdatingDisplayName
                          ? null
                          : (_isEditingDisplayName
                              ? _cancelDisplayNameEditing
                              : _startDisplayNameEditing),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _brandDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: _brandPrimary.withOpacity(0.44)),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_radiusMd),
                        ),
                        shadowColor: _brandPrimary.withOpacity(0.10),
                      ),
                      icon: Icon(
                        _isEditingDisplayName
                            ? Icons.close_rounded
                            : Icons.edit_outlined,
                      ),
                      label: Text(
                        _isEditingDisplayName
                            ? "\u0e22\u0e01\u0e40\u0e25\u0e34\u0e01"
                            : "\u0e41\u0e01\u0e49\u0e44\u0e02\u0e0a\u0e37\u0e48\u0e2d",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isUploadingProfileImage
                          ? null
                          : () => _pickAndUploadProfileImage(_profileUser),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _brandDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: _profileTeal.withOpacity(0.36)),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_radiusMd),
                        ),
                        shadowColor: _profileTeal.withOpacity(0.10),
                      ),
                      icon: _isUploadingProfileImage
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_a_photo_outlined),
                      label: const Text("\u0e40\u0e1b\u0e25\u0e35\u0e48\u0e22\u0e19\u0e23\u0e39\u0e1b"),
                    ),
                  ),
                ],
              ),
              if (_isEditingDisplayName) ...[
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_radiusLg),
                      border: Border.all(color: _brandPrimary.withOpacity(0.16)),
                      boxShadow: [
                        BoxShadow(
                          color: _profileTeal.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "\u0e41\u0e01\u0e49\u0e44\u0e02\u0e0a\u0e37\u0e48\u0e2d\u0e17\u0e35\u0e48\u0e41\u0e2a\u0e14\u0e07",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: _brandDeep,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _displayNameController,
                          enabled: !_isUpdatingDisplayName,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _saveDisplayName(),
                          decoration: InputDecoration(
                            labelText: "\u0e0a\u0e37\u0e48\u0e2d\u0e17\u0e35\u0e48\u0e41\u0e2a\u0e14\u0e07",
                            errorText: _displayNameError,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isUpdatingDisplayName ? null : _saveDisplayName,
                            child: _isUpdatingDisplayName
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text("\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e0a\u0e37\u0e48\u0e2d"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: widget.onLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brandDeep,
                  backgroundColor: _brandSurface,
                  side: BorderSide(color: _brandPrimary.withOpacity(0.34)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radiusMd),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text("\u0e2d\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e23\u0e30\u0e1a\u0e1a"),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Color.lerp(_brandSurface, _profileAccent, 0.24)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(_radiusXl),
                  border: Border.all(color: _profileTeal.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: _profileTeal.withOpacity(0.08),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Color.lerp(_brandSurface, _brandSurfaceStrong, 0.14)!,
                          labelStyle: TextStyle(
                            color: _profileTeal.withOpacity(0.78),
                            fontWeight: FontWeight.w700,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_radiusMd),
                            borderSide: BorderSide(color: _profileTeal.withOpacity(0.12)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_radiusMd),
                            borderSide: BorderSide(color: _profileTeal.withOpacity(0.12)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_radiusMd),
                            borderSide: const BorderSide(color: _profileTeal, width: 1.4),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    _brandPrimary,
                                    _profileAccent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: _brandDeep,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "\u0e40\u0e1b\u0e25\u0e35\u0e48\u0e22\u0e19 PIN",
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: _brandDeep,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "\u0e2d\u0e31\u0e1b\u0e40\u0e14\u0e15 PIN \u0e02\u0e2d\u0e07\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e43\u0e2b\u0e49\u0e1b\u0e25\u0e2d\u0e14\u0e20\u0e31\u0e22\u0e02\u0e36\u0e49\u0e19",
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: _brandInk.withOpacity(0.72),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 1,
                          color: _profileTeal.withOpacity(0.08),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          "\u0e43\u0e0a\u0e49 PIN \u0e1b\u0e31\u0e08\u0e08\u0e38\u0e1a\u0e31\u0e19\u0e40\u0e1e\u0e37\u0e48\u0e2d\u0e22\u0e37\u0e19\u0e22\u0e31\u0e19 \u0e41\u0e25\u0e49\u0e27\u0e15\u0e31\u0e49\u0e07 PIN \u0e43\u0e2b\u0e21\u0e48\u0e2d\u0e22\u0e48\u0e32\u0e07\u0e19\u0e49\u0e2d\u0e22 4 \u0e2b\u0e25\u0e31\u0e01",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _brandInk.withOpacity(0.70),
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _currentPinController,
                          keyboardType: TextInputType.number,
                          obscureText: _obscureCurrentPin,
                          decoration: InputDecoration(
                            labelText: "PIN \u0e1b\u0e31\u0e08\u0e08\u0e38\u0e1a\u0e31\u0e19",
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureCurrentPin = !_obscureCurrentPin;
                                });
                              },
                              icon: Icon(
                                _obscureCurrentPin
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPinController,
                          keyboardType: TextInputType.number,
                          obscureText: _obscureNewPin,
                          decoration: InputDecoration(
                            labelText: "PIN \u0e43\u0e2b\u0e21\u0e48",
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureNewPin = !_obscureNewPin;
                                });
                              },
                              icon: Icon(
                                _obscureNewPin
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPinController,
                          keyboardType: TextInputType.number,
                          obscureText: _obscureConfirmPin,
                          decoration: InputDecoration(
                            labelText: "\u0e22\u0e37\u0e19\u0e22\u0e31\u0e19 PIN \u0e43\u0e2b\u0e21\u0e48",
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPin = !_obscureConfirmPin;
                                });
                              },
                              icon: Icon(
                                _obscureConfirmPin
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isChangingPin ? null : _changePin,
                          style: FilledButton.styleFrom(
                            backgroundColor: _brandDeep,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_radiusMd),
                            ),
                            elevation: 0,
                            shadowColor: _profileTeal.withOpacity(0.18),
                          ),
                          icon: _isChangingPin
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.lock_reset_outlined),
                          label: Text(
                            _isChangingPin
                                ? "\u0e01\u0e33\u0e25\u0e31\u0e07\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01..."
                                : "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01 PIN \u0e43\u0e2b\u0e21\u0e48",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ),
              if (!widget.currentUser.isAdmin) ...[
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e19\u0e35\u0e49\u0e44\u0e21\u0e48\u0e21\u0e35\u0e2a\u0e34\u0e17\u0e18\u0e34\u0e4c\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49"),
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
                        Text("\u0e40\u0e1e\u0e34\u0e48\u0e21\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19", style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _userIdController,
                          decoration: const InputDecoration(
                            labelText: "\u0e23\u0e2b\u0e31\u0e2a\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _userNameController,
                          decoration: const InputDecoration(
                            labelText: "\u0e0a\u0e37\u0e48\u0e2d\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49",
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
                            labelText: "\u0e2a\u0e34\u0e17\u0e18\u0e34\u0e4c",
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: "staff", child: Text("\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19")),
                            DropdownMenuItem(value: "admin", child: Text("\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25")),
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
                          title: const Text("\u0e40\u0e1b\u0e34\u0e14\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19"),
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
                          label: const Text("\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19"),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text("\u0e23\u0e32\u0e22\u0e0a\u0e37\u0e48\u0e2d\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_radiusMd),
                    border: Border.all(color: _brandPrimary.withOpacity(0.16)),
                    boxShadow: [
                      BoxShadow(
                        color: _brandPrimary.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _brandSurfaceStrong.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _brandPrimary.withOpacity(0.10)),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: _brandPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "\u0e2b\u0e21\u0e32\u0e22\u0e40\u0e2b\u0e15\u0e38",
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: _brandDeep,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2d\u0e22\u0e39\u0e48\u0e08\u0e30\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e1b\u0e34\u0e14\u0e2b\u0e23\u0e37\u0e2d\u0e25\u0e1a\u0e44\u0e14\u0e49",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _brandInk,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (users.isEmpty)
                  const _EmptyTile(message: "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e43\u0e19\u0e23\u0e30\u0e1a\u0e1a")
                else
                  ...users.map(
                    (user) {
                      final isCurrentUser = user.userId == widget.currentUser.userId;
                      final isAdmin = user.role.trim().toLowerCase() == "admin";
                      final badgeColor = isAdmin ? _brandDeep : _brandInk;
                      final badgeBackground = isAdmin
                          ? _brandPrimary.withOpacity(0.24)
                          : _brandSurfaceStrong.withOpacity(0.26);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                          child: Row(
                            children: [
                              _UserAvatar(
                                imageUrl: widget.api.resolveAssetUrl(user.profileImageUrl),
                                name: user.userName,
                                radius: 24,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            user.userName,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontSize: 17,
                                                ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: badgeBackground,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            isAdmin ? "ADMIN" : "STAFF",
                                            style: TextStyle(
                                              color: badgeColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      user.userId,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: _brandInk.withOpacity(0.72),
                                          ),
                                    ),
                                    if (isCurrentUser) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _brandSurfaceStrong.withOpacity(0.26),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          "\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19",
                                          style: TextStyle(
                                            color: _brandPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  PopupMenuButton<String>(
                                    tooltip: "\u0e15\u0e31\u0e27\u0e40\u0e25\u0e37\u0e2d\u0e01",
                                    onSelected: (value) {
                                      if (value == "upload") {
                                        _pickAndUploadProfileImage(user);
                                      } else if (value == "delete") {
                                        _deleteUser(user);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem<String>(
                                        value: "upload",
                                        child: ListTile(
                                          leading: Icon(Icons.add_photo_alternate_outlined),
                                          title: Text("\u0e2d\u0e31\u0e1b\u0e42\u0e2b\u0e25\u0e14\u0e23\u0e39\u0e1b"),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      if (!isCurrentUser)
                                        const PopupMenuItem<String>(
                                          value: "delete",
                                          child: ListTile(
                                            leading: Icon(Icons.delete_outline),
                                            title: Text("\u0e25\u0e1a\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19"),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                    ],
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.78),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.more_horiz_rounded, color: _brandInk),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isCurrentUser)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Tooltip(
                                            message: "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e25\u0e1a\u0e2b\u0e23\u0e37\u0e2d\u0e1b\u0e34\u0e14\u0e44\u0e21\u0e48\u0e44\u0e14\u0e49",
                                            child: Icon(Icons.lock_outline, size: 18, color: _brandInk),
                                          ),
                                        ),
                                      Transform.scale(
                                        scale: 0.92,
                                        child: Switch.adaptive(
                                          value: user.active,
                                          onChanged: isCurrentUser ? null : (_) => _toggleUser(user),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.api,
    required this.refreshSignal,
    required this.currentUser,
  });

  final StockApiService api;
  final ValueListenable<int> refreshSignal;
  final AppUser currentUser;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.refreshSignal.addListener(_handleRealtimeRefresh);
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_handleRealtimeRefresh);
    super.dispose();
  }

  void _handleRealtimeRefresh() {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = _load();
    });
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
          return ColoredBox(
            color: _brandSurface,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _PageHeader(
                  title: "\u0e20\u0e32\u0e1e\u0e23\u0e27\u0e21\u0e2a\u0e15\u0e4a\u0e2d\u0e01",
                  subtitle: "\u0e20\u0e32\u0e1e\u0e23\u0e27\u0e21\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e41\u0e25\u0e30\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e17\u0e35\u0e48\u0e15\u0e49\u0e2d\u0e07\u0e14\u0e39\u0e41\u0e25",
                ),
                const SizedBox(height: 16),
                _DashboardIdentityCard(
                  imageUrl: widget.api.resolveAssetUrl(widget.currentUser.profileImageUrl),
                  name: widget.currentUser.userName,
                  roleLabel: _roleLabel(widget.currentUser.role),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: "\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32",
                        value: "${data.summary.totalProducts}",
                        icon: Icons.inventory_2_outlined,
                        tone: _profileTeal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        title: "\u0e08\u0e33\u0e19\u0e27\u0e19\u0e23\u0e27\u0e21",
                        value: "${data.summary.totalUnits}",
                        icon: Icons.layers_outlined,
                        tone: _profileAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        title: "\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e15\u0e48\u0e33",
                        value: "${data.summary.lowStockCount}",
                        icon: Icons.warning_amber_outlined,
                        tone: _brandPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text("\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e15\u0e48\u0e33", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (data.summary.lowStockItems.isEmpty)
                  const _EmptyTile(message: "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e17\u0e35\u0e48\u0e15\u0e48\u0e33\u0e01\u0e27\u0e48\u0e32\u0e08\u0e38\u0e14\u0e40\u0e15\u0e37\u0e2d\u0e19")
                else
                  ...data.summary.lowStockItems.map(
                    (item) => _ProductTile(
                      product: item,
                      onOpenCode: () => _showProductCodeSheet(context, item),
                    ),
                  ),
                const SizedBox(height: 20),
                Text("\u0e41\u0e08\u0e49\u0e07\u0e40\u0e15\u0e37\u0e2d\u0e19\u0e25\u0e48\u0e32\u0e2a\u0e38\u0e14", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (data.notifications.isEmpty)
                  const _EmptyTile(message: "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e41\u0e08\u0e49\u0e07\u0e40\u0e15\u0e37\u0e2d\u0e19")
                else
                  ...data.notifications.map(
                    (item) => _NotificationTile(notification: item),
                  ),
              ],
            ),
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
  static const MethodChannel _scanSoundChannel = MethodChannel("stock_scanner/sound");
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
  bool _isSkuManuallyEdited = false;
  ScanResult? _lastResult;
  String? _lastAutoGeneratedSku;

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
    _showAppSnack(context, message);
  }

  Future<void> _playNativeScanBeep() async {
    try {
      await _scanSoundChannel.invokeMethod<void>("playScanBeep");
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _playScanHaptic() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      await HapticFeedback.selectionClick();
    }
  }

  void _playScanFeedback() {
    unawaited(_playScanHaptic());
    if (kIsWeb) {
      unawaited(SystemSound.play(SystemSoundType.click));
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_playNativeScanBeep());
      return;
    }
    unawaited(SystemSound.play(SystemSoundType.click));
  }

  String _trimSkuSegment(String value, int maxLength) {
    final cleaned = value.replaceAll(RegExp(r"[^A-Z0-9]"), "");
    if (cleaned.isEmpty) {
      return "";
    }
    return cleaned.length <= maxLength ? cleaned : cleaned.substring(0, maxLength);
  }

  String _buildAutoSku() {
    final normalizedName = _productNameController.text.trim().toUpperCase();
    final words = normalizedName
        .split(RegExp(r"[^A-Z0-9]+"))
        .where((item) => item.isNotEmpty)
        .toList();

    String namePart;
    if (words.isEmpty) {
      namePart = "ITEM";
    } else if (words.length == 1) {
      namePart = _trimSkuSegment(words.first, 6);
    } else {
      final first = _trimSkuSegment(words[0], 3);
      final second = _trimSkuSegment(words[1], 3);
      namePart = [first, second].where((item) => item.isNotEmpty).join("-");
    }

    if (namePart.isEmpty) {
      namePart = "ITEM";
    }

    final barcodePart = _trimSkuSegment(
      _barcodeController.text.trim().toUpperCase(),
      24,
    );
    final tail = barcodePart.isEmpty
        ? "AUTO"
        : (barcodePart.length <= 4
            ? barcodePart
            : barcodePart.substring(barcodePart.length - 4));

    return "$namePart-$tail";
  }

  void _syncAutoSku({bool force = false}) {
    if (!_newProductMode) {
      return;
    }

    final nextSku = _buildAutoSku();
    final currentSku = _productSkuController.text.trim();
    final shouldReplace = force ||
        currentSku.isEmpty ||
        (!_isSkuManuallyEdited && currentSku == (_lastAutoGeneratedSku ?? currentSku));

    if (!shouldReplace) {
      return;
    }

    _productSkuController.text = nextSku;
    _productSkuController.selection = TextSelection.collapsed(offset: nextSku.length);
    _lastAutoGeneratedSku = nextSku;
    _isSkuManuallyEdited = false;
  }

  InputDecoration _scanInputDecoration(
    String label, {
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.96),
      labelStyle: TextStyle(
        color: _brandInk.withOpacity(0.88),
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: _brandDeep,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: TextStyle(
        color: _brandInk.withOpacity(0.52),
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: _spaceMd,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: BorderSide(color: _brandPrimary.withOpacity(0.16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: BorderSide(color: _brandPrimary.withOpacity(0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radiusMd),
        borderSide: const BorderSide(color: _brandPrimary, width: 1.5),
      ),
    );
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
      _syncAutoSku();
      if (!silent) {
        _showSnack("\u0e2a\u0e23\u0e49\u0e32\u0e07 barcode \u0e43\u0e2b\u0e21\u0e48\u0e41\u0e25\u0e49\u0e27");
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
    final shouldCreateProduct = _newProductMode;

    if (shouldCreateProduct && _productSkuController.text.trim().isEmpty) {
      _syncAutoSku(force: true);
    }

    if (_barcodeController.text.trim().isEmpty || quantity == null || quantity <= 0) {
      _showSnack("\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01 barcode \u0e41\u0e25\u0e30\u0e08\u0e33\u0e19\u0e27\u0e19\u0e43\u0e2b\u0e49\u0e04\u0e23\u0e1a");
      return;
    }
    if (shouldCreateProduct && _productNameController.text.trim().isEmpty) {
      _showSnack("\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01\u0e0a\u0e37\u0e48\u0e2d\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e40\u0e21\u0e37\u0e48\u0e2d\u0e40\u0e1b\u0e34\u0e14\u0e42\u0e2b\u0e21\u0e14\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48");
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
        _showSnack("\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48\u0e41\u0e25\u0e30\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e40\u0e23\u0e35\u0e22\u0e1a\u0e23\u0e49\u0e2d\u0e22");
      } else if (result.lowStock) {
        _showSnack("\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e41\u0e25\u0e49\u0e27 \u0e41\u0e25\u0e30\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e19\u0e35\u0e49\u0e2d\u0e22\u0e39\u0e48\u0e43\u0e19\u0e23\u0e30\u0e14\u0e31\u0e1a\u0e40\u0e15\u0e37\u0e2d\u0e19");
      } else {
        _showSnack("\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e40\u0e23\u0e35\u0e22\u0e1a\u0e23\u0e49\u0e2d\u0e22");
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
    return ColoredBox(
      color: Color.lerp(_brandSurface, Colors.white, 0.14)!,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
        _PageHeader(
          title: "\u0e2a\u0e41\u0e01\u0e19\u0e41\u0e25\u0e30\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01",
          subtitle: "\u0e04\u0e38\u0e13\u0e43\u0e0a\u0e49\u0e44\u0e14\u0e49\u0e17\u0e31\u0e49\u0e07\u0e42\u0e2b\u0e21\u0e14\u0e2a\u0e41\u0e01\u0e19\u0e1b\u0e01\u0e15\u0e34\u0e41\u0e25\u0e30\u0e42\u0e2b\u0e21\u0e14\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48",
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text("\u0e2a\u0e41\u0e01\u0e19\u0e40\u0e02\u0e49\u0e32/\u0e2d\u0e2d\u0e01"), icon: Icon(Icons.qr_code_scanner)),
            ButtonSegment(value: true, label: Text("\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48"), icon: Icon(Icons.add_box_outlined)),
          ],
          selected: {_newProductMode},
          onSelectionChanged: (selection) {
            final wantsNewMode = selection.first;
            setState(() {
              _newProductMode = wantsNewMode;
            });
            if (wantsNewMode && _barcodeController.text.trim().isEmpty) {
              _generateBarcode(silent: true);
            } else if (wantsNewMode) {
              _syncAutoSku();
            }
          },
        ),
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
                _playScanFeedback();
                setState(() {
                  _barcodeController.text = value;
                  _scannerEnabled = false;
                });
                _syncAutoSku();
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
          onChanged: (_) => _syncAutoSku(),
          decoration: _scanInputDecoration(
            "Barcode",
            hintText: "เช่น STK000001",
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
                    tooltip: "\u0e2a\u0e23\u0e49\u0e32\u0e07 barcode \u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34",
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
              label: const Text("\u0e2a\u0e23\u0e49\u0e32\u0e07 barcode \u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48\u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34"),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!_newProductMode) ...[
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "in", label: Text("\u0e23\u0e31\u0e1a\u0e40\u0e02\u0e49\u0e32"), icon: Icon(Icons.call_received)),
              ButtonSegment(value: "out", label: Text("\u0e08\u0e48\u0e32\u0e22\u0e2d\u0e2d\u0e01"), icon: Icon(Icons.call_made)),
              ButtonSegment(value: "issue", label: Text("\u0e40\u0e1a\u0e34\u0e01\u0e43\u0e0a\u0e49"), icon: Icon(Icons.assignment_turned_in_outlined)),
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
                decoration: _scanInputDecoration(
                  "\u0e08\u0e33\u0e19\u0e27\u0e19",
                  hintText: "1",
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _referenceController,
                decoration: _scanInputDecoration(
                  "\u0e40\u0e25\u0e02\u0e2d\u0e49\u0e32\u0e07\u0e2d\u0e34\u0e07",
                  hintText: "\u0e16\u0e49\u0e32\u0e21\u0e35",
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 2,
          decoration: _scanInputDecoration(
            "\u0e2b\u0e21\u0e32\u0e22\u0e40\u0e2b\u0e15\u0e38",
            hintText: "\u0e23\u0e32\u0e22\u0e25\u0e30\u0e40\u0e2d\u0e35\u0e22\u0e14\u0e40\u0e1e\u0e34\u0e48\u0e21",
          ),
        ),
        if (_newProductMode) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _productNameController,
            onChanged: (_) => _syncAutoSku(),
            decoration: _scanInputDecoration(
              "\u0e0a\u0e37\u0e48\u0e2d\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32",
              hintText: "\u0e40\u0e0a\u0e48\u0e19 Motor",
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _productSkuController,
                  onChanged: (value) {
                    final trimmed = value.trim();
                    _isSkuManuallyEdited =
                        trimmed.isNotEmpty && trimmed != _lastAutoGeneratedSku;
                  },
                  decoration: _scanInputDecoration(
                    "SKU",
                    hintText: "\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34",
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _syncAutoSku(force: true)),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      tooltip: "\u0e2a\u0e23\u0e49\u0e32\u0e07 SKU \u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34",
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _productUnitController,
                  decoration: _scanInputDecoration(
                    "\u0e2b\u0e19\u0e48\u0e27\u0e22",
                    hintText: "pcs",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "\u0e1b\u0e25\u0e48\u0e2d\u0e22\u0e27\u0e48\u0e32\u0e07\u0e44\u0e14\u0e49 \u0e23\u0e30\u0e1a\u0e1a\u0e08\u0e30\u0e2a\u0e23\u0e49\u0e32\u0e07 SKU \u0e43\u0e2b\u0e49\u0e08\u0e32\u0e01\u0e0a\u0e37\u0e48\u0e2d\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e41\u0e25\u0e30 barcode \u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _brandInk.withOpacity(0.84),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _productCategoryController,
            decoration: _scanInputDecoration(
              "\u0e2b\u0e21\u0e27\u0e14\u0e2b\u0e21\u0e39\u0e48",
              hintText: "\u0e40\u0e0a\u0e48\u0e19 \u0e44\u0e1f\u0e1f\u0e49\u0e32",
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _productLocationController,
            decoration: _scanInputDecoration(
              "\u0e15\u0e33\u0e41\u0e2b\u0e19\u0e48\u0e07\u0e08\u0e31\u0e14\u0e40\u0e01\u0e47\u0e1a",
              hintText: "\u0e40\u0e0a\u0e48\u0e19 Rack A1",
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
          label: Text(_newProductMode ? "\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48\u0e41\u0e25\u0e30\u0e23\u0e31\u0e1a\u0e40\u0e02\u0e49\u0e32" : "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23"),
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
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.api,
    required this.refreshSignal,
  });

  final StockApiService api;
  final ValueListenable<int> refreshSignal;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<MovementRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getMovements();
    widget.refreshSignal.addListener(_handleRealtimeRefresh);
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_handleRealtimeRefresh);
    super.dispose();
  }

  void _handleRealtimeRefresh() {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = widget.api.getMovements();
    });
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
          return ColoredBox(
            color: _brandSurface,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _PageHeader(
                  title: "\u0e1b\u0e23\u0e30\u0e27\u0e31\u0e15\u0e34\u0e01\u0e32\u0e23\u0e40\u0e04\u0e25\u0e37\u0e48\u0e2d\u0e19\u0e44\u0e2b\u0e27",
                  subtitle: "\u0e14\u0e39\u0e27\u0e48\u0e32\u0e43\u0e04\u0e23\u0e40\u0e1b\u0e47\u0e19\u0e04\u0e19\u0e22\u0e34\u0e07\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e40\u0e02\u0e49\u0e32 \u0e2d\u0e2d\u0e01 \u0e2b\u0e23\u0e37\u0e2d\u0e40\u0e1a\u0e34\u0e01\u0e43\u0e0a\u0e49",
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const _EmptyTile(message: "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35 movement \u0e43\u0e19\u0e23\u0e30\u0e1a\u0e1a")
                else
                  ...items.map((item) => _MovementTile(item: item)),
              ],
            ),
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
    this.refreshSignal,
  });

  final StockApiService api;
  final AppUser currentUser;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefreshSession;
  final ValueListenable<int>? refreshSignal;

  Future<void> _openPage(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <_MoreAction>[
      _MoreAction(
        title: "\u0e42\u0e1b\u0e23\u0e44\u0e1f\u0e25\u0e4c",
        subtitle: "\u0e14\u0e39\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49 \u0e2d\u0e31\u0e1b\u0e42\u0e2b\u0e25\u0e14\u0e23\u0e39\u0e1b \u0e41\u0e25\u0e30\u0e2d\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e23\u0e30\u0e1a\u0e1a",
        icon: Icons.person_outline,
        onTap: () => _openPage(
          context,
          ProfilePage(
            currentUser: currentUser,
            api: api,
            onLogout: () async {
              Navigator.of(context).popUntil((route) => route.isFirst);
              await onLogout();
            },
            onRefreshSession: onRefreshSession,
          ),
        ),
      ),
      _MoreAction(
        title: "\u0e41\u0e08\u0e49\u0e07\u0e40\u0e15\u0e37\u0e2d\u0e19",
        subtitle: "\u0e14\u0e39\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e41\u0e08\u0e49\u0e07\u0e40\u0e15\u0e37\u0e2d\u0e19\u0e25\u0e48\u0e32\u0e2a\u0e38\u0e14\u0e08\u0e32\u0e01\u0e01\u0e32\u0e23\u0e22\u0e34\u0e07\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32",
        icon: Icons.notifications_none_outlined,
        onTap: () => _openPage(
          context,
          NotificationsPage(
            api: api,
            refreshSignal: refreshSignal,
          ),
        ),
      ),
    ];

    if (currentUser.isAdmin) {
      items.add(
        _MoreAction(
          title: "\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25\u0e23\u0e30\u0e1a\u0e1a",
          subtitle: "\u0e0b\u0e34\u0e07\u0e01\u0e4c Google Sheets \u0e41\u0e25\u0e30\u0e2a\u0e48\u0e07\u0e2d\u0e2d\u0e01\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25",
          icon: Icons.admin_panel_settings_outlined,
          onTap: () => _openPage(
            context,
            AdminPage(api: api, currentUser: currentUser),
          ),
        ),
      );
    }

    return SafeArea(
      child: ColoredBox(
        color: _brandSurface,
        child: ListView(
          padding: _pagePadding,
          children: [
            const _PageHeader(
              title: "\u0e40\u0e1e\u0e34\u0e48\u0e21\u0e40\u0e15\u0e34\u0e21",
              subtitle: "\u0e23\u0e27\u0e21\u0e40\u0e21\u0e19\u0e39\u0e17\u0e35\u0e48\u0e43\u0e0a\u0e49\u0e44\u0e21\u0e48\u0e1a\u0e48\u0e2d\u0e22\u0e44\u0e27\u0e49\u0e43\u0e19\u0e2b\u0e19\u0e49\u0e32\u0e40\u0e14\u0e35\u0e22\u0e27 \u0e40\u0e1e\u0e37\u0e48\u0e2d\u0e43\u0e2b\u0e49\u0e41\u0e16\u0e1a\u0e25\u0e48\u0e32\u0e07\u0e14\u0e39\u0e2a\u0e1a\u0e32\u0e22\u0e15\u0e32\u0e02\u0e36\u0e49\u0e19",
              showBackButton: true,
            ),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor: Color.lerp(_brandSurface, _brandSurfaceStrong, 0.75),
                    child: Icon(item.icon, color: _brandDeep),
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: item.onTap,
                ),
              ),
            ),
          ],
        ),
      ),
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
  const NotificationsPage({
    super.key,
    required this.api,
    this.refreshSignal,
  });

  final StockApiService api;
  final ValueListenable<int>? refreshSignal;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getNotifications();
    widget.refreshSignal?.addListener(_handleRealtimeRefresh);
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRealtimeRefresh);
    super.dispose();
  }

  void _handleRealtimeRefresh() {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = widget.api.getNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: _brandSurface,
        child: RefreshIndicator(
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
                    title: "\u0e01\u0e32\u0e23\u0e41\u0e08\u0e49\u0e07\u0e40\u0e15\u0e37\u0e2d\u0e19",
                    subtitle: "\u0e1f\u0e35\u0e14\u0e41\u0e08\u0e49\u0e07\u0e40\u0e15\u0e37\u0e2d\u0e19\u0e08\u0e32\u0e01\u0e01\u0e32\u0e23\u0e22\u0e34\u0e07\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e41\u0e15\u0e48\u0e25\u0e30\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23",
                    showBackButton: true,
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const _EmptyTile(message: "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e01\u0e32\u0e23\u0e41\u0e08\u0e49\u0e07\u0e40\u0e15\u0e37\u0e2d\u0e19")
                  else
                    ...items.map((item) => _NotificationTile(notification: item)),
                ],
              );
            },
          ),
        ),
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
  final TextEditingController _downloadSearchController = TextEditingController();
  String _downloadSearch = "";
  String _downloadTypeFilter = "all";

  @override
  void initState() {
    super.initState();
    _exportLinksFuture = _loadExportLinks();
  }

  @override
  void dispose() {
    _downloadSearchController.dispose();
    super.dispose();
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
      _showSnack("\u0e40\u0e09\u0e1e\u0e32\u0e30 admin \u0e40\u0e17\u0e48\u0e32\u0e19\u0e31\u0e49\u0e19\u0e17\u0e35\u0e48\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2b\u0e19\u0e49\u0e32\u0e19\u0e35\u0e49\u0e44\u0e14\u0e49");
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
    _showAppSnack(context, message);
  }

  bool _matchesDownloadSearch(String label) {
    final query = _downloadSearch.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return label.toLowerCase().contains(query);
  }

  bool _matchesDownloadType(String group) {
    return _downloadTypeFilter == "all" || _downloadTypeFilter == group;
  }

  List<({String label, String url, DateTime? expiresAt, String group})> _buildExportItems(
    Map<String, ExportLink>? links,
  ) {
    return <({String label, String url, DateTime? expiresAt, String group})>[
      (
        label: "สินค้า CSV",
        url: links?["products"]?.url ??
            widget.api.exportUrl(
              path: "/exports/products.csv",
              requesterId: widget.currentUser.userId,
            ),
        expiresAt: links?["products"]?.expiresAt,
        group: "csv",
      ),
      (
        label: "ผู้ใช้ CSV",
        url: links?["users"]?.url ??
            widget.api.exportUrl(
              path: "/exports/users.csv",
              requesterId: widget.currentUser.userId,
            ),
        expiresAt: links?["users"]?.expiresAt,
        group: "csv",
      ),
      (
        label: "ประวัติ CSV",
        url: links?["movements"]?.url ??
            widget.api.exportUrl(
              path: "/exports/movements.csv",
              requesterId: widget.currentUser.userId,
            ),
        expiresAt: links?["movements"]?.expiresAt,
        group: "csv",
      ),
      (
        label: "ไฟล์ Excel ทั้งหมด",
        url: links?["excel"]?.url ??
            widget.api.exportUrl(
              path: "/exports/all.xlsx",
              requesterId: widget.currentUser.userId,
            ),
        expiresAt: links?["excel"]?.expiresAt,
        group: "excel",
      ),
    ];
  }

  List<Widget> _buildGroupedExportWidgets(Map<String, ExportLink>? links) {
    final filtered = _buildExportItems(links)
        .where((item) => _matchesDownloadSearch(item.label))
        .where((item) => _matchesDownloadType(item.group))
        .toList();
    if (filtered.isEmpty) {
      return const [
        _EmptyTile(message: "ไม่พบไฟล์ที่ค้นหา ลองพิมพ์คำว่า Excel, CSV, สินค้า หรือ ประวัติ"),
      ];
    }

    final csvItems = filtered.where((item) => item.group == "csv").toList();
    final excelItems = filtered.where((item) => item.group == "excel").toList();
    final widgets = <Widget>[];

    if (csvItems.isNotEmpty) {
      widgets.add(
        _ExportGroupCard(
          title: "ไฟล์ CSV",
          icon: Icons.table_view_outlined,
          children: csvItems
              .map(
                (item) => _SelectableUrl(
                  label: item.label,
                  url: item.url,
                  expiresAt: item.expiresAt,
                ),
              )
              .toList(),
        ),
      );
    }
    if (excelItems.isNotEmpty) {
      widgets.add(
        _ExportGroupCard(
          title: "ไฟล์ Excel",
          icon: Icons.grid_on_rounded,
          children: excelItems
              .map(
                (item) => _SelectableUrl(
                  label: item.label,
                  url: item.url,
                  expiresAt: item.expiresAt,
                ),
              )
              .toList(),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 28;

    if (!widget.currentUser.isAdmin) {
      return SafeArea(
        child: ColoredBox(
          color: _brandSurface,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
            children: const [
              _PageHeader(
                title: "\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25\u0e23\u0e30\u0e1a\u0e1a",
                subtitle: "\u0e2b\u0e19\u0e49\u0e32\u0e19\u0e35\u0e49\u0e2a\u0e33\u0e2b\u0e23\u0e31\u0e1a\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25\u0e23\u0e30\u0e1a\u0e1a\u0e40\u0e17\u0e48\u0e32\u0e19\u0e31\u0e49\u0e19",
                showBackButton: true,
              ),
              SizedBox(height: 16),
              _EmptyTile(message: "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e19\u0e35\u0e49\u0e44\u0e21\u0e48\u0e21\u0e35\u0e2a\u0e34\u0e17\u0e18\u0e34\u0e4c\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e1f\u0e31\u0e07\u0e01\u0e4c\u0e0a\u0e31\u0e19 admin"),
            ],
          ),
        ),
      );
    }

    final requesterId = widget.currentUser.userId;

    return SafeArea(
      child: ColoredBox(
        color: _brandSurface,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          children: [
            const _PageHeader(
              title: "\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25\u0e23\u0e30\u0e1a\u0e1a",
              subtitle: "\u0e07\u0e32\u0e19 sync \u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e41\u0e25\u0e30\u0e25\u0e34\u0e07\u0e01\u0e4c export \u0e2a\u0e33\u0e2b\u0e23\u0e31\u0e1a\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25\u0e23\u0e30\u0e1a\u0e1a",
              showBackButton: true,
            ),
            const SizedBox(height: 16),
            Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("\u0e04\u0e33\u0e2a\u0e31\u0e48\u0e07 Google Sheets", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runAction(
                            () => widget.api.syncProducts(requesterId: requesterId),
                          ),
                  child: const Text("\u0e0b\u0e34\u0e07\u0e01\u0e4c\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32"),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runAction(
                            () => widget.api.syncUsers(requesterId: requesterId),
                          ),
                  child: const Text("\u0e0b\u0e34\u0e07\u0e01\u0e4c\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49"),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runAction(
                            () => widget.api.syncStocks(requesterId: requesterId),
                          ),
                  child: const Text("\u0e2d\u0e31\u0e1b\u0e40\u0e14\u0e15\u0e22\u0e2d\u0e14\u0e04\u0e07\u0e40\u0e2b\u0e25\u0e37\u0e2d"),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runAction(
                            () => widget.api.appendTest(requesterId: requesterId),
                          ),
                  child: const Text("\u0e17\u0e14\u0e2a\u0e2d\u0e1a\u0e40\u0e1e\u0e34\u0e48\u0e21\u0e41\u0e16\u0e27"),
                ),
                if (_lastMessage != null) ...[
                  const SizedBox(height: 12),
                  Text("\u0e25\u0e48\u0e32\u0e2a\u0e38\u0e14: $_lastMessage"),
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
                Text("\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e2a\u0e48\u0e07\u0e2d\u0e2d\u0e01\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const Text("\u0e40\u0e1b\u0e34\u0e14\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e40\u0e2b\u0e25\u0e48\u0e32\u0e19\u0e35\u0e49\u0e43\u0e19\u0e40\u0e1a\u0e23\u0e32\u0e27\u0e4c\u0e40\u0e0b\u0e2d\u0e23\u0e4c\u0e17\u0e35\u0e48\u0e40\u0e02\u0e49\u0e32\u0e16\u0e36\u0e07 backend \u0e44\u0e14\u0e49"),
                const SizedBox(height: 12),
                TextField(
                  controller: _downloadSearchController,
                  onChanged: (value) {
                    setState(() {
                      _downloadSearch = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "ค้นหาไฟล์ เช่น Excel, CSV, สินค้า",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _downloadSearch.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _downloadSearchController.clear();
                              setState(() {
                                _downloadSearch = "";
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: "all",
                      label: Text("ทั้งหมด"),
                      icon: Icon(Icons.apps_rounded),
                    ),
                    ButtonSegment<String>(
                      value: "csv",
                      label: Text("CSV"),
                      icon: Icon(Icons.table_view_outlined),
                    ),
                    ButtonSegment<String>(
                      value: "excel",
                      label: Text("Excel"),
                      icon: Icon(Icons.grid_on_rounded),
                    ),
                  ],
                  selected: {_downloadTypeFilter},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _downloadTypeFilter = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                ..._buildGroupedExportWidgets(null),
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
                Text("\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e0a\u0e31\u0e48\u0e27\u0e04\u0e23\u0e32\u0e27\u0e41\u0e1a\u0e1a\u0e1b\u0e25\u0e2d\u0e14\u0e20\u0e31\u0e22", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                const Text("\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e0a\u0e38\u0e14\u0e19\u0e35\u0e49\u0e0b\u0e48\u0e2d\u0e19 requester_id \u0e41\u0e25\u0e30\u0e43\u0e0a\u0e49\u0e44\u0e14\u0e49\u0e0a\u0e48\u0e27\u0e07\u0e2a\u0e31\u0e49\u0e19 \u0e46"),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _refreshExportLinks,
                    icon: const Icon(Icons.refresh),
                    label: const Text("\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e43\u0e2b\u0e21\u0e48"),
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
                            ? "\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e0a\u0e31\u0e48\u0e27\u0e04\u0e23\u0e32\u0e27\u0e44\u0e14\u0e49"
                            : snapshot.error.toString().replaceFirst("Exception: ", ""),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._buildGroupedExportWidgets(snapshot.data),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
          ],
        ),
      ),
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

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.products = const [],
    this.usedAi = false,
    this.action,
    this.downloadLink,
  });

  factory _ChatMessage.user(String text) => _ChatMessage(text: text, isUser: true);

  factory _ChatMessage.bot(
    String text, {
    List<Product> products = const [],
    bool usedAi = false,
    ChatAssistantAction? action,
    ExportLink? downloadLink,
  }) {
    return _ChatMessage(
      text: text,
      isUser: false,
      products: products,
      usedAi: usedAi,
      action: action,
      downloadLink: downloadLink,
    );
  }

  final String text;
  final bool isUser;
  final List<Product> products;
  final bool usedAi;
  final ChatAssistantAction? action;
  final ExportLink? downloadLink;
}

class _PendingChatAction {
  const _PendingChatAction({
    required this.type,
    required this.quantity,
    required this.productHint,
  });

  final String type;
  final int quantity;
  final String productHint;

  String get summary {
    final verb = switch (type) {
      "in" => "เพิ่มสต๊อก",
      "issue" => "เบิกใช้",
      _ => "ตัด/เบิกสต๊อก",
    };
    return "$verb จำนวน $quantity สำหรับ \"$productHint\"";
  }
}

_PendingChatAction? _detectPendingChatAction(String message) {
  final lowered = message.trim().toLowerCase();
  final intents = <String, List<String>>{
    "in": ["เพิ่ม", "รับเข้า", "เติม", "นำเข้า", "เอาเข้า", "เพิ่มสต๊อก", "เพิ่มสตอก"],
    "out": ["เบิก", "ตัด", "ลด", "จ่ายออก", "เอาออก", "ลดสต๊อก", "ลดสตอก", "ตัดสต๊อก", "ตัดสตอก"],
    "issue": ["issue", "ใช้ไป", "นำออกใช้", "หยิบใช้", "เบิกใช้"],
  };

  String? detectedType;
  List<String> matchedKeywords = const [];
  for (final entry in intents.entries) {
    final hit = entry.value.where((keyword) => lowered.contains(keyword)).toList();
    if (hit.isNotEmpty) {
      detectedType = entry.key;
      matchedKeywords = hit;
      break;
    }
  }
  if (detectedType == null) {
    return null;
  }

  int? quantity;
  for (final token in message.replaceAll(",", " ").split(RegExp(r"\s+"))) {
    if (token.isEmpty) {
      continue;
    }
    final parsed = int.tryParse(token);
    if (parsed != null && parsed > 0) {
      quantity = parsed;
      break;
    }
  }
  if (quantity == null) {
    return null;
  }

  var productHint = message;
  for (final keyword in matchedKeywords) {
    productHint = productHint.replaceAll(keyword, " ");
    productHint = productHint.replaceAll(keyword.toUpperCase(), " ");
  }
  productHint = productHint.replaceAll(RegExp(r"\b\d+\b"), " ");
  productHint = productHint.replaceAll(RegExp(r"\s+"), " ").trim();
  if (productHint.isEmpty) {
    productHint = "สินค้าที่ระบุ";
  }

  return _PendingChatAction(
    type: detectedType,
    quantity: quantity,
    productHint: productHint,
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _brandSurface,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.8,
            color: _brandPrimary,
          ),
        ),
      ),
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
    final headerColor = Color.lerp(_brandSurfaceStrong, _brandPrimary, 0.34)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(_spaceLg, _spaceLg, _spaceLg, _spaceMd),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(_radiusXl),
        border: Border.all(color: _brandPrimary.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: _brandPrimary.withOpacity(0.10),
            blurRadius: 18,
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
              color: _brandDeep,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.82),
              ),
            ),
            const SizedBox(height: _spaceXs),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _brandDeep,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _brandInk.withOpacity(0.82),
                ),
          ),
          const SizedBox(height: _spaceSm),
          Container(
            width: 64,
            height: 4,
            decoration: BoxDecoration(
              color: _brandPrimary,
              borderRadius: BorderRadius.circular(999),
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
    final iconChipColor = Color.lerp(_brandSurface, tone, 0.16)!;
    final iconColor = Color.lerp(_brandDeep, tone, 0.55)!;
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, _spaceSm),
      decoration: _softPanelDecoration(
        tone: tone,
        radius: 20,
        surfaceStrength: 0.80,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconChipColor,
              borderRadius: BorderRadius.circular(_spaceSm),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: _spaceXs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _brandDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                  ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _brandInk.withOpacity(0.9),
                  fontSize: 12,
                  height: 1.1,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DashboardIdentityCard extends StatelessWidget {
  const _DashboardIdentityCard({
    required this.imageUrl,
    required this.name,
    required this.roleLabel,
  });

  final String? imageUrl;
  final String name;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final woodTone = Color.lerp(_brandPrimary, _brandSurfaceStrong, 0.34)!;
    final woodDeep = Color.lerp(_brandDeep, _brandPrimary, 0.20)!;

    return Container(
      decoration: BoxDecoration(
        color: _brandCard,
        borderRadius: BorderRadius.circular(_radiusXl),
        border: Border.all(color: _brandPrimary.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: _brandDeep.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                height: 132,
                decoration: BoxDecoration(
                  color: woodTone,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_radiusXl),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 18,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _brandPrimary.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                top: 18,
                right: 18,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                top: 58,
                left: 0,
                child: Container(
                  width: 96,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _profileAccent.withOpacity(0.90),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(999),
                      bottomRight: Radius.circular(999),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 58,
                right: 0,
                child: Container(
                  width: 96,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _profileAccent.withOpacity(0.90),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(999),
                      bottomLeft: Radius.circular(999),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -52,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _brandDeep.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: woodTone, width: 3),
                      color: woodTone,
                    ),
                    child: _UserAvatar(
                      imageUrl: imageUrl,
                      name: name,
                      radius: 44,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 64, 18, 18),
            child: Column(
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 22,
                        color: _brandDeep,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: woodDeep,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: _brandDeep.withOpacity(0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    roleLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _brandSurface,
                          fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: _profileAccent.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: _brandSurfaceStrong.withOpacity(0.62),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: _profileAccent.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.onOpenProduct,
  });

  final _ChatMessage message;
  final ValueChanged<Product> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser ? _brandDeep : _brandCard;
    final textColor = message.isUser ? Colors.white : _brandInk;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(18),
                border: message.isUser
                    ? null
                    : Border.all(color: _brandPrimary.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isUser && (message.usedAi || message.action != null)) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (message.usedAi)
                          _ChatMetaChip(
                            label: "AI",
                            tone: _profileTeal,
                          ),
                        if (message.action != null)
                          _ChatMetaChip(
                            label: "สั่งงานแล้ว",
                            tone: message.action!.lowStock ? _brandPrimary : _brandDeep,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    message.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                ],
              ),
            ),
          ),
          if (message.products.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...message.products.map(
              (product) => SizedBox(
                width: 320,
                child: _ProductTile(
                  product: product,
                  onOpenCode: () => onOpenProduct(product),
                ),
              ),
            ),
          ],
          if (message.downloadLink != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 320,
              child: _SelectableUrl(
                label: "ดาวน์โหลดไฟล์",
                url: message.downloadLink!.url,
                expiresAt: message.downloadLink!.expiresAt,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatMetaChip extends StatelessWidget {
  const _ChatMetaChip({
    required this.label,
    required this.tone,
  });

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
      ),
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
        subtitle: Text("${product.barcode} • ${product.location ?? "\u0e44\u0e21\u0e48\u0e23\u0e30\u0e1a\u0e38\u0e15\u0e33\u0e41\u0e2b\u0e19\u0e48\u0e07"}"),
        leading: CircleAvatar(
          backgroundColor: (product.isLowStock ? _brandPrimary : _brandDeep).withOpacity(0.10),
          child: Icon(
            product.isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
            color: product.isLowStock ? _brandPrimary : _brandDeep,
          ),
        ),
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
                tooltip: "\u0e14\u0e39 barcode",
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
        return _brandDeep;
      default:
        return _brandInk;
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
        trailing: Text(
          "${item.beforeStock} -> ${item.afterStock}",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _tone(),
                fontWeight: FontWeight.w700,
              ),
        ),
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
        leading: CircleAvatar(
          backgroundColor: _brandPrimary.withOpacity(0.10),
          child: const Icon(Icons.notifications_active_outlined, color: _brandPrimary),
        ),
        title: Text(notification.title),
        subtitle: Text(notification.message),
        trailing: Text(
          _formatDateTime(notification.createdAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
    final tone = result.lowStock ? _brandPrimary : _brandDeep;
    return Container(
      padding: _cardPadding,
      decoration: _softPanelDecoration(
        tone: tone,
        surfaceStrength: 0.70,
      ).copyWith(
        border: Border.all(color: tone.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.productCreated
                ? "\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48\u0e41\u0e25\u0e30\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e2a\u0e33\u0e40\u0e23\u0e47\u0e08"
                : result.lowStock
                    ? "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e41\u0e25\u0e49\u0e27: \u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e2d\u0e22\u0e39\u0e48\u0e43\u0e19\u0e23\u0e30\u0e14\u0e31\u0e1a\u0e40\u0e15\u0e37\u0e2d\u0e19"
                    : "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e2a\u0e33\u0e40\u0e23\u0e47\u0e08",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: tone),
          ),
          const SizedBox(height: 8),
          Text(result.product.name),
          Text("\u0e1a\u0e32\u0e23\u0e4c\u0e42\u0e04\u0e49\u0e14: ${result.product.barcode}"),
          Text("\u0e04\u0e07\u0e40\u0e2b\u0e25\u0e37\u0e2d: ${result.product.currentStock} ${result.product.unit}"),
          Text("\u0e1c\u0e39\u0e49\u0e17\u0e33\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23: ${result.movement.actorName}"),
          if (onOpenCode != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenCode,
              icon: const Icon(Icons.qr_code_2_outlined),
              label: const Text("\u0e14\u0e39 barcode / QR"),
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
        throw Exception("\u0e44\u0e21\u0e48\u0e1e\u0e1a\u0e20\u0e32\u0e1e\u0e2a\u0e33\u0e2b\u0e23\u0e31\u0e1a\u0e2a\u0e48\u0e07\u0e2d\u0e2d\u0e01");
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        throw Exception("\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e44\u0e1f\u0e25\u0e4c\u0e20\u0e32\u0e1e\u0e44\u0e21\u0e48\u0e2a\u0e33\u0e40\u0e23\u0e47\u0e08");
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
        _showAppSnack(
          context,
          error.toString().replaceFirst("Exception: ", ""),
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
                        "Barcode \u0e41\u0e25\u0e30 QR \u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32",
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
                          "\u0e2a\u0e41\u0e01\u0e19\u0e44\u0e14\u0e49\u0e17\u0e31\u0e49\u0e07 Barcode \u0e41\u0e25\u0e30 QR",
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
                        label: const Text("\u0e41\u0e0a\u0e23\u0e4c / \u0e2a\u0e48\u0e07\u0e2d\u0e2d\u0e01\u0e1b\u0e49\u0e32\u0e22"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: product.barcode));
                        if (context.mounted) {
                          _showAppSnack(
                            context,
                            "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01 barcode \u0e41\u0e25\u0e49\u0e27",
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      tooltip: "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01\u0e23\u0e2b\u0e31\u0e2a",
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
      _showAppSnack(context, "\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e44\u0e21\u0e48\u0e16\u0e39\u0e01\u0e15\u0e49\u0e2d\u0e07");
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showAppSnack(
        context,
        "\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e40\u0e1b\u0e34\u0e14\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e14\u0e32\u0e27\u0e19\u0e4c\u0e42\u0e2b\u0e25\u0e14\u0e44\u0e14\u0e49",
      );
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      _showAppSnack(context, "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e41\u0e25\u0e49\u0e27");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _spaceSm),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _softPanelDecoration(
          radius: _radiusMd,
          surfaceStrength: 0.32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            if (expiresAt != null) ...[
              const SizedBox(height: 4),
              Text(
                "\u0e2b\u0e21\u0e14\u0e2d\u0e32\u0e22\u0e38 ${_formatDateTime(expiresAt!)}",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _openUrl(context),
              borderRadius: BorderRadius.circular(_radiusSm),
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
                    label: const Text("\u0e14\u0e32\u0e27\u0e19\u0e4c\u0e42\u0e2b\u0e25\u0e14\u0e40\u0e25\u0e22"),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _copyUrl(context),
                  icon: const Icon(Icons.copy_all_outlined),
                  tooltip: "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01\u0e25\u0e34\u0e07\u0e01\u0e4c",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportGroupCard extends StatelessWidget {
  const _ExportGroupCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _softPanelDecoration(
        radius: _radiusMd,
        surfaceStrength: 0.36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _brandPrimary.withOpacity(0.10),
                child: Icon(icon, color: _brandPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: _spaceLg, vertical: 22),
      decoration: _softPanelDecoration(surfaceStrength: 0.45),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _brandPrimary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: _brandPrimary.withOpacity(0.82),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _brandInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _brandInk.withOpacity(0.70),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding,
      children: [
        const SizedBox(height: 80),
        Container(
          padding: _cardPadding,
          decoration: _softPanelDecoration(
            tone: _profileAccent,
            surfaceStrength: 0.30,
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _profileAccent.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: _brandTextOnLight,
                  size: 26,
                ),
              ),
              const SizedBox(height: _spaceSm),
              Text(
                "\u0e40\u0e0a\u0e37\u0e48\u0e2d\u0e21\u0e15\u0e48\u0e2d API \u0e44\u0e21\u0e48\u0e2a\u0e33\u0e40\u0e23\u0e47\u0e08",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: _spaceXs),
              Text(
                message.replaceFirst("Exception: ", ""),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _brandInk.withOpacity(0.72),
                    ),
              ),
            ],
          ),
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


import "dart:async";
import "dart:io";
import "dart:math";
import "dart:typed_data";
import "dart:ui" as ui;

import "dart:convert";
import "package:barcode_widget/barcode_widget.dart";
import "package:file_picker/file_picker.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:mobile_scanner/mobile_scanner.dart" hide Barcode;
import "package:path_provider/path_provider.dart";
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:printing/printing.dart";
import "package:qr_flutter/qr_flutter.dart";
import "package:share_plus/share_plus.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

import "api_service.dart";
import "models.dart";
import "theme/app_theme.dart";

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}

const _sessionUserIdKey = "session_user_id";
const _sessionPinKey = "session_pin";
const _sessionAccessTokenKey = "session_access_token";
const _sessionUserJsonKey = "session_user_json";
const _brandPrimary = Color(0xFF005AA7);
const _brandSurface = Colors.white;
const _brandSurfaceStrong = Color(0xFFB9D6F2);
const _brandTextOnLight = Color(0xFF123B63);
const _brandDeep = Color(0xFF003B73);
const _brandInk = Color(0xFF123B63);
const _brandCard = Colors.white;
const _profileTeal = Color(0xFF0068BF);
const _profileAccent = Color(0xFF7DB8E8);
const double _spaceXs = 8;
const double _spaceSm = 12;
const double _spaceMd = 16;
const double _spaceLg = 20;
const double _spaceXl = 24;
const String _webBuildTag = "2026-05-08-dashboard-v1";
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brandPrimary, _profileTeal],
        ),
        boxShadow: [
          BoxShadow(
            color: _brandPrimary.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.inventory_2_rounded,
            color: Colors.white.withOpacity(0.95),
            size: size * 0.54,
          ),
          Positioned(
            bottom: size * 0.14,
            child: SizedBox(
              width: size * 0.56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => Container(
                    width: size * 0.038,
                    height: index.isEven ? size * 0.17 : size * 0.13,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLogoWordmark extends StatelessWidget {
  const _BrandLogoWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: _brandDeep,
          fontWeight: FontWeight.w800,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _BrandLogoIcon(size: 26),
        const SizedBox(width: 8),
        Text("StockScan", style: textStyle),
      ],
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
  final repaired = _repairThaiMojibake(cleaned);

  final lowered = repaired.toLowerCase();
  if (repaired.contains("เซิร์ฟเวอร์") ||
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
  // Backend not updated / missing chat endpoints.
  // We avoid matching mojibake literals here; just look for stable Thai/English keywords.
  if (repaired.contains("ฟีเจอร์แชท") &&
      (repaired.contains("ยังไม่อัปเดต") ||
          lowered.contains("not updated") ||
          lowered.contains("missing") ||
          lowered.contains("endpoint"))) {
    return "เซิร์ฟเวอร์ยังไม่อัปเดตฟีเจอร์แชท กรุณา deploy backend เวอร์ชันล่าสุดก่อน";
  }
  if (lowered.contains("not found")) {
    return "ไม่พบปลายทางที่ต้องการบนเซิร์ฟเวอร์ อาจเป็นเพราะ backend ยังไม่อัปเดต";
  }

  return repaired;
}

String _repairThaiMojibake(String value) {
  var repaired = value;
  // Typical Thai mojibake sequences when UTF-8 is mis-decoded as Latin-1/Windows-1252.
  // Examples: "à¸", "à¹", "Ã", "�".
  bool looksMojibake(String s) {
    return RegExp(r"(à¸|à¹|Ã|�)").hasMatch(s);
  }

  for (var i = 0; i < 2; i++) {
    if (!looksMojibake(repaired)) {
      break;
    }
    try {
      repaired = utf8.decode(latin1.encode(repaired));
    } catch (_) {
      break;
    }
  }
  return repaired;
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase options aren't configured for web in this project yet.
  // Avoid crashing on Flutter Web; push notifications remain mobile-only.
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  runApp(const StockScannerApp());
}

class StockScannerApp extends StatefulWidget {
  const StockScannerApp({super.key});

  @override
  State<StockScannerApp> createState() => _StockScannerAppState();
}

class _StockScannerAppState extends State<StockScannerApp> {
  static final RouteObserver<ModalRoute<void>> _routeObserver =
      RouteObserver<ModalRoute<void>>();
  final StockApiService _api = StockApiService();
  static const Duration _minSplashDuration = Duration(milliseconds: 900);
  static const Duration _restoreTimeout = Duration(seconds: 4);
  AppUser? _currentUser;
  bool _isRestoring = true;
  FirebaseMessaging? _messaging;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _messaging = FirebaseMessaging.instance;
    }
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final startedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_sessionAccessTokenKey);
    final savedUserId = prefs.getString(_sessionUserIdKey);
    final savedPin = prefs.getString(_sessionPinKey);
    final savedUserJson = prefs.getString(_sessionUserJsonKey);

    if (savedToken != null &&
        savedToken.isNotEmpty &&
        savedUserJson != null &&
        savedUserJson.isNotEmpty) {
      try {
        final cachedUser = AppUser.fromJson(
          jsonDecode(savedUserJson) as Map<String, dynamic>,
        );
        _api.setAccessToken(savedToken);
        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed < _minSplashDuration) {
          await Future<void>.delayed(_minSplashDuration - elapsed);
        }
        if (mounted) {
          setState(() {
            _currentUser = cachedUser;
            _isRestoring = false;
          });
        }
        unawaited(_refreshRestoredSession(prefs));
        return;
      } catch (_) {
        await prefs.remove(_sessionUserJsonKey);
      }
    }

    if (savedToken != null && savedToken.isNotEmpty) {
      try {
        _api.setAccessToken(savedToken);
        final user = await _api.getCurrentUser().timeout(_restoreTimeout);
        await prefs.setString(_sessionUserJsonKey, jsonEncode(user.toJson()));
        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed < _minSplashDuration) {
          await Future<void>.delayed(_minSplashDuration - elapsed);
        }
        if (mounted) {
          setState(() {
            _currentUser = user;
            _isRestoring = false;
          });
        }
        await _registerPushForUser(user.userId);
        return;
      } catch (_) {
        _api.clearAccessToken();
        await prefs.remove(_sessionAccessTokenKey);
        await prefs.remove(_sessionUserJsonKey);
      }
    }

    if (savedUserId != null && savedPin != null) {
      try {
        final session = await _api
            .login(userId: savedUserId, pin: savedPin)
            .timeout(_restoreTimeout);
        await prefs.setString(_sessionAccessTokenKey, session.accessToken);
        await prefs.setString(
            _sessionUserJsonKey, jsonEncode(session.user.toJson()));
        await prefs.remove(_sessionPinKey);
        final elapsed = DateTime.now().difference(startedAt);
        if (elapsed < _minSplashDuration) {
          await Future<void>.delayed(_minSplashDuration - elapsed);
        }
        if (mounted) {
          setState(() {
            _currentUser = session.user;
            _isRestoring = false;
          });
        }
        _api.setAccessToken(session.accessToken);
        await _registerPushForUser(session.user.userId);
        return;
      } catch (_) {
        _api.clearAccessToken();
        await prefs.remove(_sessionAccessTokenKey);
        await prefs.remove(_sessionUserIdKey);
        await prefs.remove(_sessionPinKey);
        await prefs.remove(_sessionUserJsonKey);
      }
    }

    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < _minSplashDuration) {
      await Future<void>.delayed(_minSplashDuration - elapsed);
    }
    if (mounted) {
      setState(() {
        _isRestoring = false;
      });
    }
  }

  Future<void> _refreshRestoredSession(SharedPreferences prefs) async {
    try {
      final user = await _api.getCurrentUser().timeout(_restoreTimeout);
      await prefs.setString(_sessionUserJsonKey, jsonEncode(user.toJson()));
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
      await _registerPushForUser(user.userId);
    } catch (_) {
      _api.clearAccessToken();
      await prefs.remove(_sessionAccessTokenKey);
      await prefs.remove(_sessionUserIdKey);
      await prefs.remove(_sessionPinKey);
      await prefs.remove(_sessionUserJsonKey);
      if (mounted) {
        setState(() {
          _currentUser = null;
        });
      }
    }
  }

  Future<void> _handleLogin(LoginSession session) async {
    final prefs = await SharedPreferences.getInstance();
    _api.setAccessToken(session.accessToken);
    await prefs.setString(_sessionUserIdKey, session.user.userId);
    await prefs.setString(_sessionAccessTokenKey, session.accessToken);
    await prefs.setString(
        _sessionUserJsonKey, jsonEncode(session.user.toJson()));
    await prefs.remove(_sessionPinKey);
    if (mounted) {
      setState(() {
        _currentUser = session.user;
      });
    }
    try {
      await _registerPushForUser(session.user.userId);
    } catch (_) {
      // best effort
    }
  }

  Future<void> _registerPushForUser(String userId) async {
    if (kIsWeb) return;
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _api.registerDeviceToken(
        requesterId: userId,
        platform: Platform.isAndroid ? "android" : "ios",
        token: token,
      );
    } catch (_) {
      // best effort
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
    await prefs.remove(_sessionUserJsonKey);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserJsonKey, jsonEncode(refreshed.toJson()));
    if (mounted) {
      setState(() {
        _currentUser = refreshed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:
          "\u0e41\u0e2d\u0e1b\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32",
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
          indicatorColor: Color.lerp(_brandSurface, _brandSurfaceStrong, 0.70)!
              .withOpacity(0.90),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? _brandDeep
                  : _brandInk,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
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
      navigatorObservers: [_routeObserver],
      home: _isRestoring
          ? const _SplashScreen()
          : Builder(
              builder: (context) {
                final inner = _currentUser == null
                    ? LoginPage(api: _api, onLogin: _handleLogin)
                    : StockHomePage(
                        api: _api,
                        currentUser: _currentUser!,
                        onLogout: _handleLogout,
                        onRefreshSession: _refreshSession,
                      );

                return inner;
              },
            ),
    );
  }
}

class _WebLandingPage extends StatelessWidget {
  const _WebLandingPage({
    required this.onEnter,
  });

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 960;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            "assets/web_hero.jpg",
            fit: BoxFit.cover,
          ),
          // Darken the background for readability.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.62),
                  Colors.black.withOpacity(0.45),
                  Colors.black.withOpacity(0.65),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: const Icon(Icons.local_shipping_outlined,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      if (!isNarrow) ...[
                        _LandingNavItem(label: "Home"),
                        const SizedBox(width: 18),
                        _LandingNavItem(label: "Orders"),
                        const SizedBox(width: 18),
                        _LandingNavItem(label: "Stock"),
                        const SizedBox(width: 18),
                        _LandingNavItem(label: "Contact"),
                      ] else
                        FilledButton(
                          onPressed: onEnter,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.18),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                  color: Colors.white.withOpacity(0.18)),
                            ),
                          ),
                          child: const Text("เข้าใช้งาน"),
                        ),
                    ],
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: isNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LandingHeroText(
                                  onEnter: onEnter, accent: scheme.primary),
                              const SizedBox(height: 18),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final tileW = (constraints.maxWidth - 14) / 2;
                                  return Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    children: [
                                      _LandingTile(
                                        width: tileW,
                                        height: 130,
                                        title: "Orders",
                                        icon: Icons.receipt_rounded,
                                      ),
                                      _LandingTile(
                                        width: tileW,
                                        height: 130,
                                        title: "Shipping",
                                        icon: Icons.local_shipping_outlined,
                                      ),
                                      _LandingTile(
                                        width: tileW,
                                        height: 130,
                                        title: "Stock",
                                        icon: Icons.inventory_2_rounded,
                                      ),
                                      _LandingTile(
                                        width: tileW,
                                        height: 130,
                                        title: "Assistant",
                                        icon: Icons.smart_toy_rounded,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 7,
                                child: _LandingHeroText(
                                  onEnter: onEnter,
                                  accent: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 28),
                              Expanded(
                                flex: 6,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final tileW =
                                        (constraints.maxWidth - 18) / 2;
                                    return Wrap(
                                      spacing: 18,
                                      runSpacing: 18,
                                      children: [
                                        _LandingTile(
                                          width: tileW,
                                          height: 150,
                                          title: "Orders",
                                          icon: Icons.receipt_rounded,
                                        ),
                                        _LandingTile(
                                          width: tileW,
                                          height: 150,
                                          title: "Shipping",
                                          icon: Icons.local_shipping_outlined,
                                        ),
                                        _LandingTile(
                                          width: tileW,
                                          height: 150,
                                          title: "Stock",
                                          icon: Icons.inventory_2_rounded,
                                        ),
                                        _LandingTile(
                                          width: tileW,
                                          height: 150,
                                          title: "Assistant",
                                          icon: Icons.smart_toy_rounded,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _webBuildTag,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.55),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingHeroText extends StatelessWidget {
  const _LandingHeroText({
    required this.onEnter,
    required this.accent,
  });

  final VoidCallback onEnter;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Thailand",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withOpacity(0.88),
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          "STOCK\nSCANNER",
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 0.92,
                letterSpacing: -1.4,
              ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            "จัดการสต็อก ออเดอร์ และการจัดส่งได้ในที่เดียว เหมาะสำหรับเปิดบน Chrome เพื่อคัดลอกข้อมูลลูกค้าจากแชทแล้ววางสร้างออเดอร์ได้ทันที",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.82),
                  height: 1.5,
                ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onEnter,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text("เข้าสู่ระบบ"),
        ),
      ],
    );
  }
}

class _LandingNavItem extends StatelessWidget {
  const _LandingNavItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _LandingTile extends StatelessWidget {
  const _LandingTile({
    required this.width,
    required this.height,
    required this.title,
    required this.icon,
  });

  final double width;
  final double height;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child:
                  Icon(icon, color: Colors.white.withOpacity(0.88), size: 28),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
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
        _userIdError =
            "\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01 User ID";
      });
      return;
    }
    if (pin.isEmpty) {
      setState(() {
        _pinError =
            "\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01 PIN";
      });
      return;
    }
    if (pin.length < 4) {
      setState(() {
        _pinError =
            "PIN \u0e15\u0e49\u0e2d\u0e07\u0e21\u0e35\u0e2d\u0e22\u0e48\u0e32\u0e07\u0e19\u0e49\u0e2d\u0e22 4 \u0e2b\u0e25\u0e31\u0e01";
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });
    _showAppSnack(context, "กำลังเข้าสู่ระบบ...");

    try {
      final session = await widget.api
          .login(userId: userId, pin: pin)
          .timeout(const Duration(seconds: 20));
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
      } else if (error is TimeoutException ||
          message.contains("TimeoutException")) {
        _showSnack("เชื่อมต่อช้าเกินไป (timeout) ลองใหม่อีกครั้ง");
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

    if (false)
      return Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                    20, 24, 20, 24 + safeBottom + keyboardBottom),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 24),
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
                              Text("เข้าสู่ระบบ",
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall),
                              const SizedBox(height: 8),
                              const Text(
                                "กรอก User ID และ PIN เพื่อเข้าใช้งานระบบ",
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _userIdController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r"[A-Za-z0-9_-]"),
                                  ),
                                  _UpperCaseTextFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  labelText: "User ID (เช่น EMP001)",
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
                                    icon: Icon(_obscurePin
                                        ? Icons.visibility
                                        : Icons.visibility_off),
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
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
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
                          Text(
                              "\u0e40\u0e02\u0e49\u0e32\u0e2a\u0e39\u0e48\u0e23\u0e30\u0e1a\u0e1a",
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          const Text(
                              "\u0e40\u0e02\u0e49\u0e32\u0e2a\u0e39\u0e48\u0e23\u0e30\u0e1a\u0e1a\u0e14\u0e49\u0e27\u0e22\u0e23\u0e2b\u0e31\u0e2a\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e41\u0e25\u0e30 PIN"),
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
                                icon: Icon(_obscurePin
                                    ? Icons.visibility
                                    : Icons.visibility_off),
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
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
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
  final GlobalKey<_DashboardPageState> _dashboardKey =
      GlobalKey<_DashboardPageState>();
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
        widget.api.websocketUri("/ws/realtime", {"token": token}).toString(),
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
        key: _dashboardKey,
        api: widget.api,
        refreshSignal: _realtimeRevision,
        currentUser: widget.currentUser,
        onOpenOrdersTab: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrdersPage(
                api: widget.api,
                currentUser: widget.currentUser,
                refreshSignal: _realtimeRevision,
              ),
            ),
          );
        },
      ),
      ScanPage(api: widget.api, currentUser: widget.currentUser),
      HistoryPage(api: widget.api, refreshSignal: _realtimeRevision),
      ChatAssistantPage(
        api: widget.api,
        refreshSignal: _realtimeRevision,
        onBack: () {
          setState(() {
            _currentIndex = 0;
          });
        },
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
                  tooltip:
                      "\u0e40\u0e1e\u0e34\u0e48\u0e21\u0e40\u0e15\u0e34\u0e21",
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
              if (index == 0) {
                _dashboardKey.currentState?.refreshNow();
              }
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
                icon: Icon(Icons.smart_toy_rounded),
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
    this.onBack,
  });

  final StockApiService api;
  final ValueListenable<int> refreshSignal;
  final VoidCallback? onBack;

  @override
  State<ChatAssistantPage> createState() => _ChatAssistantPageState();
}

class _ChatAssistantPageState extends State<ChatAssistantPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<_ChatMessage> _messages;
  bool _isSending = false;
  bool? _assistantAvailable;
  bool _isOpeningWithdraw = false;

  @override
  void initState() {
    super.initState();
    _messages = [
      _ChatMessage.bot(
        "ถามสต็อกหรือสั่งงานได้เลย เช่น \"อะไรใกล้หมดบ้าง\" หรือ \"เบิก 2 8851234567890\"",
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
        _ChatMessage.bot("สต็อกมีการอัปเดตแล้ว ถามใหม่ได้เลย"),
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
            "ยังดึงข้อมูลสต็อกไม่ได้: ${_normalizeFeedbackMessage(error.toString())}",
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
          title: const Text("ยืนยันคำสั่งสต็อก"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(action.summary),
              const SizedBox(height: 8),
              Text(
                "คำสั่งนี้จะบันทึกลงสต็อกจริงทันที",
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

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _openWithdrawFlow() async {
    if (_isOpeningWithdraw || _assistantAvailable == false) {
      return;
    }
    setState(() {
      _isOpeningWithdraw = true;
    });
    try {
      final products = await widget.api.getProducts();
      if (!mounted) return;

      final qtyController = TextEditingController(text: "1");
      String? selectedBarcode;

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.remove_circle_outline,
                          color: _brandPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "เบิกสินค้า",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: "ปิด",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Material(
                    type: MaterialType.transparency,
                    // DropdownMenu inside a modal bottom sheet has caused framework assertions
                    // on some devices/emulators. DropdownButtonFormField is more stable here.
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: (selectedBarcode != null &&
                              products.any((p) => p.barcode == selectedBarcode))
                          ? selectedBarcode
                          : null,
                      decoration: const InputDecoration(
                        labelText: "เลือกสินค้า",
                        hintText: "เลือกจากรายการ",
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text("— เลือกสินค้า —"),
                        ),
                        ...products.map(
                          (p) => DropdownMenuItem<String>(
                            value: p.barcode,
                            child: Text(
                              "${p.name} • ${p.barcode} • คงเหลือ ${p.currentStock} ${p.unit}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setSheetState(() {
                          selectedBarcode = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "จำนวนที่ต้องการเบิก",
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text("ยกเลิก"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (selectedBarcode == null ||
                                selectedBarcode!.trim().isEmpty) {
                              _showAppSnack(context, "กรุณาเลือกสินค้า",
                                  isError: true);
                              return;
                            }
                            final qty = int.tryParse(qtyController.text.trim());
                            if (qty == null || qty <= 0) {
                              _showAppSnack(context, "จำนวนไม่ถูกต้อง",
                                  isError: true);
                              return;
                            }
                            Navigator.of(sheetContext).pop(true);
                          },
                          child: const Text("เบิก"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (confirmed == true && mounted) {
        final qty = int.tryParse(qtyController.text.trim()) ?? 1;
        final barcode = (selectedBarcode ?? "").trim();
        if (barcode.isNotEmpty) {
          await _sendMessage("เบิก $qty $barcode");
        }
      }

      qtyController.dispose();
    } catch (error) {
      if (mounted) {
        _showAppSnack(
          context,
          "โหลดรายการสินค้าไม่สำเร็จ: ${_normalizeFeedbackMessage(error.toString())}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningWithdraw = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      "อะไรใกล้หมดบ้าง",
      "ขอไฟล์ Excel",
      "เบิกสินค้า",
    ];

    return Material(
      color: _brandSurface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: IconButton(
                      tooltip: "ย้อนกลับ",
                      onPressed: _handleBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, left: 6),
                      child: const _PageHeader(
                        title:
                            "\u0e41\u0e0a\u0e17\u0e1c\u0e39\u0e49\u0e0a\u0e48\u0e27\u0e22\u0e2a\u0e15\u0e4a\u0e2d\u0e01",
                        subtitle:
                            "\u0e16\u0e32\u0e21\u0e08\u0e33\u0e19\u0e27\u0e19\u0e04\u0e07\u0e40\u0e2b\u0e25\u0e37\u0e2d \u0e14\u0e39\u0e02\u0e2d\u0e07\u0e43\u0e01\u0e25\u0e49\u0e2b\u0e21\u0e14 \u0e2b\u0e23\u0e37\u0e2d\u0e2a\u0e31\u0e48\u0e07\u0e40\u0e1e\u0e34\u0e48\u0e21-\u0e15\u0e31\u0e14\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e41\u0e0a\u0e17\u0e44\u0e14\u0e49\u0e40\u0e25\u0e22",
                      ),
                    ),
                  ),
                ],
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
                      onPressed: _isSending
                          ? null
                          : () {
                              if (suggestion == "เบิกสินค้า") {
                                _openWithdrawFlow();
                                return;
                              }
                              _sendMessage(suggestion);
                            },
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
                    onOpenProduct: (product) =>
                        _showProductCodeSheet(context, product),
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
                        hintText:
                            "\u0e1e\u0e34\u0e21\u0e1e\u0e4c\u0e04\u0e33\u0e16\u0e32\u0e21\u0e40\u0e01\u0e35\u0e48\u0e22\u0e27\u0e01\u0e31\u0e1a\u0e2a\u0e15\u0e4a\u0e2d\u0e01...",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _isSending || _assistantAvailable == false
                        ? null
                        : _sendMessage,
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
  int _profileImageNonce = 0;
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _profileImageUrlController =
      TextEditingController();
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
        oldWidget.currentUser.profileImageUrl !=
            widget.currentUser.profileImageUrl ||
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
    _positionController.dispose();
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
    final userId = _userIdController.text.trim().toUpperCase();
    final userName = _userNameController.text.trim();
    final position = _positionController.text.trim();
    if (userId.isEmpty || userName.isEmpty) {
      _showSnack(
          "\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01\u0e23\u0e2b\u0e31\u0e2a\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e41\u0e25\u0e30\u0e0a\u0e37\u0e48\u0e2d\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e43\u0e2b\u0e49\u0e04\u0e23\u0e1a");
      return;
    }
    if (_pinController.text.trim().length < 4) {
      _showSnack(
          "PIN \u0e15\u0e49\u0e2d\u0e07\u0e21\u0e35\u0e2d\u0e22\u0e48\u0e32\u0e07\u0e19\u0e49\u0e2d\u0e22 4 \u0e2b\u0e25\u0e31\u0e01");
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
        position: position.isEmpty ? null : position,
        active: _active,
        pin: _pinController.text.trim(),
        profileImageUrl: _profileImageUrlController.text.trim().isEmpty
            ? null
            : _profileImageUrlController.text.trim(),
      );
      _userIdController.clear();
      _userNameController.clear();
      _positionController.clear();
      _pinController.clear();
      _profileImageUrlController.clear();
      setState(() {
        _role = "staff";
        _active = true;
      });
      await _reload();
      _showSnack(
          "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e40\u0e23\u0e35\u0e22\u0e1a\u0e23\u0e49\u0e2d\u0e22");
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
      _showSnack(
          "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2d\u0e22\u0e39\u0e48\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e1b\u0e34\u0e14\u0e44\u0e14\u0e49");
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
      _showSnack(
          "\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e25\u0e1a\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2d\u0e22\u0e39\u0e48\u0e44\u0e14\u0e49");
      return;
    }

    bool deleteMovements = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                  "\u0e25\u0e1a\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19 ${user.userName}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "\u0e15\u0e49\u0e2d\u0e07\u0e01\u0e32\u0e23\u0e25\u0e1a\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e02\u0e2d\u0e07 ${user.userId} \u0e2d\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e23\u0e30\u0e1a\u0e1a\u0e2b\u0e23\u0e37\u0e2d\u0e44\u0e21\u0e48"),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: deleteMovements,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                        "\u0e25\u0e1a\u0e1b\u0e23\u0e30\u0e27\u0e31\u0e15\u0e34\u0e01\u0e32\u0e23\u0e17\u0e33\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e02\u0e2d\u0e07\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19\u0e04\u0e19\u0e19\u0e35\u0e49\u0e14\u0e49\u0e27\u0e22"),
                    subtitle: const Text(
                        "\u0e40\u0e2b\u0e21\u0e32\u0e30\u0e2a\u0e33\u0e2b\u0e23\u0e31\u0e1a\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19\u0e40\u0e01\u0e48\u0e32\u0e17\u0e35\u0e48\u0e44\u0e21\u0e48\u0e15\u0e49\u0e2d\u0e07\u0e40\u0e01\u0e47\u0e1a\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e22\u0e49\u0e2d\u0e19\u0e2b\u0e25\u0e31\u0e07"),
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
                  child: const Text(
                      "\u0e25\u0e1a\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25"),
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
      String? filePath;
      List<int>? bytes;
      String? filename;

      if (kIsWeb) {
        final picked = await FilePicker.pickFiles(
          type: FileType.image,
          withData: true,
        );
        final platformFile =
            picked?.files.isNotEmpty == true ? picked!.files.first : null;
        if (platformFile == null) {
          _showSnack("ยังไม่ได้เลือกไฟล์รูป");
          return;
        }
        if (platformFile.bytes == null || platformFile.bytes!.isEmpty) {
          _showSnack(
              "ไม่สามารถอ่านไฟล์รูปจากเบราว์เซอร์ได้ ลองเลือกใหม่อีกครั้ง");
          return;
        }
        bytes = platformFile.bytes!;
        filename = platformFile.name;
      } else {
        final file = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1600,
        );
        if (file == null) {
          _showSnack("ยังไม่ได้เลือกรูป");
          return;
        }
        filePath = file.path;
        filename = file.name;
      }

      setState(() {
        _isUploadingProfileImage = true;
      });

      await widget.api.uploadProfileImage(
        requesterId: widget.currentUser.userId,
        targetUserId: targetUser.userId,
        filePath: filePath,
        bytes: bytes,
        filename: filename,
      );
      await _reload();
      if (mounted) {
        setState(() {
          // Bust browser caches so the new image shows immediately on web.
          _profileImageNonce = DateTime.now().millisecondsSinceEpoch;
        });
      }
      _showSnack(
          "\u0e2d\u0e31\u0e1b\u0e42\u0e2b\u0e25\u0e14\u0e23\u0e39\u0e1b\u0e42\u0e1b\u0e23\u0e44\u0e1f\u0e25\u0e4c\u0e40\u0e23\u0e35\u0e22\u0e1a\u0e23\u0e49\u0e2d\u0e22");
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
                    title: _profileUser.isAdmin
                        ? "\u0e42\u0e1b\u0e23\u0e44\u0e1f\u0e25\u0e4c\u0e41\u0e25\u0e30\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49"
                        : "\u0e42\u0e1b\u0e23\u0e44\u0e1f\u0e25\u0e4c",
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
                                    border: Border.all(
                                        color: _profileTeal.withOpacity(0.08)),
                                  ),
                                  child: _UserAvatar(
                                    imageUrl: (() {
                                      final base = widget.api.resolveAssetUrl(
                                        _profileUser.profileImageUrl,
                                      );
                                      if (base.isEmpty) return base;
                                      final nonce = _profileImageNonce;
                                      if (nonce == 0) return base;
                                      final sep =
                                          base.contains("?") ? "&" : "?";
                                      return "$base${sep}v=$nonce";
                                    })(),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: _brandDeep,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                height: 1,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 12),
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
                                        borderRadius:
                                            BorderRadius.circular(999),
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
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: _profileAccent.withOpacity(0.55),
                                        borderRadius:
                                            BorderRadius.circular(999),
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
                            side: BorderSide(
                                color: _brandPrimary.withOpacity(0.44)),
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
                            side: BorderSide(
                                color: _profileTeal.withOpacity(0.36)),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_a_photo_outlined),
                          label: const Text(
                              "\u0e40\u0e1b\u0e25\u0e35\u0e48\u0e22\u0e19\u0e23\u0e39\u0e1b"),
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
                          border: Border.all(
                              color: _brandPrimary.withOpacity(0.16)),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
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
                                labelText:
                                    "\u0e0a\u0e37\u0e48\u0e2d\u0e17\u0e35\u0e48\u0e41\u0e2a\u0e14\u0e07",
                                errorText: _displayNameError,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isUpdatingDisplayName
                                    ? null
                                    : _saveDisplayName,
                                child: _isUpdatingDisplayName
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text(
                                        "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e0a\u0e37\u0e48\u0e2d"),
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
                    label: const Text(
                        "\u0e2d\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e23\u0e30\u0e1a\u0e1a"),
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
                              fillColor: Color.lerp(
                                  _brandSurface, _brandSurfaceStrong, 0.14)!,
                              labelStyle: TextStyle(
                                color: _profileTeal.withOpacity(0.78),
                                fontWeight: FontWeight.w700,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(_radiusMd),
                                borderSide: BorderSide(
                                    color: _profileTeal.withOpacity(0.12)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(_radiusMd),
                                borderSide: BorderSide(
                                    color: _profileTeal.withOpacity(0.12)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(_radiusMd),
                                borderSide: const BorderSide(
                                    color: _profileTeal, width: 1.4),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "\u0e40\u0e1b\u0e25\u0e35\u0e48\u0e22\u0e19 PIN",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: _brandDeep,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "\u0e2d\u0e31\u0e1b\u0e40\u0e14\u0e15 PIN \u0e02\u0e2d\u0e07\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e43\u0e2b\u0e49\u0e1b\u0e25\u0e2d\u0e14\u0e20\u0e31\u0e22\u0e02\u0e36\u0e49\u0e19",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    _brandInk.withOpacity(0.72),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
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
                                  labelText:
                                      "PIN \u0e1b\u0e31\u0e08\u0e08\u0e38\u0e1a\u0e31\u0e19",
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureCurrentPin =
                                            !_obscureCurrentPin;
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
                                  labelText:
                                      "\u0e22\u0e37\u0e19\u0e22\u0e31\u0e19 PIN \u0e43\u0e2b\u0e21\u0e48",
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPin =
                                            !_obscureConfirmPin;
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(_radiusMd),
                                  ),
                                  elevation: 0,
                                  shadowColor: _profileTeal.withOpacity(0.18),
                                ),
                                icon: _isChangingPin
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
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
                        child: Text(
                            "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e19\u0e35\u0e49\u0e44\u0e21\u0e48\u0e21\u0e35\u0e2a\u0e34\u0e17\u0e18\u0e34\u0e4c\u0e08\u0e31\u0e14\u0e01\u0e32\u0e23\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49"),
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
                            Text(
                                "\u0e40\u0e1e\u0e34\u0e48\u0e21\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19",
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _userIdController,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r"[A-Za-z0-9_-]"),
                                ),
                                _UpperCaseTextFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText:
                                    "\u0e23\u0e2b\u0e31\u0e2a\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _userNameController,
                              decoration: const InputDecoration(
                                labelText:
                                    "\u0e0a\u0e37\u0e48\u0e2d\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _positionController,
                              decoration: const InputDecoration(
                                labelText: "ตำแหน่ง",
                                hintText: "เช่น ฝ่ายผลิต / QC / จัดส่ง",
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
                                labelText:
                                    "\u0e2a\u0e34\u0e17\u0e18\u0e34\u0e4c",
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: "staff",
                                    child: Text(
                                        "\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19")),
                                DropdownMenuItem(
                                    value: "admin",
                                    child: Text(
                                        "\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25")),
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
                              title: const Text(
                                  "\u0e40\u0e1b\u0e34\u0e14\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19"),
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
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.person_add_alt_1),
                              label: const Text(
                                  "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                        "\u0e23\u0e32\u0e22\u0e0a\u0e37\u0e48\u0e2d\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_radiusMd),
                        border:
                            Border.all(color: _brandPrimary.withOpacity(0.16)),
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
                              border: Border.all(
                                  color: _brandPrimary.withOpacity(0.10)),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: _brandDeep,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2d\u0e22\u0e39\u0e48\u0e08\u0e30\u0e44\u0e21\u0e48\u0e2a\u0e32\u0e21\u0e32\u0e23\u0e16\u0e1b\u0e34\u0e14\u0e2b\u0e23\u0e37\u0e2d\u0e25\u0e1a\u0e44\u0e14\u0e49",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
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
                      const _EmptyTile(
                          message:
                              "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49\u0e43\u0e19\u0e23\u0e30\u0e1a\u0e1a")
                    else
                      ...users.map(
                        (user) {
                          final isCurrentUser =
                              user.userId == widget.currentUser.userId;
                          final isAdmin =
                              user.role.trim().toLowerCase() == "admin";
                          final badgeColor = isAdmin ? _brandDeep : _brandInk;
                          final badgeBackground = isAdmin
                              ? _brandPrimary.withOpacity(0.24)
                              : _brandSurfaceStrong.withOpacity(0.26);
                          return Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 12, 14),
                              child: Row(
                                children: [
                                  _UserAvatar(
                                    imageUrl: widget.api
                                        .resolveAssetUrl(user.profileImageUrl),
                                    name: user.userName,
                                    radius: 24,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                user.userName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontSize: 17,
                                                    ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: badgeBackground,
                                                borderRadius:
                                                    BorderRadius.circular(999),
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color:
                                                    _brandInk.withOpacity(0.72),
                                              ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: _brandSurfaceStrong
                                                  .withOpacity(0.26),
                                              borderRadius:
                                                  BorderRadius.circular(999),
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
                                        tooltip:
                                            "\u0e15\u0e31\u0e27\u0e40\u0e25\u0e37\u0e2d\u0e01",
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
                                              leading: Icon(Icons
                                                  .add_photo_alternate_outlined),
                                              title: Text(
                                                  "\u0e2d\u0e31\u0e1b\u0e42\u0e2b\u0e25\u0e14\u0e23\u0e39\u0e1b"),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          if (!isCurrentUser)
                                            const PopupMenuItem<String>(
                                              value: "delete",
                                              child: ListTile(
                                                leading:
                                                    Icon(Icons.delete_outline),
                                                title: Text(
                                                    "\u0e25\u0e1a\u0e1e\u0e19\u0e31\u0e01\u0e07\u0e32\u0e19"),
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                        ],
                                        child: Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.78),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                              Icons.more_horiz_rounded,
                                              color: _brandInk),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCurrentUser)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 6),
                                              child: Tooltip(
                                                message:
                                                    "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e17\u0e35\u0e48\u0e01\u0e33\u0e25\u0e31\u0e07\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e25\u0e1a\u0e2b\u0e23\u0e37\u0e2d\u0e1b\u0e34\u0e14\u0e44\u0e21\u0e48\u0e44\u0e14\u0e49",
                                                child: Icon(Icons.lock_outline,
                                                    size: 18, color: _brandInk),
                                              ),
                                            ),
                                          Transform.scale(
                                            scale: 0.92,
                                            child: Switch.adaptive(
                                              value: user.active,
                                              onChanged: isCurrentUser
                                                  ? null
                                                  : (_) => _toggleUser(user),
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
    required this.onOpenOrdersTab,
  });

  final StockApiService api;
  final ValueListenable<int> refreshSignal;
  final AppUser currentUser;
  final VoidCallback onOpenOrdersTab;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with RouteAware {
  late Future<DashboardData> _future;
  final TextEditingController _productSearchController =
      TextEditingController();
  String _productSearch = "";

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.refreshSignal.addListener(_handleRealtimeRefresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      _StockScannerAppState._routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    widget.refreshSignal.removeListener(_handleRealtimeRefresh);
    _StockScannerAppState._routeObserver.unsubscribe(this);
    super.dispose();
  }

  void refreshNow() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  @override
  void didPopNext() {
    // Returned to Dashboard from another page -> refresh.
    refreshNow();
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _productSearch.trim().toLowerCase();
    if (query.isEmpty) {
      return const <Product>[];
    }
    return products
        .where((product) {
          return product.name.toLowerCase().contains(query) ||
              product.barcode.toLowerCase().contains(query) ||
              (product.sku?.toLowerCase().contains(query) ?? false);
        })
        .take(12)
        .toList();
  }

  void _handleRealtimeRefresh() {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = _load();
    });
  }

  Future<void> _showOrderPreview(DeliveryOrder order) async {
    final statusLabel = order.status == "new"
        ? "ใหม่"
        : order.status == "assigned"
            ? "มอบหมายแล้ว"
            : order.status == "preparing"
                ? "กำลังจัดสินค้า"
                : order.status == "out_for_delivery"
                    ? "กำลังส่ง"
                    : order.status == "delivered"
                        ? "ส่งแล้ว"
                        : order.status == "cancelled"
                            ? "ยกเลิก"
                            : order.status;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.5,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "ใบสรุปออเดอร์",
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.customerName,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await Navigator.of(this.context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderChatPage(
                              api: widget.api,
                              currentUser: widget.currentUser,
                              order: order,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text("แชทติดตามงาน"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _ReceiptDivider(),
                  const SizedBox(height: 8),
                  _receiptRow("สถานะ", statusLabel),
                  _receiptRow("ผู้รับออเดอร์", order.createdByName),
                  _receiptRow(
                      "ผู้ส่ง", order.assignedToName ?? "ยังไม่มอบหมาย"),
                  if (order.customerPhone != null &&
                      order.customerPhone!.isNotEmpty)
                    _receiptRow("โทร", order.customerPhone!),
                  if (order.customerAddress != null &&
                      order.customerAddress!.isNotEmpty)
                    _receiptRow("ที่อยู่", order.customerAddress!),
                  if (order.note != null && order.note!.isNotEmpty)
                    _receiptRow("หมายเหตุ", order.note!),
                  const SizedBox(height: 10),
                  const _ReceiptDivider(),
                  const SizedBox(height: 8),
                  Text("รายการสินค้า",
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.productName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "x${item.quantity} ${item.unit}",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _ReceiptDivider(),
                  const SizedBox(height: 8),
                  _receiptRow("รวมรายการ", "${order.items.length} รายการ",
                      bold: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: _brandInk.withOpacity(0.85),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const Text(": "),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _brandDeep,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<DashboardData> _load() async {
    final results = await Future.wait([
      widget.api.getSummary(),
      widget.api.getProducts(),
      widget.api.getOrders(requesterId: widget.currentUser.userId, limit: 300),
    ]);
    final allOrders = results[2] as List<DeliveryOrder>;
    int duePriority(DeliveryOrder order) {
      final dueAt = order.scheduledDeliveryAt;
      if (dueAt == null) {
        return 9999;
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
      return dueDay.difference(today).inDays;
    }

    final activeOrders = allOrders
        .where((order) =>
            order.status != "delivered" && order.status != "cancelled")
        .toList()
      ..sort((a, b) {
        final dueCompare = duePriority(a).compareTo(duePriority(b));
        if (dueCompare != 0) {
          return dueCompare;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final todayUpdatedOrders = activeOrders
        .where((order) =>
            order.updatedAt.isAfter(startOfToday) ||
            order.updatedAt.isAtSameMomentAs(startOfToday))
        .take(4)
        .toList();
    return DashboardData(
      summary: results[0] as StockSummary,
      products: results[1] as List<Product>,
      activeOrders: activeOrders.take(6).toList(),
      todayUpdatedOrders: todayUpdatedOrders,
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
          final matchedProducts = _filterProducts(data.products);
          if (kIsWeb) {
            return ColoredBox(
              color: _brandSurface,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: _WebDashboardHome(
                      data: data,
                      onOpenOrdersTab: widget.onOpenOrdersTab,
                      productSearchController: _productSearchController,
                      productSearch: _productSearch,
                      onProductSearchChanged: (value) {
                        setState(() {
                          _productSearch = value;
                        });
                      },
                      onClearProductSearch: () {
                        _productSearchController.clear();
                        setState(() {
                          _productSearch = "";
                        });
                      },
                      matchedProducts: matchedProducts,
                    ),
                  ),
                ),
              ),
            );
          }

          return _MobileDashboardHome(
            data: data,
            currentUser: widget.currentUser,
            onOpenOrdersTab: widget.onOpenOrdersTab,
            onOpenOrderPreview: _showOrderPreview,
          );

          const listPadding = EdgeInsets.all(16);
          return ColoredBox(
            color: _brandSurface,
            child: ListView(
              padding: listPadding,
              children: [
                const _PageHeader(
                  title:
                      "\u0e20\u0e32\u0e1e\u0e23\u0e27\u0e21\u0e2a\u0e15\u0e4a\u0e2d\u0e01",
                  subtitle:
                      "\u0e20\u0e32\u0e1e\u0e23\u0e27\u0e21\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e41\u0e25\u0e30\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e17\u0e35\u0e48\u0e15\u0e49\u0e2d\u0e07\u0e14\u0e39\u0e41\u0e25",
                ),
                const SizedBox(height: 16),
                _DashboardIdentityCard(
                  imageUrl: widget.api
                      .resolveAssetUrl(widget.currentUser.profileImageUrl),
                  name: widget.currentUser.userName,
                  roleLabel: _roleLabel(widget.currentUser.role),
                  positionLabel: widget.currentUser.position,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: "\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32",
                        value: "${data.summary.totalProducts}",
                        icon: Icons.inventory_2_rounded,
                        tone: _profileTeal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        title:
                            "\u0e08\u0e33\u0e19\u0e27\u0e19\u0e23\u0e27\u0e21",
                        value: "${data.summary.totalUnits}",
                        icon: Icons.layers_outlined,
                        tone: _profileAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        title:
                            "\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e15\u0e48\u0e33",
                        value: "${data.summary.lowStockCount}",
                        icon: Icons.warning_amber_outlined,
                        tone: _brandPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (data.activeOrders.isNotEmpty)
                  Card(
                    color: _brandPrimary.withOpacity(0.06),
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping_outlined,
                          color: _brandPrimary),
                      title: Text(
                          "งานค้างส่ง ${data.activeOrders.length} ออเดอร์"),
                      subtitle:
                          const Text("แตะเพื่อเปิดแท็บออเดอร์และจัดส่งทันที"),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: widget.onOpenOrdersTab,
                    ),
                  ),
                if (data.activeOrders.isNotEmpty) const SizedBox(height: 12),
                Text(
                  "อัปเดตใหม่วันนี้",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (data.todayUpdatedOrders.isEmpty)
                  const _EmptyTile(
                      message: "ยังไม่มีออเดอร์ที่อัปเดตใหม่วันนี้")
                else
                  ...data.todayUpdatedOrders.map(
                    (order) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: _brandPrimary.withOpacity(0.04),
                      child: ListTile(
                        onTap: () => _showOrderPreview(order),
                        leading: CircleAvatar(
                          backgroundColor: _brandPrimary.withOpacity(0.10),
                          child: const Icon(
                            Icons.update_rounded,
                            color: _brandPrimary,
                          ),
                        ),
                        title: Text(
                          order.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "อัปเดต ${order.updatedAt.day.toString().padLeft(2, "0")}/${order.updatedAt.month.toString().padLeft(2, "0")}/${order.updatedAt.year} ${order.updatedAt.hour.toString().padLeft(2, "0")}:${order.updatedAt.minute.toString().padLeft(2, "0")}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: widget.onOpenOrdersTab,
                          child: const Text("ดู"),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _productSearchController,
                  onChanged: (value) {
                    setState(() {
                      _productSearch = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "พิมพ์ชื่อสินค้าเพื่อค้นหาและพิมพ์ป้าย",
                    hintText: "เช่น Printer Paper, น้ำดื่ม, 8850...",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _productSearch.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _productSearchController.clear();
                              setState(() {
                                _productSearch = "";
                              });
                            },
                            icon: const Icon(Icons.close),
                            tooltip: "ล้างคำค้น",
                          ),
                  ),
                ),
                if (_productSearch.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showCustomLabelSheet(
                        context,
                        _productSearch.trim(),
                      ),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text("พิมพ์ชื่อที่ค้นหาอยู่เลย"),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "ผลการค้นหา",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (matchedProducts.isEmpty)
                    const _EmptyTile(
                        message:
                            "ไม่พบสินค้าที่ค้นหา ลองพิมพ์ชื่อสินค้า บาร์โค้ด หรือ SKU")
                  else
                    ...matchedProducts.map(
                      (item) => _ProductTile(
                        product: item,
                        onOpenCode: () => _showProductCodeSheet(context, item),
                        onPrintLabel: () =>
                            _showProductCodeSheet(context, item),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
                Text(
                    "\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e15\u0e48\u0e33",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (data.summary.lowStockItems.isEmpty)
                  const _EmptyTile(
                      message:
                          "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e17\u0e35\u0e48\u0e15\u0e48\u0e33\u0e01\u0e27\u0e48\u0e32\u0e08\u0e38\u0e14\u0e40\u0e15\u0e37\u0e2d\u0e19")
                else
                  ...data.summary.lowStockItems.map(
                    (item) => _ProductTile(
                      product: item,
                      onOpenCode: () => _showProductCodeSheet(context, item),
                      onPrintLabel: () => _showProductCodeSheet(context, item),
                    ),
                  ),
                const SizedBox(height: 20),
                Text("อัปเดตล่าสุด",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (data.activeOrders.isNotEmpty)
                  ...data.activeOrders.map(
                    (order) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: () => _showOrderPreview(order),
                              leading: CircleAvatar(
                                backgroundColor:
                                    _brandPrimary.withOpacity(0.10),
                                child: const Icon(Icons.local_shipping_outlined,
                                    color: _brandPrimary),
                              ),
                              title: Text(order.customerName,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                "${order.items.length} รายการ · ผู้ส่ง: ${order.assignedToName ?? "ยังไม่มอบหมาย"}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (order.status == "out_for_delivery"
                                          ? _brandPrimary
                                          : _profileAccent)
                                      .withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  order.status == "new"
                                      ? "ใหม่"
                                      : order.status == "assigned"
                                          ? "มอบหมายแล้ว"
                                          : order.status == "preparing"
                                              ? "กำลังจัด"
                                              : order.status ==
                                                      "out_for_delivery"
                                                  ? "กำลังส่ง"
                                                  : order.status,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showOrderPreview(order),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text("ดูออเดอร์"),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: widget.onOpenOrdersTab,
                                  icon:
                                      const Icon(Icons.local_shipping_outlined),
                                  label: const Text("ไปจัดส่ง"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Notifications removed (kept stock changes in History instead).
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 10).floor().clamp(12, 60);
        return Row(
          children: List.generate(
            dashCount,
            (_) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                height: 1.4,
                color: _brandPrimary.withOpacity(0.35),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileDashboardHome extends StatelessWidget {
  const _MobileDashboardHome({
    required this.data,
    required this.currentUser,
    required this.onOpenOrdersTab,
    required this.onOpenOrderPreview,
  });

  final DashboardData data;
  final AppUser currentUser;
  final VoidCallback onOpenOrdersTab;
  final Future<void> Function(DeliveryOrder order) onOpenOrderPreview;

  Color _statusTone(String status) {
    switch (status) {
      case "new":
        return const Color(0xFF7DB8E8);
      case "assigned":
        return _profileTeal;
      case "in_production":
        return const Color(0xFF5B8CFF);
      case "qc_pending":
        return const Color(0xFFF5A623);
      case "qc_passed":
        return const Color(0xFF2E9E6F);
      case "preparing":
        return const Color(0xFF8A6DFF);
      case "out_for_delivery":
        return _brandPrimary;
      case "delivered":
        return _brandDeep;
      case "cancelled":
        return const Color(0xFFD64545);
      default:
        return _brandInk;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "new":
        return "ใหม่";
      case "assigned":
        return "มอบหมายแล้ว";
      case "in_production":
        return "กำลังผลิต";
      case "qc_pending":
        return "รอ QC";
      case "rework_required":
        return "ต้องแก้ไข";
      case "qc_passed":
        return "ผ่าน QC";
      case "preparing":
        return "กำลังจัดสินค้า";
      case "out_for_delivery":
        return "กำลังส่ง";
      case "delivered":
        return "ส่งแล้ว";
      case "cancelled":
        return "ยกเลิก";
      default:
        return status;
    }
  }

  String _stageLabel(String status) {
    switch (status) {
      case "new":
        return "ขั้นตอนตอนนี้: รอเริ่มงาน";
      case "assigned":
        return "ขั้นตอนตอนนี้: มอบหมายผู้รับผิดชอบแล้ว";
      case "in_production":
        return "ขั้นตอนตอนนี้: อยู่ระหว่างผลิต";
      case "qc_pending":
        return "ขั้นตอนตอนนี้: รอตรวจคุณภาพ";
      case "rework_required":
        return "ขั้นตอนตอนนี้: ต้องแก้ไขก่อนส่งต่อ";
      case "qc_passed":
        return "ขั้นตอนตอนนี้: ผ่าน QC แล้ว";
      case "preparing":
        return "ขั้นตอนตอนนี้: กำลังจัดของ";
      case "out_for_delivery":
        return "ขั้นตอนตอนนี้: ออกจัดส่งแล้ว";
      case "delivered":
        return "ขั้นตอนตอนนี้: ส่งสำเร็จ";
      case "cancelled":
        return "ขั้นตอนตอนนี้: ยกเลิกออเดอร์";
      default:
        return "ขั้นตอนตอนนี้: $status";
    }
  }

  int? _daysUntilDue(DeliveryOrder order) {
    final dueAt = order.scheduledDeliveryAt;
    if (dueAt == null) {
      return null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
    return dueDay.difference(today).inDays;
  }

  Color? _dueTone(DeliveryOrder order) {
    final days = _daysUntilDue(order);
    if (days == null) {
      return null;
    }
    if (days <= 1) {
      return const Color(0xFFD64545);
    }
    if (days == 2) {
      return const Color(0xFFF28C28);
    }
    if (days == 3) {
      return const Color(0xFFE0B21B);
    }
    return null;
  }

  BoxDecoration _mobileOrderDecoration(Color tone, {bool emphasize = false}) {
    final base = emphasize ? tone.withOpacity(0.16) : tone.withOpacity(0.10);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.96),
          base,
          tone.withOpacity(emphasize ? 0.12 : 0.08),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: tone.withOpacity(0.16)),
      boxShadow: [
        BoxShadow(
          color: tone.withOpacity(0.10),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Widget _buildMobileOrderCard(
    BuildContext context,
    DeliveryOrder order, {
    required bool emphasizeDue,
    String? eyebrow,
    String? supporting,
  }) {
    final tone = _statusTone(order.status);
    final dueTone = _dueTone(order);
    final accent = dueTone ?? tone;
    final dueText = order.scheduledDeliveryAt != null
        ? "กำหนดส่ง: ${_formatDateTime(order.scheduledDeliveryAt!)}"
        : "อัปเดต: ${_formatDateTime(order.updatedAt)}";
    final supportingText = supporting ??
        "${order.items.length} รายการ · ผู้ส่ง: ${order.createdByName}";

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _HoverLift(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onOpenOrderPreview(order),
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: _mobileOrderDecoration(
                accent,
                emphasize: emphasizeDue || dueTone != null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow.toUpperCase(),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.88),
                                accent.withOpacity(0.18),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            emphasizeDue
                                ? Icons.notification_important_outlined
                                : Icons.receipt_rounded,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: _brandDeep,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                supportingText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: _brandInk.withOpacity(0.70),
                                      height: 1.35,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _OrderStatusPill(
                          label: _statusLabel(order.status),
                          tone: accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _stageLabel(order.status),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _brandDeep,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dueText,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    if (dueTone != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: dueTone.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: dueTone.withOpacity(0.16)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.priority_high_rounded,
                              size: 18,
                              color: dueTone,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "ออเดอร์นี้ใกล้ถึงกำหนดส่งแล้ว",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: dueTone,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestOrders = data.activeOrders.take(4).toList();
    final todayOrders = data.todayUpdatedOrders.take(4).toList();
    final unreadOrders = data.activeOrders
        .where((order) => order.unreadCount > 0)
        .toList()
      ..sort((a, b) => b.unreadCount.compareTo(a.unreadCount));
    final outOfStock = data.products.where((p) => p.currentStock <= 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ColoredBox(
      color: _brandSurface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _DashboardSectionHeader(
            eyebrow: "Dashboard",
            title: "ภาพรวมสต็อก",
            subtitle: "ดูออเดอร์ งานค้าง และรายการอัปเดตล่าสุดจากมือถือ",
          ),
          const SizedBox(height: 16),
          Container(
            decoration: _softPanelDecoration(
              tone: _brandPrimary,
              radius: 24,
              surfaceStrength: 0.72,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser.userName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _brandDeep,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "เช็กงานที่ต้องตามต่อวันนี้ได้ในหน้าเดียว",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _brandInk.withOpacity(0.72),
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HeroInfoChip(
                        icon: Icons.badge_outlined,
                        label: _roleLabel(currentUser.role),
                      ),
                      _HeroInfoChip(
                        icon: Icons.local_shipping_outlined,
                        label: "งานค้าง ${data.activeOrders.length} ออเดอร์",
                      ),
                      _HeroInfoChip(
                        icon: Icons.update_rounded,
                        label:
                            "อัปเดตใหม่วันนี้ ${data.todayUpdatedOrders.length}",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (data.activeOrders.isNotEmpty)
            _ActionBanner(
              title: "งานค้างส่ง ${data.activeOrders.length} ออเดอร์",
              subtitle: "แตะเพื่อเปิดหน้าออเดอร์และจัดการงานค้างต่อ",
              icon: Icons.local_shipping_outlined,
              onTap: onOpenOrdersTab,
            ),
          if (outOfStock.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ActionBanner(
              title: "สินค้าหมด: ${outOfStock.length} รายการ",
              subtitle: outOfStock.take(3).map((p) => p.name).join(" · "),
              icon: Icons.inventory_2_outlined,
              tone: Colors.redAccent,
              onTap: () => _showOutOfStockSheet(context, outOfStock),
            ),
          ],
          if (unreadOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ActionBanner(
              title: "แชทค้างอ่าน ${unreadOrders.length} ออเดอร์",
              subtitle: unreadOrders
                  .take(3)
                  .map((o) => "${o.customerName} (+${o.unreadCount})")
                  .join(" • "),
              icon: Icons.mark_chat_unread_rounded,
              tone: Colors.redAccent,
              onTap: onOpenOrdersTab,
            ),
          ],
          const SizedBox(height: 22),
          const _DashboardSectionHeader(
            eyebrow: "Focus now",
            title: "ออเดอร์ล่าสุด",
            subtitle: "ดูสถานะ ขั้นตอนปัจจุบัน และกำหนดส่งได้ทันที",
          ),
          const SizedBox(height: 12),
          if (latestOrders.isEmpty)
            const _EmptyTile(message: "ยังไม่มีรายการออเดอร์")
          else
            ...latestOrders.map(
              (order) => _buildMobileOrderCard(
                context,
                order,
                emphasizeDue: _dueTone(order) != null,
              ),
            ),
          const SizedBox(height: 8),
          const _DashboardSectionHeader(
            eyebrow: "Realtime feed",
            title: "อัปเดตใหม่วันนี้",
            subtitle: "รายการที่มีการเปลี่ยนแปลงล่าสุดในวันนี้",
          ),
          const SizedBox(height: 12),
          if (todayOrders.isEmpty)
            const _EmptyTile(message: "ยังไม่มีออเดอร์ที่อัปเดตใหม่วันนี้")
          else
            ...todayOrders.map(
              (order) => _buildMobileOrderCard(
                context,
                order,
                emphasizeDue: false,
                eyebrow: "Order update",
                supporting: "อัปเดต ${_formatDateTime(order.updatedAt)}",
              ),
            ),
        ],
      ),
    );
  }
}

class _WebDashboardHero extends StatelessWidget {
  const _WebDashboardHero();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 900 ? 38.0 : (width < 1200 ? 46.0 : 52.0);
    final subtitleSize = width < 900 ? 14.0 : (width < 1200 ? 15.5 : 17.0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(_brandSurface, _brandSurfaceStrong, 0.42)!,
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(_radiusLg),
        border: Border.all(color: _brandPrimary.withOpacity(0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1FB56A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Dashboard workspace",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _brandDeep,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "STOCK SCANNER",
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: _brandDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: titleSize,
                    height: 0.98,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              "หน้าแรกสำหรับใช้งานบน Chrome\nคัดลอกข้อมูลลูกค้าแล้ววางสร้างออเดอร์ได้ทันที",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _brandInk.withOpacity(0.84),
                    fontSize: subtitleSize,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _HeroInfoChip(
                  icon: Icons.content_paste_go_rounded,
                  label: "คัดลอกลูกค้าแล้วสร้างออเดอร์ต่อได้ทันที",
                ),
                _HeroInfoChip(
                  icon: Icons.bolt_rounded,
                  label: "เข้าถึงงานสต็อกและผู้ช่วยได้เร็ว",
                ),
                _HeroInfoChip(
                  icon: Icons.auto_awesome_rounded,
                  label: "พร้อมสำหรับ workflow บน Chrome",
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: const [
                _HeroQuickTile(
                  label: "Orders",
                  icon: Icons.receipt_rounded,
                  hint: "เปิดออเดอร์และจัดส่ง",
                  tab: "orders",
                ),
                _HeroQuickTile(
                  label: "Stock",
                  icon: Icons.inventory_2_rounded,
                  hint: "ค้นหาสินค้าและพิมพ์ป้าย",
                  tab: "stock",
                ),
                _HeroQuickTile(
                  label: "Assistant",
                  icon: Icons.smart_toy_rounded,
                  hint: "ถามสต็อกและขอไฟล์",
                  tab: "assistant",
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.70),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _brandPrimary.withOpacity(0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _brandPrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.show_chart_rounded,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1FB56A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              "Live",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: _brandDeep,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.rocket_launch_rounded,
                            color: _brandPrimary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "โหมดใช้งานเร็วสำหรับเปิดออเดอร์และสต็อกต่อเนื่อง",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _brandInk.withOpacity(0.76),
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "พร้อมสำหรับงานวันนี้",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _brandDeep,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "เปิดออเดอร์ เช็กสต็อก หรือเข้า assistant ได้จากทางลัดด้านบนโดยไม่ต้องไล่หาหลายหน้า",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _brandInk.withOpacity(0.76),
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1FB56A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Workspace online",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: _brandDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Text(
                          _webBuildTag,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _brandInk.withOpacity(0.55),
                                  ),
                        ),
                      ],
                    ),
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

class _WebDashboardHome extends StatelessWidget {
  const _WebDashboardHome({
    required this.data,
    required this.onOpenOrdersTab,
    required this.productSearchController,
    required this.productSearch,
    required this.onProductSearchChanged,
    required this.onClearProductSearch,
    required this.matchedProducts,
  });

  final DashboardData data;
  final VoidCallback onOpenOrdersTab;
  final TextEditingController productSearchController;
  final String productSearch;
  final ValueChanged<String> onProductSearchChanged;
  final VoidCallback onClearProductSearch;
  final List<Product> matchedProducts;

  @override
  Widget build(BuildContext context) {
    final unreadOrders = data.activeOrders
        .where((order) => order.unreadCount > 0)
        .toList()
      ..sort((a, b) => b.unreadCount.compareTo(a.unreadCount));
    final outOfStock = data.products.where((p) => p.currentStock <= 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _WebDashboardHero(),
        const SizedBox(height: 22),
        const _DashboardSectionHeader(
          eyebrow: "Order focus",
          title: "งานค้างส่ง",
          subtitle: "ดูออเดอร์ล่าสุดและเช็กขั้นตอนงานได้ทันทีจากด้านบน",
        ),
        const SizedBox(height: 10),
        if (data.activeOrders.isEmpty)
          const _EmptyTile(message: "ยังไม่มีออเดอร์ค้างส่ง")
        else ...[
          if (unreadOrders.isNotEmpty) ...[
            _HeroReveal(
              delayMs: 40,
              child: _ActionBanner(
                title: "แชทค้างอ่าน ${unreadOrders.length} ออเดอร์",
                subtitle: unreadOrders
                    .take(3)
                    .map((o) => "${o.customerName} (+${o.unreadCount})")
                    .join(" · "),
                icon: Icons.chat_bubble_outline,
                tone: Colors.redAccent,
                onTap: onOpenOrdersTab,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _HeroReveal(
            delayMs: 80,
            child: _ActionBanner(
              title: "งานค้างส่ง ${data.activeOrders.length} ออเดอร์",
              subtitle:
                  "แตะเพื่อเปิดหน้าออเดอร์ หรือดูขั้นตอนปัจจุบันจากรายการด้านล่าง",
              icon: Icons.local_shipping_outlined,
              onTap: onOpenOrdersTab,
            ),
          ),
          const SizedBox(height: 12),
          ...data.activeOrders.toList().asMap().entries.map(
                (entry) => _HeroReveal(
                  delayMs: 120 + (entry.key * 40),
                  child: _DashboardUpdateCard(
                    order: entry.value,
                    onTap: onOpenOrdersTab,
                  ),
                ),
              ),
          const SizedBox(height: 18),
        ],
        // Keep the homepage short: move product search to the Stock tab.
        const SizedBox(height: 18),
        const _DashboardSectionHeader(
          eyebrow: "Overview",
          title: "ภาพรวมด่วน",
          subtitle: "แตะการ์ดเพื่อไปยังงานที่ควรทำต่อทันที",
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickStatCard(
              title: "สินค้าใกล้หมด",
              value: "${data.summary.lowStockCount}",
              subtitle: "รายการที่ควรเติมสต็อก",
              icon: Icons.warning_amber_rounded,
              tone: _brandPrimary,
            ),
            _QuickStatCard(
              title: "ออเดอร์ค้างส่ง",
              value: "${data.activeOrders.length}",
              subtitle: "งานที่ยังต้องติดตาม",
              icon: Icons.local_shipping_outlined,
              tone: _profileTeal,
              onTap: onOpenOrdersTab,
            ),
            _QuickStatCard(
              title: "สินค้าทั้งหมด",
              value: "${data.summary.totalProducts}",
              subtitle: "พร้อมค้นหาและพิมพ์ป้าย",
              icon: Icons.inventory_2_rounded,
              tone: _profileAccent,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _DashboardSectionHeader(
          eyebrow: "Focus now",
          title: "ต้องดูต่อ",
          subtitle: "รายการสำคัญที่ควรเปิดเช็กจากหน้า dashboard",
        ),
        const SizedBox(height: 10),
        if (outOfStock.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: () => _showOutOfStockSheet(context, outOfStock),
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text("สินค้าหมด: ${outOfStock.length} รายการ"),
            ),
          ),
          const SizedBox(height: 10),
        ],
        ...data.summary.lowStockItems.take(3).map(
              (item) => _LowStockFocusCard(
                product: item,
                onTap: () => _showProductCodeSheet(context, item),
              ),
            ),
        const SizedBox(height: 18),
        // The homepage already shows active orders above; avoid duplicating the same feed.
      ],
    );
  }
}

class _HeroQuickTile extends StatelessWidget {
  const _HeroQuickTile({
    required this.label,
    required this.icon,
    required this.hint,
    required this.tab,
  });

  final String label;
  final IconData icon;
  final String hint;
  final String tab;

  void _open(BuildContext context) {
    // Keep navigation web-friendly and decoupled from private tab state.
    final state = context.findAncestorStateOfType<_StockHomePageState>();
    if (state == null) return;

    if (tab == "assistant") {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatAssistantPage(
            api: state.widget.api,
            refreshSignal: state._realtimeRevision,
          ),
        ),
      );
      return;
    }

    if (tab == "orders") {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrdersPage(
            api: state.widget.api,
            currentUser: state.widget.currentUser,
            refreshSignal: state._realtimeRevision,
          ),
        ),
      );
      return;
    }

    // "stock" -> just scroll users down to the search field on this page.
    _showAppSnack(context, "เลื่อนลงเพื่อค้นหาสินค้าและพิมพ์ป้าย");
  }

  @override
  Widget build(BuildContext context) {
    final accent = tab == "assistant"
        ? _profileAccent
        : tab == "stock"
            ? _profileTeal
            : _brandPrimary;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1100;
    return _HoverLift(
      lift: 10,
      scale: 1.012,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: compact ? 222 : 248,
          padding: EdgeInsets.all(compact ? 16 : 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.94),
                Color.lerp(Colors.white, accent, 0.08)!.withOpacity(0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 46 : 50,
                height: compact ? 46 : 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withOpacity(0.18),
                      Color.lerp(_brandSurfaceStrong, accent, 0.24)!
                          .withOpacity(0.34),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _brandDeep,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 16 : 17,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _brandInk.withOpacity(0.72),
                            fontSize: compact ? 12.4 : 13.2,
                            height: 1.32,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        "Open now",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: accent.withOpacity(0.82),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroGridPainter extends CustomPainter {
  const _HeroGridPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    const spacing = 34.0;
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class _HoverLift extends StatefulWidget {
  const _HoverLift({
    required this.child,
    this.lift = 8,
    this.scale = 1.01,
  });

  final Widget child;
  final double lift;
  final double scale;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = kIsWeb && _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: active ? widget.scale : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, active ? -widget.lift : 0, 0),
          child: widget.child,
        ),
      ),
    );
  }
}

class _HeroReveal extends StatefulWidget {
  const _HeroReveal({
    required this.child,
    this.delayMs = 0,
  });

  final Widget child;
  final int delayMs;

  @override
  State<_HeroReveal> createState() => _HeroRevealState();
}

class _HeroRevealState extends State<_HeroReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.08),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 360),
        opacity: _visible ? 1 : 0,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.70),
            Colors.white.withOpacity(0.50),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _brandPrimary.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _brandPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _brandDeep,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  const _DashboardSectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _brandPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _brandDeep,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _brandInk.withOpacity(0.72),
              ),
        ),
      ],
    );
  }
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.tone,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? _brandPrimary;
    return _HoverLift(
      lift: 6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withOpacity(0.12),
                  Color.lerp(accent, _profileTeal, 0.35)!.withOpacity(0.10),
                  _brandSurfaceStrong.withOpacity(0.34),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withOpacity(0.14)),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.86),
                        Colors.white.withOpacity(0.68),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: _brandDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _brandInk.withOpacity(0.72),
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: _brandDeep),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tone,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      lift: 4,
      scale: 1.006,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            width: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: tone.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: tone.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
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
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _brandDeep,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _brandInk.withOpacity(0.72),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LowStockFocusCard extends StatelessWidget {
  const _LowStockFocusCard({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _brandPrimary.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _brandPrimary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: _brandPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _brandDeep,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${product.barcode} · คงเหลือ ${product.currentStock} ${product.unit}",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _brandInk.withOpacity(0.74),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _brandPrimary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "min ${product.minimumStock}",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _brandPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "เปิดบาร์โค้ด",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _brandInk.withOpacity(0.62),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardUpdateCard extends StatelessWidget {
  const _DashboardUpdateCard({
    required this.order,
    required this.onTap,
  });

  final DeliveryOrder order;
  final VoidCallback onTap;

  String _displayStatusLabel() {
    switch (order.status) {
      case "new":
        return "ออเดอร์ใหม่";
      case "assigned":
        return "มอบหมายแล้ว";
      case "in_production":
        return "เริ่มผลิต";
      case "qc_pending":
        return "รอ QC";
      case "rework_required":
        return "ต้องแก้งาน";
      case "qc_passed":
        return "ผ่าน QC";
      case "preparing":
        return "กำลังจัดเตรียม";
      case "out_for_delivery":
        return "กำลังจัดส่ง";
      case "delivered":
        return "ส่งแล้ว";
      case "cancelled":
        return "ยกเลิก";
      default:
        return order.status;
    }
  }

  String _displayStageLabel() {
    switch (order.status) {
      case "new":
        return "ขั้นตอนตอนนี้: รอเริ่มงาน";
      case "assigned":
        return "ขั้นตอนตอนนี้: มอบหมายผู้รับผิดชอบแล้ว";
      case "in_production":
        return "ขั้นตอนตอนนี้: อยู่ระหว่างผลิต";
      case "qc_pending":
        return "ขั้นตอนตอนนี้: รอตรวจคุณภาพ";
      case "rework_required":
        return "ขั้นตอนตอนนี้: ต้องแก้ไขก่อนส่งต่อ";
      case "qc_passed":
        return "ขั้นตอนตอนนี้: ผ่าน QC แล้ว";
      case "preparing":
        return "ขั้นตอนตอนนี้: กำลังจัดของ";
      case "out_for_delivery":
        return "ขั้นตอนตอนนี้: ออกจัดส่งแล้ว";
      case "delivered":
        return "ขั้นตอนตอนนี้: ส่งสำเร็จ";
      case "cancelled":
        return "ขั้นตอนตอนนี้: ยกเลิกออเดอร์";
      default:
        return "ขั้นตอนตอนนี้: ${order.status}";
    }
  }

  int? _daysUntilDue() {
    final dueAt = order.scheduledDeliveryAt;
    if (dueAt == null) {
      return null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
    return dueDay.difference(today).inDays;
  }

  String _fmtDueAt(DateTime value) {
    final dd = value.day.toString().padLeft(2, "0");
    final mm = value.month.toString().padLeft(2, "0");
    final yy = value.year;
    final hh = value.hour.toString().padLeft(2, "0");
    final min = value.minute.toString().padLeft(2, "0");
    return "$dd/$mm/$yy $hh:$min";
  }

  bool _isDueSoon() {
    final days = _daysUntilDue();
    if (days == null) {
      return false;
    }
    return days >= 0 && days <= 3;
  }

  String? _dueWarningLabel() {
    final days = _daysUntilDue();
    if (days == null) {
      return null;
    }
    if (days < 0) {
      return "เลยกำหนดส่งแล้ว";
    }
    if (days == 0) {
      return "ครบกำหนดส่งวันนี้";
    }
    if (days == 1) {
      return "ใกล้ถึงกำหนดส่งใน 1 วัน";
    }
    if (days <= 3) {
      return "ใกล้ถึงกำหนดส่งใน $days วัน";
    }
    return null;
  }

  bool _isUrgentDue() {
    final days = _daysUntilDue();
    return days != null && days <= 1;
  }

  Color _displayStatusTone() {
    final days = _daysUntilDue();
    if (days != null && days <= 1) {
      return const Color(0xFFD64545);
    }
    if (days == 2) {
      return const Color(0xFFF28C28);
    }
    if (days == 3) {
      return const Color(0xFFE0B21B);
    }
    switch (order.status) {
      case "out_for_delivery":
        return _brandPrimary;
      case "in_production":
      case "qc_pending":
      case "qc_passed":
      case "preparing":
        return _profileTeal;
      case "rework_required":
        return Colors.orange;
      default:
        return _brandDeep;
    }
  }

  String _statusLabel() {
    switch (order.status) {
      case "assigned":
        return "กำลังจัดคิว";
      case "in_production":
        return "กำลังผลิต";
      case "qc_pending":
        return "รอ QC";
      case "rework_required":
        return "ตีกลับแก้";
      case "qc_passed":
        return "QC ผ่าน";
      case "preparing":
        return "กำลังจัดสินค้า";
      case "out_for_delivery":
        return "กำลังส่ง";
      case "delivered":
        return "ส่งแล้ว";
      case "cancelled":
        return "ยกเลิก";
      default:
        return "รอดำเนินการ";
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = _displayStatusTone();
    final dueWarning = _dueWarningLabel();
    final dueDays = _daysUntilDue();
    return _HoverLift(
      lift: 6,
      scale: 1.008,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              tone.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tone.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: tone.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tone.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.receipt_rounded, color: tone),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: tone,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Order update",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: tone,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                            ),
                            if (_isUrgentDue()) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tone.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border:
                                      Border.all(color: tone.withOpacity(0.32)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.priority_high_rounded,
                                      size: 14,
                                      color: tone,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "ด่วน",
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: tone,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: _brandDeep,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _OrderStatusPill(
                              label: _displayStatusLabel(),
                              tone: tone,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${order.items.length} รายการ · ผู้ส่ง: ${order.assignedToName ?? "ยังไม่มอบหมาย"}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _brandInk.withOpacity(0.74),
                                    fontSize: 13.4,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.scheduledDeliveryAt != null
                              ? "อัปเดต: ${_fmtDueAt(order.updatedAt)} · กำหนดส่ง: ${_fmtDueAt(order.scheduledDeliveryAt!)}"
                              : "อัปเดต: ${_fmtDueAt(order.updatedAt)}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _brandInk.withOpacity(0.68),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _displayStageLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: tone.withOpacity(0.92),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        if (dueWarning != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: tone.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: tone.withOpacity(0.28)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notification_important_outlined,
                                  size: 16,
                                  color: tone,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        dueWarning,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: tone,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      if (order.scheduledDeliveryAt != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            "กำหนดส่ง: ${_fmtDueAt(order.scheduledDeliveryAt!)}",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: tone.withOpacity(0.92),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      if (dueDays != null && dueDays < 0)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            "เลยกำหนดส่งมา ${-dueDays} วัน",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: tone.withOpacity(0.92),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.78),
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: tone.withOpacity(0.10)),
                              ),
                              child: Text(
                                "แตะเพื่อเปิดออเดอร์",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: _brandDeep,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: _brandInk.withOpacity(0.38),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderStatusPill extends StatelessWidget {
  const _OrderStatusPill({
    required this.label,
    required this.tone,
  });

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
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
  static const MethodChannel _scanSoundChannel =
      MethodChannel("stock_scanner/sound");
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: "1");
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productSkuController = TextEditingController();
  final TextEditingController _productUnitController =
      TextEditingController(text: "pcs");
  final TextEditingController _productCategoryController =
      TextEditingController();
  final TextEditingController _productLocationController =
      TextEditingController();

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
    return cleaned.length <= maxLength
        ? cleaned
        : cleaned.substring(0, maxLength);
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
        (!_isSkuManuallyEdited &&
            currentSku == (_lastAutoGeneratedSku ?? currentSku));

    if (!shouldReplace) {
      return;
    }

    _productSkuController.text = nextSku;
    _productSkuController.selection =
        TextSelection.collapsed(offset: nextSku.length);
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
        _showSnack(
            "\u0e2a\u0e23\u0e49\u0e32\u0e07 barcode \u0e43\u0e2b\u0e21\u0e48\u0e41\u0e25\u0e49\u0e27");
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

    if (_barcodeController.text.trim().isEmpty ||
        quantity == null ||
        quantity <= 0) {
      _showSnack(
          "\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01 barcode \u0e41\u0e25\u0e30\u0e08\u0e33\u0e19\u0e27\u0e19\u0e43\u0e2b\u0e49\u0e04\u0e23\u0e1a");
      return;
    }
    if (shouldCreateProduct && _productNameController.text.trim().isEmpty) {
      _showSnack(
          "\u0e01\u0e23\u0e38\u0e13\u0e32\u0e01\u0e23\u0e2d\u0e01\u0e0a\u0e37\u0e48\u0e2d\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e40\u0e21\u0e37\u0e48\u0e2d\u0e40\u0e1b\u0e34\u0e14\u0e42\u0e2b\u0e21\u0e14\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48");
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
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        autoCreateProduct: shouldCreateProduct,
        productName: _productNameController.text.trim().isEmpty
            ? null
            : _productNameController.text.trim(),
        productUnit: _productUnitController.text.trim().isEmpty
            ? "pcs"
            : _productUnitController.text.trim(),
        productCategory: _productCategoryController.text.trim().isEmpty
            ? null
            : _productCategoryController.text.trim(),
        productLocation: _productLocationController.text.trim().isEmpty
            ? null
            : _productLocationController.text.trim(),
        productSku: _productSkuController.text.trim().isEmpty
            ? null
            : _productSkuController.text.trim(),
      );
      setState(() {
        _lastResult = result;
      });
      if (result.productCreated) {
        _showSnack(
            "\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48\u0e41\u0e25\u0e30\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e40\u0e23\u0e35\u0e22\u0e1a\u0e23\u0e49\u0e2d\u0e22");
      } else if (result.lowStock) {
        _showSnack(
            "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e41\u0e25\u0e49\u0e27 \u0e41\u0e25\u0e30\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e19\u0e35\u0e49\u0e2d\u0e22\u0e39\u0e48\u0e43\u0e19\u0e23\u0e30\u0e14\u0e31\u0e1a\u0e40\u0e15\u0e37\u0e2d\u0e19");
      } else {
        _showSnack(
            "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23\u0e40\u0e23\u0e35\u0e22\u0e1a\u0e23\u0e49\u0e2d\u0e22");
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
            title:
                "\u0e2a\u0e41\u0e01\u0e19\u0e41\u0e25\u0e30\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01",
            subtitle:
                "\u0e04\u0e38\u0e13\u0e43\u0e0a\u0e49\u0e44\u0e14\u0e49\u0e17\u0e31\u0e49\u0e07\u0e42\u0e2b\u0e21\u0e14\u0e2a\u0e41\u0e01\u0e19\u0e1b\u0e01\u0e15\u0e34\u0e41\u0e25\u0e30\u0e42\u0e2b\u0e21\u0e14\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48",
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: false,
                  label: Text(
                      "\u0e2a\u0e41\u0e01\u0e19\u0e40\u0e02\u0e49\u0e32/\u0e2d\u0e2d\u0e01"),
                  icon: Icon(Icons.qr_code_scanner)),
              ButtonSegment(
                  value: true,
                  label: Text(
                      "\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48"),
                  icon: Icon(Icons.add_box_outlined)),
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
                      tooltip:
                          "\u0e2a\u0e23\u0e49\u0e32\u0e07 barcode \u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34",
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
                label: const Text(
                    "\u0e2a\u0e23\u0e49\u0e32\u0e07 barcode \u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48\u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34"),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!_newProductMode) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: "in",
                    label: Text("\u0e23\u0e31\u0e1a\u0e40\u0e02\u0e49\u0e32"),
                    icon: Icon(Icons.call_received)),
                ButtonSegment(
                    value: "out",
                    label: Text("\u0e08\u0e48\u0e32\u0e22\u0e2d\u0e2d\u0e01"),
                    icon: Icon(Icons.call_made)),
                ButtonSegment(
                    value: "issue",
                    label: Text("\u0e40\u0e1a\u0e34\u0e01\u0e43\u0e0a\u0e49"),
                    icon: Icon(Icons.assignment_turned_in_outlined)),
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
              hintText:
                  "\u0e23\u0e32\u0e22\u0e25\u0e30\u0e40\u0e2d\u0e35\u0e22\u0e14\u0e40\u0e1e\u0e34\u0e48\u0e21",
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
                      _isSkuManuallyEdited = trimmed.isNotEmpty &&
                          trimmed != _lastAutoGeneratedSku;
                    },
                    decoration: _scanInputDecoration(
                      "SKU",
                      hintText:
                          "\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34",
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _syncAutoSku(force: true)),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        tooltip:
                            "\u0e2a\u0e23\u0e49\u0e32\u0e07 SKU \u0e2d\u0e31\u0e15\u0e42\u0e19\u0e21\u0e31\u0e15\u0e34",
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
                hintText:
                    "\u0e40\u0e0a\u0e48\u0e19 \u0e44\u0e1f\u0e1f\u0e49\u0e32",
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
            label: Text(_newProductMode
                ? "\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e43\u0e2b\u0e21\u0e48\u0e41\u0e25\u0e30\u0e23\u0e31\u0e1a\u0e40\u0e02\u0e49\u0e32"
                : "\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23"),
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
                  title:
                      "\u0e1b\u0e23\u0e30\u0e27\u0e31\u0e15\u0e34\u0e01\u0e32\u0e23\u0e40\u0e04\u0e25\u0e37\u0e48\u0e2d\u0e19\u0e44\u0e2b\u0e27",
                  subtitle:
                      "\u0e14\u0e39\u0e27\u0e48\u0e32\u0e43\u0e04\u0e23\u0e40\u0e1b\u0e47\u0e19\u0e04\u0e19\u0e22\u0e34\u0e07\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e40\u0e02\u0e49\u0e32 \u0e2d\u0e2d\u0e01 \u0e2b\u0e23\u0e37\u0e2d\u0e40\u0e1a\u0e34\u0e01\u0e43\u0e0a\u0e49",
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  const _EmptyTile(
                      message:
                          "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35 movement \u0e43\u0e19\u0e23\u0e30\u0e1a\u0e1a")
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
        subtitle:
            "\u0e14\u0e39\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49 \u0e2d\u0e31\u0e1b\u0e42\u0e2b\u0e25\u0e14\u0e23\u0e39\u0e1b \u0e41\u0e25\u0e30\u0e2d\u0e2d\u0e01\u0e08\u0e32\u0e01\u0e23\u0e30\u0e1a\u0e1a",
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
        title: "ออเดอร์และจัดส่ง",
        subtitle: "สร้างออเดอร์ มอบหมายพนักงานส่งของ และติดตามสถานะงาน",
        icon: Icons.local_shipping_outlined,
        onTap: () => _openPage(
          context,
          OrdersPage(
            api: api,
            currentUser: currentUser,
            refreshSignal: refreshSignal,
          ),
        ),
      ),
      _MoreAction(
        title: "ค้นหาสินค้า",
        subtitle: "ค้นหารายการสินค้า เช็กสต็อก และพิมพ์ป้ายสินค้า",
        icon: Icons.search_rounded,
        onTap: () => _openPage(
          context,
          ProductSearchPage(api: api),
        ),
      ),
    ];

    if (currentUser.isAdmin) {
      items.add(
        _MoreAction(
          title:
              "\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25\u0e23\u0e30\u0e1a\u0e1a",
          subtitle:
              "\u0e0b\u0e34\u0e07\u0e01\u0e4c Google Sheets \u0e41\u0e25\u0e30\u0e2a\u0e48\u0e07\u0e2d\u0e2d\u0e01\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25",
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
              subtitle:
                  "\u0e23\u0e27\u0e21\u0e40\u0e21\u0e19\u0e39\u0e17\u0e35\u0e48\u0e43\u0e0a\u0e49\u0e44\u0e21\u0e48\u0e1a\u0e48\u0e2d\u0e22\u0e44\u0e27\u0e49\u0e43\u0e19\u0e2b\u0e19\u0e49\u0e32\u0e40\u0e14\u0e35\u0e22\u0e27 \u0e40\u0e1e\u0e37\u0e48\u0e2d\u0e43\u0e2b\u0e49\u0e41\u0e16\u0e1a\u0e25\u0e48\u0e32\u0e07\u0e14\u0e39\u0e2a\u0e1a\u0e32\u0e22\u0e15\u0e32\u0e02\u0e36\u0e49\u0e19",
              showBackButton: true,
            ),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor:
                        Color.lerp(_brandSurface, _brandSurfaceStrong, 0.75),
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
                    title:
                        "\u0e01\u0e32\u0e23\u0e41\u0e08\u0e49\u0e07\u0e40\u0e15\u0e37\u0e2d\u0e19",
                    subtitle:
                        "\u0e1f\u0e35\u0e14\u0e41\u0e08\u0e49\u0e07\u0e40\u0e15\u0e37\u0e2d\u0e19\u0e08\u0e32\u0e01\u0e01\u0e32\u0e23\u0e22\u0e34\u0e07\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32\u0e41\u0e15\u0e48\u0e25\u0e30\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23",
                    showBackButton: true,
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const _EmptyTile(
                        message:
                            "\u0e22\u0e31\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e01\u0e32\u0e23\u0e41\u0e08\u0e49\u0e07\u0e40\u0e15\u0e37\u0e2d\u0e19")
                  else
                    ...items
                        .map((item) => _NotificationTile(notification: item)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({
    super.key,
    required this.api,
  });

  final StockApiService api;

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = "";
  List<Product> _allProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: _brandPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "สแกนบาร์โค้ดสินค้า",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 300,
                  child: MobileScanner(
                    controller: MobileScannerController(
                      detectionSpeed: DetectionSpeed.noDuplicates,
                      returnImage: false,
                    ),
                    onDetect: (capture) {
                      final value = capture.barcodes.first.rawValue;
                      if (value != null && value.isNotEmpty) {
                        unawaited(HapticFeedback.lightImpact());
                        Navigator.of(sheetContext).pop(value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      _controller.text = result;
      setState(() {
        _query = result;
      });

      // Exact Match Auto-Select for barcode scan
      final trimmedResult = result.trim().toLowerCase();
      final exactMatches = _allProducts.where((p) {
        return p.barcode.toLowerCase() == trimmedResult ||
            (p.sku?.toLowerCase() == trimmedResult);
      }).toList();

      if (exactMatches.length == 1) {
        _showProductCodeSheet(context, exactMatches.first);
      }
    }
  }

  Future<void> _load() async {
    try {
      final products = await widget.api.getProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showAppSnack(context, e.toString(), isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Product> _filteredProducts() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _allProducts;
    return _allProducts.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q) ||
          (p.sku?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredProducts();

    return Scaffold(
      backgroundColor: _brandSurface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: "ค้นหาชื่อสินค้า บาร์โค้ด หรือ SKU...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = "");
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                  ),
                ],
              ),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          "พบ ${results.length} รายการ",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: results.isEmpty
                      ? _EmptyTile(
                          message: _query.isEmpty
                              ? "ไม่มีรายการสินค้า"
                              : "ไม่พบสินค้าที่ตรงกับคำค้นหา",
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final product = results[index];
                            return _ProductSearchTile(
                              product: product,
                              query: _query,
                              onTap: () => _showProductCodeSheet(context, product),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _ProductSearchTile extends StatelessWidget {
  const _ProductSearchTile({
    required this.product,
    required this.query,
    required this.onTap,
  });

  final Product product;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String statusText;

    if (product.currentStock <= 0) {
      badgeColor = Colors.red;
      statusText = "หมด";
    } else if (product.currentStock <= product.minimumStock) {
      badgeColor = Colors.orange;
      statusText = "ใกล้หมด";
    } else {
      badgeColor = Colors.green;
      statusText = "ปกติ";
    }

    final bool isLongUnit = product.unit.length > 4;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("${product.barcode} | ${product.category ?? 'ทั่วไป'}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isLongUnit
                    ? "${product.currentStock}"
                    : "${product.currentStock} ${product.unit}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isLongUnit ? "$statusText (${product.unit})" : statusText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    required this.api,
    required this.currentUser,
    this.refreshSignal,
  });

  final StockApiService api;
  final AppUser currentUser;
  final ValueListenable<int>? refreshSignal;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final ImagePicker _proofImagePicker = ImagePicker();
  final Map<String, List<String>> _orderProofPhotos = {};
  final GlobalKey<FormState> _createOrderFormKey = GlobalKey<FormState>();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _customerAddressController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _selectedAssigneeId;
  String? _selectedProductionUserId;
  String? _selectedQcUserId;
  String? _selectedDeliveryUserId;
  DateTime? _scheduledDeliveryAt;
  bool _showAdvancedTeam = false;
  AutovalidateMode _createOrderAutovalidate = AutovalidateMode.disabled;
  bool _isSaving = false;
  String? _orderPickerId;
  late Future<_OrdersPageData> _future;
  late List<_DraftOrderItem> _draftItems;

  Future<void> _showOrderPreview(DeliveryOrder order) async {
    final statusLabel = order.status == "new"
        ? "ใหม่"
        : order.status == "assigned"
            ? "มอบหมายแล้ว"
            : order.status == "in_production"
                ? "กำลังผลิต"
                : order.status == "qc_pending"
                    ? "รอ QC"
                    : order.status == "qc_passed"
                        ? "ผ่าน QC"
                        : order.status == "preparing"
                            ? "กำลังจัดสินค้า"
                            : order.status == "out_for_delivery"
                                ? "กำลังส่ง"
                                : order.status == "delivered"
                                    ? "ส่งแล้ว"
                                    : order.status == "cancelled"
                                        ? "ยกเลิก"
                                        : order.status;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.52,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "ใบสรุปออเดอร์",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.customerName,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _ReceiptDivider(),
                  const SizedBox(height: 8),
                  _receiptRow("สถานะ", statusLabel),
                  _receiptRow("ผู้รับออเดอร์", order.createdByName),
                  _receiptRow(
                      "ผู้ส่ง", order.assignedToName ?? "ยังไม่มอบหมาย"),
                  if (order.customerPhone != null &&
                      order.customerPhone!.isNotEmpty)
                    _receiptRow("โทร", order.customerPhone!),
                  if (order.customerAddress != null &&
                      order.customerAddress!.isNotEmpty)
                    _receiptRow("ที่อยู่", order.customerAddress!),
                  if (order.scheduledDeliveryAt != null)
                    _receiptRow(
                        "กำหนดส่ง", _fmtDateTime(order.scheduledDeliveryAt!)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openOrder(order);
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text("เปิดออเดอร์นี้"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black.withOpacity(0.60),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _openOrder(DeliveryOrder order) {
    // Keep this lightweight: the order is already visible in the list.
    setState(() {
      _orderPickerId = order.id;
    });
    _showAppSnack(context, "เลือกออเดอร์แล้ว เลื่อนลงเพื่อจัดการได้เลย");
  }

  @override
  void initState() {
    super.initState();
    _draftItems = [_DraftOrderItem()];
    _future = _load();
    widget.refreshSignal?.addListener(_handleRealtimeRefresh);
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRealtimeRefresh);
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _noteController.dispose();
    for (final item in _draftItems) {
      item.dispose();
    }
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

  Future<_OrdersPageData> _load() async {
    final results = await Future.wait([
      widget.api.getOrders(requesterId: widget.currentUser.userId, limit: 400),
      widget.api.getUsers(activeOnly: true),
      widget.api.getProducts(),
    ]);
    return _OrdersPageData(
      orders: results[0] as List<DeliveryOrder>,
      users: results[1] as List<AppUser>,
      products: results[2] as List<Product>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _loadProofPhotosForOrder(String orderId) async {
    try {
      final photos = await widget.api.getOrderProofPhotos(
        requesterId: widget.currentUser.userId,
        orderId: orderId,
      );
      if (!mounted) return;
      setState(() {
        _orderProofPhotos[orderId] = photos;
      });
    } catch (_) {}
  }

  Product? _resolveDraftProduct(_DraftOrderItem item, List<Product> products) {
    if (item.barcode != null) {
      for (final product in products) {
        if (product.barcode == item.barcode) {
          return product;
        }
      }
    }

    final query = item.productController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return null;
    }

    for (final product in products) {
      if (product.name.toLowerCase() == query ||
          product.barcode.toLowerCase() == query ||
          (product.sku?.toLowerCase() == query)) {
        return product;
      }
    }

    final partialMatches = products
        .where((product) {
          return product.name.toLowerCase().contains(query) ||
              product.barcode.toLowerCase().contains(query) ||
              (product.sku?.toLowerCase().contains(query) ?? false);
        })
        .take(2)
        .toList();
    if (partialMatches.length == 1) {
      return partialMatches.first;
    }
    return null;
  }

  Future<void> _createOrder(_OrdersPageData data) async {
    final formState = _createOrderFormKey.currentState;
    if (formState != null) {
      setState(() {
        _createOrderAutovalidate = AutovalidateMode.onUserInteraction;
      });
      if (!formState.validate()) {
        _showAppSnack(context, "กรุณากรอก ชื่อ/เบอร์โทร/ที่อยู่ ให้ครบ",
            isError: true);
        return;
      }
    }

    final customerName = _customerNameController.text.trim();
    final items = <Map<String, dynamic>>[];
    for (final item in _draftItems) {
      final resolvedProduct = _resolveDraftProduct(item, data.products);
      final qty = int.tryParse(item.quantityController.text.trim());
      if (resolvedProduct == null || qty == null || qty <= 0) {
        _showAppSnack(context, "กรุณาเลือกสินค้าและจำนวนให้ครบทุกแถว");
        return;
      }
      item.barcode = resolvedProduct.barcode;
      item.productController.text = resolvedProduct.name;
      items.add({
        "barcode": resolvedProduct.barcode,
        "quantity": qty,
      });
    }
    if (customerName.isEmpty || items.isEmpty) {
      _showAppSnack(context, "กรุณากรอกชื่อลูกค้าและรายการสินค้า");
      return;
    }
    if (_customerPhoneController.text.trim().isEmpty ||
        _customerAddressController.text.trim().isEmpty) {
      _showAppSnack(context, "กรุณากรอก ชื่อ/เบอร์โทร/ที่อยู่ ให้ครบ",
          isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });
    _showAppSnack(context, "กำลังสร้างออเดอร์...");
    try {
      await widget.api.createOrder(
        requesterId: widget.currentUser.userId,
        customerName: customerName,
        customerPhone: _customerPhoneController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        assignedToId: _selectedAssigneeId,
        productionUserId: _selectedProductionUserId,
        qcUserId: _selectedQcUserId,
        deliveryUserId: _selectedDeliveryUserId,
        scheduledDeliveryAt: _scheduledDeliveryAt,
        items: items,
      );
      setState(() {
        _customerNameController.clear();
        _customerPhoneController.clear();
        _customerAddressController.clear();
        _noteController.clear();
        _createOrderFormKey.currentState?.reset();
        _createOrderAutovalidate = AutovalidateMode.disabled;
        _selectedAssigneeId = null;
        _selectedProductionUserId = null;
        _selectedQcUserId = null;
        _selectedDeliveryUserId = null;
        _scheduledDeliveryAt = null;
        for (final item in _draftItems) {
          item.dispose();
        }
        _draftItems = [_DraftOrderItem()];
      });
      if (mounted) {
        _showAppSnack(context, "สร้างออเดอร์เรียบร้อย");
      }
      await _refresh();
    } catch (error) {
      final message = error.toString().replaceFirst("Exception: ", "");
      if (mounted) {
        _showAppSnack(context, message, isError: true);
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("สร้างออเดอร์ไม่สำเร็จ"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("ปิด"),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _addDraftItem() {
    setState(() {
      _draftItems = [..._draftItems, _DraftOrderItem()];
    });
  }

  void _removeDraftItem(int index) {
    if (_draftItems.length == 1) {
      _showAppSnack(context, "ออเดอร์ต้องมีสินค้าอย่างน้อย 1 รายการ");
      return;
    }
    setState(() {
      final target = _draftItems[index];
      target.dispose();
      _draftItems = [
        ..._draftItems.sublist(0, index),
        ..._draftItems.sublist(index + 1),
      ];
    });
  }

  String _fmtDateTime(DateTime value) {
    final d = value;
    final dd = d.day.toString().padLeft(2, "0");
    final mm = d.month.toString().padLeft(2, "0");
    final yy = d.year;
    final hh = d.hour.toString().padLeft(2, "0");
    final mi = d.minute.toString().padLeft(2, "0");
    return "$dd/$mm/$yy $hh:$mi";
  }

  Map<String, String> _parseCustomerFromText(String raw) {
    final cleaned = raw.replaceAll("\r\n", "\n").replaceAll("\r", "\n").trim();
    if (cleaned.isEmpty) {
      return {"name": "", "phone": "", "address": "", "note": ""};
    }

    final lines = cleaned
        .split("\n")
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String name = "";
    String phone = "";
    String address = "";
    String note = "";

    int? sendIndex;
    int? phoneIndex;

    String stripPrefix(String line, List<String> prefixes) {
      var out = line.trim();
      for (final prefix in prefixes) {
        if (out.toLowerCase().startsWith(prefix.toLowerCase())) {
          out = out.substring(prefix.length).trim();
        }
      }
      return out;
    }

    for (var i = 0; i < lines.length; i++) {
      if (lines[i] == "ส่ง") {
        sendIndex = i;
        break;
      }
    }

    for (final line in lines) {
      final lower = line.toLowerCase();
      final digits = line.replaceAll(RegExp(r"\\D"), "");

      if (phone.isEmpty &&
          (lower.startsWith("โทร") ||
              lower.startsWith("tel") ||
              lower.startsWith("phone") ||
              digits.length >= 9)) {
        final candidate = stripPrefix(
            line, ["โทร:", "โทร", "tel:", "tel", "phone:", "phone"]);
        final phoneDigits = candidate.replaceAll(RegExp(r"\\D"), "");
        if (phoneDigits.length >= 9) {
          phone = phoneDigits;
          phoneIndex = lines.indexOf(line);
          continue;
        }
      }

      if (address.isEmpty &&
          (lower.startsWith("ที่อยู่") ||
              lower.startsWith("addr") ||
              lower.startsWith("address"))) {
        address = stripPrefix(line,
            ["ที่อยู่:", "ที่อยู่", "addr:", "addr", "address:", "address"]);
        continue;
      }

      if (note.isEmpty &&
          (lower.startsWith("หมายเหตุ") || lower.startsWith("note"))) {
        note = stripPrefix(line, ["หมายเหตุ:", "หมายเหตุ", "note:", "note"]);
        continue;
      }
    }

    // Pattern: "ส่ง" then name, then multi-line address, then phone.
    if (sendIndex != null) {
      if (sendIndex! + 1 < lines.length && name.isEmpty) {
        name = lines[sendIndex! + 1];
      }
      final startAddr = (sendIndex! + 2).clamp(0, lines.length);
      final endAddr = phoneIndex == null
          ? lines.length
          : phoneIndex!.clamp(0, lines.length);
      if (startAddr < endAddr) {
        final addrLines =
            lines.sublist(startAddr, endAddr).where((l) => l != "ส่ง").toList();
        if (addrLines.isNotEmpty && address.isEmpty) {
          address = addrLines.join(" ");
        }
      }
      // Everything before "ส่ง" is usually items; keep in note if note not provided.
      if (note.isEmpty && sendIndex! > 0) {
        note = lines.sublist(0, sendIndex!).join(" | ");
      }
    }

    if (name.isEmpty) {
      for (final line in lines) {
        final lower = line.toLowerCase();
        if (lower.startsWith("โทร") ||
            lower.startsWith("tel") ||
            lower.startsWith("phone") ||
            lower.startsWith("ที่อยู่") ||
            lower.startsWith("addr") ||
            lower.startsWith("address") ||
            lower.startsWith("หมายเหตุ") ||
            lower.startsWith("note")) {
          continue;
        }
        final digits = line.replaceAll(RegExp(r"\\D"), "");
        if (digits.length >= 9 && digits.length >= (line.length * 0.7)) {
          continue;
        }
        if (line == "ส่ง") {
          continue;
        }
        name = line;
        break;
      }
    }

    if (address.isEmpty && lines.length >= 2) {
      final ignored = <String>{};
      if (name.isNotEmpty) ignored.add(name);
      if (note.isNotEmpty) ignored.add(note);
      final phoneDigits = phone;
      final candidates = lines.where((l) {
        if (ignored.contains(l)) return false;
        final digits = l.replaceAll(RegExp(r"\\D"), "");
        if (phoneDigits.isNotEmpty && digits == phoneDigits) return false;
        final lower = l.toLowerCase();
        if (lower.startsWith("โทร") ||
            lower.startsWith("tel") ||
            lower.startsWith("phone") ||
            lower.startsWith("หมายเหตุ") ||
            lower.startsWith("note")) return false;
        return true;
      }).toList();
      if (candidates.isNotEmpty) {
        address = candidates.join(" ");
      }
    }

    return {"name": name, "phone": phone, "address": address, "note": note};
  }

  Future<void> _pasteCustomerFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? "";
      final parsed = _parseCustomerFromText(text);
      if (!mounted) return;
      setState(() {
        if (parsed["name"]!.trim().isNotEmpty)
          _customerNameController.text = parsed["name"]!.trim();
        if (parsed["phone"]!.trim().isNotEmpty)
          _customerPhoneController.text = parsed["phone"]!.trim();
        if (parsed["address"]!.trim().isNotEmpty)
          _customerAddressController.text = parsed["address"]!.trim();
        if (parsed["note"]!.trim().isNotEmpty)
          _noteController.text = parsed["note"]!.trim();
      });
      if (mounted) _showAppSnack(context, "วางข้อมูลลูกค้าแล้ว");
    } catch (e) {
      if (mounted) {
        _showAppSnack(context, "วางจากคลิปบอร์ดไม่สำเร็จ", isError: true);
      }
    }
  }

  Future<void> _openCancelledOrders(
    List<DeliveryOrder> cancelled,
    List<AppUser> activeStaff,
    _OrdersPageData data,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CancelledOrdersPage(
          orders: cancelled,
          currentUser: widget.currentUser,
          api: widget.api,
          proofPhotos: _orderProofPhotos,
          onLoadProofPhotos: _loadProofPhotosForOrder,
          staff: activeStaff,
          onAssign: _assignOrder,
          onOpenProofGallery: _openProofGallery,
        ),
      ),
    );
  }

  String _userLabelById(List<AppUser> users, String? id, String fallback) {
    if (id == null) return fallback;
    for (final user in users) {
      if (user.userId == id) return "${user.userName} (${user.userId})";
    }
    return fallback;
  }

  Future<void> _updateStatus(DeliveryOrder order, String status) async {
    try {
      await widget.api.updateOrderStatus(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
        status: status,
      );
      if (status == "delivered" && mounted) {
        await _showDeliveredCatAnimation();
      }
      _showAppSnack(context, "อัปเดตสถานะแล้ว");
      await _refresh();
    } catch (error) {
      _showAppSnack(
        context,
        error.toString().replaceFirst("Exception: ", ""),
        isError: true,
      );
    }
  }

  Future<void> _showDeliveredCatAnimation() {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: "delivery_success",
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const _DeliverySuccessOverlay(),
    );
  }

  Future<void> _uploadProofPhoto(DeliveryOrder order) async {
    try {
      final file = await _proofImagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1800,
      );
      if (file == null) return;
      await widget.api.uploadOrderProofPhoto(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
        filePath: file.path,
      );
      await _loadProofPhotosForOrder(order.id);
      _showAppSnack(context, "อัปโหลดรูปหลักฐานแล้ว");
    } catch (error) {
      _showAppSnack(context, error.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _deliverPartial(DeliveryOrder order) async {
    final qtyValues = <String, String>{
      for (final item in order.items)
        item.barcode:
            "${(item.quantity - item.deliveredQuantity).clamp(0, item.quantity)}",
    };
    String note = "";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("ส่งสินค้า (บางส่วน)"),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...order.items.map((item) {
                        final remaining =
                            item.quantity - item.deliveredQuantity;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      "${item.productName} (ค้าง $remaining)")),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: TextFormField(
                                  initialValue: qtyValues[item.barcode] ?? "0",
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      const InputDecoration(labelText: "ส่ง"),
                                  onChanged: (value) =>
                                      qtyValues[item.barcode] = value,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      TextField(
                        onChanged: (value) => note = value,
                        decoration:
                            const InputDecoration(labelText: "หมายเหตุ"),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text("ยกเลิก")),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text("บันทึก")),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    try {
      final items = <Map<String, dynamic>>[];
      for (final item in order.items) {
        final qty = int.tryParse((qtyValues[item.barcode] ?? "0").trim()) ?? 0;
        if (qty > 0) {
          items.add({"barcode": item.barcode, "quantity": qty});
        }
      }
      if (items.isEmpty) {
        _showAppSnack(context, "กรุณาใส่จำนวนที่ส่งอย่างน้อย 1 รายการ");
        return;
      }
      final updated = await widget.api.deliverOrderPartial(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
        items: items,
        note: note.isEmpty ? null : note,
      );
      if (updated.status == "delivered") {
        await widget.api.updateOrderStatus(
          requesterId: widget.currentUser.userId,
          orderId: order.id,
          status: "out_for_delivery",
        );
      }
      _showAppSnack(context, "บันทึกการส่งบางส่วนแล้ว");
      await _loadProofPhotosForOrder(order.id);
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
      await _future;
    } catch (error) {
      _showAppSnack(context, error.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _fixDeliveryStatus(DeliveryOrder order) async {
    final targetValues = <String, String>{
      for (final item in order.items)
        item.barcode: "${item.deliveredQuantity}",
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("แก้ไขจำนวนส่ง (แอดมิน)"),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "${item.productName} (ทั้งหมด ${item.quantity})",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: TextFormField(
                                  initialValue:
                                      targetValues[item.barcode] ?? "0",
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: "ส่งแล้ว"),
                                  onChanged: (value) =>
                                      targetValues[item.barcode] = value,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          "ใส่จำนวน 'ส่งแล้ว' ทั้งหมดที่ต้องการให้เป็นระบบจะคำนวณส่วนต่างให้อัตโนมัติ",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text("ยกเลิก")),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text("บันทึกการแก้ไข")),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    try {
      final items = <Map<String, dynamic>>[];
      for (final item in order.items) {
        final target =
            int.tryParse((targetValues[item.barcode] ?? "0").trim()) ?? 0;
        final delta = target - item.deliveredQuantity;
        if (delta != 0) {
          items.add({"barcode": item.barcode, "quantity": delta});
        }
      }
      if (items.isEmpty) {
        _showAppSnack(context, "ไม่มีการเปลี่ยนแปลง");
        return;
      }
      await widget.api.deliverOrderPartial(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
        items: items,
        note: "Admin fixed delivery status",
      );
      _showAppSnack(context, "แก้ไขจำนวนส่งเรียบร้อยแล้ว");
      if (!mounted) return;
      setState(() {
        _future = _load();
      });
      await _future;
    } catch (error) {
      _showAppSnack(context, error.toString().replaceFirst("Exception: ", ""));
    }
  }

  void _openProofGallery(DeliveryOrder order) {
    final photos = _orderProofPhotos[order.id] ?? const <String>[];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.7,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("รูปหลักฐานการส่ง",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (photos.isEmpty)
                const Expanded(child: Center(child: Text("ยังไม่มีรูปหลักฐาน")))
              else
                Expanded(
                  child: GridView.builder(
                    itemCount: photos.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          photos[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color:
                                  _brandSurfaceStrong.withValues(alpha: 0.35),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(12),
                              child: const Text(
                                "ดูรูปไม่ได้",
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _assignOrder(DeliveryOrder order, List<AppUser> users) async {
    String? production = order.productionUserId;
    String? qc = order.qcUserId;
    String? delivery = order.deliveryUserId ?? order.assignedToId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("มอบหมายทีมงาน"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String?>(
                      value: production,
                      decoration: const InputDecoration(labelText: "ฝ่ายผลิต"),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text("ยังไม่กำหนด")),
                        ...users.map((u) => DropdownMenuItem<String?>(
                            value: u.userId,
                            child: Text("${u.userName} (${u.userId})"))),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => production = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: qc,
                      decoration: const InputDecoration(labelText: "QC"),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text("ยังไม่กำหนด")),
                        ...users.map((u) => DropdownMenuItem<String?>(
                            value: u.userId,
                            child: Text("${u.userName} (${u.userId})"))),
                      ],
                      onChanged: (value) => setDialogState(() => qc = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: delivery,
                      decoration: const InputDecoration(labelText: "จัดส่ง"),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text("ยังไม่กำหนด")),
                        ...users.map((u) => DropdownMenuItem<String?>(
                            value: u.userId,
                            child: Text("${u.userName} (${u.userId})"))),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => delivery = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text("ยกเลิก"),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text("บันทึก"),
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
      await widget.api.assignOrderTeam(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
        productionUserId: production,
        qcUserId: qc,
        deliveryUserId: delivery,
      );
      _showAppSnack(context, "บันทึกทีมงานเรียบร้อย");
      await _refresh();
    } catch (error) {
      _showAppSnack(context, error.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _resolveBackorder(DeliveryOrder order) async {
    try {
      await widget.api.resolveBackorder(
        requesterId: widget.currentUser.userId,
        orderId: order.id,
      );
      _showAppSnack(context, "ปิดค้างจ่ายแล้ว");
      await _refresh();
    } catch (error) {
      _showAppSnack(context, error.toString().replaceFirst("Exception: ", ""),
          isError: true);
    }
  }

  void _openBackorderReport(List<DeliveryOrder> orders) {
    final backorders = orders.where((order) {
      return order.items.any((item) => item.deliveredQuantity < item.quantity);
    }).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.82,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _BackorderReportSheet(
            backorders: backorders,
            currentUser: widget.currentUser,
            onFixStatus: _fixDeliveryStatus,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: _brandSurface,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<_OrdersPageData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ErrorState(message: snapshot.error.toString());
              }
              final data = snapshot.data!;
              for (final order in data.orders) {
                if (!_orderProofPhotos.containsKey(order.id)) {
                  unawaited(_loadProofPhotosForOrder(order.id));
                }
              }
              final backorderOrders = data.orders.where((order) {
                if (order.status == "cancelled") {
                  return false;
                }
                return order.items
                    .any((item) => item.deliveredQuantity < item.quantity);
              }).toList();
              final activeStaff =
                  data.users.where((item) => item.active).toList();

              final listPadding = kIsWeb
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                  : const EdgeInsets.all(16);
              return ListView(
                padding: listPadding,
                children: [
                  const _PageHeader(
                    title: "ออเดอร์และจัดส่ง",
                    subtitle:
                        "รับออเดอร์จากลูกค้า มอบหมายคนส่ง และติดตามสถานะงาน",
                    showBackButton: true,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            color: Colors.red.withOpacity(0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "รายงานค้างจ่าย (${backorderOrders.length} ออเดอร์)",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _openBackorderReport(data.orders),
                                      icon: const Icon(Icons.list_alt_outlined),
                                      label: const Text("เปิดรายงานแบบเต็ม"),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (backorderOrders.isEmpty)
                                    const Text("ไม่มีออเดอร์ค้างจ่ายตอนนี้")
                                  else
                                    ...backorderOrders.take(6).map((order) {
                                      final pendingItems = order.items.where(
                                        (item) =>
                                            item.deliveredQuantity <
                                            item.quantity,
                                      );
                                      final summary = pendingItems
                                          .map(
                                            (item) =>
                                                "${item.productName} ค้าง ${item.quantity - item.deliveredQuantity}",
                                          )
                                          .join(", ");
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Text(
                                            "โดย ${order.customerName}: $summary"),
                                      );
                                    }),
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
                                  Text(
                                    "สร้างออเดอร์ใหม่",
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: _pasteCustomerFromClipboard,
                                      icon: const Icon(
                                          Icons.content_paste_go_outlined),
                                      label:
                                          const Text("วางข้อมูลลูกค้าจากแชท"),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Form(
                                    key: _createOrderFormKey,
                                    autovalidateMode: _createOrderAutovalidate,
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          controller: _customerNameController,
                                          decoration: const InputDecoration(
                                            labelText: "ชื่อลูกค้า",
                                            helperText: "จำเป็น",
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return "กรุณากรอกชื่อลูกค้า";
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: _customerPhoneController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          decoration: const InputDecoration(
                                            labelText: "เบอร์โทร",
                                            helperText: "จำเป็น",
                                          ),
                                          validator: (value) {
                                            final v = value?.trim() ?? "";
                                            if (v.isEmpty)
                                              return "กรุณากรอกเบอร์โทร";
                                            if (v.length < 9)
                                              return "เบอร์โทรสั้นเกินไป";
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller:
                                              _customerAddressController,
                                          maxLines: 2,
                                          decoration: const InputDecoration(
                                            labelText: "ที่อยู่",
                                            helperText: "จำเป็น",
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return "กรุณากรอกที่อยู่";
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "รายการสินค้า",
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 10),
                                  ...List.generate(_draftItems.length, (index) {
                                    final draftItem = _draftItems[index];
                                    Product? selectedProduct;
                                    if (draftItem.barcode != null) {
                                      for (final product in data.products) {
                                        if (product.barcode ==
                                            draftItem.barcode) {
                                          selectedProduct = product;
                                          break;
                                        }
                                      }
                                    }
                                    final query = draftItem
                                        .productController.text
                                        .trim()
                                        .toLowerCase();
                                    final showSuggestions = query.isNotEmpty &&
                                        selectedProduct == null;
                                    final matchedProducts = showSuggestions
                                        ? data.products
                                            .where((product) {
                                              return product.name
                                                      .toLowerCase()
                                                      .contains(query) ||
                                                  product.barcode
                                                      .toLowerCase()
                                                      .contains(query) ||
                                                  (product.sku
                                                          ?.toLowerCase()
                                                          .contains(query) ??
                                                      false);
                                            })
                                            .take(6)
                                            .toList()
                                        : const <Product>[];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextField(
                                            controller:
                                                draftItem.productController,
                                            decoration: InputDecoration(
                                              labelText: "สินค้า ${index + 1}",
                                              hintText:
                                                  "พิมพ์ชื่อสินค้า บาร์โค้ด หรือ SKU",
                                              prefixIcon:
                                                  const Icon(Icons.search),
                                            ),
                                            onChanged: (_) {
                                              setState(() {
                                                draftItem.barcode = null;
                                              });
                                            },
                                          ),
                                          if (matchedProducts.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: _brandPrimary
                                                        .withOpacity(0.16)),
                                              ),
                                              child: Column(
                                                children: matchedProducts
                                                    .map((product) {
                                                  return ListTile(
                                                    dense: true,
                                                    title: Text(
                                                      product.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    subtitle: Text(
                                                      "${product.barcode} · คงเหลือ ${product.currentStock} ${product.unit}",
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    onTap: () {
                                                      setState(() {
                                                        draftItem.barcode =
                                                            product.barcode;
                                                        draftItem
                                                            .productController
                                                            .text = product.name;
                                                      });
                                                    },
                                                    trailing: const Icon(
                                                        Icons
                                                            .north_west_rounded,
                                                        size: 18),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ],
                                          if (selectedProduct != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              "บาร์โค้ด: ${selectedProduct.barcode} · คงเหลือ ${selectedProduct.currentStock} ${selectedProduct.unit}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: _brandInk
                                                        .withOpacity(0.72),
                                                  ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: draftItem
                                                      .quantityController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText: "จำนวน"),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton.filledTonal(
                                                onPressed: () =>
                                                    _removeDraftItem(index),
                                                icon: const Icon(
                                                    Icons.delete_outline),
                                                tooltip: "ลบรายการ",
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: _addDraftItem,
                                      icon: const Icon(Icons.add),
                                      label: const Text("เพิ่มสินค้าอีกตัว"),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text("ทีมงานออเดอร์"),
                                    subtitle: Text(
                                      "ผลิต: ${_userLabelById(activeStaff, _selectedProductionUserId, "-")} · "
                                      "QC: ${_userLabelById(activeStaff, _selectedQcUserId, "-")} · "
                                      "ส่ง: ${_userLabelById(activeStaff, _selectedDeliveryUserId ?? _selectedAssigneeId, "-")}",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: TextButton(
                                      onPressed: () => setState(
                                        () => _showAdvancedTeam =
                                            !_showAdvancedTeam,
                                      ),
                                      child: Text(
                                          _showAdvancedTeam ? "ย่อ" : "กำหนด"),
                                    ),
                                  ),
                                  if (_showAdvancedTeam) ...[
                                    DropdownButtonFormField<String?>(
                                      value: _selectedProductionUserId,
                                      decoration: const InputDecoration(
                                          labelText: "ฝ่ายผลิต"),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text("-"),
                                        ),
                                        ...activeStaff.map(
                                          (user) => DropdownMenuItem<String?>(
                                            value: user.userId,
                                            child: Text(
                                                "${user.userName} (${user.userId})"),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) => setState(
                                        () => _selectedProductionUserId = value,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String?>(
                                      value: _selectedQcUserId,
                                      decoration: const InputDecoration(
                                          labelText: "QC"),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text("-"),
                                        ),
                                        ...activeStaff.map(
                                          (user) => DropdownMenuItem<String?>(
                                            value: user.userId,
                                            child: Text(
                                                "${user.userName} (${user.userId})"),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) => setState(
                                          () => _selectedQcUserId = value),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String?>(
                                      value: _selectedDeliveryUserId ??
                                          _selectedAssigneeId,
                                      decoration: const InputDecoration(
                                          labelText: "จัดส่ง"),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text("-"),
                                        ),
                                        ...activeStaff.map(
                                          (user) => DropdownMenuItem<String?>(
                                            value: user.userId,
                                            child: Text(
                                                "${user.userName} (${user.userId})"),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) => setState(() {
                                        _selectedDeliveryUserId = value;
                                        _selectedAssigneeId = value;
                                      }),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _scheduledDeliveryAt ?? now,
                                        firstDate: now
                                            .subtract(const Duration(days: 1)),
                                        lastDate:
                                            now.add(const Duration(days: 365)),
                                      );
                                      if (pickedDate == null || !mounted)
                                        return;
                                      final pickedTime = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(
                                          _scheduledDeliveryAt ?? now,
                                        ),
                                      );
                                      if (pickedTime == null || !mounted)
                                        return;
                                      setState(() {
                                        _scheduledDeliveryAt = DateTime(
                                          pickedDate.year,
                                          pickedDate.month,
                                          pickedDate.day,
                                          pickedTime.hour,
                                          pickedTime.minute,
                                        );
                                      });
                                    },
                                    icon: const Icon(Icons.schedule_outlined),
                                    label: Text(
                                      _scheduledDeliveryAt == null
                                          ? "กำหนดเวลาจัดส่ง"
                                          : "เวลาจัดส่ง: ${_fmtDateTime(_scheduledDeliveryAt!)}",
                                    ),
                                  ),
                                  TextField(
                                    controller: _noteController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                        labelText: "หมายเหตุ"),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _isSaving
                                          ? null
                                          : () => _createOrder(data),
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Icon(Icons.add_task_outlined),
                                      label: const Text("สร้างออเดอร์"),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "รายการออเดอร์",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (data.orders.isEmpty)
                            const _EmptyTile(message: "ยังไม่มีออเดอร์ในระบบ")
                          else
                            ...(() {
                              final cancelled = data.orders
                                  .where((o) => o.status == "cancelled")
                                  .toList();
                              final active = data.orders
                                  .where((o) => o.status != "cancelled")
                                  .toList();
                              return <Widget>[
                                if (active.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: DropdownMenu<String>(
                                        initialSelection: _orderPickerId,
                                        expandedInsets: EdgeInsets.zero,
                                        enableFilter: true,
                                        enableSearch: true,
                                        leadingIcon:
                                            const Icon(Icons.search_rounded),
                                        label: const Text("เลือกออเดอร์"),
                                        hintText:
                                            "พิมพ์ชื่อ/เบอร์/รหัสออเดอร์เพื่อค้นหา",
                                        dropdownMenuEntries: active
                                            .map(
                                              (order) =>
                                                  DropdownMenuEntry<String>(
                                                value: order.id,
                                                label:
                                                    "${order.customerName} • ${order.id.substring(0, 8)} • ${order.status}",
                                              ),
                                            )
                                            .toList(),
                                        onSelected: (value) async {
                                          if (value == null) return;
                                          setState(() {
                                            _orderPickerId = value;
                                          });
                                          final target = active.firstWhere(
                                            (o) => o.id == value,
                                            orElse: () => active.first,
                                          );
                                          await _showOrderPreview(target);
                                        },
                                      ),
                                    ),
                                  ),
                                if (cancelled.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: OutlinedButton.icon(
                                      onPressed: () => _openCancelledOrders(
                                          cancelled, activeStaff, data),
                                      icon: const Icon(Icons.archive_outlined),
                                      label: Text(
                                          "ดูออเดอร์ที่ยกเลิก (${cancelled.length})"),
                                    ),
                                  ),
                                ...active.map(
                                  (order) => _OrderTile(
                                    order: order,
                                    api: widget.api,
                                    currentUser: widget.currentUser,
                                    printUrl: widget.api.orderPrintUrl(
                                      orderId: order.id,
                                      requesterId: widget.currentUser.userId,
                                    ),
                                    packingSlipUrl:
                                        widget.api.orderPackingSlipUrl(
                                      orderId: order.id,
                                      requesterId: widget.currentUser.userId,
                                    ),
                                    pdfUrl: widget.api.orderPdfUrl(
                                      orderId: order.id,
                                      requesterId: widget.currentUser.userId,
                                    ),
                                    onAssign: () =>
                                        _assignOrder(order, activeStaff),
                                    onUploadProof: () =>
                                        _uploadProofPhoto(order),
                                    onOpenProofGallery: () =>
                                        _openProofGallery(order),
                                    onResolveBackorder: () =>
                                        _resolveBackorder(order),
                                    proofCount: (_orderProofPhotos[order.id] ??
                                            const <String>[])
                                        .length,
                                    onDeliverPartial: () =>
                                        _deliverPartial(order),
                                    onFixDeliveryStatus: () =>
                                        _fixDeliveryStatus(order),
                                    onStatusChanged: (status) =>
                                        _updateStatus(order, status),
                                    onChatUpdated: _refresh,
                                  ),
                                ),
                              ];
                            })(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrdersPageData {
  _OrdersPageData({
    required this.orders,
    required this.users,
    required this.products,
  });

  final List<DeliveryOrder> orders;
  final List<AppUser> users;
  final List<Product> products;
}

class _CancelledOrdersPage extends StatelessWidget {
  const _CancelledOrdersPage({
    required this.orders,
    required this.currentUser,
    required this.api,
    required this.proofPhotos,
    required this.onLoadProofPhotos,
    required this.staff,
    required this.onAssign,
    required this.onOpenProofGallery,
  });

  final List<DeliveryOrder> orders;
  final AppUser currentUser;
  final StockApiService api;
  final Map<String, List<String>> proofPhotos;
  final Future<void> Function(String orderId) onLoadProofPhotos;
  final List<AppUser> staff;
  final Future<void> Function(DeliveryOrder order, List<AppUser> users)
      onAssign;
  final void Function(DeliveryOrder order) onOpenProofGallery;

  @override
  Widget build(BuildContext context) {
    final sorted = [...orders]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Scaffold(
      appBar: AppBar(
        title: const Text("ออเดอร์ที่ยกเลิก"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (sorted.isEmpty)
            const Center(child: Text("ยังไม่มีออเดอร์ที่ยกเลิก"))
          else
            ...sorted.map(
              (order) => _OrderTile(
                order: order,
                api: api,
                currentUser: currentUser,
                printUrl: api.orderPrintUrl(
                    orderId: order.id, requesterId: currentUser.userId),
                packingSlipUrl: api.orderPackingSlipUrl(
                    orderId: order.id, requesterId: currentUser.userId),
                pdfUrl: api.orderPdfUrl(
                    orderId: order.id, requesterId: currentUser.userId),
                onAssign: () => onAssign(order, staff),
                onUploadProof: () {},
                onOpenProofGallery: () => onOpenProofGallery(order),
                onResolveBackorder: () {},
                proofCount: (proofPhotos[order.id] ?? const <String>[]).length,
                onDeliverPartial: () {},
                onFixDeliveryStatus: () {},
                onStatusChanged: (_) {},
                onChatUpdated: () {},
              ),
            ),
        ],
      ),
    );
  }
}

class _BackorderReportSheet extends StatefulWidget {
  const _BackorderReportSheet({
    required this.backorders,
    required this.currentUser,
    required this.onFixStatus,
  });

  final List<DeliveryOrder> backorders;
  final AppUser currentUser;
  final Function(DeliveryOrder) onFixStatus;

  @override
  State<_BackorderReportSheet> createState() => _BackorderReportSheetState();
}

class _BackorderReportSheetState extends State<_BackorderReportSheet> {
  String _assigneeFilter = "all";
  String _dateFilter = "all";

  List<DeliveryOrder> _filteredOrders() {
    final now = DateTime.now();
    DateTime? from;
    if (_dateFilter == "today") {
      from = DateTime(now.year, now.month, now.day);
    } else if (_dateFilter == "7d") {
      from = now.subtract(const Duration(days: 7));
    } else if (_dateFilter == "30d") {
      from = now.subtract(const Duration(days: 30));
    }

    return widget.backorders.where((order) {
      final byAssignee = _assigneeFilter == "all" ||
          (_assigneeFilter == "unassigned" &&
              (order.assignedToId == null || order.assignedToId!.isEmpty)) ||
          order.assignedToId == _assigneeFilter;
      if (!byAssignee) return false;
      if (from == null) return true;
      return order.createdAt.isAfter(from) ||
          order.createdAt.isAtSameMomentAs(from);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final assignees = <String, String>{};
    for (final o in widget.backorders) {
      if (o.assignedToId != null && o.assignedToId!.isNotEmpty) {
        assignees[o.assignedToId!] = o.assignedToName ?? o.assignedToId!;
      }
    }
    final filtered = _filteredOrders();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("รายงานค้างจ่าย", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text("ทั้งหมด ${filtered.length} ออเดอร์"),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _assigneeFilter,
                decoration: const InputDecoration(labelText: "พนักงานส่ง"),
                items: [
                  const DropdownMenuItem(value: "all", child: Text("ทั้งหมด")),
                  const DropdownMenuItem(
                      value: "unassigned", child: Text("ยังไม่มอบหมาย")),
                  ...assignees.entries.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: (v) => setState(() => _assigneeFilter = v ?? "all"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _dateFilter,
                decoration: const InputDecoration(labelText: "ช่วงวันที่"),
                items: const [
                  DropdownMenuItem(value: "all", child: Text("ทั้งหมด")),
                  DropdownMenuItem(value: "today", child: Text("วันนี้")),
                  DropdownMenuItem(value: "7d", child: Text("7 วัน")),
                  DropdownMenuItem(value: "30d", child: Text("30 วัน")),
                ],
                onChanged: (v) => setState(() => _dateFilter = v ?? "all"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          const Expanded(
              child: Center(child: Text("ไม่มีออเดอร์ค้างจ่ายตามตัวกรอง")))
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (context, index) {
                final order = filtered[index];
                final pending = order.items
                    .where((item) => item.deliveredQuantity < item.quantity)
                    .map((item) =>
                        "${item.productName} ค้าง ${item.quantity - item.deliveredQuantity}")
                    .join(", ");
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.customerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  "ผู้ส่ง: ${order.assignedToName ?? "ยังไม่มอบหมาย"}"),
                            ],
                          ),
                        ),
                        if (widget.currentUser.isAdmin)
                          IconButton.filledTonal(
                            onPressed: () => widget.onFixStatus(order),
                            icon: const Icon(Icons.edit_note_rounded, size: 20),
                            tooltip: "แก้ไขจำนวนส่ง",
                          ),
                      ],
                    ),
                    Text(pending, style: const TextStyle(color: Colors.red)),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DraftOrderItem {
  _DraftOrderItem({
    this.barcode,
    String productQuery = "",
    String quantity = "1",
  })  : productController = TextEditingController(text: productQuery),
        quantityController = TextEditingController(text: quantity);

  String? barcode;
  final TextEditingController productController;
  final TextEditingController quantityController;

  void dispose() {
    productController.dispose();
    quantityController.dispose();
  }
}

class _AdminPageState extends State<AdminPage> {
  bool _isRunning = false;
  String? _lastMessage;
  late Future<Map<String, ExportLink>> _exportLinksFuture;
  final TextEditingController _downloadSearchController =
      TextEditingController();
  String _downloadSearch = "";
  String _downloadTypeFilter = "all";

  Future<void> _exportOrdersBackorderCsv() async {
    final orders =
        await widget.api.getOrders(requesterId: widget.currentUser.userId);
    final buffer = StringBuffer()
      ..writeln(
          "order_id,customer_name,status,assigned_to,created_by,items,delivered_items,backorder");
    for (final order in orders) {
      final totalItems = order.items.length;
      final deliveredItems =
          order.items.where((i) => i.deliveredQuantity >= i.quantity).length;
      final backorder = order.items
          .where((i) => i.deliveredQuantity < i.quantity)
          .map((i) => "${i.productName}:${i.quantity - i.deliveredQuantity}")
          .join("|");
      final esc = (String v) => "\"${v.replaceAll("\"", "\"\"")}\"";
      buffer.writeln([
        esc(order.id),
        esc(order.customerName),
        esc(order.status),
        esc(order.assignedToName ?? ""),
        esc(order.createdByName),
        totalItems,
        deliveredItems,
        esc(backorder),
      ].join(","));
    }
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/orders_backorder_report.csv");
    await file.writeAsString(buffer.toString(), flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: "รายงานออเดอร์และค้างจ่าย",
    );
  }

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
      widget.api.createExportLink(
          exportName: "products_csv", requesterId: requesterId),
      widget.api
          .createExportLink(exportName: "users_csv", requesterId: requesterId),
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
      _showSnack(
          "\u0e40\u0e09\u0e1e\u0e32\u0e30 admin \u0e40\u0e17\u0e48\u0e32\u0e19\u0e31\u0e49\u0e19\u0e17\u0e35\u0e48\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2b\u0e19\u0e49\u0e32\u0e19\u0e35\u0e49\u0e44\u0e14\u0e49");
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

  Future<void> _pickAndImportProductsExcel() async {
    if (!widget.currentUser.isAdmin) {
      _showSnack(
          "\u0e40\u0e09\u0e1e\u0e32\u0e30 admin \u0e40\u0e17\u0e48\u0e32\u0e19\u0e31\u0e49\u0e19\u0e17\u0e35\u0e48\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e2b\u0e19\u0e49\u0e32\u0e19\u0e35\u0e49\u0e44\u0e14\u0e49");
      return;
    }

    try {
      String? filePath;
      List<int>? bytes;
      String? filename;

      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ["xlsx", "xlsm"],
        withData: kIsWeb,
      );
      final platformFile =
          picked?.files.isNotEmpty == true ? picked!.files.first : null;
      if (platformFile == null) {
        _showSnack("ยังไม่ได้เลือกไฟล์ Excel");
        return;
      }

      filename = platformFile.name;
      if (kIsWeb) {
        if (platformFile.bytes == null || platformFile.bytes!.isEmpty) {
          _showSnack(
              "ไม่สามารถอ่านไฟล์ Excel จากเบราว์เซอร์ได้ ลองเลือกใหม่อีกครั้ง");
          return;
        }
        bytes = platformFile.bytes!;
      } else {
        filePath = platformFile.path;
        if (filePath == null || filePath.isEmpty) {
          _showSnack("ไม่พบ path ของไฟล์ Excel");
          return;
        }
      }

      setState(() {
        _isRunning = true;
      });
      final message = await widget.api.importProductsExcel(
        requesterId: widget.currentUser.userId,
        filePath: filePath,
        bytes: bytes,
        filename: filename,
      );
      if (!mounted) {
        return;
      }
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

  List<({String label, String url, DateTime? expiresAt, String group})>
      _buildExportItems(
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
        _EmptyTile(
          message:
              "ไม่พบไฟล์ที่ค้นหา ลองพิมพ์คำว่า Excel, CSV, สินค้า หรือ ประวัติ",
        ),
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
                title:
                    "\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25\u0e23\u0e30\u0e1a\u0e1a",
                subtitle:
                    "\u0e2b\u0e19\u0e49\u0e32\u0e19\u0e35\u0e49\u0e2a\u0e33\u0e2b\u0e23\u0e31\u0e1a\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25\u0e23\u0e30\u0e1a\u0e1a\u0e40\u0e17\u0e48\u0e32\u0e19\u0e31\u0e49\u0e19",
                showBackButton: true,
              ),
              SizedBox(height: 16),
              _EmptyTile(
                  message:
                      "\u0e1a\u0e31\u0e0d\u0e0a\u0e35\u0e19\u0e35\u0e49\u0e44\u0e21\u0e48\u0e21\u0e35\u0e2a\u0e34\u0e17\u0e18\u0e34\u0e4c\u0e43\u0e0a\u0e49\u0e07\u0e32\u0e19\u0e1f\u0e31\u0e07\u0e01\u0e4c\u0e0a\u0e31\u0e19 admin"),
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
              title:
                  "\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25\u0e23\u0e30\u0e1a\u0e1a",
              subtitle:
                  "\u0e07\u0e32\u0e19 sync \u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25\u0e41\u0e25\u0e30\u0e25\u0e34\u0e07\u0e01\u0e4c export \u0e2a\u0e33\u0e2b\u0e23\u0e31\u0e1a\u0e1c\u0e39\u0e49\u0e14\u0e39\u0e41\u0e25\u0e23\u0e30\u0e1a\u0e1a",
              showBackButton: true,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("\u0e04\u0e33\u0e2a\u0e31\u0e48\u0e07 Google Sheets",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isRunning
                          ? null
                          : () => _runAction(
                                () => widget.api
                                    .syncProducts(requesterId: requesterId),
                              ),
                      child: const Text(
                          "\u0e0b\u0e34\u0e07\u0e01\u0e4c\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed:
                          _isRunning ? null : _pickAndImportProductsExcel,
                      child: const Text(
                          "\u0e19\u0e33\u0e40\u0e02\u0e49\u0e32 Excel \u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _isRunning
                          ? null
                          : () => _runAction(
                                () => widget.api
                                    .syncUsers(requesterId: requesterId),
                              ),
                      child: const Text(
                          "\u0e0b\u0e34\u0e07\u0e01\u0e4c\u0e1c\u0e39\u0e49\u0e43\u0e0a\u0e49"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _isRunning
                          ? null
                          : () => _runAction(
                                () => widget.api
                                    .syncStocks(requesterId: requesterId),
                              ),
                      child: const Text(
                          "\u0e2d\u0e31\u0e1b\u0e40\u0e14\u0e15\u0e22\u0e2d\u0e14\u0e04\u0e07\u0e40\u0e2b\u0e25\u0e37\u0e2d"),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isRunning
                          ? null
                          : () => _runAction(
                                () => widget.api
                                    .appendTest(requesterId: requesterId),
                              ),
                      child: const Text(
                          "\u0e17\u0e14\u0e2a\u0e2d\u0e1a\u0e40\u0e1e\u0e34\u0e48\u0e21\u0e41\u0e16\u0e27"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _isRunning
                          ? null
                          : () => _runAction(() async {
                                await _exportOrdersBackorderCsv();
                                return "ส่งออกรายงานออเดอร์/ค้างจ่ายแล้ว";
                              }),
                      child: const Text("ส่งออกรายงานออเดอร์/ค้างจ่าย (CSV)"),
                    ),
                    if (_lastMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                          "\u0e25\u0e48\u0e32\u0e2a\u0e38\u0e14: $_lastMessage"),
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
                    Text(
                        "\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e2a\u0e48\u0e07\u0e2d\u0e2d\u0e01\u0e02\u0e49\u0e2d\u0e21\u0e39\u0e25",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    const Text(
                        "\u0e40\u0e1b\u0e34\u0e14\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e40\u0e2b\u0e25\u0e48\u0e32\u0e19\u0e35\u0e49\u0e43\u0e19\u0e40\u0e1a\u0e23\u0e32\u0e27\u0e4c\u0e40\u0e0b\u0e2d\u0e23\u0e4c\u0e17\u0e35\u0e48\u0e40\u0e02\u0e49\u0e32\u0e16\u0e36\u0e07 backend \u0e44\u0e14\u0e49"),
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
                    Text(
                        "\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e0a\u0e31\u0e48\u0e27\u0e04\u0e23\u0e32\u0e27\u0e41\u0e1a\u0e1a\u0e1b\u0e25\u0e2d\u0e14\u0e20\u0e31\u0e22",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    const Text(
                        "\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e0a\u0e38\u0e14\u0e19\u0e35\u0e49\u0e0b\u0e48\u0e2d\u0e19 requester_id \u0e41\u0e25\u0e30\u0e43\u0e0a\u0e49\u0e44\u0e14\u0e49\u0e0a\u0e48\u0e27\u0e07\u0e2a\u0e31\u0e49\u0e19 \u0e46"),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _refreshExportLinks,
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                            "\u0e2a\u0e23\u0e49\u0e32\u0e07\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e43\u0e2b\u0e21\u0e48"),
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
                                : snapshot.error
                                    .toString()
                                    .replaceFirst("Exception: ", ""),
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
    required this.activeOrders,
    required this.todayUpdatedOrders,
  });

  final StockSummary summary;
  final List<Product> products;
  final List<DeliveryOrder> activeOrders;
  final List<DeliveryOrder> todayUpdatedOrders;
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

  factory _ChatMessage.user(String text) =>
      _ChatMessage(text: text, isUser: true);

  factory _ChatMessage.bot(
    String text, {
    List<Product> products = const [],
    bool usedAi = false,
    ChatAssistantAction? action,
    ExportLink? downloadLink,
  }) {
    return _ChatMessage(
      text: _repairThaiMojibake(text),
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
      "in" => "เพิ่มสต็อก",
      "issue" => "เบิกใช้",
      _ => "ตัด/เบิกสต็อก",
    };
    return "$verb จำนวน $quantity สำหรับ \"$productHint\"";
  }
}

_PendingChatAction? _detectPendingChatAction(String message) {
  final lowered = message.trim().toLowerCase();
  final intents = <String, List<String>>{
    "in": [
      "เพิ่ม",
      "รับเข้า",
      "เติม",
      "นำเข้า",
      "เอาเข้า",
      "เพิ่มสต็อก",
      "เพิ่มสต็อก"
    ],
    "out": [
      "เบิก",
      "ตัด",
      "ลด",
      "จ่ายออก",
      "เอาออก",
      "ลดสต็อก",
      "ลดสต็อก",
      "ตัดสต็อก",
      "ตัดสต็อก"
    ],
    "issue": ["issue", "ใช้ไป", "นำออกใช้", "หยิบใช้", "เบิกใช้"],
  };

  String? detectedType;
  List<String> matchedKeywords = const [];
  for (final entry in intents.entries) {
    final hit =
        entry.value.where((keyword) => lowered.contains(keyword)).toList();
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

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1650),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 90,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  final truckX = Curves.easeInOut.transform(t) * 148;
                  return Stack(
                    children: [
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 16,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: _brandPrimary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      ...List.generate(4, (index) {
                        final offset = ((t * 6) + index) % 6;
                        return Positioned(
                          left: 34 + (offset * 24),
                          bottom: 19,
                          child: Opacity(
                            opacity: 0.12 + (index * 0.06),
                            child: Container(
                              width: 14,
                              height: 3,
                              decoration: BoxDecoration(
                                color: _brandDeep.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        );
                      }),
                      Positioned(
                        left: 18 + truckX,
                        top: 26 + (t < 0.5 ? 1.5 : 0),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _brandPrimary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            size: 24,
                            color: _brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "กำลังโหลดข้อมูล...",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _brandDeep,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              "แมวกำลังช่วยเช็กสต็อกให้คุณ",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _brandInk.withOpacity(0.7),
                  ),
            ),
          ],
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
      padding:
          const EdgeInsets.fromLTRB(_spaceLg, _spaceLg, _spaceLg, _spaceMd),
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
    this.positionLabel,
  });

  final String? imageUrl;
  final String name;
  final String roleLabel;
  final String? positionLabel;

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                if (positionLabel != null &&
                    positionLabel!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    "ตำแหน่ง: ${positionLabel!.trim()}",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _brandInk.withOpacity(0.78),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
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
      // Force a fresh image resolution when the URL changes (helps on web + in-app caches).
      key: ValueKey(imageUrl),
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
    final alignment =
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
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
                  if (!message.isUser &&
                      (message.usedAi || message.action != null)) ...[
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
                            tone: message.action!.lowStock
                                ? _brandPrimary
                                : _brandDeep,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    message.text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: textColor),
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
                  onPrintLabel: () => onOpenProduct(product),
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

class OrderChatPage extends StatefulWidget {
  const OrderChatPage({
    super.key,
    required this.api,
    required this.currentUser,
    required this.order,
  });

  final StockApiService api;
  final AppUser currentUser;
  final DeliveryOrder order;

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _isLoading = false;
  bool _isSending = false;
  List<OrderMessageModel> _messages = const [];

  @override
  void initState() {
    super.initState();
    widget.api.markOrderMessagesRead(
      requesterId: widget.currentUser.userId,
      orderId: widget.order.id,
    );
    _load(initial: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _isSending) return;
      _load();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final items = await widget.api.getOrderMessages(
        requesterId: widget.currentUser.userId,
        orderId: widget.order.id,
      );
      await widget.api.markOrderMessagesRead(
        requesterId: widget.currentUser.userId,
        orderId: widget.order.id,
      );
      if (!mounted) return;
      setState(() {
        _messages = items;
      });
      if (initial) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    } catch (_) {
      // Silent background refresh.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isSending = true;
    });
    _controller.clear();
    try {
      await widget.api.postOrderMessage(
        requesterId: widget.currentUser.userId,
        orderId: widget.order.id,
        message: text,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        _showAppSnack(
          context,
          error.toString().replaceFirst("Exception: ", ""),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderTitle = widget.order.customerName;
    return Scaffold(
      appBar: AppBar(
        title: Text("แชทออเดอร์: $orderTitle"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final item = _messages[index];
                final isMe = item.userId == widget.currentUser.userId;
                final bubbleColor = isMe ? _brandPrimary : Colors.white;
                final textColor = isMe ? Colors.white : _brandInk;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                      border: isMe
                          ? null
                          : Border.all(color: _brandPrimary.withOpacity(0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.userName,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: textColor.withOpacity(0.85),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.message,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: "พิมพ์ข้อความติดตามงาน...",
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    tooltip: "ส่ง",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.api,
    required this.currentUser,
    required this.printUrl,
    required this.packingSlipUrl,
    required this.pdfUrl,
    required this.onAssign,
    required this.onUploadProof,
    required this.onOpenProofGallery,
    required this.onResolveBackorder,
    required this.proofCount,
    required this.onDeliverPartial,
    required this.onFixDeliveryStatus,
    required this.onStatusChanged,
    required this.onChatUpdated,
  });

  final DeliveryOrder order;
  final StockApiService api;
  final AppUser currentUser;
  final String printUrl;
  final String packingSlipUrl;
  final String pdfUrl;
  final VoidCallback onAssign;
  final VoidCallback onUploadProof;
  final VoidCallback onOpenProofGallery;
  final VoidCallback onResolveBackorder;
  final int proofCount;
  final VoidCallback onDeliverPartial;
  final VoidCallback onFixDeliveryStatus;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onChatUpdated;

  String _fmtOrderDateTime(DateTime value) {
    final dd = value.day.toString().padLeft(2, "0");
    final mm = value.month.toString().padLeft(2, "0");
    final yy = value.year;
    final hh = value.hour.toString().padLeft(2, "0");
    final mi = value.minute.toString().padLeft(2, "0");
    return "$dd/$mm/$yy $hh:$mi";
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Color _statusTone() {
    switch (order.status) {
      case "assigned":
        return _profileTeal;
      case "preparing":
        return _profileAccent;
      case "out_for_delivery":
        return _brandPrimary;
      case "delivered":
        return _brandDeep;
      case "cancelled":
        return Colors.redAccent;
      default:
        return _brandInk;
    }
  }

  String _statusLabel() {
    switch (order.status) {
      case "assigned":
        return "กำลังจัดคิว";
      case "in_production":
        return "กำลังผลิต";
      case "qc_pending":
        return "รอ QC";
      case "rework_required":
        return "ตีกลับแก้";
      case "qc_passed":
        return "QC ผ่าน";
      case "preparing":
        return "กำลังจัดสินค้า";
      case "out_for_delivery":
        return "กำลังส่ง";
      case "delivered":
        return "ส่งแล้ว";
      case "cancelled":
        return "ยกเลิก";
      default:
        return "รอดำเนินการ";
    }
  }

  @override
  Widget build(BuildContext context) {
    String _roleNorm(String? value) => (value ?? "").trim().toLowerCase();
    bool _hasThaiWord(String haystack, String needle) =>
        haystack.contains(needle);
    String _nameNorm(String? value) =>
        (value ?? "").trim().toLowerCase().replaceAll(RegExp(r"\\s+"), " ");

    final canAssign =
        currentUser.isAdmin || currentUser.userId == order.createdById;
    final role = _roleNorm(currentUser.role);
    final isProducerRole =
        role.contains("production") || _hasThaiWord(role, "ผลิต");
    final isQcRole =
        role == "qc" || role.contains("quality") || role.contains("ตรวจ");
    final isDeliveryRole =
        role.contains("delivery") || _hasThaiWord(role, "ส่ง");

    final isProducerNameMatch =
        _nameNorm(currentUser.userName) == _nameNorm(order.productionUserName);
    final isQcNameMatch =
        _nameNorm(currentUser.userName) == _nameNorm(order.qcUserName);
    final isDeliveryNameMatch =
        _nameNorm(currentUser.userName) == _nameNorm(order.deliveryUserName);

    final isProducer = currentUser.userId == (order.productionUserId ?? "") ||
        isProducerNameMatch ||
        isProducerRole;
    final isQc = currentUser.userId == (order.qcUserId ?? "") ||
        isQcNameMatch ||
        isQcRole;
    final isDelivery = currentUser.userId == (order.deliveryUserId ?? "") ||
        currentUser.userId == (order.assignedToId ?? "") ||
        isDeliveryNameMatch ||
        isDeliveryRole;
    final canOperate = currentUser.isAdmin ||
        currentUser.userId == order.createdById ||
        isProducer ||
        isQc ||
        isDelivery;
    final hasProduction = (order.productionUserId ?? "").isNotEmpty ||
        (order.productionUserName ?? "").trim().isNotEmpty;
    final qcAssigned = (order.qcUserId ?? "").isNotEmpty ||
        (order.qcUserName ?? "").trim().isNotEmpty;
    // If the team didn't explicitly assign QC, still allow QC-role staff/admin
    // to see and claim QC steps.
    final qcEnabled = qcAssigned || currentUser.isAdmin || isQcRole;
    final canMarkDelivered = proofCount > 0;
    final deliveredCount = order.items
        .where((item) => item.deliveredQuantity >= item.quantity)
        .length;
    final hasBackorder = (order.note ?? "").contains("ค้างจ่าย");
    final canCancel =
        (currentUser.isAdmin || currentUser.userId == order.createdById) &&
            order.status != "delivered" &&
            order.status != "cancelled";
    final isCancelled = order.status == "cancelled";
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (order.unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "${order.unreadCount}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (hasBackorder)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.red.withOpacity(0.35)),
                    ),
                    child: const Text(
                      "ค้างจ่าย",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusTone().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _statusTone(),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "สถานะการส่งสินค้า: ส่งแล้ว $deliveredCount/${order.items.length} รายการ",
            ),
            const SizedBox(height: 6),
            ...order.items.map((item) {
              final isDone = item.deliveredQuantity >= item.quantity;
              final remaining = (item.quantity - item.deliveredQuantity)
                  .clamp(0, item.quantity);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color:
                          isDone ? Colors.green : _brandInk.withOpacity(0.55),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isDone
                            ? "${item.productName} x${item.quantity} (ส่งแล้ว)"
                            : "${item.productName} x${item.quantity} (ค้าง $remaining)",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDone ? Colors.green.shade700 : _brandInk,
                              fontWeight:
                                  isDone ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
              Text("โทร: ${order.customerPhone}"),
            if (order.customerAddress != null &&
                order.customerAddress!.isNotEmpty)
              Text("ที่อยู่: ${order.customerAddress}"),
            Text("ผู้รับออเดอร์: ${order.createdByName}"),
            Text(
              "ผู้ส่ง (ผู้รับผิดชอบ): ${order.assignedToName ?? "ยังไม่ระบุ"}${(order.assignedToId ?? "").isNotEmpty ? " (${order.assignedToId})" : ""}",
            ),
            if (order.lastHandoffFrom != null &&
                order.lastHandoffTo != null &&
                order.lastHandoffAt != null)
              Text(
                "ล่าสุด: ${order.lastHandoffFrom} -> ${order.lastHandoffTo} · ${_fmtOrderDateTime(order.lastHandoffAt!)}",
              ),
            Text(
              "ฝ่ายผลิต: ${(order.productionUserName ?? "-")}${(order.productionUserId ?? "").isNotEmpty ? " (${order.productionUserId})" : ""}",
            ),
            Text(
              "QC: ${(order.qcUserName ?? "-")}${(order.qcUserId ?? "").isNotEmpty ? " (${order.qcUserId})" : ""}",
            ),
            Text(
              "จัดส่ง: ${(order.deliveryUserName ?? "-")}${(order.deliveryUserId ?? "").isNotEmpty ? " (${order.deliveryUserId})" : ""}",
            ),
            if (order.scheduledDeliveryAt != null)
              Text(
                "กำหนดส่ง: ${_fmtOrderDateTime(order.scheduledDeliveryAt!)}",
              ),
            if (order.note != null && order.note!.isNotEmpty)
              Text("หมายเหตุ: ${order.note}"),
            const SizedBox(height: 10),
            if (order.status == "delivered")
              OutlinedButton.icon(
                onPressed: onOpenProofGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text("รูปหลักฐาน ($proofCount)"),
              )
            else if (isCancelled)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderChatPage(
                            api: api,
                            currentUser: currentUser,
                            order: order,
                          ),
                        ),
                      );
                      onChatUpdated();
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text("แชทติดตามงาน"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(printUrl),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text("พิมพ์ใบออเดอร์"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(packingSlipUrl),
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: const Text("ใบปะหน้าจัดของ"),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenProofGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text("รูปหลักฐาน ($proofCount)"),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(printUrl),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text("พิมพ์ใบออเดอร์"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(packingSlipUrl),
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: const Text("ใบปะหน้าจัดของ"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderChatPage(
                            api: api,
                            currentUser: currentUser,
                            order: order,
                          ),
                        ),
                      );
                      onChatUpdated();
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text("แชทติดตามงาน"),
                  ),
                  OutlinedButton.icon(
                    onPressed: canOperate ? onUploadProof : null,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text("ถ่ายรูปหลักฐาน"),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenProofGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text("รูปหลักฐาน ($proofCount)"),
                  ),
                  if (hasBackorder)
                    OutlinedButton.icon(
                      onPressed: onResolveBackorder,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("ปิดค้างจ่าย"),
                    ),
                  FilledButton.tonal(
                    onPressed: canOperate ? onDeliverPartial : null,
                    child: const Text("ส่งบางส่วน"),
                  ),
                  OutlinedButton.icon(
                    onPressed: canOperate ? onFixDeliveryStatus : null,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text("แก้ไขจำนวนส่ง"),
                  ),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text("ยกเลิกออเดอร์"),
                            content:
                                const Text("ต้องการยกเลิกออเดอร์นี้ใช่ไหม"),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text("ไม่ยกเลิก"),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text("ยกเลิกออเดอร์"),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          onStatusChanged("cancelled");
                        }
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text("ยกเลิกออเดอร์"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  // If production/QC aren't configured, skip those steps and move to delivery flow.
                  if (hasProduction &&
                      (currentUser.isAdmin || isProducer) &&
                      (order.status == "new" ||
                          order.status == "assigned" ||
                          order.status == "rework_required"))
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("in_production"),
                      child: const Text("เริ่มผลิต"),
                    ),
                  // Allow sending to QC even if production wasn't assigned (some teams skip the production step).
                  if (qcEnabled &&
                      (currentUser.isAdmin || isProducer) &&
                      (order.status == "in_production" ||
                          ((!hasProduction) &&
                              (order.status == "new" ||
                                  order.status == "assigned" ||
                                  order.status == "rework_required"))))
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("qc_pending"),
                      child: const Text("ส่ง QC"),
                    ),
                  if (qcEnabled &&
                      (currentUser.isAdmin || isQc) &&
                      order.status == "qc_pending")
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("rework_required"),
                      child: const Text("ตีกลับแก้"),
                    ),
                  if (qcEnabled &&
                      (currentUser.isAdmin || isQc) &&
                      order.status == "qc_pending")
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("qc_passed"),
                      child: const Text("QC ผ่าน"),
                    ),
                  if ((currentUser.isAdmin || isDelivery) &&
                      ((hasProduction &&
                              qcAssigned &&
                              order.status == "qc_passed") ||
                          (hasProduction &&
                              !qcAssigned &&
                              order.status == "in_production") ||
                          (!hasProduction &&
                              !qcAssigned &&
                              (order.status == "new" ||
                                  order.status == "assigned"))))
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("preparing"),
                      child: const Text("กำลังจัด"),
                    ),
                  if ((currentUser.isAdmin || isDelivery) &&
                      order.status == "preparing")
                    FilledButton.tonal(
                      onPressed: () => onStatusChanged("out_for_delivery"),
                      child: const Text("กำลังส่ง"),
                    ),
                  FilledButton.tonal(
                    onPressed: (canOperate && canMarkDelivered)
                        ? () => onStatusChanged("delivered")
                        : null,
                    child: const Text("ส่งแล้ว"),
                  ),
                  if (!canMarkDelivered)
                    Text(
                      "ต้องมีรูปหลักฐานก่อนกดส่งแล้ว",
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: _brandPrimary),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DeliverySuccessOverlay extends StatefulWidget {
  const _DeliverySuccessOverlay();

  @override
  State<_DeliverySuccessOverlay> createState() =>
      _DeliverySuccessOverlayState();
}

class _DeliverySuccessOverlayState extends State<_DeliverySuccessOverlay> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 330,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _brandPrimary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, 0.65),
                      child: Container(
                        width: 220,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _brandPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: -1.2, end: 1.2),
                      duration: const Duration(milliseconds: 1800),
                      curve: Curves.easeInOutCubic,
                      builder: (context, value, child) => Align(
                        alignment: Alignment(value, 0.25),
                        child: child,
                      ),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        size: 34,
                        color: _brandPrimary.withOpacity(0.85),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: -1.35, end: 1.0),
                      duration: const Duration(milliseconds: 1600),
                      curve: Curves.easeInOutCubic,
                      builder: (context, value, child) => Align(
                        alignment: Alignment(value, -0.1),
                        child: child,
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        size: 46,
                        color: _brandDeep.withOpacity(0.88),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: -1.55, end: 0.8),
                      duration: const Duration(milliseconds: 1700),
                      curve: Curves.easeInOutCubic,
                      builder: (context, value, child) => Align(
                        alignment: Alignment(value, 0.15),
                        child: child,
                      ),
                      child: Icon(
                        Icons.all_inbox_rounded,
                        size: 42,
                        color: _profileAccent.withOpacity(0.92),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "ส่งสินค้าเรียบร้อย!",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: _brandDeep),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    this.onOpenCode,
    this.onPrintLabel,
  });

  final Product product;
  final VoidCallback? onOpenCode;
  final VoidCallback? onPrintLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
        minLeadingWidth: 34,
        onTap: onOpenCode,
        title: Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "${product.barcode} · ${product.location ?? "ไม่ระบุตำแหน่ง"}",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5),
        ),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: (product.isLowStock ? _brandPrimary : _brandDeep)
              .withOpacity(0.10),
          child: Icon(
            product.isLowStock
                ? Icons.warning_amber_rounded
                : Icons.inventory_2_rounded,
            size: 18,
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
                Text(
                  "${product.currentStock} ${product.unit}",
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                Text(
                  "min ${product.minimumStock}",
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        product.isLowStock ? _brandPrimary : _brandTextOnLight,
                  ),
                ),
              ],
            ),
            if (onPrintLabel != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onPrintLabel,
                icon: const Icon(Icons.print_outlined, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: "พิมพ์ป้ายสินค้า",
              ),
            ],
            if (onOpenCode != null) ...[
              const SizedBox(width: 2),
              IconButton(
                onPressed: onOpenCode,
                icon: const Icon(Icons.qr_code_2_outlined, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
          "${item.actorName} (${item.actorId}) · ${item.action} · ${_formatDateTime(item.createdAt)}",
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
          child: const Icon(Icons.notifications_active_outlined,
              color: _brandPrimary),
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
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(color: tone),
          ),
          const SizedBox(height: 8),
          Text(result.product.name),
          Text(
              "\u0e1a\u0e32\u0e23\u0e4c\u0e42\u0e04\u0e49\u0e14: ${result.product.barcode}"),
          Text(
              "\u0e04\u0e07\u0e40\u0e2b\u0e25\u0e37\u0e2d: ${result.product.currentStock} ${result.product.unit}"),
          Text(
              "\u0e1c\u0e39\u0e49\u0e17\u0e33\u0e23\u0e32\u0e22\u0e01\u0e32\u0e23: ${result.movement.actorName}"),
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

Future<void> _showCustomLabelSheet(BuildContext context, String label) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CustomLabelSheet(label: label),
  );
}

Future<void> _showOutOfStockSheet(
    BuildContext context, List<Product> products) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      builder: (context, controller) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Colors.redAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "สินค้าหมด: ${products.length} รายการ",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _brandDeep,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: "ปิด",
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "แตะสินค้าเพื่อดู barcode/QR และพิมพ์ป้ายได้ทันที",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _brandInk.withOpacity(0.72),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.redAccent.withOpacity(0.10),
                      child: const Icon(Icons.error_outline,
                          color: Colors.redAccent),
                    ),
                    title: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      "${product.barcode} · คงเหลือ ${product.currentStock} ${product.unit}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showProductCodeSheet(context, product),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
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
  bool _isPrinting = false;

  Future<Uint8List> _captureLabelBytes() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception("ไม่พบภาพสำหรับสร้างป้ายสินค้า");
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) {
      throw Exception("สร้างไฟล์ภาพป้ายสินค้าไม่สำเร็จ");
    }
    return bytes;
  }

  Future<void> _shareLabel() async {
    try {
      setState(() {
        _isSharing = true;
      });

      final bytes = await _captureLabelBytes();

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

  Future<void> _printLabel() async {
    try {
      setState(() {
        _isPrinting = true;
      });

      final bytes = await _captureLabelBytes();
      final image = pw.MemoryImage(bytes);
      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a6,
              margin: const pw.EdgeInsets.all(16),
              build: (context) => pw.Center(
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          );
          return doc.save();
        },
        name: "${widget.product.name}-${widget.product.barcode}",
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
          _isPrinting = false;
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
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: _brandPrimary.withOpacity(0.10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          product.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
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
                          drawText: false,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.barcode,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _brandInk,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
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
                        onPressed: _isPrinting ? null : _printLabel,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.print_outlined),
                        label: const Text("พิมพ์ป้ายสินค้า"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSharing ? null : _shareLabel,
                        icon: _isSharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.ios_share_outlined),
                        label: const Text(
                            "\u0e41\u0e0a\u0e23\u0e4c / \u0e2a\u0e48\u0e07\u0e2d\u0e2d\u0e01\u0e1b\u0e49\u0e32\u0e22"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: product.barcode));
                        if (context.mounted) {
                          _showAppSnack(
                            context,
                            "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01 barcode \u0e41\u0e25\u0e49\u0e27",
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_all_outlined),
                      tooltip:
                          "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01\u0e23\u0e2b\u0e31\u0e2a",
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

class _CustomLabelSheet extends StatefulWidget {
  const _CustomLabelSheet({required this.label});

  final String label;

  @override
  State<_CustomLabelSheet> createState() => _CustomLabelSheetState();
}

class _CustomLabelSheetState extends State<_CustomLabelSheet> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isSharing = false;
  bool _isPrinting = false;

  Future<Uint8List> _captureLabelBytes() async {
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception("ไม่พบภาพสำหรับสร้างป้ายชื่อสินค้า");
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) {
      throw Exception("สร้างไฟล์ภาพป้ายชื่อสินค้าไม่สำเร็จ");
    }
    return bytes;
  }

  Future<void> _shareLabel() async {
    try {
      setState(() {
        _isSharing = true;
      });

      final bytes = await _captureLabelBytes();
      final tempDir = await getTemporaryDirectory();
      final safeName =
          widget.label.trim().replaceAll(RegExp(r"[^a-zA-Z0-9ก-๙_-]+"), "_");
      final file = File("${tempDir.path}/$safeName-custom-label.png");
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: widget.label,
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

  Future<void> _printLabel() async {
    try {
      setState(() {
        _isPrinting = true;
      });

      final bytes = await _captureLabelBytes();
      final image = pw.MemoryImage(bytes);
      await Printing.layoutPdf(
        onLayout: (format) async {
          final doc = pw.Document();
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a6,
              margin: const pw.EdgeInsets.all(16),
              build: (context) => pw.Center(
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          );
          return doc.save();
        },
        name: widget.label,
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
          _isPrinting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        "พิมพ์ชื่อสินค้า",
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
                    constraints:
                        const BoxConstraints(maxWidth: 420, minHeight: 220),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: _brandPrimary.withOpacity(0.10)),
                    ),
                    child: Center(
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: _brandInk,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isPrinting ? null : _printLabel,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.print_outlined),
                        label: const Text("พิมพ์ชื่อสินค้า"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSharing ? null : _shareLabel,
                        icon: _isSharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.ios_share_outlined),
                        label: const Text("แชร์ / ส่งออกป้าย"),
                      ),
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
      _showAppSnack(context,
          "\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e44\u0e21\u0e48\u0e16\u0e39\u0e01\u0e15\u0e49\u0e2d\u0e07");
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
      _showAppSnack(context,
          "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01\u0e25\u0e34\u0e07\u0e01\u0e4c\u0e41\u0e25\u0e49\u0e27");
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
                    label: const Text(
                        "\u0e14\u0e32\u0e27\u0e19\u0e4c\u0e42\u0e2b\u0e25\u0e14\u0e40\u0e25\u0e22"),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _copyUrl(context),
                  icon: const Icon(Icons.copy_all_outlined),
                  tooltip:
                      "\u0e04\u0e31\u0e14\u0e25\u0e2d\u0e01\u0e25\u0e34\u0e07\u0e01\u0e4c",
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

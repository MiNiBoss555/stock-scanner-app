import "dart:async";
import "dart:io";
import "dart:math";

import "dart:convert";
import "package:file_picker/file_picker.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart";
import "package:image_picker/image_picker.dart";
import "package:mobile_scanner/mobile_scanner.dart" hide Barcode;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

import "api_service.dart";
import "orders_page.dart";
import "order_chat_page.dart";
import "product_label_sheets.dart";
import "product_search_page.dart";
import "chat_assistant_page.dart";
import "profile_page.dart";
import "dashboard_components.dart";
import "dashboard_home.dart";
import "login_page.dart";
import "scan_page.dart";
import "dashboard_page.dart";
import "models.dart";
import "theme/app_theme.dart";



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
  // Firebase options aren't configured for web or windows in this project yet.
  // Avoid crashing; push notifications remain mobile-only.
  if (!kIsWeb && !Platform.isWindows) {
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
    if (!kIsWeb && !Platform.isWindows) {
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
    if (kIsWeb || Platform.isWindows) return;
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
  final GlobalKey<DashboardPageState> _dashboardKey =
      GlobalKey<DashboardPageState>();
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
        routeObserver: _StockScannerAppState._routeObserver,
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
        onOpenProductList: (context, products, title, icon, color) {
          showProductListSheet(
            context: context,
            products: products,
            title: title,
            icon: icon,
            color: color,
          );
        },
        onOpenProductDetails: (context, product) => showProductCodeSheet(context, product),
        onOpenCustomLabel: (context, label) => showCustomLabelSheet(context, label),
        onOpenOrderChat: (context, order) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderChatPage(
              api: widget.api,
              currentUser: widget.currentUser,
              order: order,
            ),
          ),
        ),
      ),
      ScanPage(
        api: widget.api,
        currentUser: widget.currentUser,
        onOpenProductDetails: (context, product) => showProductCodeSheet(context, product),
      ),
      HistoryPage(api: widget.api, refreshSignal: _realtimeRevision),
      ChatAssistantPage(
        api: widget.api,
        refreshSignal: _realtimeRevision,
        onOpenProductDetails: (context, product) => showProductCodeSheet(context, product),
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
          ProductSearchPage(
            api: api,
            onOpenProductDetails: (context, product) => showProductCodeSheet(context, product),
          ),
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

  Future<void> _downloadAndShareBackup() async {
    if (!widget.currentUser.isAdmin) return;

    _showSnack("กำลังสำรองข้อมูล...");

    setState(() {
      _isRunning = true;
    });
    try {
      debugPrint("Starting downloadBackup for user: ${widget.currentUser.userId}");
      final bytes = await widget.api.downloadBackup(widget.currentUser.userId);
      debugPrint("downloadBackup completed, received ${bytes.length} bytes");

      final dir = await getTemporaryDirectory();

      final now = DateTime.now();
      final timestamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
          "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";

      final file = File("${dir.path}/backup_$timestamp.zip");
      await file.writeAsBytes(bytes, flush: true);

      debugPrint("Backup file written to: ${file.path}");

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Backup System Data",
      );

      _showSnack("ดาวน์โหลดไฟล์สำรองแล้ว");

      if (mounted) {
        setState(() {
          _lastMessage = "ดาวน์โหลดไฟล์สำรองแล้ว";
        });
      }
    } catch (error) {
      debugPrint("Backup failed: $error");
      _showSnack(error.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }
  Future<bool> _confirmRestoreBackup() async {
    final controller = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Restore System Data"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "WARNING: DESTRUCTIVE ACTION!",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "This will completely REPLACE the current database and all uploaded files. This cannot be undone.",
                ),
                const SizedBox(height: 12),
                const Text(
                  "Type RESTORE in the field below to confirm this action.",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  inputFormatters: [UpperCaseTextFormatter()],
                  decoration: const InputDecoration(
                    labelText: "Confirmation",
                    hintText: "RESTORE",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("CANCEL"),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final isMatch = value.text.trim().toUpperCase() == "RESTORE";
                  return FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isMatch ? Colors.red : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isMatch
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    child: const Text("CONFIRM RESTORE"),
                  );
                },
              ),
            ],
          );
        },
      );
      return confirmed == true;
    } finally {
      controller.dispose();
    }
  }

  Future<void> _pickAndRestoreBackup() async {
    if (!widget.currentUser.isAdmin) return;

    final confirmed = await _confirmRestoreBackup();
    if (!confirmed) {
      _showSnack("Restore cancelled.");
      return;
    }

    try {
      String? filePath;
      List<int>? bytes;
      String? filename;

      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ["zip"],
        withData: kIsWeb,
      );
      final platformFile =
          picked?.files.isNotEmpty == true ? picked!.files.first : null;
      if (platformFile == null) {
        _showSnack("No backup ZIP selected.");
        return;
      }

      filename = platformFile.name;
      if (kIsWeb) {
        if (platformFile.bytes == null || platformFile.bytes!.isEmpty) {
          _showSnack("Unable to read the selected backup ZIP.");
          return;
        }
        bytes = platformFile.bytes!;
      } else {
        filePath = platformFile.path;
        if (filePath == null || filePath.isEmpty) {
          _showSnack("Unable to read the selected backup ZIP path.");
          return;
        }
      }

      _showSnack("กำลังกู้คืนข้อมูล...");
      setState(() {
        _isRunning = true;
      });

      debugPrint("Starting restoreBackup for user: ${widget.currentUser.userId}");
      final message = await widget.api.restoreBackup(
        requesterId: widget.currentUser.userId,
        filePath: filePath,
        bytes: bytes,
        filename: filename,
      );
      debugPrint("restoreBackup completed: $message");

      if (!mounted) return;

      _showSnack("กู้คืนข้อมูลสำเร็จ");

      setState(() {
        _lastMessage = message;
      });
    } catch (error) {
      debugPrint("Restore failed: $error");
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
                                return "\u0e2a\u0e48\u0e07\u0e2d\u0e2d\u0e01\u0e23\u0e32\u0e22\u0e07\u0e32\u0e19\u0e2d\u0e2d\u0e40\u0e14\u0e2d\u0e23\u0e4c/\u0e07\u0e32\u0e19\u0e04\u0e49\u0e32\u0e07\u0e2a\u0e48\u0e07\u0e41\u0e25\u0e49\u0e27";
                              }),
                      child: const Text(
                          "\u0e2a\u0e48\u0e07\u0e2d\u0e2d\u0e01\u0e23\u0e32\u0e22\u0e07\u0e32\u0e19\u0e2d\u0e2d\u0e40\u0e14\u0e2d\u0e23\u0e4c/\u0e07\u0e32\u0e19\u0e04\u0e49\u0e32\u0e07\u0e2a\u0e48\u0e07 (CSV)"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isRunning ? null : _downloadAndShareBackup,
                      child: const Text("Download Backup (ZIP)"),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isRunning ? null : _pickAndRestoreBackup,
                      child: const Text("Restore Backup (ZIP)"),
                    ),
                    if (_lastMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        "\u0e25\u0e48\u0e32\u0e2a\u0e38\u0e14: $_lastMessage",
                      ),
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
                        hintText: "\u0e04\u0e49\u0e19\u0e2b\u0e32\u0e44\u0e1f\u0e25\u0e4c \u0e40\u0e0a\u0e48\u0e19 Excel, CSV, \u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32",
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
                          label: Text("\u0e17\u0e31\u0e49\u0e07\u0e2b\u0e21\u0e14"),
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

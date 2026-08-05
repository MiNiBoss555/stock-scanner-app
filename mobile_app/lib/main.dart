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
import "config.dart";
import "server_scanner.dart";
import "admin_page.dart";
import "product_recycle_bin_page.dart";
import "product_activity_log_page.dart";
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
import "help_center_page.dart";
import "models.dart";
import "theme/app_theme.dart";
import "package:google_fonts/google_fonts.dart";



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
const String _webBuildTag = "v1.0.11";
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
  if (lowered.contains("socketexception") ||
      lowered.contains("clientexception") ||
      lowered.contains("connection refused") ||
      lowered.contains("errno = 111") ||
      lowered.contains("errno = 1225")) {
    return "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาเปิดเซิร์ฟเวอร์บนคอมพิวเตอร์ เช็กว่าต่อ Wi-Fi เดียวกัน หรือกดเปลี่ยน IP เซิร์ฟเวอร์";
  }
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
  await AppConfig.loadCustomServerUrl();
  // Firebase options aren't configured for web or windows in this project yet.
  // Avoid crashing; push notifications remain mobile-only.
  if (!kIsWeb && !Platform.isWindows) {
    await Firebase.initializeApp();
  }
  final appSettings = AppSettings();
  await appSettings.loadSettings(); // await so theme is ready before first frame
  runApp(StockScannerApp(initialSettings: appSettings));
}

class StockScannerApp extends StatefulWidget {
  const StockScannerApp({super.key, this.initialSettings});

  final AppSettings? initialSettings;

  @override
  State<StockScannerApp> createState() => _StockScannerAppState();
}

class _StockScannerAppState extends State<StockScannerApp> {
  static final RouteObserver<ModalRoute<void>> _routeObserver =
      RouteObserver<ModalRoute<void>>();
  final StockApiService _api = StockApiService();
  late final AppSettings _appSettings;
  static const Duration _minSplashDuration = Duration(milliseconds: 900);
  static const Duration _restoreTimeout = Duration(seconds: 4);
  AppUser? _currentUser;
  bool _isRestoring = true;
  FirebaseMessaging? _messaging;

  @override
  void initState() {
    super.initState();
    _appSettings = widget.initialSettings ?? AppSettings()
      ..loadSettings();
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

    if (!kIsWeb && !Platform.isWindows) {
      unawaited(Future(() async {
        if (!await ServerScanner.pingServer(AppConfig.baseUrl)) {
          await ServerScanner.autoDiscoverServer();
        }
      }));
    }

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
    final saveSessionStart = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    _api.setAccessToken(session.accessToken);
    await prefs.setString(_sessionUserIdKey, session.user.userId);
    await prefs.setString(_sessionAccessTokenKey, session.accessToken);
    await prefs.setString(
        _sessionUserJsonKey, jsonEncode(session.user.toJson()));
    await prefs.remove(_sessionPinKey);
    debugPrint("DEBUG TIMER: save session duration = ${DateTime.now().difference(saveSessionStart).inMilliseconds} ms");
    if (mounted) {
      setState(() {
        _currentUser = session.user;
      });
    }
    unawaited(_registerPushForUser(session.user.userId).catchError((e) {
      debugPrint("Push token registration error: $e");
    }));
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
    return AppSettingsScope(
      notifier: _appSettings,
      child: ListenableBuilder(
        listenable: _appSettings,
        builder: (context, _) {
          return MaterialApp(
            title:
                "\u0e41\u0e2d\u0e1b\u0e2a\u0e15\u0e4a\u0e2d\u0e01\u0e2a\u0e34\u0e19\u0e04\u0e49\u0e32",
            debugShowCheckedModeBanner: false,
            theme: buildLightThemeData(),
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
  List<Map<String, dynamic>> menuItems = [];
  final Set<int> _loadedTabs = {0};
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
    final isDesktopOrWeb = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        MediaQuery.sizeOf(context).width > 700;

    if (authCompleteTime != null) {
      debugPrint("DEBUG TIMER: auth complete to home visible = ${DateTime.now().difference(authCompleteTime!).inMilliseconds} ms");
      authCompleteTime = null;
    }
    menuItems = [
      {
        "icon": Icons.dashboard_outlined,
        "selectedIcon": Icons.dashboard,
        "label": "ภาพรวม",
        "page": (BuildContext context) => DashboardPage(
          key: _dashboardKey,
          api: widget.api,
          refreshSignal: _realtimeRevision,
          currentUser: widget.currentUser,
          routeObserver: _StockScannerAppState._routeObserver,
          onOpenOrdersTab: () {
            if (kIsWeb) {
              // Find the index of the "ออเดอร์และจัดส่ง" page
              for (int i = 0; i < menuItems.length; i++) {
                if (menuItems[i]["label"] == "ออเดอร์และจัดส่ง") {
                  setState(() {
                    _currentIndex = i;
                    _loadedTabs.add(i);
                  });
                  break;
                }
              }
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrdersPage(
                    api: widget.api,
                    currentUser: widget.currentUser,
                    refreshSignal: _realtimeRevision,
                  ),
                ),
              );
            }
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
        )
      },
      {
        "icon": Icons.qr_code_scanner_outlined,
        "selectedIcon": Icons.qr_code_scanner,
        "label": "สแกน",
        "page": (BuildContext context) => ScanPage(
          api: widget.api,
          currentUser: widget.currentUser,
          isActive: _currentIndex == 1,
          onOpenProductDetails: (context, product) => showProductCodeSheet(context, product),
        )
      },
      {
        "icon": Icons.history_outlined,
        "selectedIcon": Icons.history,
        "label": "ประวัติ",
        "page": (BuildContext context) => HistoryPage(api: widget.api, refreshSignal: _realtimeRevision)
      },
      {
        "icon": Icons.smart_toy_rounded,
        "selectedIcon": Icons.smart_toy,
        "label": "ผู้ช่วย",
        "page": (BuildContext context) => ChatAssistantPage(
          api: widget.api,
          refreshSignal: _realtimeRevision,
          onOpenProductDetails: (context, product) => showProductCodeSheet(context, product),
          onBack: () {
            setState(() {
              _currentIndex = 0;
            });
          },
        )
      },
    ];

    if (isDesktopOrWeb) {
      menuItems.addAll([
        {
          "icon": Icons.person_outline,
          "selectedIcon": Icons.person,
          "label": "โปรไฟล์",
          "page": (BuildContext context) => ProfilePage(
            currentUser: widget.currentUser,
            api: widget.api,
            onLogout: () async {
              await widget.onLogout();
            },
            onRefreshSession: widget.onRefreshSession,
          )
        },
        {
          "icon": Icons.local_shipping_outlined,
          "selectedIcon": Icons.local_shipping,
          "label": "ออเดอร์และจัดส่ง",
          "page": (BuildContext context) => OrdersPage(
            api: widget.api,
            currentUser: widget.currentUser,
            refreshSignal: _realtimeRevision,
          )
        },
        {
          "icon": Icons.search_rounded,
          "selectedIcon": Icons.search,
          "label": "ค้นหาสินค้า",
          "page": (BuildContext context) => ProductSearchPage(
            api: widget.api,
            currentUser: widget.currentUser,
            refreshSignal: _realtimeRevision,
            onOpenProductDetails: (context, product) => showProductCodeSheet(context, product),
          )
        },
        {
          "icon": Icons.help_outline,
          "selectedIcon": Icons.help,
          "label": "วิธีใช้งาน",
          "page": (BuildContext context) => HelpCenterPage(
            api: widget.api,
            currentUser: widget.currentUser,
          )
        },
      ]);

      if (widget.currentUser.isAdmin) {
        menuItems.addAll([
          {
            "icon": Icons.restore_from_trash_outlined,
            "selectedIcon": Icons.restore_from_trash,
            "label": "ถังขยะสินค้า",
            "page": (BuildContext context) => ProductRecycleBinPage(api: widget.api, currentUser: widget.currentUser)
          },
          {
            "icon": Icons.history_outlined,
            "selectedIcon": Icons.history,
            "label": "ประวัติกิจกรรมสินค้า",
            "page": (BuildContext context) => ProductActivityLogPage(api: widget.api, currentUser: widget.currentUser)
          },
          {
            "icon": Icons.admin_panel_settings_outlined,
            "selectedIcon": Icons.admin_panel_settings,
            "label": "ผู้ดูแลระบบ",
            "page": (BuildContext context) => AdminPage(api: widget.api, currentUser: widget.currentUser)
          },
        ]);
      }
    }

    final pages = <Widget>[];
    for (int i = 0; i < menuItems.length; i++) {
      if (i == 0 || _loadedTabs.contains(i)) {
        final widgetChild = menuItems[i]["page"](context) as Widget;
        pages.add(
          KeyedSubtree(
            key: ValueKey("tab_page_$i"),
            child: widgetChild,
          ),
        );
      } else {
        pages.add(const SizedBox.shrink());
      }
    }

    Widget buildNavTile(int index) {
      final isSelected = _currentIndex == index;
      final data = menuItems[index];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: InkWell(
          onTap: () {
            setState(() {
              _currentIndex = index;
              _loadedTabs.add(index);
            });
            if (index == 0) {
              _dashboardKey.currentState?.refreshNow();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _brandPrimary.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? data["selectedIcon"] as IconData : data["icon"] as IconData,
                  color: isSelected ? _brandPrimary : _brandInk.withOpacity(0.70),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data["label"] as String,
                    style: TextStyle(
                      color: isSelected ? _brandPrimary : _brandInk.withOpacity(0.85),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sidebar = Container(
      width: 260,
      decoration: BoxDecoration(
        color: _brandCard,
        border: Border(right: BorderSide(color: _brandPrimary.withOpacity(0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: _BrandLogoWordmark(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: List.generate(menuItems.length, (index) => buildNavTile(index)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _brandPrimary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _brandPrimary.withOpacity(0.12),
                    child: Text(
                      widget.currentUser.userName.substring(0, min(1, widget.currentUser.userName.length)).toUpperCase(),
                      style: const TextStyle(color: _brandPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentUser.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _brandInk),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.currentUser.role.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: _brandInk.withOpacity(0.60), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                    onPressed: () async {
                      await widget.onLogout();
                    },
                    tooltip: "ออกจากระบบ",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isDesktopOrWeb) {
      return Scaffold(
        body: Row(
          children: [
            sidebar,
            Expanded(
              child: SafeArea(
                child: IndexedStack(
                  index: _currentIndex,
                  children: pages,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: false,
      body: Stack(
        children: [
          SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
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
                _loadedTabs.add(index);
              });
              if (index == 0) {
                _dashboardKey.currentState?.refreshNow();
              }
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
              NavigationDestination(
                icon: Icon(Icons.smart_toy_rounded),
                selectedIcon: Icon(Icons.smart_toy),
                label: "ผู้ช่วย",
              ),
            ],
          ),
        ),
      ),
    ); }
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
  static bool _firstHistoryLoadLogged = false;
  late Future<List<MovementRecord>> _future;

  @override
  void initState() {
    super.initState();
    final start = DateTime.now();
    _future = widget.api.getMovements().then((val) {
      if (!_firstHistoryLoadLogged) {
        debugPrint("DEBUG TIMER: first HistoryPage load duration = ${DateTime.now().difference(start).inMilliseconds} ms");
        _firstHistoryLoadLogged = true;
      }
      return val;
    });
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return ColoredBox(
            color: isDark ? darkSurface : _brandSurface,
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
            currentUser: currentUser,
            onOpenProductDetails: (context, product) => showProductCodeSheet(context, product),
          ),
        ),
      ),
      _MoreAction(
        title: "วิธีใช้งาน",
        subtitle: "เรียนรู้การใช้งานแบบสั้น ๆ",
        icon: Icons.help_outline,
        onTap: () => _openPage(
          context,
          HelpCenterPage(
            api: api,
            currentUser: currentUser,
          ),
        ),
      ),
    ];

    if (currentUser.isAdmin) {
      items.add(
        _MoreAction(
          title: "ถังขยะสินค้า",
          subtitle: "ดูและกู้คืนสินค้าที่ถูกซ่อนหรือปิดใช้งาน",
          icon: Icons.restore_from_trash_outlined,
          onTap: () => _openPage(
            context,
            ProductRecycleBinPage(api: api, currentUser: currentUser),
          ),
        ),
      );
      items.add(
        _MoreAction(
          title: "ประวัติกิจกรรมสินค้า",
          subtitle: "ดูประวัติการปิดใช้งาน กู้คืน และลบสินค้า",
          icon: Icons.history_outlined,
          onTap: () => _openPage(
            context,
            ProductActivityLogPage(api: api, currentUser: currentUser),
          ),
        ),
      );
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: ColoredBox(
        color: isDark ? darkSurface : _brandSurface,
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
                    backgroundColor: isDark
                        ? darkCard
                        : Color.lerp(_brandSurface, _brandSurfaceStrong, 0.75),
                    child: Icon(item.icon, color: isDark ? brandPrimary : _brandDeep),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: ColoredBox(
        color: isDark ? darkSurface : _brandSurface,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark
        ? const Color(0xFF1A2744)
        : Color.lerp(_brandSurfaceStrong, _brandPrimary, 0.34)!;
    return Container(
      padding:
          const EdgeInsets.fromLTRB(_spaceLg, _spaceLg, _spaceLg, _spaceMd),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(_radiusXl),
        border: Border.all(
          color: isDark ? darkCardBorder.withOpacity(0.6) : _brandPrimary.withOpacity(0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.25) : _brandPrimary.withOpacity(0.10),
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
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? darkTextPrimary : _brandDeep,
              ),
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? darkCard.withOpacity(0.82)
                    : Colors.white.withOpacity(0.82),
              ),
            ),
            const SizedBox(height: _spaceXs),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isDark ? darkTextPrimary : _brandDeep,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? darkTextSecondary : _brandInk.withOpacity(0.82),
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

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

class AppConfig {
  static const String _prefServerUrlKey = "custom_server_url";
  static String? _customServerUrl;

  static const String _apiUrl = String.fromEnvironment(
    "API_URL",
    defaultValue: "http://192.168.1.112:8000",
  );

  static Future<void> loadCustomServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefServerUrlKey)?.trim();
      if (saved != null && saved.isNotEmpty) {
        _customServerUrl = saved;
      }
    } catch (_) {}
  }

  static Future<void> setCustomServerUrl(String? url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = url?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        _customServerUrl = null;
        await prefs.remove(_prefServerUrlKey);
      } else {
        _customServerUrl = trimmed;
        await prefs.setString(_prefServerUrlKey, trimmed);
      }
    } catch (_) {}
  }

  static String get baseUrl {
    if (_customServerUrl != null && _customServerUrl!.isNotEmpty) {
      return _customServerUrl!;
    }

    if (kIsWeb) {
      final base = Uri.base;
      if (base.scheme.startsWith("http")) {
        return "${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}";
      }
      return _apiUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final parsed = Uri.tryParse(_apiUrl);
      if (parsed != null &&
          (parsed.host == "127.0.0.1" || parsed.host == "localhost")) {
        return parsed.replace(host: "10.0.2.2").toString();
      }
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      final parsed = Uri.tryParse(_apiUrl);
      if (parsed != null && parsed.host == "10.0.2.2") {
        return parsed.replace(host: "127.0.0.1").toString();
      }
      // On Windows Desktop, if default _apiUrl is on a LAN IP that might not match,
      // localhost / 127.0.0.1 is the primary local backend target unless custom URL is set.
      if (_customServerUrl == null || _customServerUrl!.isEmpty) {
        return "http://127.0.0.1:8000";
      }
    }

    return _apiUrl;
  }
}

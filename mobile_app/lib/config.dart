import "package:flutter/foundation.dart";

class AppConfig {
  static const String _apiUrl = String.fromEnvironment(
    "API_URL",
    defaultValue: "http://192.168.1.108:8000",
  );

  static String get baseUrl {
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

    return _apiUrl;
  }
}

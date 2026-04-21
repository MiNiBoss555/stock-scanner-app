import "package:flutter/foundation.dart";

class AppConfig {
  static const String _apiUrl = String.fromEnvironment(
    "API_URL",
    defaultValue: "http://192.168.1.199:8000",
  );

  static String get baseUrl {
    if (kIsWeb) {
      return _apiUrl;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _apiUrl,
      _ => _apiUrl,
    };
  }
}

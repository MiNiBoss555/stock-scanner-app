import "package:flutter/foundation.dart";

class AppConfig {
  static const String _apiUrl = String.fromEnvironment(
    "API_URL",
    defaultValue: "https://stock-scanner-api-478e.onrender.com",
  );

  static String get baseUrl {
    if (kIsWeb) {
      return _apiUrl;
    }

    // When running on Android emulator, "127.0.0.1" points to the emulator itself.
    // Map it to "10.0.2.2" so it reaches the host machine where uvicorn runs.
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

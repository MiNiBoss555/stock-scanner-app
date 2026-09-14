import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:shared_preferences/shared_preferences.dart";

class SecureSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const accessTokenKey = "session_access_token";
  static const refreshTokenKey = "session_refresh_token";
  static const legacyPinKey = "session_pin";

  final FlutterSecureStorage _storage;

  Future<String?> readAccessToken() => _storage.read(key: accessTokenKey);

  Future<void> writeAccessToken(String token) =>
      _storage.write(key: accessTokenKey, value: token);

  Future<void> clearCredentials() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(accessTokenKey);
    await preferences.remove(refreshTokenKey);
    await preferences.remove(legacyPinKey);
  }

  Future<void> migrateLegacyCredentials() async {
    final preferences = await SharedPreferences.getInstance();
    final legacyToken = preferences.getString(accessTokenKey);
    final secureToken = await readAccessToken();
    if ((secureToken == null || secureToken.isEmpty) &&
        legacyToken != null &&
        legacyToken.isNotEmpty) {
      await writeAccessToken(legacyToken);
    }
    await preferences.remove(accessTokenKey);
    await preferences.remove(refreshTokenKey);
    await preferences.remove(legacyPinKey);
  }
}

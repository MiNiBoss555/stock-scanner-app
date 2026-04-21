# Stock Scanner Mobile

Flutter app scaffold for iOS and Android that connects to the FastAPI backend in the repo root.

## Features

- Scan barcode with camera
- Select user from dropdown
- Stock in
- Stock out
- Issue for internal usage
- Auto-create product when barcode is not in the system
- Audit trail by user
- Notifications feed
- Product and low stock dashboard

## API setup

The app reads the backend URL from a Dart define named `API_URL`.

Default fallback in `lib/config.dart`:

- `http://192.168.1.199:8000`

Examples:

- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://127.0.0.1:8000`
- Real device on same Wi-Fi: `http://YOUR-PC-IP:8000`
- Public production backend: `https://api.yourdomain.com`

## Run

1. Install Flutter SDK
2. Create target platforms if needed:
   `flutter create .`
3. Get packages:
   `flutter pub get`
4. Start the API:
   `python -m uvicorn main:app --host 0.0.0.0 --port 8000`
5. Run the app:
   `flutter run --dart-define=API_URL=http://YOUR-PC-IP:8000`

## Direct APK Distribution

1. Create a signing keystore once:
   `keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Copy `android/key.properties.example` to `android/key.properties`
3. Fill in your real keystore values in `android/key.properties`
4. Build a release APK:
   `flutter build apk --release --dart-define=API_URL=https://api.yourdomain.com`
5. Find the APK here:
   `build/app/outputs/flutter-apk/app-release.apk`

Notes:

- If `android/key.properties` does not exist, the project falls back to the debug signing key.
- For a real public release, use an HTTPS backend URL.
- You can send the APK directly to users or host it on your own download page.

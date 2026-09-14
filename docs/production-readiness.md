# Production Readiness & Release Checklist

This document details the configuration requirements, verification checklists, smoke testing procedures, and rollback strategies for the Stock Scanner production release.

> [!IMPORTANT]
> **PostgreSQL migration is NOT part of this release.**
> This release hardens application security, API transport, authentication session lifecycles, and build configurations on the existing SQLite database architecture.

> [!CAUTION]
> **Do not deploy production with `STOCK_SCANNER_DB=stock_scanner.db` on Render Free.**
> Render Free web services utilize an ephemeral filesystem and do not support persistent disks. Any database file stored in the local working directory will be lost on container restart, redeploy, or idle spin-down.

---

## 1. Environment Variables

Only environment variable names are documented below. **Never commit secret values to the repository.**

### Backend Environment Variables
| Variable Name | Required | Default / Expected | Purpose |
|---|---|---|---|
| `APP_ENV` | Yes | `production` | Enables production security constraints (e.g. strict CORS validation, disabling demo seeds, requiring persistent SQLite paths). |
| `ALLOWED_ORIGINS` | Yes | Explicit HTTPS URLs (comma-separated) | Whitelist of allowed web clients for CORS. Wildcard `*` is strictly rejected in production. |
| `ENABLE_DEMO_SEED` | Yes | `false` | Disables automated demo user/product creation on clean databases. |
| `STOCK_SCANNER_DB` | Yes | `/var/data/stock_scanner.db` | Absolute path to persistent SQLite database file on an attached persistent disk (unless PostgreSQL is configured via `DATABASE_URL`). Unsafe default `stock_scanner.db` is rejected in production. |
| `AUTH_TOKEN_TTL_HOURS` | Optional | `12` | Token time-to-live in hours. |
| `PIN_HASH_ITERATIONS` | Optional | `120000` | PBKDF2 iterations for password/PIN hashing. |
| `EXPORT_LINK_TTL_MINUTES` | Optional | `10` | Single-use export token expiration time in minutes. |
| `WEBHOOK_SECRET` | Optional | Random secret string | Shared secret for webhook integrity verification. |
| `GOOGLE_SERVICE_ACCOUNT_FILE` | Optional | Path to JSON key file | Google service account credentials for Google Sheets synchronization. |
| `GOOGLE_SHEETS_SPREADSHEET_ID` | Optional | Spreadsheet ID string | Target Google Sheets spreadsheet ID. |
| `OPENAI_API_KEY` | Optional | API Key string | API key for AI assistant features. |

### Mobile Build Variables (`--dart-define`)
| Variable Name | Required in Release | Expected Value | Purpose |
|---|---|---|---|
| `API_URL` | Yes | `https://YOUR-PRODUCTION-DOMAIN` | Base URL for API endpoints. Must use `https://` in release builds. |

---

## 2. Production SQLite Storage Requirements

If deploying the SQLite backend on Render:

1. **Compute Plan**:
   - Must use a paid Render Web Service plan (e.g., `Starter`) that supports persistent disks. The Free plan is ephemeral and cannot preserve data.
2. **Attach Persistent Disk**:
   - Attach a persistent disk in the Render Dashboard (or via `render.yaml` with `plan: starter`).
   - Disk name: `stock-scanner-data`
   - Mount path: `/var/data`
   - Size: Minimum 1 GB
3. **Environment Variable Configuration**:
   - Set `STOCK_SCANNER_DB=/var/data/stock_scanner.db`
   - In `APP_ENV=production`, the backend enforces that `STOCK_SCANNER_DB` is explicitly set to a non-ephemeral path and rejects the default relative `stock_scanner.db`.
4. **Pre-Deployment Backup**:
   - Always download/backup the existing `.db` file and sidecars (`-wal`, `-shm`) prior to running deployments or schema updates.
5. **Persistence Restart Verification**:
   - After initial setup, create a test record, restart/redeploy the Render service, and verify the record persists after container recreation.

---

## 3. Pre-Release Checklists

### Backend Checklist
- [ ] Set `APP_ENV=production` in the hosting environment (e.g. Render).
- [ ] Verify `ENABLE_DEMO_SEED=false` so test credentials are not seeded.
- [ ] Configure `ALLOWED_ORIGINS` with explicit HTTPS origins (e.g. `https://stock.example.com`).
- [ ] Verify persistent disk is attached and mounted to `/var/data`.
- [ ] Set `STOCK_SCANNER_DB=/var/data/stock_scanner.db`.
- [ ] Verify no secrets or private keys are stored in source code or Git history.
- [ ] Perform a full SQLite database backup (`.db`, `-wal`, `-shm`) and verify integrity before deploying.
- [ ] Verify HTTPS endpoint connectivity and check `/health` returns `{ "status": "ok" }`.

### Android Checklist
- [ ] Generate or obtain the production release keystore file.
- [ ] Create `mobile_app/android/key.properties` with:
  - `storeFile` (relative path from `android/` to the keystore)
  - `storePassword`
  - `keyAlias`
  - `keyPassword`
- [ ] Place production `google-services.json` in `mobile_app/android/app/`.
- [ ] Ensure `mobile_app/android/app/src/main/AndroidManifest.xml` has `android:usesCleartextTraffic="false"`.
- [ ] Verify `mobile_app/pubspec.yaml` contains the target release version (`1.0.23+24`).
- [ ] Run release build with explicit HTTPS API URL:
  ```powershell
  flutter build apk --release --dart-define=API_URL=https://YOUR-PRODUCTION-DOMAIN
  flutter build appbundle --release --dart-define=API_URL=https://YOUR-PRODUCTION-DOMAIN
  ```

### iOS Checklist
- [ ] Place production `GoogleService-Info.plist` in `mobile_app/ios/Runner/`.
- [ ] Configure Apple Developer signing certificate and provisioning profile in Xcode.
- [ ] Verify privacy usage descriptions in `Info.plist`:
  - `NSCameraUsageDescription` (Barcode scanning & delivery evidence)
  - `NSPhotoLibraryUsageDescription` (Product and delivery image selection)
  - `NSPhotoLibraryAddUsageDescription` (Label saving)
- [ ] Ensure App Transport Security (ATS) requires HTTPS for all network communication.

---

## 4. Smoke Test Checklist

Execute these validation tests on the release build connected to the production staging/live backend:

### Authentication & Session Lifecycle
- [ ] **Valid Login**: Authenticate with valid staff and admin accounts; confirm JWT token is stored securely in encrypted storage.
- [ ] **Invalid Login**: Attempt login with incorrect PIN/credentials; verify clear error message without internal stack traces.
- [ ] **Session Verification (`/auth/me`)**: Confirm profile information loads correctly from `/auth/me`.
- [ ] **Session Restore**: Close and restart app; confirm valid session restores without requiring re-login.
- [ ] **Logout**: Log out; confirm tokens and sensitive session data are wiped from local storage.

### Core Inventory & Scanning
- [ ] **Barcode Scan**: Scan an existing product barcode via camera; confirm product details load with debounce and no race conditions.
- [ ] **Manual Product Search**: Search products by name and SKU; verify search filters and list display.
- [ ] **Auto-SKU & Add Product**: Auto-generate SKU and add a new product; confirm it persists.
- [ ] **Stock In / Stock Out**: Perform stock in/out scans; verify quantity and timeline movement logging.

### Orders & Workflow Management
- [ ] **Create Order**: Create a new customer order with line items and verify calculation totals.
- [ ] **Order Status Update**: Transition order through workflow stages (pending, confirmed, packing, delivering, completed).
- [ ] **Cancelled Order Guard**: Confirm cancelled orders prevent invalid status updates.
- [ ] **Delivery Slip / Print**: Generate order packing slip / PDF / thermal label preview.

### Roles & Permissions
- [ ] **Staff Access**: Verify staff can perform scans and view assigned orders, but cannot access admin user management.
- [ ] **Admin Access**: Verify admin can view activity logs, user management, and recycle bin.

### Exports & Network Resilience
- [ ] **Data Export**: Trigger CSV / Excel export; verify single-use download token and formula neutralization.
- [ ] **Offline / Network Failure**: Simulate network disconnection; verify app displays graceful connection error banner rather than crashing.

---

## 5. Rollback Procedure

If unexpected issues occur post-deployment:

1. **Mobile App Rollback**:
   - Keep previous release APK / App Bundle artifacts archived.
   - If an issue is detected on client devices, distribute the previous stable APK or submit a rapid hotfix build to app stores.
2. **Backend Rollback**:
   - Redeploy the previous Git release tag / commit on Render / web hosting.
   - Point the backend service to the existing persistent database file.
   - Because no destructive database schema migrations or PostgreSQL cutover occurred, rollback requires no database restore unless corrupt writes occurred.
3. **Database Restore (Emergency only)**:
   - In case of database file corruption, restore the verified pre-deployment SQLite backup file along with any WAL files to `/var/data/stock_scanner.db`.

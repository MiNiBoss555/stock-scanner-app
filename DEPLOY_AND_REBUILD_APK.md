# Deploy Backend And Rebuild APK

## 1. Deploy the API

This repo now includes `render.yaml` for a simple Render deployment.

Steps:

1. Push this project to GitHub.
2. Create a new Render Blueprint or Web Service from the repo.
3. Confirm the service uses:
   - Build command: `pip install -r requirements.txt`
   - Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
4. Set environment variables as needed:
   - `STOCK_SCANNER_DB`
   - `ALLOWED_ORIGINS`
   - `WEBHOOK_SECRET`
   - `GOOGLE_SHEETS_SPREADSHEET_ID`
   - `GOOGLE_SERVICE_ACCOUNT_FILE`

Notes:

- `render.yaml` points `STOCK_SCANNER_DB` at `/var/data/stock_scanner.db`.
- For real production, prefer PostgreSQL over SQLite if many users will write at the same time.
- If you upload files, make sure your hosting setup provides persistent storage.

## 2. Verify the public API

After deploy, check:

```text
https://YOUR-API-DOMAIN/health
```

If this works, the backend is reachable from the internet.

## 3. Rebuild the Android APK

Use your public API URL when building:

```powershell
cd c:\my-api\mobile_app
flutter build apk --release --dart-define=API_URL=https://YOUR-API-DOMAIN
```

APK output:

```text
mobile_app/build/app/outputs/flutter-apk/app-release.apk
```

## 4. Share the APK

You can send the APK directly through:

- Google Drive
- OneDrive
- Dropbox
- LINE or Telegram file attachment
- Your own download page

## 5. Important before public use

- Change default test PINs like `1234`
- Set `ALLOWED_ORIGINS` to your real frontend origins instead of `*`
- Use HTTPS only
- Keep `WEBHOOK_SECRET` private
- Back up your data regularly

# Deploy Backend And Rebuild APK

## 1. Deploy the API

This repo includes `render.yaml` for Render deployment with persistent disk support.

Steps:

1. Push this project to GitHub.
2. Create a new Render Blueprint or Web Service from the repo.
3. Confirm the service uses:
   - Build command: `pip install -r requirements.txt`
   - Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
4. Set environment variables:
   - `STOCK_SCANNER_DB` (e.g. `/var/data/stock_scanner.db` on mounted disk)
   - `ALLOWED_ORIGINS` (explicit HTTPS web origin, e.g. `https://stock.example.com`)
   - `APP_ENV=production`
   - `ENABLE_DEMO_SEED=false`
   - `WEBHOOK_SECRET`
   - `GOOGLE_SHEETS_SPREADSHEET_ID` (optional)
   - `GOOGLE_SERVICE_ACCOUNT_FILE` (optional)

Notes:

- `render.yaml` configures a Starter service with a persistent disk mounted at `/var/data` and `STOCK_SCANNER_DB=/var/data/stock_scanner.db`.
- **Caution**: Do not deploy production with `STOCK_SCANNER_DB=stock_scanner.db` on Render Free. Render Free instances use an ephemeral filesystem without persistent disk support, which causes SQLite databases to be lost on container restart or spin-down.
- For high-concurrency production, PostgreSQL can be configured with `DATABASE_URL` (see `docs/database-migration-plan.md`).
- If you upload files locally, make sure your hosting setup provides persistent storage (or configure S3 bucket via environment variables).

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

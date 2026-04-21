# Google Sheets Setup

Use this flow to connect the API in this repo to your existing Google Sheet.

## 1. Create a Google service account

1. Open Google Cloud Console
2. Create or choose a project
3. Enable Google Sheets API
4. Create a Service Account
5. Create a JSON key and save it on the server machine

## 2. Share the sheet

Share your Google Sheet with the service account email from the JSON file.

Example:

`stock-bot@your-project.iam.gserviceaccount.com`

Give it `Editor` access.

## 3. Prepare your sheet tabs

Recommended tabs:

- `products`
- `movements`
- `users`

### `products` columns

- `barcode`
- `sku`
- `name`
- `unit`
- `current_stock`
- `minimum_stock`
- `category`
- `location`

### `movements` columns

- `movement_id`
- `timestamp`
- `barcode`
- `product_name`
- `action`
- `quantity`
- `before_stock`
- `after_stock`
- `actor_id`
- `actor_name`
- `note`
- `reference`

### `users` columns

- `user_id`
- `user_name`
- `role`
- `active`
- `pin`
- `profile_image_url`

## 4. Install dependencies

```powershell
pip install -r requirements.txt
```

## 5. Set environment variables

Copy `.env.example` values into your environment or deployment config.

## 6. Configure and sync

Run the API:

```powershell
uvicorn main:app --reload
```

Optional: set config by API if your sheet tab names or columns differ.

`POST /integrations/google-sheets/config`

Example body:

```json
{
  "spreadsheet_id": "YOUR_SHEET_ID",
  "service_account_file": "C:\\secrets\\service-account.json",
  "products_sheet": "products",
  "movements_sheet": "movements",
  "users_sheet": "users",
  "barcode_column": "barcode",
  "name_column": "name",
  "stock_column": "current_stock",
  "minimum_stock_column": "minimum_stock",
  "sku_column": "sku",
  "unit_column": "unit",
  "category_column": "category",
  "location_column": "location"
}
```

Then import products from Google Sheets:

`POST /integrations/google-sheets/sync/products`

Then import users for the mobile dropdown:

`POST /integrations/google-sheets/sync/users`

Optional: push all current stock balances from the API back to the `products` tab:

`POST /integrations/google-sheets/sync/stocks`

## 7. What happens after setup

- Existing products are loaded from your Google Sheet
- Existing users are loaded from your Google Sheet and can be selected from the mobile app
- Every scan from the mobile app is appended to the `movements` tab
- Every successful scan also updates `current_stock` in the matching row of the `products` tab
- If a barcode is new, the API can auto-create the product row in the `products` tab before logging movement
- The API response includes Google Sheets append status for each scan

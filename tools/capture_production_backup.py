#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Safe Production Backup Capture Utility for Stock Scanner API.

Features:
- Enforces HTTPS for remote production base URLs (unless --allow-insecure is set)
- Preflights /health and detects 503 / Render suspended state safely
- Authenticates via Bearer token without ever logging or leaking credentials
- Streams /admin/backup ZIP directly to disk in chunks (no full in-memory buffer)
- Computes SHA-256 and writes companion .sha256 file
- Validates ZIP archive integrity (testzip)
- Inspects extracted SQLite database (PRAGMA integrity_check, PRAGMA foreign_key_check)
- Summarizes table row counts and uploads count without dumping any PII or secrets
- Generates backup_verification_<timestamp>.json
"""

import argparse
import datetime
import getpass
import hashlib
import json
import logging
import os
import re
import shutil
import sqlite3
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

logger = logging.getLogger("capture_backup")


def sanitize_url_for_display(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    netloc = parsed.hostname or parsed.netloc
    if parsed.port and parsed.port not in (80, 443):
        netloc = f"{netloc}:{parsed.port}"
    return f"{parsed.scheme}://{netloc}"


def validate_base_url(url: str, allow_insecure: bool = False) -> str:
    cleaned = url.strip().rstrip("/")
    if not cleaned:
        raise ValueError("Base URL cannot be empty.")
    parsed = urllib.parse.urlparse(cleaned)
    if parsed.scheme not in ("http", "https"):
        raise ValueError(f"Invalid URL scheme: '{parsed.scheme}'. Must be https or http.")
    if parsed.scheme == "http" and not allow_insecure:
        is_local = parsed.hostname in ("localhost", "127.0.0.1", "::1")
        if not is_local:
            raise ValueError(
                "HTTPS is strictly required for remote production servers. "
                "Use --allow-insecure only for local testing."
            )
    return cleaned


def resolve_admin_token(token_arg: Optional[str] = None) -> str:
    token = (
        token_arg
        or os.getenv("STOCK_SCANNER_ADMIN_TOKEN")
        or os.getenv("ADMIN_TOKEN")
    )
    if token and token.strip():
        return token.strip()

    if sys.stdin.isatty():
        prompt_token = getpass.getpass("Enter Admin Token: ").strip()
        if prompt_token:
            return prompt_token

    raise ValueError(
        "Admin token is required. Provide via --token, STOCK_SCANNER_ADMIN_TOKEN, "
        "or ADMIN_TOKEN environment variable."
    )


def preflight_health_check(base_url: str, timeout: int = 15) -> Dict[str, Any]:
    health_url = f"{base_url}/health"
    req = urllib.request.Request(
        health_url,
        headers={"User-Agent": "StockScanner-Backup-Tool/1.0", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            status = response.status
            body_bytes = response.read()
            body_text = body_bytes.decode("utf-8", errors="replace")
            is_json = "application/json" in response.headers.get("Content-Type", "").lower()
            return {
                "ok": status == 200,
                "status_code": status,
                "headers": dict(response.headers),
                "body": body_text if is_json else None,
            }
    except urllib.error.HTTPError as exc:
        headers_dict = dict(exc.headers)
        body = exc.read().decode("utf-8", errors="replace")
        is_suspended = (
            exc.code == 503
            or headers_dict.get("x-render-routing") == "suspend"
            or "Service Suspended" in body
        )
        return {
            "ok": False,
            "status_code": exc.code,
            "is_suspended": is_suspended,
            "headers": headers_dict,
            "error": "Service Suspended / Inactive" if is_suspended else f"HTTP {exc.code}",
        }
    except urllib.error.URLError as exc:
        return {
            "ok": False,
            "status_code": None,
            "error": f"Connection error: {exc.reason}",
        }
    except Exception as exc:
        return {
            "ok": False,
            "status_code": None,
            "error": f"Unexpected error: {str(exc)}",
        }


def stream_backup_download(
    base_url: str,
    token: str,
    dest_path: Path,
    chunk_size: int = 65536,
    timeout: int = 120,
) -> Tuple[str, int]:
    backup_url = f"{base_url}/admin/backup"
    req = urllib.request.Request(
        backup_url,
        headers={
            "Authorization": f"Bearer {token}",
            "User-Agent": "StockScanner-Backup-Tool/1.0",
            "Accept": "application/zip",
        },
    )

    dest_path.parent.mkdir(parents=True, exist_ok=True)
    temp_download_path = dest_path.with_name(f"{dest_path.name}.part")
    hasher = hashlib.sha256()
    total_bytes = 0

    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            if response.status != 200:
                raise RuntimeError(f"Unexpected status code: {response.status}")

            content_type = response.headers.get("Content-Type", "")
            if "zip" not in content_type and "octet-stream" not in content_type:
                raise ValueError(f"Expected ZIP response, got Content-Type: '{content_type}'")

            with open(temp_download_path, "wb") as f_out:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    f_out.write(chunk)
                    hasher.update(chunk)
                    total_bytes += len(chunk)

        if total_bytes == 0:
            raise ValueError("Received empty backup file.")

        temp_download_path.replace(dest_path)
        sha256_hex = hasher.hexdigest().lower()
        return sha256_hex, total_bytes

    except urllib.error.HTTPError as exc:
        if temp_download_path.exists():
            temp_download_path.unlink()
        err_msg = f"HTTP {exc.code}: {exc.reason}"
        if exc.code in (401, 403):
            err_msg = f"Authentication/Authorization failed ({exc.code}). Token is invalid or lacks Admin rights."
        raise RuntimeError(err_msg) from None
    except Exception:
        if temp_download_path.exists():
            temp_download_path.unlink()
        raise


def verify_zip_and_database(
    zip_path: Path,
    expected_sha256: str,
) -> Dict[str, Any]:
    file_hasher = hashlib.sha256()
    with open(zip_path, "rb") as f:
        while chunk := f.read(65536):
            file_hasher.update(chunk)
    actual_sha256 = file_hasher.hexdigest().lower()
    if actual_sha256 != expected_sha256.lower():
        raise ValueError(
            f"SHA256 mismatch! Streamed: {expected_sha256}, On-disk: {actual_sha256}"
        )

    if not zipfile.is_zipfile(zip_path):
        raise ValueError("Target file is not a valid ZIP archive.")

    with zipfile.ZipFile(zip_path, "r") as zf:
        bad_file = zf.testzip()
        if bad_file is not None:
            raise ValueError(f"Corrupt file found in ZIP archive: {bad_file}")

    with tempfile.TemporaryDirectory() as extract_dir_str:
        extract_dir = Path(extract_dir_str)
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(extract_dir)

        sqlite_file: Optional[Path] = None
        candidate = extract_dir / "stock_scanner.db"
        if candidate.exists() and candidate.is_file():
            sqlite_file = candidate
        else:
            db_candidates = list(extract_dir.glob("**/*.db"))
            if db_candidates:
                sqlite_file = db_candidates[0]

        if not sqlite_file:
            raise ValueError("No SQLite database file found inside backup archive.")

        try:
            conn = sqlite3.connect(f"file:{sqlite_file.resolve()}?mode=ro", uri=True)
            try:
                cur = conn.cursor()

                cur.execute("PRAGMA integrity_check;")
                integrity_rows = cur.fetchall()
                if not integrity_rows or integrity_rows[0][0] != "ok":
                    raise ValueError(f"SQLite PRAGMA integrity_check failed: {integrity_rows}")

                cur.execute("PRAGMA foreign_key_check;")
                fk_violations = cur.fetchall()
                if fk_violations:
                    raise ValueError(f"SQLite foreign key check failed with violations: {len(fk_violations)}")

                cur.execute(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;"
                )
                tables = [row[0] for row in cur.fetchall()]
                table_counts: Dict[str, int] = {}
                for table_name in tables:
                    if not re.match(r"^[A-Za-z0-9_]+$", table_name):
                        continue
                    cur.execute(f'SELECT COUNT(*) FROM "{table_name}"')
                    table_counts[table_name] = cur.fetchone()[0]
            finally:
                conn.close()
        except sqlite3.Error as exc:
            raise ValueError(f"SQLite database error / corruption detected: {exc}") from exc

        uploads_dir = extract_dir / "uploads"
        uploads_count = 0
        uploads_bytes = 0
        if uploads_dir.exists() and uploads_dir.is_dir():
            for p in uploads_dir.rglob("*"):
                if p.is_file():
                    uploads_count += 1
                    uploads_bytes += p.stat().st_size

    return {
        "zip_integrity": "ok",
        "sqlite_db_name": sqlite_file.name,
        "sqlite_integrity": "ok",
        "foreign_key_check": "ok",
        "tables": table_counts,
        "total_tables": len(table_counts),
        "uploads_file_count": uploads_count,
        "uploads_total_bytes": uploads_bytes,
    }


def run_backup_capture(
    base_url: str,
    token: str,
    output_dir: Path,
    allow_insecure: bool = False,
    timeout: int = 120,
) -> int:
    sanitized_url = sanitize_url_for_display(base_url)
    print(f"[*] Target API: {sanitized_url}")

    print("[*] Performing preflight /health check...")
    health_result = preflight_health_check(base_url, timeout=15)
    if not health_result["ok"]:
        if health_result.get("is_suspended"):
            print("\n[!] SERVICE UNAVAILABLE / SUSPENDED (HTTP 503)")
            print("    The Render service container is currently suspended.")
            print("    Traffic is blocked before reaching the application.")
            print("    Backup cannot be captured while the service is suspended.\n")
            return 2
        print(f"\n[!] Preflight check failed: {health_result.get('error')}\n")
        return 1

    print("[+] Preflight check successful (Service is healthy).")

    output_dir.mkdir(parents=True, exist_ok=True)
    now_utc = datetime.datetime.now(datetime.timezone.utc)
    timestamp_str = now_utc.strftime("%Y%m%dT%H%M%SZ")
    zip_filename = f"production_backup_{timestamp_str}.zip"
    zip_path = output_dir / zip_filename

    print(f"[*] Requesting /admin/backup and streaming to disk: {zip_filename}...")
    try:
        sha256_hex, total_bytes = stream_backup_download(
            base_url=base_url,
            token=token,
            dest_path=zip_path,
            timeout=timeout,
        )
    except Exception as exc:
        print(f"\n[!] Download failed: {exc}\n")
        return 1

    print(f"[+] Download complete. Size: {total_bytes:,} bytes")
    print(f"[+] SHA-256: {sha256_hex}")

    sha256_path = output_dir / f"{zip_filename}.sha256"
    sha256_path.write_text(f"{sha256_hex}  {zip_filename}\n", encoding="utf-8")
    print(f"[+] Checksum saved to: {sha256_path.name}")

    print("[*] Validating ZIP archive and SQLite database integrity...")
    try:
        verification_details = verify_zip_and_database(zip_path, sha256_hex)
    except Exception as exc:
        print(f"\n[!] Backup verification failed: {exc}\n")
        return 1

    print("[+] ZIP archive integrity: OK (testzip passed)")
    print(f"[+] SQLite database: {verification_details['sqlite_db_name']} (PRAGMA integrity_check: OK, FK check: OK)")
    print(f"[+] Database tables verified: {verification_details['total_tables']} tables")
    for tbl, count in sorted(verification_details["tables"].items()):
        print(f"    - {tbl}: {count:,} rows")
    print(
        f"[+] Uploaded assets: {verification_details['uploads_file_count']} files "
        f"({verification_details['uploads_total_bytes']:,} bytes)"
    )

    report_filename = f"backup_verification_{timestamp_str}.json"
    report_path = output_dir / report_filename
    report_data = {
        "timestamp_utc": now_utc.isoformat(),
        "target_url": sanitized_url,
        "backup_file": zip_filename,
        "file_size_bytes": total_bytes,
        "sha256": sha256_hex,
        "verification": verification_details,
    }
    report_path.write_text(json.dumps(report_data, indent=2), encoding="utf-8")
    print(f"[+] Verification manifest written to: {report_path.name}")
    print("\n[SUCCESS] Production backup successfully captured and verified.\n")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Safely capture and verify production backup from Stock Scanner API."
    )
    parser.add_argument(
        "--base-url",
        default=os.getenv("STOCK_SCANNER_BASE_URL", "https://stock-scanner-api-478e.onrender.com"),
        help="Base URL of the Stock Scanner API (default: https://stock-scanner-api-478e.onrender.com)",
    )
    parser.add_argument(
        "--token",
        default=None,
        help="Admin Bearer token. Recommended to pass via STOCK_SCANNER_ADMIN_TOKEN or prompt.",
    )
    parser.add_argument(
        "--output-dir",
        default="production_backups",
        help="Directory to save backup artifacts (default: production_backups)",
    )
    parser.add_argument(
        "--allow-insecure",
        action="store_true",
        help="Allow HTTP connections for local testing.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=120,
        help="HTTP request timeout in seconds (default: 120)",
    )

    args = parser.parse_args()

    try:
        clean_url = validate_base_url(args.base_url, allow_insecure=args.allow_insecure)
        token = resolve_admin_token(args.token)
    except Exception as exc:
        print(f"[!] Configuration error: {exc}", file=sys.stderr)
        sys.exit(1)

    out_path = Path(args.output_dir).resolve()
    exit_code = run_backup_capture(
        base_url=clean_url,
        token=token,
        output_dir=out_path,
        allow_insecure=args.allow_insecure,
        timeout=args.timeout,
    )
    sys.exit(exit_code)


if __name__ == "__main__":
    main()

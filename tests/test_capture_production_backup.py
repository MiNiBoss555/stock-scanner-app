# -*- coding: utf-8 -*-
import io
import json
import os
import shutil
import sqlite3
import sys
import tempfile
import urllib.error
import zipfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from tools.capture_production_backup import (
    SafeRedirectHandler,
    preflight_health_check,
    resolve_admin_token,
    run_backup_capture,
    stream_backup_download,
    validate_base_url,
    validate_zip_members_safety,
    verify_zip_and_database,
)


def _create_valid_test_zip(zip_path: Path) -> str:
    import hashlib

    with tempfile.TemporaryDirectory() as td:
        tdp = Path(td)
        db_path = tdp / "stock_scanner.db"
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        cur.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);")
        cur.execute("CREATE TABLE products (barcode TEXT PRIMARY KEY, qty INTEGER);")
        cur.execute("INSERT INTO users VALUES (1, 'admin');")
        cur.execute("INSERT INTO products VALUES ('123456', 10);")
        cur.execute("INSERT INTO products VALUES ('654321', 5);")
        conn.commit()
        conn.close()

        uploads_dir = tdp / "uploads"
        uploads_dir.mkdir()
        (uploads_dir / "photo1.jpg").write_bytes(b"image data 1")
        (uploads_dir / "photo2.jpg").write_bytes(b"image data 2")

        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.write(db_path, arcname="stock_scanner.db")
            zf.write(uploads_dir / "photo1.jpg", arcname="uploads/photo1.jpg")
            zf.write(uploads_dir / "photo2.jpg", arcname="uploads/photo2.jpg")

    hasher = hashlib.sha256()
    with open(zip_path, "rb") as f:
        while chunk := f.read(65536):
            hasher.update(chunk)
    return hasher.hexdigest().lower()


def test_validate_base_url_remote_https_and_loopback_http():
    # HTTPS accepted for remote and local
    assert validate_base_url("https://api.example.com") == "https://api.example.com"
    assert validate_base_url("https://localhost:8000") == "https://localhost:8000"

    # HTTP accepted ONLY for loopback
    assert validate_base_url("http://localhost:8000") == "http://localhost:8000"
    assert validate_base_url("http://127.0.0.1:8000") == "http://127.0.0.1:8000"
    assert validate_base_url("http://[::1]:8000") == "http://[::1]:8000"

    # Remote HTTP strictly rejected
    with pytest.raises(ValueError, match="Plain HTTP is strictly forbidden for remote host"):
        validate_base_url("http://api.example.com")

    with pytest.raises(ValueError, match="Plain HTTP is strictly forbidden for remote host"):
        validate_base_url("http://192.168.1.50:8000")


def test_validate_base_url_cli_no_allow_insecure():
    # Ensure CLI parser does not expose --allow-insecure or accept remote http
    from tools.capture_production_backup import main
    with patch("sys.argv", ["capture_production_backup.py", "--allow-insecure"]):
        with pytest.raises(SystemExit):
            main()


def test_resolve_admin_token_sources_and_no_cli(monkeypatch):
    monkeypatch.delenv("STOCK_SCANNER_ADMIN_TOKEN", raising=False)
    monkeypatch.delenv("ADMIN_TOKEN", raising=False)

    # CLI does not have --token
    from tools.capture_production_backup import main
    with patch("sys.argv", ["capture_production_backup.py", "--token", "secret"]):
        with pytest.raises(SystemExit):
            main()

    # Environment variable 1
    monkeypatch.setenv("STOCK_SCANNER_ADMIN_TOKEN", "env_token_primary")
    assert resolve_admin_token() == "env_token_primary"

    # Environment variable 2 fallback
    monkeypatch.delenv("STOCK_SCANNER_ADMIN_TOKEN")
    monkeypatch.setenv("ADMIN_TOKEN", "env_token_fallback")
    assert resolve_admin_token() == "env_token_fallback"

    # Interactive getpass fallback
    monkeypatch.delenv("ADMIN_TOKEN")
    with patch("sys.stdin.isatty", return_value=True):
        with patch("getpass.getpass", return_value="interactive_token"):
            assert resolve_admin_token() == "interactive_token"

    # Missing token error
    with patch("sys.stdin.isatty", return_value=False):
        with pytest.raises(ValueError, match="Admin token is required"):
            resolve_admin_token()


def test_safe_redirect_handler_same_origin():
    handler = SafeRedirectHandler(expected_scheme="https", expected_host="api.example.com", expected_port=443)
    req = urllib.request.Request("https://api.example.com/admin/backup")
    req.headers["Authorization"] = "Bearer secret_token_xyz"

    new_req = handler.redirect_request(
        req=req,
        fp=io.BytesIO(),
        code=302,
        msg="Found",
        headers={},
        newurl="https://api.example.com/admin/backup/v2",
    )
    assert new_req.get_full_url() == "https://api.example.com/admin/backup/v2"


def test_safe_redirect_handler_cross_host_blocked():
    handler = SafeRedirectHandler(expected_scheme="https", expected_host="api.example.com", expected_port=443)
    req = urllib.request.Request("https://api.example.com/admin/backup")
    req.headers["Authorization"] = "Bearer secret_token_xyz"

    with pytest.raises(urllib.error.HTTPError) as exc_info:
        handler.redirect_request(
            req=req,
            fp=io.BytesIO(),
            code=302,
            msg="Found",
            headers={},
            newurl="https://attacker.com/admin/backup",
        )
    assert exc_info.value.code == 302
    assert "Cross-origin redirect" in str(exc_info.value.reason)
    assert "secret_token_xyz" not in str(exc_info.value)


def test_safe_redirect_handler_https_to_http_downgrade_blocked():
    handler = SafeRedirectHandler(expected_scheme="https", expected_host="api.example.com", expected_port=443)
    req = urllib.request.Request("https://api.example.com/admin/backup")
    req.headers["Authorization"] = "Bearer secret_token_xyz"

    with pytest.raises(urllib.error.HTTPError) as exc_info:
        handler.redirect_request(
            req=req,
            fp=io.BytesIO(),
            code=302,
            msg="Found",
            headers={},
            newurl="http://api.example.com/admin/backup",
        )
    assert exc_info.value.code == 302
    assert "Insecure redirect from HTTPS to HTTP blocked" in str(exc_info.value.reason)
    assert "secret_token_xyz" not in str(exc_info.value)


def test_preflight_suspended_503_detected():
    mock_headers = {"x-render-routing": "suspend", "Content-Type": "text/html"}
    mock_error = urllib.error.HTTPError(
        url="https://api.example.com/health",
        code=503,
        msg="Service Unavailable",
        hdrs=mock_headers,
        fp=io.BytesIO(b"<html><title>Service Suspended</title>Service Suspended</html>"),
    )
    with patch("urllib.request.urlopen", side_effect=mock_error):
        res = preflight_health_check("https://api.example.com")
        assert res["ok"] is False
        assert res["status_code"] == 503
        assert res["is_suspended"] is True


def test_preflight_health_200_ok():
    mock_response = MagicMock()
    mock_response.status = 200
    mock_response.headers = {"Content-Type": "application/json"}
    mock_response.read.return_value = b'{"status": "ok"}'
    mock_response.__enter__.return_value = mock_response

    with patch("urllib.request.urlopen", return_value=mock_response):
        res = preflight_health_check("https://api.example.com")
        assert res["ok"] is True
        assert res["status_code"] == 200
        assert "ok" in res["body"]


def test_stream_backup_download_and_sha256(tmp_path):
    zip_target = tmp_path / "downloaded.zip"
    dummy_content = b"PK\x03\x04test zip binary stream data chunking verification"
    import hashlib

    expected_sha = hashlib.sha256(dummy_content).hexdigest().lower()

    mock_response = MagicMock()
    mock_response.status = 200
    mock_response.headers = {"Content-Type": "application/zip"}
    mock_response.read.side_effect = [dummy_content[:15], dummy_content[15:], b""]
    mock_response.__enter__.return_value = mock_response

    with patch("urllib.request.OpenerDirector.open", return_value=mock_response):
        sha256, size = stream_backup_download(
            base_url="https://api.example.com",
            token="secret_token_123",
            dest_path=zip_target,
            chunk_size=16,
        )
        assert sha256 == expected_sha
        assert size == len(dummy_content)
        assert zip_target.exists()
        assert zip_target.read_bytes() == dummy_content


def test_verify_zip_and_database_valid(tmp_path):
    zip_path = tmp_path / "test_backup.zip"
    sha256 = _create_valid_test_zip(zip_path)

    report = verify_zip_and_database(zip_path, sha256)
    assert report["zip_integrity"] == "ok"
    assert report["sqlite_integrity"] == "ok"
    assert report["foreign_key_check"] == "ok"
    assert report["total_tables"] == 2
    assert report["tables"]["users"] == 1
    assert report["tables"]["products"] == 2
    assert report["uploads_file_count"] == 2
    assert report["uploads_total_bytes"] == len(b"image data 1") + len(b"image data 2")


def test_verify_zip_sha256_mismatch(tmp_path):
    zip_path = tmp_path / "test_mismatch.zip"
    _create_valid_test_zip(zip_path)
    with pytest.raises(ValueError, match="SHA256 mismatch"):
        verify_zip_and_database(zip_path, "0000000000000000000000000000000000000000000000000000000000000000")


def test_verify_invalid_zip(tmp_path):
    corrupt_zip = tmp_path / "corrupt.zip"
    corrupt_zip.write_bytes(b"not a zip file at all")
    import hashlib

    sha = hashlib.sha256(b"not a zip file at all").hexdigest()
    with pytest.raises(ValueError, match="not a valid ZIP"):
        verify_zip_and_database(corrupt_zip, sha)


def test_verify_corrupted_sqlite(tmp_path):
    zip_path = tmp_path / "corrupt_db.zip"
    with zipfile.ZipFile(zip_path, "w") as zf:
        zf.writestr("stock_scanner.db", b"SQLite format 3\x00this is damaged database content\x00\x00\x00")
    import hashlib

    sha = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    with pytest.raises(ValueError, match="SQLite database error / corruption detected"):
        verify_zip_and_database(zip_path, sha)


def test_malicious_zip_path_traversal_rejected(tmp_path):
    # Test path traversal with ..
    traversal_zip = tmp_path / "traversal.zip"
    with zipfile.ZipFile(traversal_zip, "w") as zf:
        zf.writestr("../escaped.txt", b"evil contents")
        zf.writestr("stock_scanner.db", b"dummy")
    import hashlib
    sha = hashlib.sha256(traversal_zip.read_bytes()).hexdigest()

    with pytest.raises(ValueError, match="path traversal rejected"):
        verify_zip_and_database(traversal_zip, sha)

    # Test absolute path starting with /
    abs_zip = tmp_path / "abs.zip"
    with zipfile.ZipFile(abs_zip, "w") as zf:
        zf.writestr("/etc/passwd", b"evil contents")
        zf.writestr("stock_scanner.db", b"dummy")
    sha_abs = hashlib.sha256(abs_zip.read_bytes()).hexdigest()

    with pytest.raises(ValueError, match="absolute path rejected"):
        verify_zip_and_database(abs_zip, sha_abs)

    # Test Windows drive letter
    drive_zip = tmp_path / "drive.zip"
    with zipfile.ZipFile(drive_zip, "w") as zf:
        zf.writestr("C:evil.dll", b"evil contents")
        zf.writestr("stock_scanner.db", b"dummy")
    sha_drive = hashlib.sha256(drive_zip.read_bytes()).hexdigest()

    with pytest.raises(ValueError, match="drive letter rejected"):
        verify_zip_and_database(drive_zip, sha_drive)


def test_run_backup_capture_full_flow_no_token_leak(tmp_path, capsys):
    secret_token = "MY_SUPER_SECRET_ADMIN_TOKEN_99999"
    zip_path = tmp_path / "valid.zip"
    sha = _create_valid_test_zip(zip_path)
    zip_bytes = zip_path.read_bytes()

    def mock_urlopen(req, timeout=120):
        url = req.full_url if hasattr(req, "full_url") else str(req)
        if url.endswith("/health"):
            resp = MagicMock()
            resp.status = 200
            resp.headers = {"Content-Type": "application/json"}
            resp.read.return_value = b'{"status":"healthy"}'
            resp.__enter__.return_value = resp
            return resp
        raise RuntimeError(f"Unexpected URL: {url}")

    def mock_opener_open(self, req, timeout=120):
        url = req.full_url if hasattr(req, "full_url") else str(req)
        if url.endswith("/admin/backup"):
            auth = req.headers.get("Authorization")
            assert auth == f"Bearer {secret_token}"
            resp = MagicMock()
            resp.status = 200
            resp.headers = {"Content-Type": "application/zip"}
            resp.read.side_effect = [zip_bytes, b""]
            resp.__enter__.return_value = resp
            return resp
        raise RuntimeError(f"Unexpected Opener URL: {url}")

    out_dir = tmp_path / "output_backups"
    with patch("urllib.request.urlopen", side_effect=mock_urlopen):
        with patch("urllib.request.OpenerDirector.open", mock_opener_open):
            exit_code = run_backup_capture(
                base_url="https://api.test.com",
                token=secret_token,
                output_dir=out_dir,
            )
            assert exit_code == 0

    captured = capsys.readouterr()
    stdout_text = captured.out
    stderr_text = captured.err

    # Strictly assert secret token is NEVER printed
    assert secret_token not in stdout_text
    assert secret_token not in stderr_text

    # Verify output files exist
    zips = list(out_dir.glob("*.zip"))
    assert len(zips) == 1
    sha_files = list(out_dir.glob("*.sha256"))
    assert len(sha_files) == 1
    json_files = list(out_dir.glob("backup_verification_*.json"))
    assert len(json_files) == 1

    # Verify JSON content has NO secrets
    json_content = json_files[0].read_text(encoding="utf-8")
    assert secret_token not in json_content
    data = json.loads(json_content)
    assert data["verification"]["sqlite_integrity"] == "ok"
    assert data["verification"]["tables"]["users"] == 1
    assert data["verification"]["tables"]["products"] == 2

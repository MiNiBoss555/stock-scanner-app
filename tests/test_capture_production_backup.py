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
    preflight_health_check,
    resolve_admin_token,
    run_backup_capture,
    stream_backup_download,
    validate_base_url,
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


def test_validate_base_url_https_enforced():
    assert validate_base_url("https://api.example.com") == "https://api.example.com"
    with pytest.raises(ValueError, match="HTTPS is strictly required"):
        validate_base_url("http://api.example.com")
    # Localhost allowed with http
    assert validate_base_url("http://localhost:8000") == "http://localhost:8000"
    assert validate_base_url("http://127.0.0.1:8000") == "http://127.0.0.1:8000"
    # Remote allowed with --allow-insecure
    assert validate_base_url("http://api.example.com", allow_insecure=True) == "http://api.example.com"


def test_resolve_admin_token(monkeypatch):
    monkeypatch.delenv("STOCK_SCANNER_ADMIN_TOKEN", raising=False)
    monkeypatch.delenv("ADMIN_TOKEN", raising=False)
    assert resolve_admin_token("direct_token") == "direct_token"

    monkeypatch.setenv("STOCK_SCANNER_ADMIN_TOKEN", "env_token")
    assert resolve_admin_token() == "env_token"

    monkeypatch.delenv("STOCK_SCANNER_ADMIN_TOKEN")
    monkeypatch.setenv("ADMIN_TOKEN", "fallback_env_token")
    assert resolve_admin_token() == "fallback_env_token"


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
    # Return in 2 chunks then empty
    mock_response.read.side_effect = [dummy_content[:15], dummy_content[15:], b""]
    mock_response.__enter__.return_value = mock_response

    with patch("urllib.request.urlopen", return_value=mock_response):
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
    with pytest.raises(ValueError, match="integrity_check failed|file is not a database"):
        verify_zip_and_database(zip_path, sha)


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
        elif url.endswith("/admin/backup"):
            auth = req.headers.get("Authorization")
            assert auth == f"Bearer {secret_token}"
            resp = MagicMock()
            resp.status = 200
            resp.headers = {"Content-Type": "application/zip"}
            resp.read.side_effect = [zip_bytes, b""]
            resp.__enter__.return_value = resp
            return resp
        raise RuntimeError(f"Unexpected URL: {url}")

    out_dir = tmp_path / "output_backups"
    with patch("urllib.request.urlopen", side_effect=mock_urlopen):
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

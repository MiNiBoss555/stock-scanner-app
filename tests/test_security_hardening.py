import csv
import io
import logging
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


def test_csv_response_neutralizes_spreadsheet_formulas(api_context: dict) -> None:
    module = api_context["module"]
    response = module.csv_response(
        "test.csv",
        ["name", "note"],
        [["=HYPERLINK(\"https://example.invalid\")", "  @SUM(1,1)"], ["safe", 12]],
    )

    rows = list(csv.reader(io.StringIO(response.body.decode("utf-8-sig"))))
    assert rows[1] == ["'=HYPERLINK(\"https://example.invalid\")", "'  @SUM(1,1)"]
    assert rows[2] == ["safe", "12"]


def test_cors_does_not_reflect_unapproved_origin(api_context: dict) -> None:
    client = api_context["client"]

    rejected = client.options(
        "/health",
        headers={
            "Origin": "https://attacker.invalid",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert rejected.headers.get("access-control-allow-origin") is None

    allowed = client.options(
        "/health",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert allowed.headers["access-control-allow-origin"] == "http://localhost:3000"


def test_production_requires_explicit_non_wildcard_cors(
    api_context: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    module = api_context["module"]
    monkeypatch.setattr(module, "APP_ENV", "production")

    monkeypatch.delenv("ALLOWED_ORIGINS", raising=False)
    with pytest.raises(RuntimeError, match="explicit ALLOWED_ORIGINS"):
        module._allowed_origins()

    monkeypatch.setenv("ALLOWED_ORIGINS", "*")
    with pytest.raises(RuntimeError, match="wildcard origins"):
        module._allowed_origins()

    monkeypatch.setenv("ALLOWED_ORIGINS", "https://stock.example.com/")
    assert module._allowed_origins() == ["https://stock.example.com"]


def test_demo_credentials_are_not_seeded_when_disabled(
    api_context: dict, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    module = api_context["module"]
    isolated_db = tmp_path / "production-empty.db"
    monkeypatch.setattr(module, "DB_PATH", isolated_db)
    monkeypatch.setattr(module, "ENABLE_DEMO_SEED", False)

    module.init_database()

    with module.db_connection() as connection:
        assert connection.execute("SELECT COUNT(*) AS count FROM users").fetchone()["count"] == 0
        assert connection.execute("SELECT COUNT(*) AS count FROM products").fetchone()["count"] == 0


def test_export_failures_do_not_log_download_token(
    api_context: dict, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    module = api_context["module"]
    secret_token = "sensitive-export-token"

    def fail_export(_token: str):
        raise RuntimeError("forced export failure")

    monkeypatch.setattr(module, "consume_export_token", fail_export)
    caplog.set_level(logging.ERROR, logger="stock_scanner_api")

    with TestClient(module.app, raise_server_exceptions=False) as client:
        response = client.get(f"/exports/download/{secret_token}")

    assert response.status_code == 500
    assert secret_token not in caplog.text
    assert "Export download failed (RuntimeError)" in caplog.text


def test_production_sqlite_requires_explicit_persistent_path(
    api_context: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    module = api_context["module"]

    # In development, unset STOCK_SCANNER_DB defaults to local SQLite file
    monkeypatch.setattr(module, "APP_ENV", "development")
    monkeypatch.delenv("STOCK_SCANNER_DB", raising=False)
    monkeypatch.setattr(module, "DATABASE_URL", "")
    assert module._database_path() == Path("stock_scanner.db")

    # In production, unset STOCK_SCANNER_DB raises RuntimeError
    monkeypatch.setattr(module, "APP_ENV", "production")
    monkeypatch.delenv("STOCK_SCANNER_DB", raising=False)
    with pytest.raises(RuntimeError, match="explicit persistent STOCK_SCANNER_DB path"):
        module._database_path()

    # In production, unsafe default 'stock_scanner.db' raises RuntimeError
    monkeypatch.setenv("STOCK_SCANNER_DB", "stock_scanner.db")
    with pytest.raises(RuntimeError, match="ephemeral 'stock_scanner.db'"):
        module._database_path()

    # In production, explicit persistent path is accepted
    monkeypatch.setenv("STOCK_SCANNER_DB", "/var/data/stock_scanner.db")
    assert module._database_path() == Path("/var/data/stock_scanner.db")

    # When DATABASE_URL is set (PostgreSQL), database path check does not block
    monkeypatch.setattr(module, "DATABASE_URL", "postgresql://user:pass@host/db")
    monkeypatch.delenv("STOCK_SCANNER_DB", raising=False)
    assert module._database_path() == Path("stock_scanner.db")

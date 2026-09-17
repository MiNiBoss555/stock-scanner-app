import importlib
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


def test_app_uses_lifespan_without_deprecated_event_handlers(api_context: dict) -> None:
    module = api_context["module"]

    assert module.app.router.lifespan_context is module.lifespan
    assert module.app.router.on_startup == []
    assert module.app.router.on_shutdown == []


def test_testclient_lifespan_refreshes_state_once(
    api_context: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    module = api_context["module"]
    calls: list[str] = []

    monkeypatch.setattr(
        module,
        "cleanup_legacy_thai_text_in_db",
        lambda: calls.append("cleanup"),
    )
    monkeypatch.setattr(
        module,
        "load_state_from_db",
        lambda: calls.append("load"),
    )

    with TestClient(module.app) as client:
        assert client.get("/health").status_code == 200

    assert calls == ["cleanup", "load"]


def test_lifespan_startup_initializes_database(api_context: dict) -> None:
    client = api_context["client"]

    with TestClient(api_context["module"].app) as lifespan_client:
        response = lifespan_client.get("/health")

    assert response.status_code == 200
    assert api_context["db_path"].exists()
    assert client.get("/products").status_code == 200


def test_lifespan_startup_exception_is_not_swallowed(
    api_context: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    module = api_context["module"]

    def fail_refresh() -> None:
        raise RuntimeError("startup failed")

    monkeypatch.setattr(module, "cleanup_legacy_thai_text_in_db", fail_refresh)

    with pytest.raises(RuntimeError, match="startup failed"):
        with TestClient(module.app):
            pass


def test_lifespan_preserves_demo_seed_disable_behavior(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setenv("STOCK_SCANNER_DB", str(tmp_path / "no-seed.db"))
    monkeypatch.setenv("ENABLE_DEMO_SEED", "false")
    monkeypatch.delenv("WEBHOOK_SECRET", raising=False)
    sys.modules.pop("main", None)
    module = importlib.import_module("main")

    with TestClient(module.app):
        pass

    assert module.products == {}
    assert module.users == {}

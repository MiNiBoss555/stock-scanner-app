import importlib
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def api_context(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> dict:
    db_path = tmp_path / "test-stock-scanner.db"
    monkeypatch.setenv("STOCK_SCANNER_DB", str(db_path))
    monkeypatch.delenv("WEBHOOK_SECRET", raising=False)

    sys.modules.pop("main", None)
    module = importlib.import_module("main")
    module = importlib.reload(module)
    client = TestClient(module.app)

    return {
        "module": module,
        "client": client,
        "db_path": db_path,
    }

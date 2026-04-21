import importlib

from fastapi.testclient import TestClient


def login_and_get_token(client: TestClient, user_id: str = "EMP001", pin: str = "1234") -> str:
    response = client.post(
        "/auth/login",
        json={
            "user_id": user_id,
            "pin": pin,
        },
    )
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["token_type"] == "bearer"
    return payload["access_token"]


def auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_login_returns_token_and_auth_me_works(api_context: dict) -> None:
    client = api_context["client"]

    token = login_and_get_token(client, user_id="EMP001", pin="1234")
    response = client.get("/auth/me", headers=auth_headers(token))

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["user_id"] == "EMP001"
    assert payload["role"] == "admin"
    assert "pin" not in payload
    assert "pin_hash" not in payload


def test_scan_rejects_mismatched_authenticated_actor(api_context: dict) -> None:
    client = api_context["client"]
    token = login_and_get_token(client, user_id="EMP002", pin="1234")

    response = client.post(
        "/scan",
        headers=auth_headers(token),
        json={
            "barcode": "8850001110012",
            "action": "in",
            "quantity": 1,
            "actor_id": "EMP001",
            "actor_name": "Nok",
        },
    )

    assert response.status_code == 403, response.text
    assert response.json()["detail"] == "Authenticated user does not match actor_id."


def test_scan_persists_stock_and_movement_after_reload(api_context: dict) -> None:
    client = api_context["client"]
    module = api_context["module"]
    token = login_and_get_token(client, user_id="EMP002", pin="1234")

    before = client.get("/products/8850001110012").json()
    response = client.post(
        "/scan",
        headers=auth_headers(token),
        json={
            "barcode": "8850001110012",
            "action": "in",
            "quantity": 3,
            "actor_id": "EMP002",
            "actor_name": "Wrong Name Will Be Normalized",
        },
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["product"]["current_stock"] == before["current_stock"] + 3
    assert payload["movement"]["actor_name"] == "Mek"
    assert api_context["db_path"].exists()

    reloaded_module = importlib.reload(module)
    reloaded_client = TestClient(reloaded_module.app)
    product_after_reload = reloaded_client.get("/products/8850001110012").json()
    movements_after_reload = reloaded_client.get(
        "/movements",
        params={"barcode": "8850001110012", "limit": 5},
    ).json()

    assert product_after_reload["current_stock"] == before["current_stock"] + 3
    assert len(movements_after_reload) >= 1
    assert movements_after_reload[0]["quantity"] == 3
    assert movements_after_reload[0]["actor_id"] == "EMP002"


def test_admin_can_create_user_and_user_login_survives_reload(api_context: dict) -> None:
    client = api_context["client"]
    module = api_context["module"]
    admin_token = login_and_get_token(client, user_id="EMP001", pin="1234")

    response = client.post(
        "/users/upsert",
        headers=auth_headers(admin_token),
        json={
            "requester_id": "EMP001",
            "user_id": "EMP777",
            "user_name": "Test User",
            "role": "staff",
            "active": True,
            "pin": "5678",
        },
    )

    assert response.status_code == 200, response.text
    created_user = response.json()
    assert created_user["user_id"] == "EMP777"
    assert created_user["user_name"] == "Test User"

    reloaded_module = importlib.reload(module)
    reloaded_client = TestClient(reloaded_module.app)
    login_response = reloaded_client.post(
        "/auth/login",
        json={
            "user_id": "EMP777",
            "pin": "5678",
        },
    )

    assert login_response.status_code == 200, login_response.text
    login_payload = login_response.json()
    assert login_payload["user"]["user_id"] == "EMP777"
    assert login_payload["user"]["role"] == "staff"


def test_export_link_is_single_use_and_returns_file(api_context: dict) -> None:
    client = api_context["client"]
    admin_token = login_and_get_token(client, user_id="EMP001", pin="1234")

    link_response = client.post(
        "/exports/link",
        headers=auth_headers(admin_token),
        json={
            "export_name": "products_csv",
            "movement_limit": 5000,
        },
    )

    assert link_response.status_code == 200, link_response.text
    download_url = link_response.json()["url"]
    assert download_url.startswith("/exports/download/")

    first_download = client.get(download_url)
    assert first_download.status_code == 200, first_download.text
    assert "attachment; filename=\"products.csv\"" in first_download.headers["content-disposition"]
    assert "text/csv" in first_download.headers["content-type"]

    second_download = client.get(download_url)
    assert second_download.status_code == 404, second_download.text

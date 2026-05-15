from fastapi.testclient import TestClient

from tests.test_api import auth_headers, login_and_get_token


def test_chat_assistant_can_list_products(api_context: dict) -> None:
    client: TestClient = api_context["client"]
    token = login_and_get_token(client, user_id="EMP001", pin="1234")

    response = client.post(
        "/assistant/chat",
        headers=auth_headers(token),
        json={"message": "ตอนนี้มีสินค้าอะไรบ้าง"},
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    assert len(payload["matched_products"]) >= 1
    assert "สินค้าในระบบ" in payload["message"]

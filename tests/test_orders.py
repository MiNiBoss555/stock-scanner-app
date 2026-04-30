from tests.test_api import auth_headers, login_and_get_token


def test_create_order_and_assign_delivery(api_context: dict) -> None:
    client = api_context["client"]
    token = login_and_get_token(client, user_id="EMP001", pin="1234")

    create_response = client.post(
        "/orders",
        headers=auth_headers(token),
        json={
            "customer_name": "Customer A",
            "customer_phone": "0800000000",
            "customer_address": "Bangkok",
            "assigned_to_id": "EMP002",
            "items": [
                {"barcode": "8850001110012", "quantity": 2},
            ],
        },
    )

    assert create_response.status_code == 200, create_response.text
    order = create_response.json()
    assert order["customer_name"] == "Customer A"
    assert order["assigned_to_id"] == "EMP002"
    assert order["items"][0]["barcode"] == "8850001110012"


def test_assigned_staff_can_view_assigned_orders(api_context: dict) -> None:
    client = api_context["client"]
    admin_token = login_and_get_token(client, user_id="EMP001", pin="1234")
    staff_token = login_and_get_token(client, user_id="EMP002", pin="1234")

    client.post(
        "/orders",
        headers=auth_headers(admin_token),
        json={
            "customer_name": "Customer B",
            "assigned_to_id": "EMP002",
            "items": [
                {"barcode": "8850001110012", "quantity": 1},
            ],
        },
    )

    response = client.get(
        "/orders",
        headers=auth_headers(staff_token),
        params={"assigned_only": "true"},
    )

    assert response.status_code == 200, response.text
    payload = response.json()
    assert len(payload) >= 1
    assert payload[0]["assigned_to_id"] == "EMP002"

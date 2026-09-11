import pytest
from fastapi.testclient import TestClient
from tests.test_api import login_and_get_token, auth_headers

def test_product_activity_logging(api_context: dict) -> None:
    client = api_context["client"]

    # 1. Login as admin (EMP001)
    admin_token = login_and_get_token(client, user_id="EMP001", pin="1234")
    headers = auth_headers(admin_token)

    # 2. Get activity logs (should start empty or with initial db logs, let's check)
    response = client.get("/products/activity", headers=headers)
    assert response.status_code == 200, response.text
    initial_logs = response.json()

    # Perform a scan to create a movement history so deleting archives it
    scan_resp = client.post(
        "/scan",
        headers=headers,
        json={
            "barcode": "8850001110012",
            "action": "in",
            "quantity": 1,
            "actor_id": "EMP001",
            "actor_name": "Nok",
        },
    )
    assert scan_resp.status_code == 200

    # Let's archive a product (which has movements or is active)
    del_response = client.delete("/products/8850001110012", headers=headers, params={"requester_id": "EMP001"})
    assert del_response.status_code == 200, del_response.text

    # Since 8850001110012 has movements/history, it should be archived
    assert del_response.json()["message"] == "ปิดใช้งานสินค้าแล้ว เนื่องจากมีประวัติการใช้งาน"

    # Let's verify there is an 'archive' log
    response = client.get("/products/activity", headers=headers)
    assert response.status_code == 200
    logs = response.json()
    assert len(logs) > len(initial_logs)
    archive_log = logs[0]
    assert archive_log["action"] == "archive"
    assert archive_log["barcode"] == "8850001110012"
    assert archive_log["actor_id"] == "EMP001"

    # Let's restore the product
    restore_response = client.post("/products/8850001110012/restore", headers=headers, params={"requester_id": "EMP001"})
    assert restore_response.status_code == 200, restore_response.text

    # Let's verify there is a 'restore' log
    response = client.get("/products/activity", headers=headers)
    assert response.status_code == 200
    logs = response.json()
    assert logs[0]["action"] == "restore"
    assert logs[0]["barcode"] == "8850001110012"

    # Let's create a new product without movements and hard-delete it
    # First we POST to create product
    create_response = client.post(
        "/products/upsert",
        headers=headers,
        json={
            "barcode": "9999999999999",
            "name": "Temp Test Product",
            "unit": "pcs",
            "minimum_stock": 5,
            "current_stock": 0,
        },
        params={"requester_id": "EMP001"},
    )
    assert create_response.status_code == 200

    # Then hard delete it
    hard_del_response = client.delete("/products/9999999999999", headers=headers, params={"requester_id": "EMP001"})
    assert hard_del_response.status_code == 200
    assert hard_del_response.json()["message"] == "Product deleted successfully."

    # Verify there is a 'hard_delete' log
    response = client.get("/products/activity", headers=headers)
    assert response.status_code == 200
    logs = response.json()
    assert logs[0]["action"] == "hard_delete"
    assert logs[0]["barcode"] == "9999999999999"

def test_activity_logs_permissions(api_context: dict) -> None:
    client = api_context["client"]

    # Login as staff (EMP002 is staff in default db)
    staff_token = login_and_get_token(client, user_id="EMP002", pin="1234")
    headers = auth_headers(staff_token)

    # Requesting activity logs as staff should return 403 Forbidden
    response = client.get("/products/activity", headers=headers)
    assert response.status_code == 403

def test_product_timeline(api_context: dict) -> None:
    client = api_context["client"]

    # Login as admin
    admin_token = login_and_get_token(client, user_id="EMP001", pin="1234")
    headers = auth_headers(admin_token)

    # 1. Access timeline for a non-existent/no-history product -> should return 404
    resp = client.get("/products/nonexistent123/timeline", headers=headers)
    assert resp.status_code == 404

    # 2. Add movements to product 8850001110012
    scan_resp = client.post(
        "/scan",
        headers=headers,
        json={
            "barcode": "8850001110012",
            "action": "in",
            "quantity": 10,
            "actor_id": "EMP001",
            "actor_name": "Nok",
            "note": "Test incoming movement for timeline",
        },
    )
    assert scan_resp.status_code == 200

    # Archive it to generate an activity log entry
    del_response = client.delete("/products/8850001110012", headers=headers, params={"requester_id": "EMP001"})
    assert del_response.status_code == 200

    # Restore it
    restore_response = client.post("/products/8850001110012/restore", headers=headers, params={"requester_id": "EMP001"})
    assert restore_response.status_code == 200

    # 3. Get timeline as admin
    timeline_resp = client.get("/products/8850001110012/timeline", headers=headers)
    assert timeline_resp.status_code == 200
    timeline = timeline_resp.json()
    assert len(timeline) >= 3

    # First item should be restore activity (reverse chronological order)
    assert timeline[0]["type"] == "activity"
    assert timeline[0]["action"] == "restore"
    assert timeline[0]["barcode"] == "8850001110012"

    # Second should be archive
    assert timeline[1]["type"] == "activity"
    assert timeline[1]["action"] == "archive"

    # Find movement in the list
    movements = [item for item in timeline if item["type"] == "movement"]
    assert len(movements) >= 1
    assert movements[0]["action"] == "in"
    assert movements[0]["quantity"] == 10

    # 4. Access as staff user (should be allowed)
    staff_token = login_and_get_token(client, user_id="EMP002", pin="1234")
    staff_headers = auth_headers(staff_token)
    staff_timeline_resp = client.get("/products/8850001110012/timeline", headers=staff_headers)
    assert staff_timeline_resp.status_code == 200
    assert len(staff_timeline_resp.json()) == len(timeline)

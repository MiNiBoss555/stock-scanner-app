from fastapi.testclient import TestClient
from tests.test_api import login_and_get_token, auth_headers

def test_db_info_endpoints(api_context: dict):
    client = api_context["client"]

    # 1. Non-admin request should fail
    staff_token = login_and_get_token(client, user_id="EMP002", pin="1234")
    response = client.get("/admin/db-info", headers=auth_headers(staff_token))
    assert response.status_code == 403

    # 2. Admin request should succeed
    admin_token = login_and_get_token(client, user_id="EMP001", pin="1234")
    response = client.get("/admin/db-info?requester_id=EMP001", headers=auth_headers(admin_token))
    assert response.status_code == 200
    data = response.json()
    assert "db_path" in data
    assert data["exists"] is True
    assert data["file_size"] > 0
    assert "table_counts" in data

def test_upload_db_endpoint_is_removed(api_context: dict):
    client = api_context["client"]
    admin_token = login_and_get_token(client, user_id="EMP001", pin="1234")

    response = client.post(
        "/admin/upload-db",
        headers=auth_headers(admin_token),
        files={"file": ("uploaded.db", b"SQLite format 3\000")},
        data={"requester_id": "EMP001"},
    )

    assert response.status_code in (404, 405)

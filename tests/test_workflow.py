import pytest
from tests.test_api import auth_headers, login_and_get_token

def test_workflow_endpoint(api_context: dict) -> None:
    client = api_context["client"]
    admin_token = login_and_get_token(client, user_id="EMP001", pin="1234")
    
    # 1. Create an order as admin
    create_response = client.post(
        "/orders",
        headers=auth_headers(admin_token),
        json={
            "customer_name": "Test Customer",
            "items": [
                {"barcode": "8850001110012", "quantity": 1},
            ],
        },
    )
    assert create_response.status_code == 200, create_response.text
    order = create_response.json()
    order_id = order["id"]
    
    assert order["order_workflow_status"] == "pending_board"
    
    # 2. Test invalid action returns 400
    invalid_response = client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(admin_token),
        json={"action": "invalid_action_name"},
    )
    assert invalid_response.status_code == 400
    
    # 3. Test rejection note validation
    reject_no_note_response = client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(admin_token),
        json={"action": "reject_to_board"},
    )
    assert reject_no_note_response.status_code == 400
    
    reject_empty_note_response = client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(admin_token),
        json={"action": "reject_to_board", "note": "   "},
    )
    assert reject_empty_note_response.status_code == 400
    
    # 4. Create users with different roles for permission testing
    # Production user
    p_resp = client.post(
        "/users/upsert",
        headers=auth_headers(admin_token),
        json={
            "requester_id": "EMP001",
            "user_id": "EMP_PROD",
            "user_name": "Prod Worker",
            "role": "staff",
            "position": "ฝ่ายผลิต",
            "active": True,
            "pin": "1234"
        }
    )
    assert p_resp.status_code == 200, p_resp.text

    # QC user
    q_resp = client.post(
        "/users/upsert",
        headers=auth_headers(admin_token),
        json={
            "requester_id": "EMP001",
            "user_id": "EMP_QC",
            "user_name": "QC Worker",
            "role": "qc",
            "position": "QC",
            "active": True,
            "pin": "1234"
        }
    )
    assert q_resp.status_code == 200, q_resp.text

    # Delivery user
    d_resp = client.post(
        "/users/upsert",
        headers=auth_headers(admin_token),
        json={
            "requester_id": "EMP001",
            "user_id": "EMP_DELIVERY",
            "user_name": "Delivery Worker",
            "role": "delivery",
            "position": "delivery",
            "active": True,
            "pin": "1234"
        }
    )
    assert d_resp.status_code == 200, d_resp.text
    
    prod_token = login_and_get_token(client, user_id="EMP_PROD", pin="1234")
    qc_token = login_and_get_token(client, user_id="EMP_QC", pin="1234")
    delivery_token = login_and_get_token(client, user_id="EMP_DELIVERY", pin="1234")
    
    # Test that QC worker cannot do production actions
    forbidden_prod = client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(qc_token),
        json={"action": "send_to_robot"},
    )
    assert forbidden_prod.status_code == 403
    
    # Test that Prod worker can do production action
    success_prod = client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(prod_token),
        json={"action": "send_to_robot"},
    )
    assert success_prod.status_code == 200
    res_order = success_prod.json()
    assert res_order["order_workflow_status"] == "pending_robot"
    # Auto-claim verification
    assert res_order["production_user_id"] == "EMP_PROD"
    
    # Test that Prod worker cannot do QC action
    forbidden_qc = client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(prod_token),
        json={"action": "qc_pass"},
    )
    assert forbidden_qc.status_code == 403
    
    # Test that QC worker can do QC reject action (needs note)
    success_qc_reject = client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(qc_token),
        json={"action": "reject_to_board", "note": "Board has scratches"},
    )
    assert success_qc_reject.status_code == 200
    res_order = success_qc_reject.json()
    assert res_order["order_workflow_status"] == "rejected_board"
    assert res_order["order_workflow_note"] == "Board has scratches"
    assert res_order["status"] == "rework_required"  # legacy status synced
    assert res_order["qc_user_id"] == "EMP_QC"  # auto-claim
    
    # Test that Delivery worker cannot do QC action
    forbidden_qc_deliv = client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(delivery_token),
        json={"action": "qc_pass"},
    )
    assert forbidden_qc_deliv.status_code == 403
    
    # Test that QC worker can do QC pass
    success_qc_pass = client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(qc_token),
        json={"action": "qc_pass"},
    )
    assert success_qc_pass.status_code == 200
    res_order = success_qc_pass.json()
    assert res_order["order_workflow_status"] == "pending_delivery"
    assert res_order["status"] == "qc_passed"  # legacy status synced
    
    # Test that Delivery worker can do delivery action
    success_deliv = client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(delivery_token),
        json={"action": "send_to_delivery"},
    )
    assert success_deliv.status_code == 200
    res_order = success_deliv.json()
    assert res_order["order_workflow_status"] == "pending_delivery"
    assert res_order["status"] == "preparing"  # legacy status synced
    assert res_order["delivery_user_id"] == "EMP_DELIVERY"  # auto-claim

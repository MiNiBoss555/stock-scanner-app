"""
tests/test_workflow.py

Comprehensive tests for the strict sequential order workflow:

  pending_board -> pending_robot -> pending_qc -> pending_delivery
  then via /status: qc_passed -> preparing -> out_for_delivery -> delivered

Covers:
  - Normal happy path
  - Department skipping blocked
  - Delivery blocked during Board/Robot/QC stages
  - State drift (wrong current status at delivery stage)
  - Exact assignment permission enforcement
  - Admin obeys state machine (cannot skip)
  - reject_to_board / reject_to_robot sequences
  - delivered sets both status and order_workflow_status
  - Legacy non-structured orders (role fallback)
  - Auto-claim verification
  - Cancelled order guard
"""
import pytest
from tests.test_api import auth_headers, login_and_get_token


def _upsert_user(client, admin_token, *, user_id, user_name, role, position="", pin="1234"):
    resp = client.post(
        "/users/upsert",
        headers=auth_headers(admin_token),
        json={
            "requester_id": "EMP001",
            "user_id": user_id,
            "user_name": user_name,
            "role": role,
            "position": position,
            "active": True,
            "pin": pin,
        },
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def _create_structured_order(client, admin_token, *, board_id, robot_id, qc_id, delivery_id):
    resp = client.post(
        "/orders",
        headers=auth_headers(admin_token),
        json={
            "customer_name": "Structured Customer",
            "items": [{"barcode": "8850001110012", "quantity": 1}],
            "board_production_user_id": board_id,
            "robot_production_user_id": robot_id,
            "qc_user_id": qc_id,
            "delivery_user_id": delivery_id,
        },
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def _workflow(client, token, order_id, action, note=None):
    return client.post(
        f"/orders/{order_id}/workflow",
        headers=auth_headers(token),
        json={"action": action, "note": note},
    )


def _status(client, token, order_id, status):
    return client.post(
        f"/orders/{order_id}/status",
        headers=auth_headers(token),
        json={"status": status},
    )


def _add_proof_photo(client, order_id, admin_token):
    import io
    fake_png = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01"
        b"\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00"
        b"\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18"
        b"\xd8N\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    return client.post(
        f"/orders/{order_id}/proof-photo",
        headers=auth_headers(admin_token),
        files={"image": ("proof.png", io.BytesIO(fake_png), "image/png")},
        data={"requester_id": "EMP001"},
    )


@pytest.fixture()
def structured_context(api_context):
    client = api_context["client"]
    admin_token = login_and_get_token(client)
    _upsert_user(client, admin_token, user_id="BOARD1", user_name="Board User", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="ROBOT1", user_name="Robot User", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="QC1",    user_name="QC User",    role="qc")
    _upsert_user(client, admin_token, user_id="DEL1",   user_name="Del User",   role="delivery")
    _upsert_user(client, admin_token, user_id="OTHER1", user_name="Other User", role="staff", position="ฝ่ายผลิต")
    board_token   = login_and_get_token(client, user_id="BOARD1")
    robot_token   = login_and_get_token(client, user_id="ROBOT1")
    qc_token      = login_and_get_token(client, user_id="QC1")
    delivery_token = login_and_get_token(client, user_id="DEL1")
    other_token   = login_and_get_token(client, user_id="OTHER1")
    order = _create_structured_order(client, admin_token, board_id="BOARD1", robot_id="ROBOT1", qc_id="QC1", delivery_id="DEL1")
    return {
        "client": client,
        "admin_token": admin_token,
        "board_token": board_token,
        "robot_token": robot_token,
        "qc_token": qc_token,
        "delivery_token": delivery_token,
        "other_token": other_token,
        "order": order,
        "order_id": order["id"],
    }


def test_full_happy_path(structured_context):
    ctx = structured_context
    client, order_id = ctx["client"], ctx["order_id"]
    assert ctx["order"]["order_workflow_status"] == "pending_board"
    r = _workflow(client, ctx["board_token"], order_id, "send_to_robot")
    assert r.status_code == 200, r.text
    assert r.json()["order_workflow_status"] == "pending_robot"
    assert r.json()["status"] == "in_production"
    r = _workflow(client, ctx["robot_token"], order_id, "send_to_qc")
    assert r.status_code == 200, r.text
    assert r.json()["order_workflow_status"] == "pending_qc"
    assert r.json()["status"] == "qc_pending"
    r = _workflow(client, ctx["qc_token"], order_id, "qc_pass")
    assert r.status_code == 200, r.text
    assert r.json()["order_workflow_status"] == "pending_delivery"
    assert r.json()["status"] == "qc_passed"
    r = _status(client, ctx["delivery_token"], order_id, "preparing")
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "preparing"
    r = _status(client, ctx["delivery_token"], order_id, "out_for_delivery")
    assert r.status_code == 200, r.text
    _add_proof_photo(client, order_id, ctx["admin_token"])
    r = _status(client, ctx["delivery_token"], order_id, "delivered")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["status"] == "delivered"
    assert data["order_workflow_status"] == "delivered"


def test_board_cannot_skip_to_qc(structured_context):
    ctx = structured_context
    r = _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_qc")
    assert r.status_code == 400, r.text


def test_board_cannot_skip_to_delivery(structured_context):
    ctx = structured_context
    r = _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_delivery")
    assert r.status_code == 400, r.text


def test_robot_cannot_skip_to_delivery(structured_context):
    ctx = structured_context
    _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_robot")
    r = _workflow(ctx["client"], ctx["robot_token"], ctx["order_id"], "send_to_delivery")
    assert r.status_code == 400, r.text


def test_admin_cannot_skip_board_to_qc(structured_context):
    ctx = structured_context
    r = _workflow(ctx["client"], ctx["admin_token"], ctx["order_id"], "send_to_qc")
    assert r.status_code == 400, r.text


def test_admin_cannot_skip_board_to_delivery(structured_context):
    ctx = structured_context
    r = _workflow(ctx["client"], ctx["admin_token"], ctx["order_id"], "send_to_delivery")
    assert r.status_code == 400, r.text


def test_status_preparing_blocked_during_board_stage(structured_context):
    ctx = structured_context
    r = _status(ctx["client"], ctx["delivery_token"], ctx["order_id"], "preparing")
    assert r.status_code == 400, r.text


def test_status_preparing_blocked_during_robot_stage(structured_context):
    ctx = structured_context
    _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_robot")
    r = _status(ctx["client"], ctx["delivery_token"], ctx["order_id"], "preparing")
    assert r.status_code == 400, r.text


def test_status_preparing_blocked_during_qc_stage(structured_context):
    ctx = structured_context
    _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_robot")
    _workflow(ctx["client"], ctx["robot_token"], ctx["order_id"], "send_to_qc")
    r = _status(ctx["client"], ctx["delivery_token"], ctx["order_id"], "preparing")
    assert r.status_code == 400, r.text


def test_delivery_preparing_works_after_qc_pass(structured_context):
    ctx = structured_context
    _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_robot")
    _workflow(ctx["client"], ctx["robot_token"], ctx["order_id"], "send_to_qc")
    _workflow(ctx["client"], ctx["qc_token"], ctx["order_id"], "qc_pass")
    r = _status(ctx["client"], ctx["delivery_token"], ctx["order_id"], "preparing")
    assert r.status_code == 200, r.text


def test_out_for_delivery_requires_preparing(structured_context):
    """pending_delivery + qc_passed -> out_for_delivery (skips preparing) must fail."""
    ctx = structured_context
    _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_robot")
    _workflow(ctx["client"], ctx["robot_token"], ctx["order_id"], "send_to_qc")
    _workflow(ctx["client"], ctx["qc_token"], ctx["order_id"], "qc_pass")
    r = _status(ctx["client"], ctx["delivery_token"], ctx["order_id"], "out_for_delivery")
    assert r.status_code == 400, r.text


def test_delivered_requires_out_for_delivery(structured_context):
    """pending_delivery + preparing -> delivered (skips out_for_delivery) must fail."""
    ctx = structured_context
    _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_robot")
    _workflow(ctx["client"], ctx["robot_token"], ctx["order_id"], "send_to_qc")
    _workflow(ctx["client"], ctx["qc_token"], ctx["order_id"], "qc_pass")
    _status(ctx["client"], ctx["delivery_token"], ctx["order_id"], "preparing")
    _add_proof_photo(ctx["client"], ctx["order_id"], ctx["admin_token"])
    r = _status(ctx["client"], ctx["delivery_token"], ctx["order_id"], "delivered")
    assert r.status_code == 400, r.text


def test_generic_prod_blocked_when_exact_assignment_exists(structured_context):
    ctx = structured_context
    r = _workflow(ctx["client"], ctx["other_token"], ctx["order_id"], "send_to_robot")
    assert r.status_code == 403, r.text


def test_wrong_user_blocked_at_robot_stage(structured_context):
    ctx = structured_context
    _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_robot")
    r = _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_qc")
    assert r.status_code == 403, r.text


def test_qc_user_blocked_at_board_stage(structured_context):
    ctx = structured_context
    r = _workflow(ctx["client"], ctx["qc_token"], ctx["order_id"], "send_to_robot")
    assert r.status_code == 403, r.text


def test_delivery_user_blocked_at_board_stage(structured_context):
    ctx = structured_context
    r = _workflow(ctx["client"], ctx["delivery_token"], ctx["order_id"], "send_to_robot")
    assert r.status_code == 403, r.text


def test_role_fallback_allowed_when_no_board_assignment(api_context):
    client = api_context["client"]
    admin_token = login_and_get_token(client)
    _upsert_user(client, admin_token, user_id="ROBOT_FB", user_name="Robot FB", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="ANYB", user_name="Any Board", role="staff", position="ฝ่ายผลิต")
    anyb_token = login_and_get_token(client, user_id="ANYB")
    resp = client.post(
        "/orders",
        headers=auth_headers(admin_token),
        json={
            "customer_name": "Fallback",
            "items": [{"barcode": "8850001110012", "quantity": 1}],

        },
    )
    order_id = resp.json()["id"]
    r = _workflow(client, anyb_token, order_id, "send_to_robot")
    assert r.status_code == 200, r.text
    assert r.json()["board_production_user_id"] == "ANYB"


def test_reject_to_board_sequence(structured_context):
    ctx = structured_context
    client, order_id = ctx["client"], ctx["order_id"]
    _workflow(client, ctx["board_token"], order_id, "send_to_robot")
    _workflow(client, ctx["robot_token"], order_id, "send_to_qc")
    r = _workflow(client, ctx["qc_token"], order_id, "reject_to_board", note="Board solder crack")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["order_workflow_status"] == "rejected_board"
    assert data["order_workflow_note"] == "Board solder crack"
    assert data["status"] == "rework_required"
    r = _workflow(client, ctx["board_token"], order_id, "send_to_robot")
    assert r.status_code == 200
    assert r.json()["order_workflow_status"] == "pending_robot"
    _workflow(client, ctx["robot_token"], order_id, "send_to_qc")
    r = _workflow(client, ctx["qc_token"], order_id, "qc_pass")
    assert r.status_code == 200
    assert r.json()["order_workflow_status"] == "pending_delivery"


def test_reject_to_board_requires_note(structured_context):
    ctx = structured_context
    _workflow(ctx["client"], ctx["board_token"], ctx["order_id"], "send_to_robot")
    _workflow(ctx["client"], ctx["robot_token"], ctx["order_id"], "send_to_qc")
    r = _workflow(ctx["client"], ctx["qc_token"], ctx["order_id"], "reject_to_board")
    assert r.status_code == 400
    r = _workflow(ctx["client"], ctx["qc_token"], ctx["order_id"], "reject_to_board", note="   ")
    assert r.status_code == 400


def test_reject_to_robot_sequence(structured_context):
    ctx = structured_context
    client, order_id = ctx["client"], ctx["order_id"]
    _workflow(client, ctx["board_token"], order_id, "send_to_robot")
    _workflow(client, ctx["robot_token"], order_id, "send_to_qc")
    r = _workflow(client, ctx["qc_token"], order_id, "reject_to_robot", note="Assembly bad")
    assert r.status_code == 200, r.text
    assert r.json()["order_workflow_status"] == "rejected_robot"
    r = _workflow(client, ctx["robot_token"], order_id, "send_to_qc")
    assert r.status_code == 200
    r = _workflow(client, ctx["qc_token"], order_id, "qc_pass")
    assert r.status_code == 200
    assert r.json()["order_workflow_status"] == "pending_delivery"


def test_delivered_sets_both_fields(structured_context):
    ctx = structured_context
    client, order_id = ctx["client"], ctx["order_id"]
    _workflow(client, ctx["board_token"], order_id, "send_to_robot")
    _workflow(client, ctx["robot_token"], order_id, "send_to_qc")
    _workflow(client, ctx["qc_token"], order_id, "qc_pass")
    _status(client, ctx["delivery_token"], order_id, "preparing")
    _status(client, ctx["delivery_token"], order_id, "out_for_delivery")
    _add_proof_photo(client, order_id, ctx["admin_token"])
    r = _status(client, ctx["delivery_token"], order_id, "delivered")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["status"] == "delivered"
    assert data["order_workflow_status"] == "delivered"


def test_cancelled_order_cannot_workflow(api_context):
    client = api_context["client"]
    admin_token = login_and_get_token(client)
    resp = client.post("/orders", headers=auth_headers(admin_token),
                       json={"customer_name": "ToCancel", "items": [{"barcode": "8850001110012", "quantity": 1}]})
    order_id = resp.json()["id"]
    client.post(f"/orders/{order_id}/status", headers=auth_headers(admin_token), json={"status": "cancelled"})
    r = _workflow(client, admin_token, order_id, "send_to_robot")
    assert r.status_code == 400
    assert "cancelled" in r.json()["detail"].lower()


def test_auto_claim_board_user(api_context):
    client = api_context["client"]
    admin_token = login_and_get_token(client)
    _upsert_user(client, admin_token, user_id="ROBOT_AC", user_name="Robot AC", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="AUTOCLAIM", user_name="Auto Claim", role="staff", position="ฝ่ายผลิต")
    ac_token = login_and_get_token(client, user_id="AUTOCLAIM")
    resp = client.post("/orders", headers=auth_headers(admin_token),
                       json={"customer_name": "AutoClaim", "items": [{"barcode": "8850001110012", "quantity": 1}],
                             })
    order_id = resp.json()["id"]
    r = _workflow(client, ac_token, order_id, "send_to_robot")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["board_production_user_id"] == "AUTOCLAIM"
    assert data["production_user_id"] == "AUTOCLAIM"

def test_same_display_name_attacker_blocked_board(api_context):
    client = api_context["client"]
    admin_token = login_and_get_token(client)
    _upsert_user(client, admin_token, user_id="BOARD_LEGIT", user_name="Somchai", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="ATTACKER_BOARD", user_name="Somchai", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="ROBOT1", user_name="Robot User", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="QC1", user_name="QC User", role="qc")
    _upsert_user(client, admin_token, user_id="DEL1", user_name="Deliv User", role="delivery")
    legit_token = login_and_get_token(client, user_id="BOARD_LEGIT")
    attacker_token = login_and_get_token(client, user_id="ATTACKER_BOARD")
    order = _create_structured_order(
        client, admin_token,
        board_id="BOARD_LEGIT", robot_id="ROBOT1", qc_id="QC1", delivery_id="DEL1"
    )
    # Attacker with same display name must receive 403
    r = _workflow(client, attacker_token, order["id"], "send_to_robot")
    assert r.status_code == 403, r.text
    # Legit user with matching ID must succeed
    r_ok = _workflow(client, legit_token, order["id"], "send_to_robot")
    assert r_ok.status_code == 200, r_ok.text


def test_same_display_name_attacker_blocked_robot(api_context):
    client = api_context["client"]
    admin_token = login_and_get_token(client)
    _upsert_user(client, admin_token, user_id="B_USER", user_name="Board User", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="ROBOT_LEGIT", user_name="Somsri", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="ATTACKER_ROBOT", user_name="Somsri", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="QC1", user_name="QC User", role="qc")
    _upsert_user(client, admin_token, user_id="DEL1", user_name="Deliv User", role="delivery")
    b_token = login_and_get_token(client, user_id="B_USER")
    legit_token = login_and_get_token(client, user_id="ROBOT_LEGIT")
    attacker_token = login_and_get_token(client, user_id="ATTACKER_ROBOT")
    order = _create_structured_order(
        client, admin_token,
        board_id="B_USER", robot_id="ROBOT_LEGIT", qc_id="QC1", delivery_id="DEL1"
    )
    _workflow(client, b_token, order["id"], "send_to_robot")
    # Attacker with same display name as robot user must receive 403
    r = _workflow(client, attacker_token, order["id"], "send_to_qc")
    assert r.status_code == 403, r.text
    # Legit robot user must succeed
    r_ok = _workflow(client, legit_token, order["id"], "send_to_qc")
    assert r_ok.status_code == 200, r_ok.text


def test_same_display_name_attacker_blocked_qc(api_context):
    client = api_context["client"]
    admin_token = login_and_get_token(client)
    _upsert_user(client, admin_token, user_id="B_USER2", user_name="Board User 2", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="R_USER2", user_name="Robot User 2", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="QC_LEGIT", user_name="Wichai", role="qc")
    _upsert_user(client, admin_token, user_id="ATTACKER_QC", user_name="Wichai", role="qc")
    _upsert_user(client, admin_token, user_id="DEL1", user_name="Deliv User", role="delivery")
    b_token = login_and_get_token(client, user_id="B_USER2")
    r_token = login_and_get_token(client, user_id="R_USER2")
    legit_token = login_and_get_token(client, user_id="QC_LEGIT")
    attacker_token = login_and_get_token(client, user_id="ATTACKER_QC")
    order = _create_structured_order(
        client, admin_token,
        board_id="B_USER2", robot_id="R_USER2", qc_id="QC_LEGIT", delivery_id="DEL1"
    )
    _workflow(client, b_token, order["id"], "send_to_robot")
    _workflow(client, r_token, order["id"], "send_to_qc")
    # Attacker with same display name as QC user must receive 403
    r = _workflow(client, attacker_token, order["id"], "qc_pass")
    assert r.status_code == 403, r.text
    # Legit QC user must succeed
    r_ok = _workflow(client, legit_token, order["id"], "qc_pass")
    assert r_ok.status_code == 200, r_ok.text


def test_same_display_name_attacker_blocked_delivery(api_context):
    client = api_context["client"]
    admin_token = login_and_get_token(client)
    _upsert_user(client, admin_token, user_id="B_USER3", user_name="Board User 3", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="R_USER3", user_name="Robot User 3", role="staff", position="ฝ่ายผลิต")
    _upsert_user(client, admin_token, user_id="Q_USER3", user_name="QC User 3", role="qc")
    _upsert_user(client, admin_token, user_id="DELIV_LEGIT", user_name="Prasert", role="delivery")
    _upsert_user(client, admin_token, user_id="ATTACKER_DELIV", user_name="Prasert", role="delivery")
    b_token = login_and_get_token(client, user_id="B_USER3")
    r_token = login_and_get_token(client, user_id="R_USER3")
    q_token = login_and_get_token(client, user_id="Q_USER3")
    legit_token = login_and_get_token(client, user_id="DELIV_LEGIT")
    attacker_token = login_and_get_token(client, user_id="ATTACKER_DELIV")
    order = _create_structured_order(
        client, admin_token,
        board_id="B_USER3", robot_id="R_USER3", qc_id="Q_USER3", delivery_id="DELIV_LEGIT"
    )
    _workflow(client, b_token, order["id"], "send_to_robot")
    _workflow(client, r_token, order["id"], "send_to_qc")
    _workflow(client, q_token, order["id"], "qc_pass")
    # Attacker with same display name as Delivery user must receive 403
    r = _status(client, attacker_token, order["id"], "preparing")
    assert r.status_code == 403, r.text
    # Legit delivery user must succeed
    r_ok = _status(client, legit_token, order["id"], "preparing")
    assert r_ok.status_code == 200, r_ok.text


def test_legacy_non_structured_order_compatibility(api_context):
    client = api_context["client"]
    admin_token = login_and_get_token(client)
    _upsert_user(client, admin_token, user_id="PROD_LEGACY", user_name="Legacy Producer", role="staff", position="ฝ่ายผลิต")
    prod_token = login_and_get_token(client, user_id="PROD_LEGACY")

    resp = client.post(
        "/orders",
        headers=auth_headers(admin_token),
        json={
            "customer_name": "Legacy Customer",
            "items": [{"barcode": "8850001110012", "quantity": 1}],
            "production_user_id": "PROD_LEGACY",
        },
    )
    assert resp.status_code == 200, resp.text
    order = resp.json()
    order_id = order["id"]

    main_mod = api_context["module"]
    db_order = main_mod.get_order_or_404(order_id)
    assert main_mod._order_is_structured(db_order) is False

    # In legacy branch, historical action assembling is preserved
    r = _workflow(client, prod_token, order_id, "assembling")
    assert r.status_code == 200, r.text
    assert r.json()["order_workflow_status"] == "assembling"
    assert r.json()["status"] == "in_production"

    # And legacy send_to_qc action
    r_qc = _workflow(client, prod_token, order_id, "send_to_qc")
    assert r_qc.status_code == 200, r_qc.text
    assert r_qc.json()["order_workflow_status"] == "pending_qc"


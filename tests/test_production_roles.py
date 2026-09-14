import sys
from main import User, _is_production_role, _is_production_role_broken

def test_production_role_detection():
    # Test case 1: Standard admin role
    user_admin = User(
        user_id="EMP001",
        user_name="Admin Nok",
        role="admin",
        position="Manager",
        active=True,
        pin_hash="dummy"
    )
    assert not _is_production_role(user_admin)
    assert not _is_production_role_broken(user_admin)

    # Test case 2: Classic production role (English)
    user_prod_en = User(
        user_id="EMP002",
        user_name="Prod Nok",
        role="production",
        position="Staff",
        active=True,
        pin_hash="dummy"
    )
    assert _is_production_role(user_prod_en)
    assert _is_production_role_broken(user_prod_en)

    # Test case 3: Classic production role (Thai)
    user_prod_th = User(
        user_id="EMP003",
        user_name="Prod Nok",
        role="ฝ่ายผลิต",
        position="Staff",
        active=True,
        pin_hash="dummy"
    )
    assert _is_production_role(user_prod_th)
    assert _is_production_role_broken(user_prod_th)

    # Test case 4: New production position: "ฝ่ายผลิตบอร์ด"
    user_board = User(
        user_id="EMP004",
        user_name="Board Nok",
        role="staff",
        position="ฝ่ายผลิตบอร์ด",
        active=True,
        pin_hash="dummy"
    )
    assert _is_production_role(user_board)
    assert _is_production_role_broken(user_board)

    # Test case 5: New production position: "ฝ่ายผลิตหุ่นยนต์"
    user_robot = User(
        user_id="EMP005",
        user_name="Robot Nok",
        role="staff",
        position="ฝ่ายผลิตหุ่นยนต์",
        active=True,
        pin_hash="dummy"
    )
    assert _is_production_role(user_robot)
    assert _is_production_role_broken(user_robot)

    # Test case 6: Any position containing "ผลิต"
    user_custom = User(
        user_id="EMP006",
        user_name="Custom Nok",
        role="staff",
        position="ผู้ช่วยหัวหน้าการผลิต",
        active=True,
        pin_hash="dummy"
    )
    assert _is_production_role(user_custom)
    assert _is_production_role_broken(user_custom)

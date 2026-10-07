import hashlib
import os
import shutil
import sys
from pathlib import Path


def prepare_data(app_dir: Path) -> None:
    data_dir = app_dir / "data"
    for directory in (
        "logs", "backups", "browser_data", "trajectory_history", "slider_cookies", "uploads/images"
    ):
        (data_dir / directory).mkdir(parents=True, exist_ok=True)
    config_path = data_dir / "global_config.yml"
    if not config_path.exists():
        shutil.copyfile(app_dir / "global_config.default.yml", config_path)


def initialize_admin(manager) -> bool:
    with manager.lock:
        cursor = manager.conn.cursor()
        cursor.execute("SELECT 1 FROM users WHERE username = 'admin'")
        if cursor.fetchone():
            print("管理员已存在，保留原账号和密码。")
            return False

        email = os.getenv("ADMIN_EMAIL", "").strip()
        password = os.getenv("ADMIN_PASSWORD", "")
        if not email and not password:
            print("请在容器环境变量中设置 ADMIN_EMAIL 和 ADMIN_PASSWORD，再重新创建容器。")
            return False
        if not email or "@" not in email or not password.strip():
            raise ValueError("首次启动需要有效的 ADMIN_EMAIL 和非空的 ADMIN_PASSWORD。")

        password_hash = hashlib.sha256(password.encode()).hexdigest()
        try:
            cursor.execute(
                "INSERT INTO users (username, email, password_hash, is_admin) VALUES (?, ?, ?, ?)",
                ("admin", email, password_hash, 1),
            )
            manager.conn.commit()
        except Exception:
            manager.conn.rollback()
            raise
        print("管理员初始化完成，用户名：admin。")
        return True


def main() -> None:
    app_dir = Path(__file__).resolve().parent.parent
    os.chdir(app_dir)
    prepare_data(app_dir)
    sys.path.insert(0, str(app_dir))
    from db_manager import db_manager

    try:
        initialize_admin(db_manager)
    finally:
        db_manager.close()


if __name__ == "__main__":
    main()

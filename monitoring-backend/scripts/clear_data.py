import sys
from pathlib import Path

from sqlalchemy import text

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.core.database import SessionLocal
from app.models import (
    Alert,
    Device,
    DeviceBandwidth,
    DeviceReplacement,
    FORoute,
    Location,
    NetworkNode,
    ProblemCategory,
    Switch,
    SwitchAlert,
    SwitchBandwidth,
    SwitchReplacement,
    User,
)


def clear_data():
    db = SessionLocal()

    confirm = input("\nConfirm with 'y' to continue: ")

    if confirm == "y":
        try:
            print("\nDeleting data...")
            # delete in correct order
            tables = [
                "device_bandwidth",
                "switch_bandwidth",
                "alerts",
                "switch_alerts",
                "device_replacement",
                "switch_replacement",
                "devices",
                "switches",
                "fo_routes",
                "network_nodes",
                "locations",
                "problem_categories",
                "users",
            ]

            tables_string = ", ".join(tables)
            sql_command = f"TRUNCATE TABLE {tables_string} RESTART IDENTITY CASCADE;"

            db.execute(text(sql_command))
            db.commit()
            print("All data deleted successfully")

        except Exception as e:
            print(f"❌ Error: {e}")
            db.rollback()
        finally:
            db.close()
    else:
        print("Cancelled")


if __name__ == "__main__":
    clear_data()

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

    confirm = input("\nCOnfirm with 'y' to continue: ")

    if confirm == "y":
        try:
            print("\nDeleting data...")

            # Delete in correct order
            db.query(DeviceBandwidth).delete()
            db.query(SwitchBandwidth).delete()
            db.query(Alert).delete()
            db.query(SwitchAlert).delete()
            db.query(DeviceReplacement).delete()
            db.query(SwitchReplacement).delete()
            db.query(Device).delete()
            db.query(Switch).delete()
            db.query(FORoute).delete()
            db.query(NetworkNode).delete()
            db.query(Location).delete()
            db.query(ProblemCategory).delete()
            db.query(User).delete()

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

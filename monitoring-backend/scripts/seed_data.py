import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.core.database import SessionLocal
from app.core.security import get_password_hash
from app.models import (
    Device,
    FORoute,
    Location,
    NetworkNode,
    ProblemCategory,
    Switch,
    User,
)


def seed_database():
    db = SessionLocal()

    try:
        print("\n[1/7] Creating users...")

        # Check if users already exist
        existing_users = db.query(User).count()
        if existing_users > 0:
            print(f"Skipping (already have {existing_users} users)")
        else:
            users = [
                User(
                    username="admin",
                    email="admin@company.com",
                    password_hash=get_password_hash("admin123"),
                    full_name="Admin User",
                    role="admin",
                ),
                User(
                    username="teknisi",
                    email="tech@company.com",
                    password_hash=get_password_hash("tech123"),
                    full_name="Technician User",
                    role="teknisi",
                ),
            ]
            db.add_all(users)
            db.commit()
            print(f"Created {len(users)} users")

        print("\n[2/7] Creating problem categories...")

        existing_categories = db.query(ProblemCategory).count()
        if existing_categories > 0:
            print(f"Skipping (already have {existing_categories} categories)")
        else:
            categories = [
                ProblemCategory(
                    name="Network Issue", description="Network connectivity problems"
                ),
                ProblemCategory(
                    name="Hardware Failure", description="Physical device failure"
                ),
                ProblemCategory(
                    name="Low Bandwidth", description="Bandwidth below threshold"
                ),
                ProblemCategory(
                    name="High Latency",
                    description="Network latency above acceptable range",
                ),
                ProblemCategory(
                    name="Packet Loss", description="Significant packet loss detected"
                ),
                ProblemCategory(
                    name="Device Offline",
                    description="Device not responding to network requests",
                ),
            ]
            db.add_all(categories)
            db.commit()
            print(f"Created {len(categories)} problem categories")

        print("\n[3/7] Creating locations...")

        existing_locations = db.query(Location).count()
        if existing_locations > 0:
            print(f"Skipping (already have {existing_locations} locations)")
            locations = db.query(Location).all()
        else:
            locations = [
                Location(
                    latitude=-5.11758,
                    longitude=119.44173,
                    name="Toll Gate Kaluku Bodoa",
                    location_type="toll_gate",
                    address="Jalan Tol Reformasi, Makassar",
                ),
                Location(
                    latitude=-5.11124,
                    longitude=119.43935,
                    name="Ramp Tallo Barat",
                    location_type="toll_gate",
                    address="Jalan Tol Insinyur Sutami, Makassar",
                ),
            ]
            db.add_all(locations)
            db.commit()
            db.refresh(locations[0])  # Refresh to get IDs
            print(f"Created {len(locations)} locations")

        print("\n[4/7] Creating network nodes...")

        existing_nodes = db.query(NetworkNode).count()
        if existing_nodes > 0:
            print(f"Skipping (already have {existing_nodes} nodes)")
            nodes = db.query(NetworkNode).all()
        else:
            nodes = [
                NetworkNode(
                    location_id=locations[0].location_id,
                    node_type="FO_TERMINATION",
                    description="Main fiber termination at Kalbod",
                ),
                NetworkNode(
                    location_id=locations[1].location_id,
                    node_type="FO_TERMINATION",
                    description="Fiber termination at Tallo Barat",
                ),
            ]
            db.add_all(nodes)
            db.commit()
            db.refresh(nodes[0])
            print(f"Created {len(nodes)} network nodes")

        print("\n[5/7] Creating FO routes...")

        existing_routes = db.query(FORoute).count()
        if existing_routes > 0:
            print(f"Skipping (already have {existing_routes} routes)")
        else:
            routes = [
                FORoute(
                    start_node_id=nodes[0].node_id,
                    end_node_id=nodes[1].node_id,
                    length_m=1500.0,
                    description="Kalbod to Tallo Barat",
                )
            ]
            db.add_all(routes)
            db.commit()
            print(f"Created {len(routes)} FO routes")

        print("\n[6/7] Creating switches...")

        existing_switches = db.query(Switch).count()
        if existing_switches > 0:
            print(f"Skipping (already have {existing_switches} switches)")
            switches = db.query(Switch).all()
        else:
            switches = [
                Switch(
                    name="SW-KALBOD-01",
                    ip_address="192.168.1.1",
                    location_id=locations[0].location_id,
                    node_id=nodes[0].node_id,
                    status="online",
                    description="Main switch Kalbod toll gate",
                ),
                Switch(
                    name="SW-TALLO-BARAT-01",
                    ip_address="192.168.1.2",
                    location_id=locations[1].location_id,
                    node_id=nodes[1].node_id,
                    status="online",
                    description="Main switch Ramp Tallo Barat",
                ),
            ]
            db.add_all(switches)
            db.commit()
            db.refresh(switches[0])
            print(f"Created {len(switches)} switches")

        print("\n[7/7] Creating devices...")

        existing_devices = db.query(Device).count()
        if existing_devices > 0:
            print(f"Skipping (already have {existing_devices} devices)")
        else:
            devices = [
                Device(
                    name="CCTV-KALBOD-ENTRY",
                    ip_address="192.168.1.101",
                    mac_address="00:11:22:33:44:01",
                    device_type="CCTV",
                    location_id=locations[0].location_id,
                    switch_id=switches[0].switch_id,
                    status="online",
                ),
                Device(
                    name="CCTV-KALBOD-EXIT",
                    ip_address="192.168.1.102",
                    mac_address="00:11:22:33:44:02",
                    device_type="CCTV",
                    location_id=locations[0].location_id,
                    switch_id=switches[0].switch_id,
                    status="online",
                ),
                Device(
                    name="CCTV-TALLO-BARAT-ENTRY",
                    ip_address="192.168.2.102",
                    mac_address="00:11:22:33:44:03",
                    device_type="CCTV",
                    location_id=locations[1].location_id,
                    switch_id=switches[1].switch_id,
                    status="online",
                ),
                Device(
                    name="CCTV-TALLO-BARAT-EXIT",
                    ip_address="192.168.2.103",
                    mac_address="00:11:22:33:44:04",
                    device_type="CCTV",
                    location_id=locations[1].location_id,
                    switch_id=switches[1].switch_id,
                    status="online",
                ),
            ]
            db.add_all(devices)
            db.commit()
            print(f"Created {len(devices)} devices")

        print("DATABASE SEEDING COMPLETE")

        # Count all records
        user_count = db.query(User).count()
        category_count = db.query(ProblemCategory).count()
        location_count = db.query(Location).count()
        node_count = db.query(NetworkNode).count()
        route_count = db.query(FORoute).count()
        switch_count = db.query(Switch).count()
        device_count = db.query(Device).count()

        print(f"\nCurrent Database State:")
        print(f"   - Users: {user_count}")
        print(f"   - Problem Categories: {category_count}")
        print(f"   - Locations: {location_count}")
        print(f"   - Network Nodes: {node_count}")
        print(f"   - FO Routes: {route_count}")
        print(f"   - Switches: {switch_count}")
        print(f"   - Devices: {device_count}")

    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        db.rollback()
        import traceback

        traceback.print_exc()
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()

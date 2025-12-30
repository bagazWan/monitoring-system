import asyncio
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.services.librenms_service import LibreNMSService


async def test_connection():
    print("=" * 60)
    print("Testing LibreNMS Connection")
    print("=" * 60)

    librenms = LibreNMSService()

    try:
        # Test 1: Get all devices
        devices = await librenms.get_devices()
        print(f"Found {len(devices)} devices")

        # Show first device
        if devices:
            first_device = devices[0]
            print(f"\nFirst device:")
            print(f"  - ID: {first_device.get('device_id')}")
            print(f"  - Hostname: {first_device.get('hostname')}")
            print(f"  - IP: {first_device.get('ip')}")
            print(f"  - Status: {first_device.get('status')}")

        # Test 2: Get port stats for first device
        if devices:
            device_id = devices[0].get("device_id")
            print(f"\n[TEST 2] Fetching port stats for device {device_id}...")
            ports = await librenms.get_device_port_stats(device_id)
            print(f"Retrieved port statistics")
            print(f"  - Total ports: {len(ports.get('ports', []))}")

        print("LibreNMS connection successful")

    except Exception as e:
        print(f"\n❌ Error connecting to LibreNMS: {e}")
        """
        Possible errors:
            - Invalid API token
            - Network issues
            - LibreNMS server down
            - Incorrect URL
        """


if __name__ == "__main__":
    asyncio.run(test_connection())

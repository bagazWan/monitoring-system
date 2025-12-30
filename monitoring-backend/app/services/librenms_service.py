from typing import Dict, List, Optional

import httpx

from app.core.config import settings


class LibreNMSService:
    def __init__(self):
        self.base_url = settings.LIBRENMS_URL
        self.api_token = settings.LIBRENMS_API_TOKEN
        self.headers = {"X-Auth-Token": self.api_token}

    async def get_devices(self) -> List[Dict]:
        """
        Get all devices from LibreNMS
        API: GET /api/v0/devices
        """
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/devices", headers=self.headers, timeout=30.0
            )
            response.raise_for_status()
            data = response.json()
            return data.get("devices", [])

    async def get_device_by_id(self, device_id: int) -> Optional[Dict]:
        """
        Get specific device from LibreNMS's internal device ID
        API: GET /api/v0/devices/{device_id}
        """
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/devices/{device_id}",
                headers=self.headers,
                timeout=30.0,
            )

            if response.status_code == 404:
                return None

            response.raise_for_status()
            data = response.json()
            return data.get("devices", [None])[0]

    async def get_device_by_hostname(self, hostname: str) -> Optional[Dict]:
        """
        Get specific device from LibreNMS by hostname
        API: GET /api/v0/devices/{hostname}
        """
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/devices/{hostname}",
                headers=self.headers,
                timeout=30.0,
            )

            if response.status_code == 404:
                return None

            response.raise_for_status()
            data = response.json()
            return data.get("devices", [None])[0]

    async def add_device(
        self,
        hostname: str,
        community: str = "public",
        snmp_version: str = "v2c",
        port: int = 161,
        transport: str = "udp",
        force_add: bool = False,
    ) -> Optional[Dict]:
        """
        Add a new device to LibreNMS
        API: POST /api/v0/devices
        Args:
            hostname: Hostname or IP address of the device
            community: SNMP community string (default: "public")
            snmp_version: SNMP version (v1, v2c, v3)
            port: SNMP port (default: 161)
            transport: Transport protocol (udp/tcp)
            force_add: Force add even if device already exists
        """
        payload = {
            "hostname": hostname,
            "community": community,
            "version": snmp_version,
            "port": port,
            "transport": transport,
            "force_add": force_add,
        }

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/api/v0/devices",
                headers=self.headers,
                json=payload,
                timeout=30.0,
            )

            if response.status_code in [200, 201]:
                data = response.json()
                return data.get("devices", [None])[0]

            return None

    async def delete_device(self, device_id: int) -> bool:
        """
        Delete a device from LibreNMS's internal device ID
        API: DELETE /api/v0/devices/{device_id}
        """
        async with httpx.AsyncClient() as client:
            response = await client.delete(
                f"{self.base_url}/api/v0/devices/{device_id}",
                headers=self.headers,
                timeout=30.0,
            )
            return response.status_code in [200, 204]

    async def get_device_port_stats(self, device_id: int) -> Dict:
        """
        Get port statistics (bandwidth) for a device
        API: GET /api/v0/devices/{device_id}/ports
        """
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/devices/{device_id}/ports",
                headers=self.headers,
                timeout=30.0,
            )
            response.raise_for_status()
            return response.json()

    async def get_device_health(self, device_id: int) -> Dict:
        """
        Get device health metrics
        API: GET /api/v0/devices/{device_id}/health
        """
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/devices/{device_id}/health",
                headers=self.headers,
                timeout=30.0,
            )
            response.raise_for_status()
            return response.json()

    async def get_device_graphs(self, device_id: int) -> Dict:
        """
        Get available graphs for a device LibreNMS's internal device ID
        API: GET /api/v0/devices/{device_id}/graphs
        """
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/devices/{device_id}/graphs",
                headers=self.headers,
                timeout=30.0,
            )
            response.raise_for_status()
            return response.json()

    async def get_alerts(self, device_id: Optional[int] = None) -> List[Dict]:
        """
        Get alerts from LibreNMS device ID
        API: GET /api/v0/alerts
        """
        params = {}
        if device_id:
            params["device_id"] = device_id

        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/alerts",
                headers=self.headers,
                params=params,
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()
            return data.get("alerts", [])

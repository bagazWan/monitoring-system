from typing import Dict, List, Optional

import httpx

from app.core.config import settings


class LibreNMSService:
    def __init__(self):
        self.base_url = settings.LIBRENMS_URL
        self.api_token = settings.LIBRENMS_API_TOKEN
        self.headers = {"X-Auth-Token": self.api_token}

    async def get_devices(self) -> List[Dict]:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/devices", headers=self.headers, timeout=30.0
            )
            response.raise_for_status()
            data = response.json()
            return data.get("devices", [])

    async def get_device_by_id(self, device_id: int) -> Optional[Dict]:
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
        async with httpx.AsyncClient() as client:
            for path in (
                f"/api/v0/devices/{hostname}",
                f"/api/v0/devices/hostname/{hostname}",
            ):
                response = await client.get(
                    f"{self.base_url}{path}",
                    headers=self.headers,
                    timeout=30.0,
                )
                if response.status_code == 404:
                    continue
                if response.status_code >= 400:
                    continue

                data = response.json()
                return data.get("devices", [None])[0]

        return None

    async def add_device(
        self,
        hostname: str,
        community: str = "public",
        snmp_version: str = "v2c",
        port: int = 161,
        transport: str = "udp",
        force_add: bool = False,
    ) -> Optional[int]:
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

            if response.status_code in (200, 201):
                data = response.json()

                if data.get("device_id") is not None:
                    return int(data["device_id"])

                devices = data.get("devices") or []
                if devices:
                    dev0 = devices[0]
                    if dev0 and dev0.get("device_id") is not None:
                        return int(dev0["device_id"])

            existing = await self.get_device_by_hostname(hostname)
            if existing and existing.get("device_id") is not None:
                return int(existing["device_id"])

            return None

    async def delete_device(self, device_id: int) -> bool:
        async with httpx.AsyncClient() as client:
            response = await client.delete(
                f"{self.base_url}/api/v0/devices/{device_id}",
                headers=self.headers,
                timeout=30.0,
            )
            return response.status_code in [200, 204]

    async def get_device_port_stats(self, device_id: int) -> Dict:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/devices/{device_id}/ports",
                headers=self.headers,
                timeout=30.0,
            )
            response.raise_for_status()
            return response.json()

    async def get_ports(self, device_id: Optional[int] = None) -> Dict:
        params = {}
        if device_id is not None:
            params["device_id"] = device_id

        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/ports",
                headers=self.headers,
                params=params,
                timeout=30.0,
            )
            response.raise_for_status()
            return response.json()

    async def get_port_by_id(self, port_id: int) -> Dict:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/ports/{port_id}",
                headers=self.headers,
                timeout=30.0,
            )
            response.raise_for_status()
            return response.json()

    async def get_device_health(self, device_id: int) -> Dict:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/devices/{device_id}/health",
                headers=self.headers,
                timeout=30.0,
            )
            response.raise_for_status()
            return response.json()

    async def get_device_graphs(self, device_id: int) -> Dict:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v0/devices/{device_id}/graphs",
                headers=self.headers,
                timeout=30.0,
            )
            response.raise_for_status()
            return response.json()

    async def get_alerts(self, device_id: Optional[int] = None) -> List[Dict]:
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

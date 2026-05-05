import asyncio
import logging
import time
from typing import Dict, Optional, Tuple

from app.core.config import settings

logger = logging.getLogger(__name__)


class PingProbe:
    def __init__(self) -> None:
        self._cache: Dict[str, Tuple[float, Optional[float]]] = {}

    async def ping(self, host: str) -> Optional[float]:
        if not host or not settings.PING_PROBE_ENABLED:
            return None

        now = time.monotonic()
        cached = self._cache.get(host)
        if cached and now - cached[0] < settings.PING_PROBE_CACHE_SECONDS:
            return cached[1]

        latency = await self._run_fping(host)

        self._cache[host] = (time.monotonic(), latency)
        return latency

    async def _run_fping(self, host: str) -> Optional[float]:
        cmd = [
            settings.PING_PROBE_PATH,
            "-C",
            str(settings.PING_PROBE_COUNT),
            "-t",
            str(settings.PING_PROBE_TIMEOUT_MS),
            host,
        ]

        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await proc.communicate()

            output = (stdout or b"").decode().strip()
            if not output:
                output = (stderr or b"").decode().strip()

            logger.info("fping raw output for %s: %s", host, output)

            if not output:
                return None

            lines = [line.strip() for line in output.splitlines() if line.strip()]
            if not lines:
                return None

            # 1. If line contains (X avg, ...), use that avg
            for line in reversed(lines):
                if "avg" in line:
                    # e.g. (0.047 avg, 0% loss)
                    try:
                        avg_part = line.split("avg", 1)[0]
                        avg_value = avg_part.split("(")[-1].strip()
                        return float(avg_value)
                    except Exception:
                        pass

            # 2. If summary line exists: "IP : 0.100 0.049 0.055"
            last = lines[-1]
            if ":" in last:
                _, values = last.split(":", 1)
                tokens = [t for t in values.strip().split() if t != "-"]
                nums = []
                for t in tokens:
                    try:
                        nums.append(float(t))
                    except Exception:
                        continue
                if nums:
                    return sum(nums) / len(nums)

            # 3. Fallback: extract the last "x ms" value
            for line in reversed(lines):
                if " ms" in line:
                    try:
                        before_ms = line.split(" ms")[0]
                        value = before_ms.split()[-1]
                        return float(value)
                    except Exception:
                        continue

            return None
        except Exception as exc:
            logger.debug("fping failed for %s: %s", host, exc)
            return None

    async def ping_bulk(self, hosts: list[str]) -> dict[str, Optional[float]]:
        if not hosts or not settings.PING_PROBE_ENABLED:
            return {}

        cmd = [
            settings.PING_PROBE_PATH,
            "-C",
            str(settings.PING_PROBE_COUNT),
            "-t",
            str(settings.PING_PROBE_TIMEOUT_MS),
            "-q",
        ] + hosts

        results = {host: None for host in hosts}

        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await proc.communicate()

            output = (stderr.decode() + "\n" + stdout.decode()).strip()

            if not output:
                return results

            for line in output.splitlines():
                if ":" in line:
                    parts = line.split(":", 1)
                    ip = parts[0].strip()
                    times_str = parts[1].strip()

                    times = [float(t) for t in times_str.split() if t != "-"]
                    if times:
                        results[ip] = sum(times) / len(times)

        except Exception as exc:
            logger.error("Bulk fping failed: %s", exc)

        return results


ping_probe = PingProbe()

from app.core.database import get_db
from app.models import Device, Switch
from app.models.alert import Alert
from app.services.librenms_service import LibreNMSService
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

router = APIRouter()


@router.get("/stats")
async def get_dashboard_summary(db: Session = Depends(get_db)):
    total_devices = db.query(Device).count()
    total_switches = db.query(Switch).count()

    online_devices = db.query(Device).filter(Device.status == "online").count()
    online_switches = db.query(Switch).filter(Switch.status == "online").count()

    monitored_devices = (
        db.query(Device).filter(Device.librenms_device_id.isnot(None)).all()
    )
    monitored_switches = (
        db.query(Switch).filter(Switch.librenms_device_id.isnot(None)).all()
    )

    all_monitored = monitored_devices + monitored_switches

    total_bandwidth_mbps = 0.0
    data_found = False
    librenms = LibreNMSService()

    try:
        for node in all_monitored:
            port_stats = await librenms.get_device_port_stats(node.librenms_device_id)
            for port in port_stats.get("ports", []):
                in_rate = port.get("ifInOctets_rate", 0) * 8 / 1_000_000
                out_rate = port.get("ifOutOctets_rate", 0) * 8 / 1_000_000
                total_bandwidth_mbps += in_rate + out_rate
                data_found = True
    except Exception:
        # If LibreNMS is down, data_found stays False
        pass

    active_alerts = db.query(Alert).filter(Alert.severity != "cleared").count()

    return {
        "total_all_devices": total_devices + total_switches,
        "all_online_devices": online_devices + online_switches,
        "active_alerts": active_alerts,
        "total_bandwidth": round(total_bandwidth_mbps, 2) if data_found else None,
    }

from app.core.database import get_db
from app.models import Device, FORoute, Location, NetworkNode, Switch
from app.schemas.network_map import MapTopologyResponse
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

router = APIRouter(prefix="/map", tags=["Map"])


@router.get("/topology", response_model=MapTopologyResponse)
def get_map_topology(db: Session = Depends(get_db)):
    locations = db.query(Location).order_by(Location.location_id.asc()).all()
    nodes = db.query(NetworkNode).order_by(NetworkNode.node_id.asc()).all()
    routes = db.query(FORoute).order_by(FORoute.routes_id.asc()).all()
    devices = db.query(Device).order_by(Device.device_id.asc()).all()
    switches = db.query(Switch).order_by(Switch.switch_id.asc()).all()

    return {
        "locations": [
            {
                "location_id": loc.location_id,
                "name": loc.name,
                "location_type": loc.location_type,
                "address": loc.address,
                "latitude": loc.latitude,
                "longitude": loc.longitude,
                "description": loc.description,
            }
            for loc in locations
        ],
        "network_nodes": nodes,
        "fo_routes": routes,
        "devices": [
            {
                "device_id": d.device_id,
                "name": d.name,
                "ip_address": d.ip_address,
                "status": d.status,
                "location_id": d.location_id,
                "switch_id": d.switch_id,
                "description": d.description,
            }
            for d in devices
        ],
        "switches": [
            {
                "switch_id": s.switch_id,
                "name": s.name,
                "ip_address": s.ip_address,
                "status": s.status,
                "location_id": s.location_id,
                "node_id": s.node_id,
                "description": s.description,
            }
            for s in switches
        ],
    }

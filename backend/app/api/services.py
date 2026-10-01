from fastapi import APIRouter, Query, Depends
from ..services.google_maps_client import google_maps_client
from ..core.security import verify_api_key
from typing import Literal

router = APIRouter(prefix="/services", tags=["services"])

# Mapping from our type names to Google Places API types
_PLACE_TYPE_MAP = {
    "police": "police",
    "hospital": "hospital",
    "fire": "fire_station",
}


@router.get("/nearest")
async def get_nearest_services(
    lat: float = Query(..., description="Latitude of the user"),
    lng: float = Query(..., description="Longitude of the user"),
    type: Literal["police", "hospital", "fire"] = Query("police"),
    limit: int = Query(3, ge=1, le=10),
    _: str = Depends(verify_api_key),
):
    """
    Returns the nearest emergency service locations.
    Uses Google Places Nearby Search API.
    Falls back to an empty list if no API key is configured.
    """
    place_type = _PLACE_TYPE_MAP.get(type, "police")
    places = await google_maps_client.nearby_search(
        lat=lat,
        lng=lng,
        place_type=place_type,
        limit=limit,
    )
    return places

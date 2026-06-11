"""
Geocode Warsaw schools via Nominatim (OpenStreetMap) using addresses from stg_rspo.

Strategy:
  1. Try full address: street + number, Warszawa
  2. If no result: try street only + Warszawa
  3. Validate coords are in Warsaw metro bounding box
  4. Cache per RSPO id → _cache/nominatim_coords.json
  5. Write stg_nominatim_coords(numer_rspo, lat, lon, display_name, match_type)
  6. UPDATE Wymiar_Szkola with found coords

Politeness: 1 req/s, User-Agent required by OSM ToS.
"""
import json
import time
from pathlib import Path

import pandas as pd
import requests
from sqlalchemy import Engine, text

from etl.config import CACHE_DIR, SCRAPE_DELAY_SEC

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
CACHE_FILE = CACHE_DIR / "nominatim_coords.json"
HEADERS = {"User-Agent": "WawaLiceum-ETL/1.0 (academic project; contact: wawaliceum@pjwstk.edu.pl)"}

LAT_MIN, LAT_MAX = 51.90, 52.50
LON_MIN, LON_MAX = 20.70, 21.40


def _load_cache() -> dict:
    if CACHE_FILE.exists():
        return json.loads(CACHE_FILE.read_text(encoding="utf-8"))
    return {}


def _save_cache(cache: dict) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")


def _in_warsaw(lat, lon) -> bool:
    return (lat is not None and lon is not None
            and LAT_MIN <= lat <= LAT_MAX and LON_MIN <= lon <= LON_MAX)


def _query(session: requests.Session, params: dict):
    resp = session.get(NOMINATIM_URL, params={**params, "format": "json", "limit": 1,
                                               "countrycodes": "pl"}, timeout=10)
    if resp.status_code == 429:
        time.sleep(10)
        resp = session.get(NOMINATIM_URL, params={**params, "format": "json", "limit": 1,
                                                   "countrycodes": "pl"}, timeout=10)
    resp.raise_for_status()
    results = resp.json()
    return results[0] if results else None


def geocode_schools(engine: Engine) -> int:
    rspo_df = pd.read_sql("""
        SELECT numer_rspo, nazwa, ulica, numer_budynku, kod_pocztowy, miejscowosc
        FROM stg_rspo
        WHERE TRY_CAST(numer_rspo AS int) IS NOT NULL
    """, engine)

    cache = _load_cache()
    session = requests.Session()
    session.headers.update(HEADERS)

    rows = []
    miss = 0

    for _, school in rspo_df.iterrows():
        rspo_id = str(school["numer_rspo"]).strip()

        if rspo_id in cache:
            rows.append(cache[rspo_id])
            continue

        ulica = str(school["ulica"] or "").strip()
        numer = str(school["numer_budynku"] or "").strip()
        miasto = str(school["miejscowosc"] or "Warszawa").strip()

        result = None
        match_type = None

        # Attempt 1: street + number
        if ulica and numer:
            time.sleep(SCRAPE_DELAY_SEC)
            result = _query(session, {"street": f"{ulica} {numer}", "city": miasto})
            if result:
                match_type = "street+number"

        # Attempt 2: street only
        if not result and ulica:
            time.sleep(SCRAPE_DELAY_SEC)
            result = _query(session, {"street": ulica, "city": miasto})
            if result:
                match_type = "street"

        # Attempt 3: school name + city
        if not result:
            name = str(school["nazwa"] or "").strip()
            time.sleep(SCRAPE_DELAY_SEC)
            result = _query(session, {"q": f"{name}, {miasto}"})
            if result:
                match_type = "name"

        if result:
            lat = float(result["lat"])
            lon = float(result["lon"])
            if _in_warsaw(lat, lon):
                entry = {
                    "numer_rspo": rspo_id,
                    "lat": lat,
                    "lon": lon,
                    "display_name": result.get("display_name", "")[:255],
                    "match_type": match_type,
                }
            else:
                entry = {"numer_rspo": rspo_id, "lat": None, "lon": None,
                         "display_name": None, "match_type": "out_of_bounds"}
                miss += 1
                print(f"  [geo] OUT OF BOUNDS: {school['nazwa'][:50]} → ({lat},{lon})")
        else:
            entry = {"numer_rspo": rspo_id, "lat": None, "lon": None,
                     "display_name": None, "match_type": "not_found"}
            miss += 1
            print(f"  [geo] NOT FOUND: {school['nazwa'][:60]}")

        cache[rspo_id] = entry
        rows.append(entry)

    _save_cache(cache)

    df = pd.DataFrame(rows)
    df.to_sql("stg_nominatim_coords", engine, if_exists="replace", index=False,
              method="multi", chunksize=500)

    found = len(df) - miss
    print(f"[stg_nominatim_coords] {found}/{len(df)} schools geocoded")

    # UPDATE Wymiar_Szkola
    with engine.begin() as conn:
        conn.execute(text("""
            UPDATE s SET
                s.wspolrzedne_lat  = TRY_CAST(n.lat AS decimal(9,6)),
                s.wspolrzedne_long = TRY_CAST(n.lon AS decimal(9,6))
            FROM dbo.Wymiar_Szkola s
            JOIN dbo.stg_nominatim_coords n
                ON n.numer_rspo = CAST(s.id_szkoly_rspo AS nvarchar(20))
            WHERE n.lat IS NOT NULL
        """))

    with engine.connect() as conn:
        result = conn.execute(text(
            "SELECT COUNT(*) FROM dbo.Wymiar_Szkola WHERE wspolrzedne_lat IS NOT NULL"
        ))
        updated = result.scalar()

    print(f"[Wymiar_Szkola] {updated} schools now have coordinates")
    return found

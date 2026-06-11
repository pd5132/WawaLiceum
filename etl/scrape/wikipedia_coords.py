"""
Scrape geographic coordinates from pl.wikipedia.org for Warsaw schools.

Strategy:
  1. Convert RSPO ALL-CAPS name to Wikipedia title case
  2. Try direct API lookup: action=query&prop=coordinates&titles=<name>
  3. If not found, try without patron ("im. X") suffix
  4. Validate coords are in Warsaw metro area (lat 51.9-52.5, lon 20.7-21.4)
  5. Cache results to _cache/wiki_coords.json
  6. Write stg_wiki_coords(numer_rspo, wiki_title, lat, lon)

Cached so re-runs don't re-hit Wikipedia. Politeness: 1.5s between uncached requests.
"""
import json
import re
import time
import unicodedata
from pathlib import Path

import pandas as pd
import requests
from sqlalchemy import Engine

from etl.config import CACHE_DIR, SCRAPE_DELAY_SEC

WIKI_API = "https://pl.wikipedia.org/w/api.php"
CACHE_FILE = CACHE_DIR / "wiki_coords.json"

# Warsaw bounding box (generous — includes outer boroughs)
LAT_MIN, LAT_MAX = 51.90, 52.50
LON_MIN, LON_MAX = 20.70, 21.40

# Words kept lowercase in Polish Wikipedia titles (prepositions, abbreviations)
_LOWER_WORDS = {
    "im", "im.", "nr", "w", "we", "z", "ze", "i", "o", "na", "do", "dla",
    "przy", "pod", "nad", "za", "przed", "po", "a", "oraz", "też"
}

# Detect Roman numerals (supports I–CXCIX common in school names)
_ROMAN = re.compile(
    r"^M{0,3}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$",
    re.IGNORECASE
)


def _to_wiki_title(rspo_name: str) -> str:
    """Convert RSPO ALL-CAPS name to Wikipedia-style title case."""
    words = rspo_name.strip().split()
    out = []
    for i, w in enumerate(words):
        wl = w.lower().rstrip(".")
        # Roman numeral: keep all-caps
        if _ROMAN.fullmatch(wl) and len(w) <= 8:
            out.append(w.upper())
        # Known lowercase words (not first word)
        elif i > 0 and wl in _LOWER_WORDS:
            out.append(w.lower())
        else:
            # Title case with diacritics preserved
            out.append(w[0].upper() + w[1:].lower() if w else w)
    return " ".join(out)


def _strip_patron(title: str) -> str:
    """Remove 'im. X Y' part — try shorter form if full name not found."""
    return re.sub(r"\s+im\..*", "", title).strip()


def _load_cache() -> dict:
    if CACHE_FILE.exists():
        return json.loads(CACHE_FILE.read_text(encoding="utf-8"))
    return {}


def _save_cache(cache: dict) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")


def _api_coords(session: requests.Session, title: str) -> tuple:
    """Query Wikipedia API for coordinates of a page title. Returns (lat, lon, resolved_title)."""
    resp = session.get(WIKI_API, params={
        "action": "query",
        "prop": "coordinates",
        "redirects": 1,
        "titles": title,
        "format": "json",
    }, timeout=10)
    if resp.status_code == 429:
        time.sleep(5)
        return None, None, None
    resp.raise_for_status()
    pages = resp.json().get("query", {}).get("pages", {})
    for page in pages.values():
        if page.get("pageid", -1) == -1:
            return None, None, None
        coords = page.get("coordinates", [])
        if coords:
            return coords[0]["lat"], coords[0]["lon"], page.get("title", title)
    return None, None, None


def _search_coords(session: requests.Session, query: str) -> tuple:
    """Fallback: search Wikipedia, then fetch coords of top result."""
    resp = session.get(WIKI_API, params={
        "action": "query",
        "list": "search",
        "srsearch": query + " liceum Warszawa",
        "srlimit": 3,
        "format": "json",
    }, timeout=10)
    if resp.status_code == 429:
        time.sleep(5)
        return None, None, None
    results = resp.json().get("query", {}).get("search", [])
    for hit in results:
        title = hit["title"]
        # Only follow hits that look like Warsaw school articles
        if "liceum" not in title.lower() and "szkoła" not in title.lower():
            continue
        time.sleep(SCRAPE_DELAY_SEC)
        lat, lon, resolved = _api_coords(session, title)
        if lat is not None:
            return lat, lon, resolved
    return None, None, None


def _in_warsaw(lat, lon) -> bool:
    return (lat is not None and lon is not None and
            LAT_MIN <= lat <= LAT_MAX and LON_MIN <= lon <= LON_MAX)


def scrape_wikipedia_coords(rspo_df: pd.DataFrame, engine: Engine) -> int:
    """
    rspo_df: DataFrame with numer_rspo (str), Nazwa (str) columns from stg_rspo.
    Returns number of schools with coords found.
    """
    cache = _load_cache()
    session = requests.Session()
    session.headers["User-Agent"] = "WawaLiceum-ETL/1.0 (academic project)"

    rows = []
    miss = 0

    for _, school in rspo_df.iterrows():
        rspo_id = str(school["numer_rspo"]).strip()
        rspo_name = str(school["nazwa"]).strip()

        # Cache key = rspo_id
        if rspo_id in cache:
            entry = cache[rspo_id]
            rows.append(entry)
            continue

        # Build title candidates
        full_title = _to_wiki_title(rspo_name)
        short_title = _strip_patron(full_title)
        candidates = [full_title]
        if short_title != full_title:
            candidates.append(short_title)

        found_lat = found_lon = found_title = None
        for candidate in candidates:
            lat, lon, resolved = _api_coords(session, candidate)
            time.sleep(SCRAPE_DELAY_SEC)
            if _in_warsaw(lat, lon):
                found_lat, found_lon, found_title = lat, lon, resolved
                break

        # Fallback: search by school name if direct title lookup failed
        if found_lat is None:
            lat, lon, resolved = _search_coords(session, full_title)
            time.sleep(SCRAPE_DELAY_SEC)
            if _in_warsaw(lat, lon):
                found_lat, found_lon, found_title = lat, lon, resolved

        entry = {
            "numer_rspo": rspo_id,
            "wiki_title": found_title,
            "lat": found_lat,
            "lon": found_lon,
        }
        cache[rspo_id] = entry
        rows.append(entry)

        if found_lat is None:
            miss += 1
            print(f"  [wiki] NO COORDS: {rspo_name[:60]}")

    _save_cache(cache)

    df = pd.DataFrame(rows)
    df.to_sql("stg_wiki_coords", engine, if_exists="replace", index=False, method="multi", chunksize=500)

    found = len(df) - miss
    print(f"[stg_wiki_coords] {found}/{len(df)} schools with Warsaw coords")
    return found

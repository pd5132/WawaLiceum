"""
EWD scraper — uses api-ewd.men.gov.pl REST API.

EWD system uses its own internal school IDs (NOT RSPO numbers).
ID crosswalk is built via zwrSzkoly (all Warsaw LO) + fuzzy name match to RSPO.

Call sequence:
  1. zwrSzkoly?teryt=146510&typSzkoly=LO → all Warsaw liceums with EWD data
  2. fuzzy match EWD school names → RSPO ids (same normalisation as school_matcher)
  3. zwrWskazniki?idSzkol={ewd_id} → indicator codes + periods per school
  4. zwrDaneEWD?idSzkol={ewd_id}&... → EWD + exam point estimates + confidence intervals

Output stg_ewd columns (one row per school × indicator × period):
  rspo_szkoly, rok, okres, typ_ewd, nazwa_wskaznika, grupa,
  ewd_oszacowanie, ewd_upper, ewd_lower,
  egzamin_oszacowanie, egzamin_upper, egzamin_lower, liczba_uczniow
"""
import json
import re
import time
import hashlib
import unicodedata
from typing import Optional
import requests
import pandas as pd
from rapidfuzz import process, fuzz
from sqlalchemy import Engine
from etl.config import CACHE_DIR, REQUEST_HEADERS, SCRAPE_DELAY_SEC, MATCH_DIR

API_BASE  = "https://api-ewd.men.gov.pl/"
TERYT_WAW = "146510"   # Warsaw powiat teryt code in EWD system
MATCH_THR = 75         # minimum fuzzy score to trust name match

CACHE_DIR.mkdir(parents=True, exist_ok=True)

_EWD_COLS = [
    "rspo_szkoly", "rok", "okres", "typ_ewd", "nazwa_wskaznika", "grupa",
    "ewd_oszacowanie", "ewd_upper", "ewd_lower",
    "egzamin_oszacowanie", "egzamin_upper", "egzamin_lower", "liczba_uczniow",
]


def _cache_key(url: str) -> str:
    return hashlib.md5(url.encode()).hexdigest()


def _get_json(params: dict, session: requests.Session, delay: bool = True):
    import urllib.parse
    url = API_BASE + "?" + urllib.parse.urlencode(params)
    cache_file = CACHE_DIR / (_cache_key(url) + ".json")
    if cache_file.exists():
        return json.loads(cache_file.read_text(encoding="utf-8"))
    if delay:
        time.sleep(SCRAPE_DELAY_SEC)
    resp = session.get(url, headers=REQUEST_HEADERS, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    cache_file.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return data


def _safe_float(v) -> Optional[float]:
    if v is None:
        return None
    try:
        return float(str(v).replace(",", "."))
    except (ValueError, TypeError):
        return None


def _norm(name: str) -> str:
    s = unicodedata.normalize("NFD", str(name)).encode("ascii", "ignore").decode()
    s = s.lower()
    s = re.sub(r"\bim\.?\b", "", s)
    s = re.sub(r"\b(liceum ogolnoksztalcace|lo)\b", "", s)
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def _build_ewd_rspo_crosswalk(rspo_df: pd.DataFrame, session: requests.Session) -> list[dict]:
    """Fetch all Warsaw LO from EWD, fuzzy-match to RSPO ids."""
    schools = _get_json({
        "akcja": "zwrSzkoly",
        "teryt": TERYT_WAW,
        "typSzkoly": "LO",
    }, session, delay=False)

    waw = [s for s in schools
           if isinstance(s, dict)
           and s.get("miejscowosc", "").lower() == "warszawa"
           and s.get("posiada_wsk")]

    print(f"[ewd] Warsaw LO with EWD data: {len(waw)}")

    rspo_names  = rspo_df["nazwa"].tolist()
    rspo_ids    = rspo_df["numer_rspo"].tolist()
    rspo_normed = [_norm(n) for n in rspo_names]

    crosswalk, unmatched = [], []
    for s in waw:
        normed = _norm(s["nazwa"])
        result = process.extractOne(
            normed, rspo_normed,
            scorer=fuzz.token_sort_ratio,
            score_cutoff=MATCH_THR,
        )
        if result:
            idx = rspo_normed.index(result[0])
            crosswalk.append({
                "ewd_id":   s["idSzkoly"],
                "ewd_name": s["nazwa"],
                "rspo":     rspo_ids[idx],
                "score":    result[1],
            })
        else:
            unmatched.append(s["nazwa"])

    print(f"[ewd] Matched {len(crosswalk)} | Unmatched {len(unmatched)}")
    if unmatched:
        pd.DataFrame({"ewd_name": unmatched}).to_csv(
            MATCH_DIR / "unresolved_ewd.csv", index=False
        )
    return crosswalk


def _fetch_school_ewd(ewd_id: int, rspo: str, session: requests.Session) -> list[dict]:
    ws = _get_json({
        "akcja": "zwrWskazniki",
        "idSzkol": str(ewd_id),
        "rodzajWsk": "ewd",
        "doPrezentacji": 1,
    }, session)

    if not ws:
        return []

    codes:   list[str] = []
    okresy:  set[str]  = set()
    meta:    dict      = {}

    for w in ws:
        code = w.get("wskaznik")
        if not code:
            continue
        codes.append(code)
        meta[code] = {"nazwa": w.get("nazwa", code), "grupa": w.get("grupa", "")}
        for p in (w.get("okresy") or []):
            okresy.add(str(p))

    if not codes:
        return []

    rows: list[dict] = []
    for okres in sorted(okresy):
        rok = int(okres[-4:])

        ed = _get_json({
            "akcja": "zwrDaneEWD",
            "idSzkol": str(ewd_id),
            "okresy":    json.dumps([okres]),
            "wskazniki": json.dumps(codes),
            "szarosci":  "",
            "anonimowe": 0,
        }, session)

        if not isinstance(ed, dict):
            continue

        for code, ind in ed.items():
            if not isinstance(ind, dict):
                continue
            m = meta.get(code, {"nazwa": code, "grupa": ""})
            for school in (ind.get("szkoly") or []):
                if not isinstance(school, dict):
                    continue
                pd_data = (school.get("okresy") or {}).get(okres, {})
                if not pd_data or not pd_data.get("wyswietlaj", True):
                    continue
                ewd = pd_data.get("ewd") or {}
                egz = pd_data.get("egz") or {}
                lu  = pd_data.get("lu")  or {}
                rows.append({
                    "rspo_szkoly":         rspo,
                    "rok":                 rok,
                    "okres":               okres,
                    "typ_ewd":             code,
                    "nazwa_wskaznika":     m["nazwa"],
                    "grupa":               m["grupa"],
                    "ewd_oszacowanie":     _safe_float(ewd.get("pkt")),
                    "ewd_upper":           _safe_float(ewd.get("max")),
                    "ewd_lower":           _safe_float(ewd.get("min")),
                    "egzamin_oszacowanie": _safe_float(egz.get("pkt")),
                    "egzamin_upper":       _safe_float(egz.get("max")),
                    "egzamin_lower":       _safe_float(egz.get("min")),
                    "liczba_uczniow":      lu.get("ogółem"),
                })
    return rows


def scrape_ewd(rspo_df: pd.DataFrame, engine: Engine) -> int:
    session = requests.Session()

    crosswalk = _build_ewd_rspo_crosswalk(rspo_df, session)

    all_rows: list[dict] = []
    no_data = 0

    for i, entry in enumerate(crosswalk, 1):
        ewd_id = entry["ewd_id"]
        rspo   = str(entry["rspo"])
        try:
            rows = _fetch_school_ewd(ewd_id, rspo, session)
            if rows:
                all_rows.extend(rows)
            else:
                no_data += 1
                print(f"  [ewd] NO DATA EWD {ewd_id} → RSPO {rspo}")
        except Exception as e:
            print(f"  [ewd] ERROR EWD {ewd_id}: {e}")
            no_data += 1

        if i % 25 == 0:
            print(f"  [ewd] {i}/{len(crosswalk)} done, {len(all_rows)} rows so far")

    df = pd.DataFrame(all_rows) if all_rows else pd.DataFrame(columns=_EWD_COLS)
    df.to_sql("stg_ewd", engine, if_exists="replace", index=False, method="multi", chunksize=500)
    print(f"[stg_ewd] {len(df)} rows | {no_data} schools with no data")
    return len(df)

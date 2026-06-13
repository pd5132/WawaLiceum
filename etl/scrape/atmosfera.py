"""
Atmosphere scraper — swiadomiewybieram.pl (updated for new URL structure)

Login via wp-login.php using env vars SW_LOGIN and SW_PASSWORD.
School pages: /szkola/warszawa/{site_id}/

ID discovery:
  1. Load from cache (etl/scrape/_cache/sw_ids.json) if exists
  2. Scan ID range 102500-106000 via GET (only once, cached)
  3. Fuzzy-match school names to RSPO

Data written to stg_atmosfera (one row per school):
  rspo_szkoly, site_id, nazwa_szkoly,
  matura_proc, atmosfera_proc, przyjemnosc_nauki_proc,
  relacje_uczniow_proc, relacja_nauczyciel_proc, nowoczesnosc_zajec_proc,
  polecanie_szkoly_proc, jakosc_odpoczynku_proc, liczba_ankiet,
  liczba_uczniow, zdawalnosc_matur_proc,
  + infra flags (czy_*)

Credentials: set env vars SW_LOGIN and SW_PASSWORD before running.
"""
import json
import os
import re
import time
import hashlib
from typing import Optional
import requests
from bs4 import BeautifulSoup
import pandas as pd
from rapidfuzz import process, fuzz
import unicodedata
from sqlalchemy import Engine

from pathlib import Path
from etl.config import CACHE_DIR, SCRAPE_DELAY_SEC, MATCH_DIR

# Load .env if present
try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parents[2] / ".env")
except ImportError:
    pass

BASE       = "https://swiadomiewybieram.pl"
IDS_CACHE  = CACHE_DIR / "sw_ids.json"
PAGE_CACHE = CACHE_DIR / "sw_pages"
ID_RANGE   = range(102000, 107000)

CACHE_DIR.mkdir(parents=True, exist_ok=True)
PAGE_CACHE.mkdir(parents=True, exist_ok=True)


# ── Login ────────────────────────────────────────────────────────────────────

def _login(session: requests.Session) -> bool:
    login    = os.environ.get("SW_LOGIN", "")
    password = os.environ.get("SW_PASSWORD", "")
    if not login or not password:
        print("[atm] WARNING: SW_LOGIN/SW_PASSWORD not set — scraping without auth (limited data)")
        return False
    # Fetch nonce from any school page (wp-login.php returns 404 on this site)
    r0 = session.get(f"{BASE}/lista/warszawa/", timeout=10)
    soup0 = BeautifulSoup(r0.text, "lxml")
    nonce_input = soup0.find("input", id="pxp-signin-modal-security")
    nonce = nonce_input["value"] if nonce_input else ""
    resp = session.post(
        f"{BASE}/wp-admin/admin-ajax.php",
        data={
            "action":      "resideo_user_signin",
            "signin_user": login,
            "signin_pass": password,
            "security":    nonce,
        },
        headers={"Referer": f"{BASE}/lista/warszawa/", "X-Requested-With": "XMLHttpRequest"},
        timeout=15,
    )
    try:
        result = resp.json()
        logged_in = result.get("signedin") is True or result.get("success") is True
    except Exception:
        logged_in = '"signedin":true' in resp.text or '"success":true' in resp.text
    print(f"[atm] Login: {'OK' if logged_in else 'FAILED'} ({resp.text[:120]})")
    return logged_in


# ── ID Discovery ─────────────────────────────────────────────────────────────

def _load_ids() -> dict:
    if IDS_CACHE.exists():
        return json.loads(IDS_CACHE.read_text(encoding="utf-8"))
    return {}


def _save_ids(ids: dict) -> None:
    IDS_CACHE.write_text(json.dumps(ids, ensure_ascii=False, indent=2), encoding="utf-8")


def _scan_ids(session: requests.Session) -> dict:
    """Discover Warsaw school IDs from listing pages. Cached after first run."""
    known = _load_ids()
    if known:
        print(f"[atm] ID cache loaded: {len(known)} schools")
        return known

    print("[atm] Scanning Warsaw school listing pages...")
    found: dict = {}
    page = 1
    while True:
        try:
            r = session.get(f"{BASE}/lista/warszawa/?pageno={page}", timeout=10)
            if r.status_code != 200:
                break
            soup = BeautifulSoup(r.text, "lxml")
            # Build has_data map from carousel cards (contain ankiety count)
            ankiety_map: dict = {}
            for card in soup.find_all("div", id=re.compile(r"^card-carousel-")):
                m = re.search(r"card-carousel-(\d+)", card["id"])
                if not m:
                    continue
                am = re.search(r"Ankiety[:\s]+(\d+)", card.get_text())
                ankiety_map[m.group(1)] = ankiety_map.get(m.group(1), False) or bool(am and int(am.group(1)) > 0)
            if not ankiety_map:
                break
            # Extract names from details-title divs (sibling col to carousel)
            for details in soup.find_all("div", class_="pxp-results-list-item-1-details-title"):
                lnk = details.find("a", href=re.compile(r"/szkola/warszawa/\d+"))
                if not lnk:
                    continue
                m = re.search(r"/(\d+)(?:/?)$", lnk["href"])
                if not m:
                    continue
                sid = m.group(1)
                name = lnk.get_text().strip()
                has_data = ankiety_map.get(sid, False)
                existing = found.get(sid, {})
                found[sid] = {
                    "name": name or existing.get("name", ""),
                    "has_data": has_data or existing.get("has_data", False),
                }
        except Exception as e:
            print(f"[atm] Page {page} error: {e}")
            break
        page += 1
        time.sleep(SCRAPE_DELAY_SEC)

    _save_ids(found)
    n_data = sum(1 for v in found.values() if v["has_data"])
    print(f"[atm] Scan done: {len(found)} Warsaw schools, {n_data} with survey data")
    return found


# ── Name matching ─────────────────────────────────────────────────────────────

def _norm(name: str) -> str:
    s = str(name)
    s = re.sub(r"\([^)]*\)", " ", s)          # strip parenthesized address/city noise
    s = s.replace("ł", "l").replace("Ł", "l") # NFD doesn't decompose ł
    s = unicodedata.normalize("NFD", s).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"\bim\.?\b", "", s)
    s = re.sub(r"\bliceum\s+og[o]lnokszt[a-z]+\b", "", s)
    s = re.sub(r"\blo\b", "", s)
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


# Manual overrides: sw site_id → rspo (schools renamed/transformed/address-in-name)
_MANUAL_XWALK = {
    "101049": "481028",  # Autorskie LO Kultura i Nauka / LO Bułhaka → LO Niepubl. im. Janusza Korczaka
    "101859": "273209",  # Liceum Chocimska → Liceum Miodowa (dawna Chocimska)
    "101098": "270503",  # Dwujęzyczne LO Wyspa JP2 → LO Wyspa JP2 (extra "dwujezyczne" token lowers score)
    "101042": "31134",   # Akademickie LO Wyższej Szkoły Menedżerskiej → Akademii Finansów i Biznesu Vistula
}


def _match_ids_to_rspo(sw_ids: dict, rspo_df: pd.DataFrame) -> dict:
    """Returns {site_id: rspo_numer} crosswalk."""
    rspo_names  = rspo_df["nazwa"].tolist()
    rspo_ids    = rspo_df["numer_rspo"].tolist()
    rspo_normed = [_norm(n) for n in rspo_names]

    xwalk = {}
    unmatched = []
    for site_id, info in sw_ids.items():
        if not info.get("has_data"):
            continue
        # Apply manual override first
        if site_id in _MANUAL_XWALK:
            rspo = _MANUAL_XWALK[site_id]
            rspo_name = rspo_df.loc[rspo_df["numer_rspo"].astype(str) == rspo, "nazwa"]
            xwalk[site_id] = {"rspo": rspo, "score": 100,
                               "sw_name": info["name"],
                               "rspo_name": rspo_name.iloc[0] if len(rspo_name) else rspo}
            continue
        normed = _norm(info["name"])
        result = process.extractOne(normed, rspo_normed,
                                    scorer=fuzz.token_sort_ratio,
                                    score_cutoff=72)
        if result:
            idx = rspo_normed.index(result[0])
            xwalk[site_id] = {"rspo": str(rspo_ids[idx]), "score": result[1],
                               "sw_name": info["name"], "rspo_name": rspo_names[idx]}
        else:
            unmatched.append({"site_id": site_id, "sw_name": info["name"]})

    if unmatched:
        pd.DataFrame(unmatched).to_csv(MATCH_DIR / "unresolved_atmosfera.csv", index=False)

    print(f"[atm] Matched {len(xwalk)} schools | Unmatched {len(unmatched)}")
    return xwalk


# ── Page parsing ──────────────────────────────────────────────────────────────

def _fetch_page(site_id: str, session: requests.Session) -> str:
    cache_file = PAGE_CACHE / f"{site_id}.html"
    if cache_file.exists():
        return cache_file.read_text(encoding="utf-8")
    time.sleep(SCRAPE_DELAY_SEC)
    try:
        r = session.get(f"{BASE}/szkola/warszawa/{site_id}/", timeout=15, allow_redirects=True)
    except Exception as e:
        print(f"  [atm] FETCH_ERR site={site_id}: {type(e).__name__}")
        return ""
    if r.status_code != 200 or "/szkola/warszawa/" not in r.url:
        return ""
    cache_file.write_text(r.text, encoding="utf-8")
    return r.text


def _pct(text: str) -> Optional[float]:
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*%", text)
    return float(m.group(1).replace(",", ".")) if m else None


def _parse_school(html: str) -> dict:
    soup = BeautifulSoup(html, "lxml")
    data: dict = {}

    # Labeled metric blocks: <div><span>LABEL:</span><b>VALUE</b><font>%</font></div>
    # Use span label directly — gp_text contains all sibling metrics and poisons context
    for b in soup.find_all("b"):
        val_text = b.get_text().strip()
        if not re.search(r"^\d+(?:[.,]\d+)?$", val_text):
            continue
        parent = b.parent
        if not parent:
            continue
        span = parent.find("span")
        label_div = (parent.parent.find("div", class_="pxp-sp-kd-item-label")
                     if parent.parent else None)
        label = " ".join(filter(None, [
            span.get_text(" ", strip=True) if span else "",
            label_div.get_text(" ", strip=True) if label_div else "",
            parent.get_text(" ", strip=True) if not span and not label_div else "",
        ])).lower()

        pct_val = float(val_text.replace(",", "."))
        num = int(float(val_text.replace(",", ".")))

        if "matura" in label and "zdawaln" not in label:  data.setdefault("matura_proc", pct_val)
        elif "atmosfer" in label:                          data.setdefault("atmosfera_proc", pct_val)
        elif "przyjemno" in label:                         data.setdefault("przyjemnosc_nauki_proc", pct_val)
        elif "relacj" in label and "naucz" not in label:   data.setdefault("relacje_uczniow_proc", pct_val)
        elif "relacj" in label and "naucz" in label:       data.setdefault("relacja_nauczyciel_proc", pct_val)
        elif "nowoczesno" in label:                        data.setdefault("nowoczesnosc_zajec_proc", pct_val)
        elif "poleca" in label:                            data.setdefault("polecanie_szkoly_proc", pct_val)
        elif "odpoczynk" in label:                         data.setdefault("jakosc_odpoczynku_proc", pct_val)
        elif "zdawaln" in label:                           data.setdefault("zdawalnosc_matur_proc", pct_val)
        elif "liczba uczni" in label:                      data.setdefault("liczba_uczniow", num)

    # Survey count
    m = re.search(r"Ankiety[:\s]+(\d+)", html)
    if m:
        data["liczba_ankiet"] = int(m.group(1))

    # Average study time — HTML: <b>1</b><font> godz</font> <b>30</b><font> min</font>
    page_text = soup.get_text(" ")
    m = re.search(r"(\d+)\s*godz\w*\s*(\d+)\s*min", page_text, re.IGNORECASE)
    if m:
        data["czas_nauki_po_lekcjach_min"] = int(m.group(1)) * 60 + int(m.group(2))
    else:
        m = re.search(r"czas nauki[^\n]{0,40}?(\d+)\s*min", page_text, re.IGNORECASE)
        if m:
            data["czas_nauki_po_lekcjach_min"] = int(m.group(1))

    # Infrastructure flags from amenities list
    full_text = soup.get_text(" ").lower()
    flags = {
        "czy_strefa_ciszy":           ["strefa ciszy"],
        "czy_miejsce_odpoczynku":     ["miejsce odpoczynku", "kanapy"],
        "czy_ciche_dzwonki":          ["ciche dzwonki", "cichy dzwonek"],
        "czy_rozowa_skrzyneczka":     ["różowa skrzyneczka", "rozowa skrzyneczka"],
        "czy_szafki_uczniow":         ["szafki"],
        "czy_stojak_na_rowery":       ["stojak na rowery"],
        "czy_teren_zielony":          ["teren zielony"],
        "czy_otwarte_boiska":         ["otwarte boiska"],
        "czy_wifi_dla_uczniow":       ["wi-fi", "wifi"],
        "czy_sklepik_szkolny":        ["sklepik"],
        "czy_bufet_stolowka":         ["bufet", "stołówka", "stolowka"],
        "czy_psycholog_na_etacie":    ["psycholog"],
        "czy_pedagog_specjalny":      ["pedagog specjalny"],
        "czy_winda":                  ["winda"],
        "czy_podjazd_dla_wozkow":     ["podjazd"],
        "czy_monitoring":             ["monitoring"],
        "czy_pielegniarka":           ["pielęgniarka", "pielegniarka"],
        "czy_rzecznik_praw_ucznia":   ["rzecznik praw ucznia"],
        "czy_drukarka_dla_uczniow":   ["drukarka"],
        "czy_przystanek_mpk":         ["przystanek mpk", "przystanek komunikacji"],
        "czy_silownia":               ["siłownia", "silownia"],
    }
    for flag, keywords in flags.items():
        data[flag] = 1 if any(kw in full_text for kw in keywords) else 0

    return data


# ── Main ──────────────────────────────────────────────────────────────────────

def scrape_atmosfera(rspo_df: pd.DataFrame, engine: Engine) -> int:
    session = requests.Session()
    session.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    session.headers["Accept-Language"] = "pl-PL,pl;q=0.9"

    _login(session)

    sw_ids = _scan_ids(session)
    xwalk  = _match_ids_to_rspo(sw_ids, rspo_df)

    all_rows = []
    for site_id, match in xwalk.items():
        html = _fetch_page(site_id, session)
        if not html:
            print(f"  [atm] EMPTY {site_id}")
            continue
        parsed = _parse_school(html)
        parsed["rspo_szkoly"]  = match["rspo"]
        parsed["site_id"]      = site_id
        parsed["nazwa_szkoly"] = match["sw_name"]
        all_rows.append(parsed)
        n_fields = sum(1 for v in parsed.values() if v is not None and v != 0)
        print(f"  [atm] OK site={site_id} rspo={match['rspo']} score={match['score']:.0f} fields={n_fields}")

    COLS = [
        "rspo_szkoly", "site_id", "nazwa_szkoly",
        "matura_proc", "atmosfera_proc", "przyjemnosc_nauki_proc",
        "relacje_uczniow_proc", "relacja_nauczyciel_proc", "nowoczesnosc_zajec_proc",
        "polecanie_szkoly_proc", "jakosc_odpoczynku_proc",
        "czas_nauki_po_lekcjach_min", "liczba_ankiet",
        "liczba_uczniow", "zdawalnosc_matur_proc",
        "czy_strefa_ciszy", "czy_miejsce_odpoczynku", "czy_ciche_dzwonki",
        "czy_rozowa_skrzyneczka", "czy_szafki_uczniow", "czy_stojak_na_rowery",
        "czy_teren_zielony", "czy_otwarte_boiska", "czy_wifi_dla_uczniow",
        "czy_sklepik_szkolny", "czy_bufet_stolowka",
        "czy_psycholog_na_etacie", "czy_pedagog_specjalny",
        "czy_winda", "czy_podjazd_dla_wozkow", "czy_monitoring",
        "czy_pielegniarka", "czy_rzecznik_praw_ucznia",
        "czy_drukarka_dla_uczniow", "czy_przystanek_mpk", "czy_silownia",
    ]
    df = pd.DataFrame(all_rows) if all_rows else pd.DataFrame(columns=COLS)
    for col in COLS:
        if col not in df.columns:
            df[col] = None
    df = df[COLS]
    # Deduplicate: keep row with most non-null fields per RSPO
    if df.duplicated("rspo_szkoly").any():
        df["_n"] = df.notna().sum(axis=1)
        df = df.sort_values("_n", ascending=False).drop_duplicates("rspo_szkoly").drop(columns="_n")
        df = df.reset_index(drop=True)
    df.to_sql("stg_atmosfera", engine, if_exists="replace", index=False,
              method="multi", chunksize=500)
    print(f"[stg_atmosfera] {len(df)} rows loaded")
    return len(df)

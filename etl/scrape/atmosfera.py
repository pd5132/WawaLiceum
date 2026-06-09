"""
Atmosphere scraper — swiadomiewybieram.pl

URL pattern: https://swiadomiewybieram.pl/szkola/warszawa/<site_id>/
Site ID ≠ RSPO. Resolved by searching:
  https://swiadomiewybieram.pl/wyszukaj/?q=<name>&miasto=warszawa

Data written to stg_atmosfera (one row per school):
  rspo_szkoly, site_id, nazwa_szkoly,
  atmosfera_proc, przyjemnosc_nauki_proc, relacje_uczniow_proc,
  relacja_nauczyciel_proc, nowoczesnosc_zajec_proc, polecanie_szkoly_proc,
  jakosc_odpoczynku_proc, liczba_ankiet,
  + infra flags (czy_*)
"""
import re
import json
import time
import hashlib
from typing import Optional
import requests
from bs4 import BeautifulSoup
import pandas as pd
from sqlalchemy import Engine
from etl.config import CACHE_DIR, REQUEST_HEADERS, SCRAPE_DELAY_SEC, MATCH_DIR

BASE = "https://swiadomiewybieram.pl"
CACHE_DIR.mkdir(parents=True, exist_ok=True)


def _cache_key(url: str) -> str:
    return hashlib.md5(url.encode()).hexdigest()


def _fetch(url: str, session: requests.Session, delay: bool = True) -> str:
    cache_file = CACHE_DIR / (_cache_key(url) + ".html")
    if cache_file.exists():
        return cache_file.read_text(encoding="utf-8")
    if delay:
        time.sleep(SCRAPE_DELAY_SEC)
    resp = session.get(url, headers=REQUEST_HEADERS, timeout=30)
    resp.raise_for_status()
    text = resp.text
    cache_file.write_text(text, encoding="utf-8")
    return text


def _find_site_id(rspo: str, name: str, session: requests.Session) -> Optional[str]:
    q = name[:35].replace(" ", "+")
    url = f"{BASE}/wyszukaj/?q={requests.utils.quote(name[:35])}&miasto=warszawa"
    html = _fetch(url, session)
    soup = BeautifulSoup(html, "lxml")
    for a in soup.select("a[href*='/szkola/warszawa/']"):
        href = a.get("href", "")
        m = re.search(r"/szkola/warszawa/(\d+)", href)
        if m:
            return m.group(1)
    return None


def _parse_percent(text: str) -> Optional[float]:
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*%", text)
    if m:
        return float(m.group(1).replace(",", "."))
    return None


def _parse_school_page(html: str) -> dict:
    soup = BeautifulSoup(html, "lxml")
    data: dict = {}

    # Atmosphere percentages — look for labeled percentage blocks
    for el in soup.find_all(string=re.compile(r"\d+\s*%")):
        pct = _parse_percent(str(el))
        parent_text = el.parent.get_text(" ", strip=True).lower() if el.parent else ""
        if pct is None:
            continue
        if "atmosfer" in parent_text:            data.setdefault("atmosfera_proc", pct)
        elif "przyjemno" in parent_text:         data.setdefault("przyjemnosc_nauki_proc", pct)
        elif "relacj" in parent_text and "ucz" in parent_text: data.setdefault("relacje_uczniow_proc", pct)
        elif "relacj" in parent_text and "naucz" in parent_text: data.setdefault("relacja_nauczyciel_proc", pct)
        elif "nowoczesno" in parent_text:        data.setdefault("nowoczesnosc_zajec_proc", pct)
        elif "poleca" in parent_text:            data.setdefault("polecanie_szkoly_proc", pct)
        elif "odpoczynk" in parent_text:         data.setdefault("jakosc_odpoczynku_proc", pct)

    # Survey count
    m = re.search(r"(\d+)\s+ankiet", soup.get_text())
    if m:
        data["liczba_ankiet"] = int(m.group(1))

    # Infrastructure flags — look for yes/no markers near keywords
    full_text = soup.get_text(" ").lower()
    flag_keywords = {
        "czy_strefa_ciszy":           "strefa ciszy",
        "czy_miejsce_odpoczynku":     "miejsce odpoczynku",
        "czy_ciche_dzwonki":          "ciche dzwonki",
        "czy_rozowa_skrzyneczka":     "różowa skrzyneczka",
        "czy_szafki_uczniow":         "szafki",
        "czy_stojak_na_rowery":       "stojak na rowery",
        "czy_teren_zielony":          "teren zielony",
        "czy_otwarte_boiska":         "otwarte boiska",
        "czy_sklepik_szkolny":        "sklepik",
        "czy_bufet_stolowka":         "bufet",
        "czy_psycholog_na_etacie":    "psycholog",
        "czy_pedagog_specjalny":      "pedagog specjalny",
        "czy_winda":                  "winda",
        "czy_podjazd_dla_wozkow":     "podjazd",
        "czy_monitoring":             "monitoring",
    }
    for flag, kw in flag_keywords.items():
        # Simple heuristic: keyword present in page text
        data[flag] = 1 if kw in full_text else 0

    return data


def scrape_atmosfera(rspo_df: pd.DataFrame, engine: Engine) -> int:
    session = requests.Session()
    all_rows = []
    unresolved = []

    for _, row in rspo_df.iterrows():
        rspo = str(row["numer_rspo"])
        name = str(row.get("nazwa", ""))
        try:
            site_id = _find_site_id(rspo, name, session)
            if not site_id:
                print(f"  [atm] UNRESOLVED {rspo} — {name}")
                unresolved.append({"rspo": rspo, "nazwa": name, "reason": "site_id_not_found"})
                continue
            url = f"{BASE}/szkola/warszawa/{site_id}/"
            html = _fetch(url, session)
            parsed = _parse_school_page(html)
            parsed["rspo_szkoly"] = rspo
            parsed["site_id"]     = site_id
            parsed["nazwa_szkoly"] = name
            all_rows.append(parsed)
            print(f"  [atm] OK {rspo} site={site_id} — {len(parsed)} fields")
        except Exception as e:
            print(f"  [atm] ERROR {rspo} — {e}")
            unresolved.append({"rspo": rspo, "nazwa": name, "reason": str(e)})

    _ATM_COLS = ["rspo_szkoly", "site_id", "nazwa_szkoly",
                 "atmosfera_proc", "przyjemnosc_nauki_proc", "relacje_uczniow_proc",
                 "relacja_nauczyciel_proc", "nowoczesnosc_zajec_proc", "polecanie_szkoly_proc",
                 "jakosc_odpoczynku_proc", "liczba_ankiet",
                 "czy_strefa_ciszy", "czy_miejsce_odpoczynku", "czy_ciche_dzwonki",
                 "czy_rozowa_skrzyneczka", "czy_szafki_uczniow", "czy_stojak_na_rowery",
                 "czy_teren_zielony", "czy_otwarte_boiska", "czy_sklepik_szkolny",
                 "czy_bufet_stolowka", "czy_psycholog_na_etacie", "czy_pedagog_specjalny",
                 "czy_winda", "czy_podjazd_dla_wozkow", "czy_monitoring"]
    df = pd.DataFrame(all_rows) if all_rows else pd.DataFrame(columns=_ATM_COLS)
    df.to_sql("stg_atmosfera", engine, if_exists="replace", index=False, method="multi", chunksize=500)
    print(f"[stg_atmosfera] {len(df)} rows | {len(unresolved)} unresolved")

    if unresolved:
        pd.DataFrame(unresolved).to_csv(MATCH_DIR / "unresolved_atmosfera.csv", index=False)

    return len(df)

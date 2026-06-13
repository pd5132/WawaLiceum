"""
Scrape 2024/2025 recruitment thresholds from otouczelnie.pl.
Covers 97 Warsaw liceums — more complete than the existing 2024 PDF (88 schools).

Output: inserts rows into stg_progi (rok=2024) and ensures stg_school_xref
        has matching entries (source='progi') so 20_transform_facts.sql works.

Usage:
    from etl.scrape.progi_otouczelnie import scrape_progi_2024
    scrape_progi_2024(rspo_df, engine)
"""

import re
import time
import unicodedata

import pandas as pd
import requests
from bs4 import BeautifulSoup
from rapidfuzz import fuzz, process
from sqlalchemy import text
from sqlalchemy.engine import Engine

BASE     = "https://www.otouczelnie.pl"
LIST_URL = BASE + "/progi-punktowe/licea/miasto/453/Warszawa/2024-2025"
YEAR_SUFFIX = "-2024-2025"
DELAY    = 1.0  # seconds between requests
ROK      = 2024


# ── Name normalisation (same logic as atmosfera.py) ──────────────────────────

def _norm(name: str) -> str:
    s = str(name)
    s = re.sub(r"\([^)]*\)", " ", s)
    s = s.replace("ł", "l").replace("Ł", "l")
    s = unicodedata.normalize("NFD", s).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"\bim\.?\b", "", s)
    s = re.sub(r"\bliceum\s+og[o]lnokszt[a-z]+\b", "", s)
    s = re.sub(r"\blo\b", "", s)
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


# ── Listing page: extract school names + detail URL slugs ────────────────────

def _get_school_links(session: requests.Session) -> list[dict]:
    r = session.get(LIST_URL, timeout=15)
    soup = BeautifulSoup(r.text, "lxml")
    table = soup.find("table")
    schools = []
    for row in table.find_all("tr"):
        title_cell = next(
            (c for c in row.find_all("td") if "m_title" in (c.get("class") or [])),
            None,
        )
        if not title_cell:
            continue
        name_link = title_cell.find("a")
        if not name_link:
            continue
        name = name_link.get_text(strip=True)
        href = name_link.get("href", "")
        schools.append({"name": name, "href": href})
    return schools


# ── Per-school detail page: parse class table ─────────────────────────────────

def _parse_detail(html: str) -> list[dict]:
    soup = BeautifulSoup(html, "lxml")
    rows = []
    for table in soup.find_all("table"):
        headers = [th.get_text(strip=True).lower() for th in table.find_all("th")]
        if "próg" not in " ".join(headers) and "prog" not in " ".join(headers):
            continue
        for tr in table.find_all("tr")[1:]:
            cells = [td.get_text(" ", strip=True) for td in tr.find_all("td")]
            if len(cells) < 2:
                continue
            klasa_raw = cells[0]        # e.g. "Klasa 1A (humanistyczna)"
            prog_raw  = cells[1]        # e.g. "141.85"
            # symbol: "1A"
            m_sym = re.search(r"Klasa\s+(\S+)", klasa_raw, re.IGNORECASE)
            symbol = m_sym.group(1) if m_sym else klasa_raw.strip()
            # nazwa_oddzialu: content in parentheses if present
            m_naz = re.search(r"\(([^)]+)\)", klasa_raw)
            nazwa = m_naz.group(1).strip() if m_naz else None
            # prog value
            try:
                prog = float(prog_raw.replace(",", "."))
            except ValueError:
                continue
            rows.append({
                "symbol_oddzialu": symbol,
                "nazwa_oddzialu":  nazwa,
                "prog_min":        prog,
                "prog_max":        None,
            })
    return rows


# ── Main ──────────────────────────────────────────────────────────────────────

def scrape_progi_2024(rspo_df: pd.DataFrame, engine: Engine) -> int:
    session = requests.Session()
    session.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"

    print("[oto] Fetching school list...")
    schools = _get_school_links(session)
    print(f"[oto] Found {len(schools)} schools")

    # Build RSPO lookup
    rspo_df = rspo_df.copy()
    rspo_df["_norm"] = rspo_df["nazwa"].apply(_norm)
    rspo_lookup = dict(zip(rspo_df["_norm"], rspo_df["numer_rspo"].astype(str)))

    all_rows = []
    xref_rows = []    # (source_name, rspo) for stg_school_xref

    for school in schools:
        name  = school["name"]
        href  = school["href"]
        # Build year-specific URL
        detail_url = BASE + href.rstrip("/") + YEAR_SUFFIX
        time.sleep(DELAY)
        try:
            r = session.get(detail_url, timeout=15)
            if r.status_code != 200:
                print(f"  [oto] SKIP {name[:40]} status={r.status_code}")
                continue
        except Exception as e:
            print(f"  [oto] ERR {name[:40]}: {e}")
            continue

        profiles = _parse_detail(r.text)
        if not profiles:
            print(f"  [oto] NO_DATA {name[:40]}")
            continue

        # Fuzzy match to RSPO
        norm_name = _norm(name)
        match = process.extractOne(
            norm_name, rspo_lookup.keys(),
            scorer=fuzz.token_sort_ratio, score_cutoff=65
        )
        if not match:
            print(f"  [oto] NO_MATCH '{name[:40]}' (norm='{norm_name[:35]}')")
            continue

        rspo = rspo_lookup[match[0]]
        score = match[1]

        for p in profiles:
            all_rows.append({
                "rok":             ROK,
                "dzielnica":       None,
                "nazwa_szkoly":    name,
                "symbol_oddzialu": p["symbol_oddzialu"],
                "nazwa_oddzialu":  p["nazwa_oddzialu"],
                "prog_min":        p["prog_min"],
                "prog_max":        p["prog_max"],
            })

        xref_rows.append({"source_name": name, "rspo": rspo})
        print(f"  [oto] OK '{name[:45]}' rspo={rspo} score={score:.0f} profiles={len(profiles)}")

    print(f"\n[oto] Scraped {len(all_rows)} profile rows for {len(xref_rows)} schools")

    if not all_rows:
        print("[oto] Nothing to load.")
        return 0

    df = pd.DataFrame(all_rows)

    with engine.begin() as c:
        # Remove existing 2024 rows from stg_progi from this source
        # (keep PDF-sourced rows for schools NOT matched here, but since we want
        # the web source to be authoritative for 2024, delete all 2024 rows first)
        deleted = c.execute(text("DELETE FROM dbo.stg_progi WHERE rok = 2024")).rowcount
        print(f"[oto] Deleted {deleted} existing rok=2024 rows from stg_progi")

    # Insert new rows
    df.to_sql("stg_progi", engine, if_exists="append", index=False,
              method="multi", chunksize=500)
    print(f"[oto] Inserted {len(df)} rows into stg_progi")

    # Upsert stg_school_xref entries (source='progi')
    with engine.begin() as c:
        for entry in xref_rows:
            existing = c.execute(text("""
                SELECT COUNT(*) FROM dbo.stg_school_xref
                WHERE source = 'progi' AND source_name = :n
            """), {"n": entry["source_name"]}).scalar()
            if not existing:
                c.execute(text("""
                    INSERT INTO dbo.stg_school_xref (source, source_name, id_szkoly_rspo)
                    VALUES ('progi', :n, :r)
                """), {"n": entry["source_name"], "r": int(entry["rspo"])})

    print(f"[oto] stg_school_xref updated for {len(xref_rows)} schools")
    return len(df)

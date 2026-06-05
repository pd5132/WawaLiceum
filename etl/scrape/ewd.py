"""
EWD scraper — Edukacyjna Wartość Dodana per school.

Primary source: waszaedukacja.pl  (server-rendered HTML table)
  URL pattern: https://waszaedukacja.pl/ponadgimnazjalne/<slug>/ewd
  The slug is found via the school search page.

Data written to stg_ewd:
  rspo_szkoly, nazwa_szkoly, rok, typ_ewd,
  ewd_oszacowanie, ewd_upper, ewd_lower,
  egzamin_oszacowanie, egzamin_upper, egzamin_lower
"""
import json
import time
import hashlib
import requests
from bs4 import BeautifulSoup
import pandas as pd
from sqlalchemy import Engine
from etl.config import CACHE_DIR, REQUEST_HEADERS, SCRAPE_DELAY_SEC

SEARCH_URL   = "https://waszaedukacja.pl/wyszukaj/liceum/"
SCHOOL_BASE  = "https://waszaedukacja.pl"

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


def _find_slug(rspo: str, school_name: str, session: requests.Session) -> str | None:
    """Search waszaedukacja for a school by name and return its slug."""
    search_url = f"https://waszaedukacja.pl/wyszukaj/liceum/?q={requests.utils.quote(school_name[:30])}&miasto=Warszawa"
    html = _fetch(search_url, session)
    soup = BeautifulSoup(html, "lxml")
    # Results are <a href="/ponadgimnazjalne/..."> links
    for a in soup.select("a[href*='/ponadgimnazjalne/']"):
        href = a.get("href", "")
        if "warszawa" in href.lower() and rspo in href:
            return href.rstrip("/")
    # Fallback: just return first Warszawa result
    for a in soup.select("a[href*='/ponadgimnazjalne/']"):
        href = a.get("href", "")
        if "warszawa" in href.lower():
            return href.rstrip("/")
    return None


def _parse_ewd_table(html: str, rspo: str, school_name: str) -> list[dict]:
    soup = BeautifulSoup(html, "lxml")
    rows = []
    for table in soup.select("div.ewd table, table"):
        headers = [th.get_text(strip=True) for th in table.select("th")]
        if not any("rok" in h.lower() or "ewd" in h.lower() for h in headers):
            continue
        for tr in table.select("tr"):
            cells = [td.get_text(strip=True) for td in tr.select("td")]
            if len(cells) < 4:
                continue
            try:
                rows.append({
                    "rspo_szkoly":       rspo,
                    "nazwa_szkoly":      school_name,
                    "rok":               cells[0],
                    "typ_ewd":           cells[1] if len(cells) > 1 else "",
                    "ewd_oszacowanie":   cells[2] if len(cells) > 2 else "",
                    "ewd_upper":         cells[3] if len(cells) > 3 else "",
                    "ewd_lower":         cells[4] if len(cells) > 4 else "",
                    "egzamin_oszacowanie": cells[5] if len(cells) > 5 else "",
                    "egzamin_upper":     cells[6] if len(cells) > 6 else "",
                    "egzamin_lower":     cells[7] if len(cells) > 7 else "",
                })
            except Exception:
                continue
    return rows


def scrape_ewd(rspo_df: pd.DataFrame, engine: Engine) -> int:
    """
    rspo_df: DataFrame with columns numer_rspo, nazwa (from stg_rspo).
    Fetches EWD for each school and writes to stg_ewd.
    """
    session = requests.Session()
    all_rows = []
    unresolved = []

    for _, row in rspo_df.iterrows():
        rspo = str(row["numer_rspo"])
        name = str(row.get("nazwa", ""))
        try:
            slug = _find_slug(rspo, name, session)
            if not slug:
                print(f"  [ewd] UNRESOLVED {rspo} — {name}")
                unresolved.append({"rspo": rspo, "nazwa": name, "reason": "slug_not_found"})
                continue
            ewd_url = f"{SCHOOL_BASE}{slug}/ewd"
            html = _fetch(ewd_url, session)
            school_rows = _parse_ewd_table(html, rspo, name)
            if not school_rows:
                print(f"  [ewd] NO TABLE {rspo} — {name}")
                unresolved.append({"rspo": rspo, "nazwa": name, "reason": "no_table_parsed"})
            else:
                all_rows.extend(school_rows)
                print(f"  [ewd] OK {rspo} — {len(school_rows)} rows")
        except Exception as e:
            print(f"  [ewd] ERROR {rspo} — {e}")
            unresolved.append({"rspo": rspo, "nazwa": name, "reason": str(e)})

    df = pd.DataFrame(all_rows)
    df.to_sql("stg_ewd", engine, if_exists="replace", index=False, method="multi")
    print(f"[stg_ewd] {len(df)} rows | {len(unresolved)} unresolved")

    if unresolved:
        from etl.config import MATCH_DIR
        unrec = pd.DataFrame(unresolved)
        existing = MATCH_DIR / "unresolved_ewd.csv"
        unrec.to_csv(existing, index=False)

    return len(df)

"""
Scraper EWD z waszaedukacja.pl dla szkół bez danych w ewd.json.

Algorytm:
  1. Pobiera sitemap-licea.xml — pełna lista URL szkół
  2. Filtruje URL z "warszawa" → buduje indeks slug→URL
  3. Dla każdej szkoły bez EWD: dopasowuje fuzzy po tokenach nazwy
  4. Pobiera stronę /ewd i parsuje tabelę HTML
  5. Zapisuje nowe rekordy do ewd.json

Użycie:
    pip install requests beautifulsoup4
    python3 etl/fetch_ewd_waszaedukacja.py

Parametry (env):
    DRY_RUN=1  — tylko pokazuje dopasowania, nie modyfikuje ewd.json
    LIMIT=10   — ogranicza liczbę szkół (do testów)
    MIN_SCORE=2 — minimalna liczba wspólnych tokenów (domyślnie 2)
"""

import json
import os
import re
import sys
import time
import unicodedata
from pathlib import Path
from xml.etree import ElementTree

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Brakuje zależności. Uruchom: pip install requests beautifulsoup4")
    sys.exit(1)

ROOT         = Path(__file__).parent.parent
SCHOOLS_JSON = ROOT / "app/data/schools.json"
EWD_JSON     = ROOT / "app/data/ewd.json"

BASE_URL    = "https://waszaedukacja.pl"
SITEMAP_URL = BASE_URL + "/sitemap-licea.xml"

DRY_RUN   = os.environ.get("DRY_RUN", "0") == "1"
LIMIT     = int(os.environ.get("LIMIT", "9999"))
MIN_SCORE = int(os.environ.get("MIN_SCORE", "2"))

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": "Mozilla/5.0 WawaLiceumBot/1.0 (research)",
    "Accept-Language": "pl-PL,pl;q=0.9",
})

# Słowa do pominięcia przy dopasowaniu
STOP_WORDS = {
    "liceum", "ogolnoksztalcace", "ogolnoksztalcące", "im", "nr",
    "warszawie", "warszawa", "w", "i", "z", "na",
}


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def remove_diacritics(text):
    return "".join(
        c for c in unicodedata.normalize("NFD", text)
        if unicodedata.category(c) != "Mn"
    )


def slugify(text):
    """Zamień tekst na slug (małe litery, bez diakrytyk, tokeny)."""
    text = remove_diacritics(text.lower())
    return set(re.findall(r"[a-z0-9]+", text)) - STOP_WORDS


def load_sitemap_index():
    """Pobiera sitemap i zwraca listę (slug_set, base_url) dla szkół z Warszawy."""
    print("Pobieranie sitemap...")
    r = SESSION.get(SITEMAP_URL, timeout=30)
    r.raise_for_status()

    ns = "http://www.sitemaps.org/schemas/sitemap/0.9"
    tree = ElementTree.fromstring(r.content)
    urls = [el.text for el in tree.findall(f".//{{{ns}}}loc")]

    # Tylko base URLs (bez podstron /matury, /ewd itd.) z "warszawa" w URL
    warsaw_urls = {}
    for url in urls:
        path = url.replace(BASE_URL, "")
        parts = path.strip("/").split("/")
        if len(parts) == 2 and parts[0] == "ponadgimnazjalne" and "warszawa" in parts[1]:
            slug = parts[1]
            if slug not in warsaw_urls:
                warsaw_urls[slug] = url

    print(f"Znaleziono {len(warsaw_urls)} szkół z Warszawy w sitemap")
    # Build (token_set, url) list
    index = []
    for slug, url in warsaw_urls.items():
        tokens = slugify(slug)
        index.append((tokens, url, slug))
    return index


def best_match(school_tokens, index, min_score):
    """Znajdź najlepsze dopasowanie URL dla danej szkoły."""
    best_score = 0
    best_url = None
    best_slug = None

    for (idx_tokens, url, slug) in index:
        score = len(school_tokens & idx_tokens)
        if score > best_score:
            best_score = score
            best_url = url
            best_slug = slug

    if best_score >= min_score:
        return best_url, best_slug, best_score
    return None, None, 0


def parse_ewd_table(soup):
    """
    Parsuje tabelę EWD z waszaedukacja.pl.

    Struktura tabeli:
      Header: [Przedmiot, Wskaźnik, górna granica, oszacowanie pkt, dolna granica]
      Wiersz EWD:   [przedmiot, "Wskaźnik EWD", upper, point_est, lower]  — 5 komórek
      Wiersz egz:   ["Wskaźnik egzaminu", upper, point_est, lower]         — 4 komórki
    """
    records = []
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if len(rows) < 2:
            continue
        header_cells = [td.get_text(strip=True).lower() for td in rows[0].find_all(["th", "td"])]
        if not any(k in " ".join(header_cells) for k in ("wskaź", "oszacowanie", "ewd")):
            continue

        current_subject = None
        for row in rows[1:]:
            cells = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
            if not cells:
                continue

            if len(cells) == 5:
                # Nowy przedmiot — wiersz EWD
                current_subject = cells[0]
                indicator = cells[1].lower()
                if "ewd" in indicator:
                    try:
                        records.append({
                            "nazwa_egzaminu": current_subject,
                            "ewd_upper": float(cells[2].replace(",", ".")),
                            "ewd_oszacowanie_punktowe": float(cells[3].replace(",", ".")),
                            "ewd_lower": float(cells[4].replace(",", ".")),
                            "egzamin_upper": None,
                            "egzamin_oszacowanie": None,
                            "egzamin_lower": None,
                            "rodzaj_zapisu": "scraped_waszaedukacja",
                        })
                    except (ValueError, IndexError):
                        pass

            elif len(cells) == 4 and current_subject and records:
                # Kontynuacja — wiersz egzaminu dla bieżącego przedmiotu
                indicator = cells[0].lower()
                if "egzamin" in indicator:
                    try:
                        records[-1]["egzamin_upper"] = float(cells[1].replace(",", "."))
                        records[-1]["egzamin_oszacowanie"] = float(cells[2].replace(",", "."))
                        records[-1]["egzamin_lower"] = float(cells[3].replace(",", "."))
                    except (ValueError, IndexError):
                        pass

        if records:
            break  # Pierwsza pasująca tabela wystarczy

    return records


def find_year(soup, page_text):
    """Wyciągnij rok danych EWD ze strony (jeśli dostępny)."""
    # Szukaj "EWD 2024" lub "rok szkolny 2023/2024" itp.
    m = re.search(r"EWD\s+(20\d\d)", page_text)
    if m:
        return int(m.group(1))
    m = re.search(r"matura\s+(20\d\d)", page_text, re.IGNORECASE)
    if m:
        return int(m.group(1))
    m = re.search(r"rok\s+szkolny\s+20\d\d/(20\d\d)", page_text, re.IGNORECASE)
    if m:
        return int(m.group(1))
    # Fallback: najnowszy rok w tekście
    years = [int(y) for y in re.findall(r"\b(202[0-9])\b", page_text)]
    if years:
        return max(years)
    return 2024  # domyślny fallback


def fetch_ewd(base_url):
    """Pobierz i sparsuj dane EWD. Zwraca listę rekordów."""
    ewd_url = base_url.rstrip("/") + "/ewd"
    try:
        r = SESSION.get(ewd_url, timeout=12)
        r.raise_for_status()
    except Exception as e:
        print(f"  [błąd HTTP] {ewd_url}: {e}")
        return []

    soup = BeautifulSoup(r.text, "html.parser")
    page_text = soup.get_text()
    rok = find_year(soup, page_text)

    records = parse_ewd_table(soup)
    for rec in records:
        rec["rok_kalendarzowy"] = rok

    return records


def main():
    schools = load_json(SCHOOLS_JSON)
    ewd_data = load_json(EWD_JSON)

    schools_with_ewd = set(e["id_szkoly_rspo"] for e in ewd_data)
    missing = [s for s in schools if s["id"] not in schools_with_ewd]

    print(f"Szkół bez EWD: {len(missing)} / {len(schools)}")

    # Pobierz indeks z sitemap
    index = load_sitemap_index()

    if DRY_RUN:
        print("\n[DRY RUN] Sprawdzam dopasowania:\n")
        for school in missing[:30]:
            tokens = slugify(school["nazwa"])
            url, slug, score = best_match(tokens, index, MIN_SCORE)
            status = f"✓ score={score} → {slug}" if url else "✗ brak dopasowania"
            print(f"  {school['id']}: {school['nazwa'][:60]}")
            print(f"    {status}")
        return

    new_records = []
    found = 0
    not_found = 0

    for i, school in enumerate(missing[:LIMIT]):
        sid = school["id"]
        nazwa = school["nazwa"]
        print(f"[{i+1}/{min(len(missing), LIMIT)}] {sid}: {nazwa}")

        tokens = slugify(nazwa)
        url, slug, score = best_match(tokens, index, MIN_SCORE)

        if not url:
            print(f"  → brak dopasowania w sitemap")
            not_found += 1
            continue

        print(f"  → {slug} (score={score})")

        records = fetch_ewd(url)
        if not records:
            print(f"  → brak danych EWD na stronie")
            not_found += 1
        else:
            for rec in records:
                rec["id_szkoly_rspo"] = sid
            new_records.extend(records)
            found += 1
            print(f"  → {len(records)} rekordów EWD (rok={records[0].get('rok_kalendarzowy')})")

        time.sleep(0.8)

    if new_records:
        ewd_data.extend(new_records)
        save_json(EWD_JSON, ewd_data)
        print(f"\nZapisano {len(new_records)} nowych rekordów EWD do {EWD_JSON}")
    else:
        print("\nBrak nowych rekordów do zapisania.")

    print(f"\nPodsumowanie: znaleziono={found}, nie znaleziono={not_found}")
    remaining = set(e["id_szkoly_rspo"] for e in ewd_data)
    still_missing = [s for s in schools if s["id"] not in remaining]
    print(f"Szkół nadal bez EWD: {len(still_missing)}")
    for s in still_missing:
        print(f"  {s['id']}: {s['nazwa']}")


if __name__ == "__main__":
    main()

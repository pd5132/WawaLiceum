"""
Scraper planów naboru 2026 ze stron szkół (zakładka Rekrutacja).

Użycie:
    pip install requests beautifulsoup4
    python3 etl/fetch_rekrutacja_2026.py

Wynik: app/data/rekrutacja_2026.json
    {
      "<id_szkoly>": [
        {"symbol": "1a", "nazwa_profilu": "mat-inf (ang-niem)", "jezyki": ["Angielski", "Niemiecki"], "miejsca": 30}
      ]
    }

Fallback: jeśli strona szkoły niedostępna lub brak danych 2026,
rekord jest pomijany — app.js używa wtedy plan_naboru.json.
"""

import json
import re
import time
from pathlib import Path
from urllib.parse import urljoin, urlparse

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("Brakuje requests/beautifulsoup4. Uruchom: pip install requests beautifulsoup4")
    import sys
    sys.exit(1)

ROOT         = Path(__file__).parent.parent
SCHOOLS_JSON = ROOT / "app/data/schools.json"
OUTPUT_JSON  = ROOT / "app/data/rekrutacja_2026.json"

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": "Mozilla/5.0 WawaLiceumBot/1.0 (research)",
    "Accept-Language": "pl-PL,pl;q=0.9",
})

REKRUTACJA_PATHS = [
    "/rekrutacja",
    "/rekrutacja-2026",
    "/oferta",
    "/oferta-2026",
    "/kandydaci",
    "/dla-kandydatow",
]

JEZYK_MAP = {
    "angielski": "Angielski", "ang": "Angielski",
    "niemiecki": "Niemiecki", "niem": "Niemiecki",
    "francuski": "Francuski", "franc": "Francuski",
    "hiszpański": "Hiszpański", "hisz": "Hiszpański", "hiszp": "Hiszpański",
    "włoski": "Włoski", "wł": "Włoski",
    "rosyjski": "Rosyjski", "ros": "Rosyjski",
    "arabski": "Arabski", "arab": "Arabski",
}

def normalize_url(url):
    if not url:
        return None
    url = url.strip()
    if not url.startswith("http"):
        url = "https://" + url
    return url.rstrip("/")


def find_rekrutacja_page(base_url):
    """Próbuje znaleźć stronę rekrutacji na stronie szkoły."""
    for path in REKRUTACJA_PATHS:
        url = base_url + path
        try:
            r = SESSION.get(url, timeout=8, allow_redirects=True)
            if r.status_code == 200 and len(r.text) > 500:
                # Sprawdź czy strona zawiera słowo 2026 lub "rekrutacja"
                text_lower = r.text.lower()
                if "2026" in text_lower or "rekrutacj" in text_lower or "oddział" in text_lower:
                    return url, r.text
        except Exception:
            pass
        time.sleep(0.2)

    # Fallback: szukaj linku na głównej stronie
    try:
        r = SESSION.get(base_url, timeout=8)
        if r.status_code == 200:
            soup = BeautifulSoup(r.text, "html.parser")
            for a in soup.find_all("a", href=True):
                href = a["href"].lower()
                text = a.get_text(strip=True).lower()
                if any(k in href or k in text for k in ["rekrutacj", "kandydat", "2026", "oferta"]):
                    full_url = urljoin(base_url, a["href"])
                    try:
                        r2 = SESSION.get(full_url, timeout=8)
                        if r2.status_code == 200:
                            return full_url, r2.text
                    except Exception:
                        pass
    except Exception:
        pass

    return None, None


def extract_profiles(html, school_name):
    """Wyciąga profile klas z HTML strony rekrutacji."""
    soup = BeautifulSoup(html, "html.parser")
    profiles = []

    # Szukaj tabel z profilami
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if len(rows) < 2:
            continue
        headers = [th.get_text(strip=True).lower() for th in rows[0].find_all(["th", "td"])]
        if not any(k in " ".join(headers) for k in ["profil", "oddział", "klasa", "kierunek"]):
            continue

        for row in rows[1:]:
            cells = [td.get_text(strip=True) for td in row.find_all(["td", "th"])]
            if len(cells) < 2:
                continue

            # Heurystycznie wyciągnij symbol, profil, miejsca
            symbol = ""
            profil = ""
            miejsca = None
            jezyki = []

            for cell in cells:
                # Symbol klasy np. "1a", "1A", "1B/2"
                if re.match(r"^[12][a-zA-Z/\d]{0,4}$", cell) and not symbol:
                    symbol = cell
                # Liczba miejsc
                elif re.match(r"^\d{1,3}$", cell) and 10 <= int(cell) <= 50:
                    miejsca = int(cell)
                # Profil — dłuższy tekst
                elif len(cell) > 5 and not profil:
                    profil = cell

            if not profil:
                continue

            # Wyciągnij języki z profilu
            jezyki = extract_languages(profil)

            profiles.append({
                "symbol": symbol,
                "nazwa_profilu": profil,
                "jezyki": jezyki,
                "miejsca": miejsca,
            })

    if profiles:
        return profiles

    # Fallback: szukaj list/paragrafów
    for el in soup.find_all(["li", "p", "div"]):
        text = el.get_text(strip=True)
        # Wzorzec: "1a – profil matematyczno-fizyczny (30 miejsc)"
        m = re.match(r"([12][a-zA-Z]{0,2})\s*[-–]\s*(.+?)(?:\((\d+)\s*miejsc)?$", text)
        if m:
            symbol = m.group(1)
            profil = m.group(2).strip()
            miejsca = int(m.group(3)) if m.group(3) else None
            profiles.append({
                "symbol": symbol,
                "nazwa_profilu": profil,
                "jezyki": extract_languages(profil),
                "miejsca": miejsca,
            })

    return profiles


def extract_languages(text):
    """Wyciąga języki z tekstu profilu."""
    text_lower = text.lower()
    found = []
    for key, label in JEZYK_MAP.items():
        if key in text_lower and label not in found:
            found.append(label)
    return found


def main():
    with open(SCHOOLS_JSON, encoding="utf-8") as f:
        schools = json.load(f)

    # Załaduj istniejące dane
    if OUTPUT_JSON.exists():
        with open(OUTPUT_JSON, encoding="utf-8") as f:
            results = json.load(f)
    else:
        results = {}

    total = len(schools)
    found_count = 0
    error_count = 0

    for i, s in enumerate(schools):
        sid = str(s["id"])
        if sid in results:
            print(f"[{i+1}/{total}] {s['id']} — pomiń (już w cache)")
            continue

        base_url = normalize_url(s.get("strona_www", ""))
        nazwa = s.get("nazwa", "")
        print(f"[{i+1}/{total}] {s['id']}: {nazwa[:60]}")

        if not base_url:
            print("  → brak URL szkoły")
            error_count += 1
            results[sid] = []
            continue

        rek_url, html = find_rekrutacja_page(base_url)
        if not html:
            print(f"  → nie znaleziono strony rekrutacji ({base_url})")
            error_count += 1
            results[sid] = []
            time.sleep(0.5)
            continue

        profiles = extract_profiles(html, nazwa)
        if profiles:
            print(f"  → {rek_url}: {len(profiles)} profili")
            found_count += 1
        else:
            print(f"  → {rek_url}: nie wyciągnięto profili")
            error_count += 1

        results[sid] = profiles
        time.sleep(1.0)

    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\nZapisano {OUTPUT_JSON}")
    print(f"Znaleziono profile: {found_count}, błąd/brak: {error_count}")


if __name__ == "__main__":
    main()

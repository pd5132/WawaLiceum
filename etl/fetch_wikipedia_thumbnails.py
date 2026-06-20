"""
Pobiera miniatury zdjęć budynków szkół z Wikipedii.

Użycie:
    pip install requests
    python3 etl/fetch_wikipedia_thumbnails.py

Wynik: app/data/school_images.json — {id_szkoly: url_miniaturki}

Algorytm:
    1. Buduje warianty tytułów Wikipedia dla każdej szkoły
    2. Odpytuje API w partiach po 50 tytułów (limity API)
    3. Mapuje trafione tytuły z powrotem na ID szkół
"""

import json
import re
import time
from pathlib import Path

try:
    import requests
except ImportError:
    print("Brakuje requests. Uruchom: pip install requests")
    import sys
    sys.exit(1)

ROOT         = Path(__file__).parent.parent
SCHOOLS_JSON = ROOT / "app/data/schools.json"
OUTPUT_JSON  = ROOT / "app/data/school_images.json"

WIKI_API   = "https://pl.wikipedia.org/w/api.php"
THUMB_SIZE = 200
BATCH_SIZE = 50  # Wikipedia API limit per request

SESSION = requests.Session()
SESSION.headers.update({"User-Agent": "WawaLiceumBot/1.0 (research)"})


def clean_patron(raw):
    raw = re.sub(r"\s+W\s+WARSZAWIE\s*$", "", raw, flags=re.IGNORECASE).strip()
    raw = re.sub(r"\s+W\s+WARSAW\s*$", "", raw, flags=re.IGNORECASE).strip()
    return raw.title()


def title_variants(nazwa):
    """Generuje warianty tytułu artykułu Wikipedii dla danej szkoły."""
    variants = []

    m = re.match(r"([IVXLCM\d]+)\s+LICEUM\s+\S+\s+IM\.\s+(.+)", nazwa)
    if m:
        num = m.group(1)
        patron = clean_patron(m.group(2))
        variants.append(f"{num} Liceum Ogólnokształcące im. {patron} w Warszawie")
        variants.append(f"{num} Liceum Ogólnokształcące im. {patron}")

    m2 = re.search(r"\bIM\.\s+(.+)", nazwa)
    if m2:
        patron = clean_patron(m2.group(1))
        v = f"Liceum im. {patron} w Warszawie"
        if v not in variants:
            variants.append(v)

    # Fallback: title-cased full name
    v_fallback = nazwa.title()
    if v_fallback not in variants:
        variants.append(v_fallback)

    return variants


def batch_query(titles):
    """
    Odpytuje Wikipedia API dla listy tytułów (max BATCH_SIZE).
    Zwraca dict {normalized_title_lower: thumbnail_url}.
    """
    params = {
        "action": "query",
        "titles": "|".join(titles),
        "prop": "pageimages",
        "pithumbsize": THUMB_SIZE,
        "format": "json",
        "redirects": 1,
    }
    try:
        r = SESSION.get(WIKI_API, params=params, timeout=15)
        if r.status_code == 429:
            print("  [429] Rate limited — czekam 30s")
            time.sleep(30)
            r = SESSION.get(WIKI_API, params=params, timeout=15)
        r.raise_for_status()
        data = r.json()
    except Exception as e:
        print(f"  [błąd batch] {e}")
        return {}

    result = {}
    query = data.get("query", {})

    redirects = {}
    for rd in query.get("redirects", []):
        redirects[rd["from"].lower()] = rd["to"].lower()

    pages = query.get("pages", {})
    for page in pages.values():
        if page.get("pageid", -1) == -1:
            continue
        title = page.get("title", "").lower()
        thumb = page.get("thumbnail", {})
        if thumb:
            url = thumb.get("source")
            result[title] = url
            for src, dst in redirects.items():
                if dst == title:
                    result[src] = url

    return result


def search_thumbnail(query_text):
    """
    Wikipedia full-text search → zwraca URL miniatury pierwszego trafienia lub None.
    Używane jako fallback gdy patron nie ma diakrytyk.
    """
    params = {
        "action": "query",
        "list": "search",
        "srsearch": query_text,
        "srlimit": 1,
        "srprop": "",
        "format": "json",
    }
    try:
        r = SESSION.get(WIKI_API, params=params, timeout=10)
        if r.status_code == 429:
            time.sleep(30)
            r = SESSION.get(WIKI_API, params=params, timeout=10)
        r.raise_for_status()
        data = r.json()
        results = data.get("query", {}).get("search", [])
        if not results:
            return None
        found_title = results[0]["title"]
    except Exception:
        return None

    # Pobierz miniaturę dla znalezionego tytułu
    params2 = {
        "action": "query",
        "titles": found_title,
        "prop": "pageimages",
        "pithumbsize": THUMB_SIZE,
        "format": "json",
        "redirects": 1,
    }
    try:
        r2 = SESSION.get(WIKI_API, params=params2, timeout=10)
        r2.raise_for_status()
        data2 = r2.json()
        pages = data2.get("query", {}).get("pages", {})
        for page in pages.values():
            if page.get("pageid", -1) != -1:
                thumb = page.get("thumbnail", {})
                if thumb:
                    return thumb.get("source")
    except Exception:
        pass
    return None


def make_search_query(nazwa):
    """Zbuduj zapytanie tekstowe do Wikipedia search dla numbered liceum."""
    m = re.match(r"([IVXLCM\d]+)\s+LICEUM", nazwa)
    num = m.group(1) if m else None

    m2 = re.search(r"\bIM\.\s+(\S+(?:\s+\S+)?)", nazwa)
    patron_words = m2.group(1) if m2 else ""
    # Bierz tylko pierwsze 2 słowa patrona (odcinamy sufiks "W WARSZAWIE")
    patron_words = " ".join(w for w in patron_words.split()
                            if w.upper() not in ("W", "WARSZAWIE"))[:30]

    if num and patron_words:
        return f"{num} liceum {patron_words} warszawa"
    return None


def main():
    with open(SCHOOLS_JSON, encoding="utf-8") as f:
        schools = json.load(f)

    if OUTPUT_JSON.exists():
        with open(OUTPUT_JSON, encoding="utf-8") as f:
            existing = json.load(f)
    else:
        existing = {}

    results = {str(k): v for k, v in existing.items()}

    # Szkoły bez cache (lub z null)
    todo = [s for s in schools if not results.get(str(s["id"]))]
    print(f"Szkoły do sprawdzenia: {len(todo)}/{len(schools)}")

    # Zbuduj mapę: variant_lower → [sid, ...]
    # variant_lower → (original_cased_title, [sid, ...])
    variant_map = {}
    sid_to_variants = {}
    for s in todo:
        sid = s["id"]
        variants = title_variants(s["nazwa"])
        sid_to_variants[sid] = [v.lower() for v in variants]
        for v in variants:
            key = v.lower()
            if key not in variant_map:
                variant_map[key] = (v, [])
            variant_map[key][1].append(sid)

    # Send properly-cased titles to Wikipedia
    all_cased = [cased for (cased, _) in variant_map.values()]
    print(f"Łącznie wariantów tytułów: {len(all_cased)}")

    found_urls = {}  # title_lower → url

    # Odpytaj w partiach
    for i in range(0, len(all_cased), BATCH_SIZE):
        batch = all_cased[i:i + BATCH_SIZE]
        print(f"  Batch {i//BATCH_SIZE + 1}/{(len(all_cased)-1)//BATCH_SIZE + 1} ({len(batch)} tytułów)...", end=" ", flush=True)
        hits = batch_query(batch)
        found_urls.update(hits)
        print(f"{len(hits)} trafień")
        time.sleep(1.0)

    # Mapuj wyniki (pass 1: exact title batch)
    new_found = 0
    unresolved = []
    for s in todo:
        sid = s["id"]
        url = None
        for key in sid_to_variants.get(sid, []):
            if key in found_urls:
                url = found_urls[key]
                new_found += 1
                break
        if url:
            print(f"  ✓ {sid}: {s['nazwa'][:55]}")
            print(f"      → {url[:80]}")
        else:
            unresolved.append(s)
        results[str(sid)] = url

    # Pass 2: Wikipedia full-text search dla unresolved numbered liceum
    numbered = [s for s in unresolved if re.match(r"[IVXLCM\d]+\s+LICEUM", s["nazwa"]) and "IM." in s["nazwa"]]
    print(f"\nPass 2 — search dla {len(numbered)} numerowanych liceum bez miniaturki...")
    for s in numbered:
        sid = s["id"]
        qtext = make_search_query(s["nazwa"])
        if not qtext:
            continue
        url = search_thumbnail(qtext)
        if url:
            results[str(sid)] = url
            new_found += 1
            print(f"  ✓ {sid}: {s['nazwa'][:55]}")
            print(f"      → {url[:80]}")
        else:
            print(f"  ✗ {sid}: {s['nazwa'][:55]}")
        time.sleep(1.0)

    still_missing = [s for s in unresolved if not results.get(str(s["id"]))]
    for s in still_missing:
        print(f"  ✗ {s['id']}: {s['nazwa'][:55]}")

    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    total_found = sum(1 for v in results.values() if v)
    print(f"\nZapisano {OUTPUT_JSON}")
    print(f"Z miniaturką: {total_found}/{len(results)} (nowe: {new_found})")


if __name__ == "__main__":
    main()

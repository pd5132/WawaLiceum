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
import unicodedata
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


WIKI_CATEGORY = "Kategoria:Licea ogólnokształcące w Warszawie"
STOP_WORDS_MATCH = {"liceum", "ogolnoksztalcace", "im", "nr", "warszawie", "warszawa",
                    "w", "i", "z", "na", "gen", "plk", "dr", "sw", "bl", "ks", "prof"}


def remove_diacritics(text):
    return "".join(
        c for c in unicodedata.normalize("NFD", text)
        if unicodedata.category(c) != "Mn"
    )


def slug_tokens(text):
    text = remove_diacritics(text.lower())
    return set(re.findall(r"[a-z0-9]+", text)) - STOP_WORDS_MATCH


def fetch_category_thumbnails():
    """
    Pobiera tytuły + miniatury wszystkich artykułów z kategorii Warsaw liceum.
    Zwraca dict {title_lower: thumbnail_url}.
    """
    # Krok 1: lista artykułów z kategorii
    titles = []
    cont = {}
    while True:
        params = {
            "action": "query",
            "list": "categorymembers",
            "cmtitle": WIKI_CATEGORY,
            "cmlimit": 500,
            "format": "json",
        }
        params.update(cont)
        try:
            r = SESSION.get(WIKI_API, params=params, timeout=15)
            r.raise_for_status()
            d = r.json()
        except Exception as e:
            print(f"  [błąd kategorii] {e}")
            break
        for m in d.get("query", {}).get("categorymembers", []):
            if m["ns"] == 0:  # tylko artykuły, nie podkategorie
                titles.append(m["title"])
        if "continue" not in d:
            break
        cont = d["continue"]

    print(f"  Znaleziono {len(titles)} artykułów w kategorii Wikipedia")

    # Krok 2: batch pageimages dla wszystkich
    result = {}
    for i in range(0, len(titles), BATCH_SIZE):
        batch = titles[i:i + BATCH_SIZE]
        hits = batch_query(batch)
        result.update(hits)
        time.sleep(0.5)

    return result


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

    # Pass 2: fuzzy match przez kategorię Wikipedia (Warsaw liceum)
    print(f"\nPass 2 — kategoria Wikipedia → fuzzy match {len(unresolved)} nierozwiązanych...")
    cat_urls = fetch_category_thumbnails()

    # Zbuduj indeks: token_set → (title_lower, url) dla artykułów z miniaturą
    cat_index = []
    for title_lower, url in cat_urls.items():
        tokens = slug_tokens(title_lower)
        cat_index.append((tokens, title_lower, url))

    for s in unresolved:
        sid = s["id"]
        school_tokens = slug_tokens(s["nazwa"])
        best_score, best_url = 0, None
        for (cat_tokens, cat_title, cat_url) in cat_index:
            score = len(school_tokens & cat_tokens)
            if score > best_score:
                best_score = score
                best_url = cat_url

        if best_url and best_score >= 2:
            results[str(sid)] = best_url
            new_found += 1
            print(f"  ✓ {sid} (score={best_score}): {s['nazwa'][:55]}")
            print(f"      → {best_url[:80]}")
        else:
            print(f"  ✗ {sid}: {s['nazwa'][:55]}")

    still_missing = [s for s in unresolved if not results.get(str(s["id"]))]
    print(f"Bez miniaturki: {len(still_missing)}")

    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    total_found = sum(1 for v in results.values() if v)
    print(f"\nZapisano {OUTPUT_JSON}")
    print(f"Z miniaturką: {total_found}/{len(results)} (nowe: {new_found})")


if __name__ == "__main__":
    main()

"""
Walidator URL-i szkół z schools.json.

Użycie:
    pip install requests
    python3 etl/check_urls.py [--fix]

Opcje:
    --fix   Automatycznie popraw typowe błędy (brak protokołu https://)
            i zapisz do schools.json

Wyjście:
    url_report.csv — raport statusów URL
"""

import csv
import json
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

try:
    import requests
except ImportError:
    print("Brakuje requests. Uruchom: pip install requests")
    sys.exit(1)

ROOT = Path(__file__).parent.parent
SCHOOLS_JSON = ROOT / "app/data/schools.json"
REPORT_CSV   = ROOT / "etl/url_report.csv"

FIX_MODE = "--fix" in sys.argv

SESSION = requests.Session()
SESSION.headers.update({
    "User-Agent": "Mozilla/5.0 WawaLiceumBot/1.0",
})


def normalize_url(url):
    """Dodaj https:// jeśli brak protokołu."""
    if not url:
        return None
    url = url.strip()
    if not url:
        return None
    parsed = urlparse(url)
    if not parsed.scheme:
        return "https://" + url
    return url


def check_url(url):
    """Sprawdź URL. Zwraca (status_code, final_url, error)."""
    normalized = normalize_url(url)
    if not normalized:
        return None, None, "brak URL"
    try:
        r = SESSION.head(normalized, timeout=8, allow_redirects=True)
        return r.status_code, r.url, None
    except requests.exceptions.SSLError:
        try:
            http = normalized.replace("https://", "http://")
            r = SESSION.head(http, timeout=8, allow_redirects=True)
            return r.status_code, r.url, "SSL_fallback_to_http"
        except Exception as e:
            return None, None, str(e)
    except Exception as e:
        return None, None, str(e)


def main():
    with open(SCHOOLS_JSON, encoding="utf-8") as f:
        schools = json.load(f)

    results = []
    modified = False

    for i, s in enumerate(schools):
        sid = s["id"]
        nazwa = s.get("nazwa", "")
        url_raw = s.get("strona_www", "")

        if not url_raw:
            results.append({
                "id": sid, "nazwa": nazwa, "url_stary": "",
                "status_code": "", "url_finalny": "", "uwagi": "brak URL w bazie",
            })
            continue

        url_norm = normalize_url(url_raw)
        status, final_url, err = check_url(url_raw)
        uwagi = err or ""

        # Automatyczna naprawa: brak protokołu
        if FIX_MODE and url_raw and not url_raw.startswith("http") and status and status < 400:
            s["strona_www"] = url_norm
            uwagi = f"NAPRAWIONO: dodano protokół https://"
            modified = True

        print(f"[{i+1}/{len(schools)}] {sid} {status or 'ERR'} {url_raw}")

        results.append({
            "id": sid,
            "nazwa": nazwa,
            "url_stary": url_raw,
            "status_code": status or "",
            "url_finalny": final_url or "",
            "uwagi": uwagi,
        })
        time.sleep(0.3)

    # Zapis raportu CSV
    with open(REPORT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["id","nazwa","url_stary","status_code","url_finalny","uwagi"])
        writer.writeheader()
        writer.writerows(results)

    print(f"\nRaport: {REPORT_CSV}")

    # Podsumowanie
    ok    = [r for r in results if isinstance(r["status_code"], int) and r["status_code"] < 400]
    err   = [r for r in results if not r["status_code"] or (isinstance(r["status_code"], int) and r["status_code"] >= 400)]
    empty = [r for r in results if not r["url_stary"]]

    print(f"OK (<400): {len(ok)}")
    print(f"Błąd/Timeout: {len(err)}")
    print(f"Brak URL: {len(empty)}")

    print("\nProblematyczne URL-e:")
    for r in err:
        if r["url_stary"]:
            print(f"  {r['id']}: {r['nazwa'][:50]} | {r['url_stary']} | {r['status_code']} | {r['uwagi']}")

    if FIX_MODE and modified:
        with open(SCHOOLS_JSON, "w", encoding="utf-8") as f:
            json.dump(schools, f, ensure_ascii=False, indent=2)
        print(f"\nZapisano poprawki do {SCHOOLS_JSON}")


if __name__ == "__main__":
    main()

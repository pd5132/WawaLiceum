"""
Parser for Informator Licea_2026.pdf.

Each school spans 1–4 pages. Sections are identified by colored stripe rectangles.
Pictogram icons (XObject names) map 1-to-1 to specific features.
Text bullet points become initiative records.

Outputs:
  stg_informator_flags    – one row per school, bit flags from pictogram detection
  stg_informator_inicjatywy – one row per (school, sekcja, element) text item
"""
import re
from pathlib import Path

import pandas as pd
import pdfplumber
from sqlalchemy import Engine

from etl.config import DATA_DIR

PDF_PATH = DATA_DIR / "Informator Licea_2026.pdf"

# ── XObject name → schema column ────────────────────────────────────────────
# Determined empirically: each XObject reused across all pages for same icon.

XOBJ_FLAG: dict[str, str] = {
    # Udogodnienia dla uczniów
    "X262": "czy_strefa_ciszy",
    "X263": "czy_miejsce_odpoczynku",
    "X264": "czy_ciche_dzwonki",
    "X265": "czy_rozowa_skrzyneczka",
    "X266": "czy_szafki_uczniow",
    "X267": "czy_stojak_na_rowery",
    "X268": "czy_teren_zielony",
    "X301": "czy_otwarte_boiska",
    # X314: rare (~30 schools), unknown feature — excluded
    # Posiłki
    "X284": "czy_sklepik_szkolny",
    "X285": "czy_bufet_stolowka",
    "X286": "czy_posilki_wegetarianskie",
    "X287": "czy_posilki_weganskie",
    "X288": "czy_zrodlo_wody_pitnej",
    # Bezpieczeństwo
    "X289": "czy_monitoring",
    "X329": "czy_wejscie_na_karty",
    "X290": "czy_rejestracja_gosci",
    # Usprawnienia dla osób z niepełnosprawnościami
    "X291": "czy_winda",
    "X307": "czy_podjazd_dla_wozkow",
    "X308": "czy_petla_indukcyjna",
    "X374": "czy_schodolaz",
    # Pracownicy wspierający ucznia
    "X292": "czy_rzecznik_praw_ucznia",
    "X293": "czy_pielegniarka",
    "X294": "czy_psycholog_na_etacie",
    "X295": "czy_pedagog_specjalny",
    "X332": "czy_osoba_zaufania",
}

ALL_FLAGS = [
    "czy_strefa_ciszy", "czy_miejsce_odpoczynku", "czy_ciche_dzwonki",
    "czy_rozowa_skrzyneczka", "czy_szafki_uczniow", "czy_stojak_na_rowery",
    "czy_teren_zielony", "czy_otwarte_boiska",
    "czy_sklepik_szkolny", "czy_bufet_stolowka",
    "czy_posilki_wegetarianskie", "czy_posilki_weganskie", "czy_zrodlo_wody_pitnej",
    "czy_monitoring", "czy_wejscie_na_karty", "czy_rejestracja_gosci",
    "czy_winda", "czy_podjazd_dla_wozkow", "czy_petla_indukcyjna", "czy_schodolaz",
    "czy_rzecznik_praw_ucznia", "czy_pielegniarka",
    "czy_psycholog_na_etacie", "czy_pedagog_specjalny", "czy_osoba_zaufania",
    "czy_zajecia_tus", "czy_rewalidacja",
]

# ── Text-based flags from section text content ───────────────────────────────
TEXT_FLAGS: list[tuple[str, str]] = [
    ("czy_zajecia_tus",    r"\btus\b"),
    ("czy_rewalidacja",    r"rewalidacj"),
    ("czy_psycholog_na_etacie", r"psycholog"),
    ("czy_pedagog_specjalny",   r"pedagog"),
    ("czy_pielegniarka",        r"piel[eę]gniark"),
    ("czy_rzecznik_praw_ucznia", r"rzecznik"),
    ("czy_osoba_zaufania",      r"osoba\s+zaufania"),
    ("czy_winda",               r"\bwinda\b|\bwind[ąę]\b"),
    ("czy_podjazd_dla_wozkow",  r"podjazd"),
    ("czy_petla_indukcyjna",    r"p[eę]tla\s+indukcyjna"),
    ("czy_schodolaz",           r"schodołaz|schodolaz"),
    ("czy_monitoring",          r"monitoring"),
    ("czy_rejestracja_gosci",   r"rejestracja\s+go[sś]ci"),
    ("czy_wejscie_na_karty",    r"wej[sś]cie\s+na\s+karty"),
    ("czy_zrodlo_wody_pitnej",  r"[zź]r[oó]d[eł].*wod|dystrybutor.*wod|wod.*dystrybutor"),
    ("czy_bufet_stolowka",      r"bufet|sto[łl][oó]wk"),
    ("czy_sklepik_szkolny",     r"sklepik"),
    ("czy_posilki_wegetarianskie", r"wegetaria"),
    ("czy_posilki_weganskie",   r"wega[nń]"),
]

# ── Stripe color classification ───────────────────────────────────────────────
_STRIPE_COLORS: dict[tuple, str] = {
    (0.898, 0.5882, 0.6706):   "Udogodnienia",
    (0.5961, 0.7765, 0.4627):  "Aktywnosc_spoleczna",
    (0.9569, 0.7725, 0.2588):  "Dodatkowa_aktywnosc",
    (0.9529, 0.7647, 0.6745):  "Wspolpraca_organizacje",
    (0.302, 0.702, 0.898):     "Wydarzenia_cykliczne",
    (0.549, 0.3569, 0.902):    "Aktywne_metody",
    (0.1216, 0.5608, 0.2745):  "Posilki",
    (0.9686, 0.5804, 0.1137):  "Bezpieczenstwo",
    # Ambiguous (left vs right, full-width)
    (0.9686, 0.9373, 0.5412):  "_YELLOW",
    (0.702, 0.851, 1.0):       "_BLUE",
}

_INITIATIVE_SECTIONS = {
    "Aktywnosc_spoleczna", "Dodatkowa_aktywnosc", "Wspolpraca_organizacje",
    "Zajecia_specjalistyczne", "Projekty_edukacyjne", "Wydarzenia_cykliczne",
    "Aktywne_metody", "Udogodnienia",
}


def _round_color(c: tuple) -> tuple:
    return tuple(round(x, 4) for x in c)


def _classify_stripe(rect: dict, page_height: float) -> tuple:
    fill = rect.get("non_stroking_color")
    if not fill or fill == (1.0, 1.0, 1.0):
        return None, ()
    y_top = page_height - rect["y1"]
    y_bot = page_height - rect["y0"]
    x0, x1 = rect["x0"], rect["x1"]
    rc = _round_color(fill)
    base = _STRIPE_COLORS.get(rc)
    if not base:
        return None, ()
    if base == "_YELLOW":
        # full-width → Zajecia_specjalistyczne; right half → Pracownicy
        base = "Pracownicy" if x0 > 200 else "Zajecia_specjalistyczne"
    elif base == "_BLUE":
        # full-width → Projekty_edukacyjne; left half → Usprawnienia
        base = "Usprawnienia" if x1 < 400 else "Projekty_edukacyjne"
    return base, (y_top, y_bot, x0, x1)


def _is_school_start(page) -> bool:
    for img in page.images:
        if img["width"] > 80 and img["height"] > 100 and img["x0"] > 450 and img["top"] < 50:
            return True
    return False


def _get_school_name(page) -> str:
    """Extract school name — stop before the address (ul./os./al. prefix)."""
    words = page.extract_words() or []
    name_words = []
    for w in sorted(words, key=lambda x: (x["top"], x["x0"])):
        if w["top"] > 120:
            break
        if w["text"].lower() in ("ul.", "os.", "al.", "pl."):
            break
        if w["x0"] > 30 and w["x0"] < 560:
            name_words.append(w["text"])
    return " ".join(name_words).strip()


def _section_content(page, sections: list[tuple]) -> dict[str, tuple[float, float, float, float]]:
    """Return {section_name: (content_y_top, content_y_bot, x0, x1)} bounding boxes."""
    ph = page.height
    result = {}
    sections_sorted = sorted(sections, key=lambda s: s[0])  # sort by y_top

    for i, (y_top, y_bot, x0, x1, sec) in enumerate(sections_sorted):
        # Next stripe boundary in overlapping x region
        next_y = ph
        for j, (ny_top, ny_bot, nx0, nx1, nsec) in enumerate(sections_sorted):
            if j <= i:
                continue
            if nx0 < x1 and nx1 > x0 and ny_top > y_bot:
                next_y = ny_top
                break
        result[sec] = (y_bot, next_y, x0, x1)
    return result


def _images_in_box(page, y_top: float, y_bot: float, x0: float, x1: float) -> list[str]:
    names = []
    for img in page.images:
        if img["width"] < 40:
            continue
        if (img["x0"] >= x0 - 5 and img["x1"] <= x1 + 5 and
                y_top - 5 <= img["top"] <= y_bot + 5):
            names.append(img["name"])
    return names


def _text_in_box(page, y_top: float, y_bot: float, x0: float, x1: float) -> str:
    words = []
    for w in (page.extract_words() or []):
        if (w["x0"] >= x0 - 5 and w["x1"] <= x1 + 5 and
                y_top - 3 <= w["top"] <= y_bot + 3):
            words.append(w["text"])
    return " ".join(words)


def _split_bullets(text: str) -> list[str]:
    """Split section text into individual bullet items."""
    # Items separated by multiple spaces or by capitalized words after lowercase
    text = text.strip()
    if not text:
        return []
    # Split on 3+ spaces (common PDF multi-column separator)
    parts = re.split(r"  {2,}", text)
    items = []
    for p in parts:
        p = p.strip()
        if p and len(p) > 2:
            items.append(p)
    return items if items else [text]


def _parse_school_pages(pages: list) -> dict:
    """Parse all pages of one school, return flags + initiative texts."""
    flags: dict[str, int] = {f: 0 for f in ALL_FLAGS}
    initiatives: list[tuple[str, str]] = []  # (sekcja, element)
    school_name = _get_school_name(pages[0])

    for page in pages:
        ph = page.height

        # Collect stripes
        raw_stripes: list[tuple] = []
        for r in page.rects:
            sec, bounds = _classify_stripe(r, ph)
            if sec and bounds:
                y_top, y_bot, x0, x1 = bounds
                raw_stripes.append((y_top, y_bot, x0, x1, sec))

        # Section content boxes
        content = _section_content(page, raw_stripes)

        for sec, (cy_top, cy_bot, cx0, cx1) in content.items():
            # Pictogram detection
            img_names = _images_in_box(page, cy_top, cy_bot, cx0, cx1)
            for name in img_names:
                flag = XOBJ_FLAG.get(name)
                if flag and flag in flags:
                    flags[flag] = 1

            # Text extraction
            text = _text_in_box(page, cy_top, cy_bot, cx0, cx1)
            if not text:
                continue

            # Text-based flags (applied for text sections)
            text_lower = text.lower()
            for flag, pattern in TEXT_FLAGS:
                if flag in flags and re.search(pattern, text_lower):
                    flags[flag] = 1

            # Collect initiative text items
            if sec in _INITIATIVE_SECTIONS:
                for item in _split_bullets(text):
                    if len(item) > 3:
                        initiatives.append((sec, item))

    # Deduplicate initiatives
    seen = set()
    unique_initiatives = []
    for sec, item in initiatives:
        key = (sec, item[:60])
        if key not in seen:
            seen.add(key)
            unique_initiatives.append((sec, item))

    return {
        "nazwa_szkoly_informator": school_name,
        "flags": flags,
        "initiatives": unique_initiatives,
    }


def extract_informator(engine: Engine) -> tuple[int, int]:
    """
    Parse Informator Licea_2026.pdf.
    Returns (flag_rows, initiative_rows).
    Writes stg_informator_flags and stg_informator_inicjatywy.
    """
    pdf = pdfplumber.open(PDF_PATH)
    total_pages = len(pdf.pages)

    # Detect school boundaries
    school_starts = [i for i, pg in enumerate(pdf.pages) if _is_school_start(pg)]
    print(f"[informator] {len(school_starts)} schools detected across {total_pages} pages")

    flag_rows: list[dict] = []
    init_rows: list[dict] = []

    for s_idx, start in enumerate(school_starts):
        end = school_starts[s_idx + 1] if s_idx + 1 < len(school_starts) else total_pages
        pages = [pdf.pages[i] for i in range(start, end)]

        result = _parse_school_pages(pages)
        school_name = result["nazwa_szkoly_informator"]

        row = {"nazwa_szkoly_informator": school_name}
        row.update(result["flags"])
        flag_rows.append(row)

        for sec, item in result["initiatives"]:
            init_rows.append({
                "nazwa_szkoly_informator": school_name,
                "sekcja": sec,
                "element": item[:500],
            })

    flags_df = pd.DataFrame(flag_rows)
    flags_df.to_sql("stg_informator_flags", engine, if_exists="replace", index=False, method="multi", chunksize=500)
    print(f"[stg_informator_flags] {len(flags_df)} rows")

    init_df = pd.DataFrame(init_rows)
    init_df.to_sql("stg_informator_inicjatywy", engine, if_exists="replace", index=False, method="multi", chunksize=500)
    print(f"[stg_informator_inicjatywy] {len(init_df)} rows")

    return len(flags_df), len(init_df)

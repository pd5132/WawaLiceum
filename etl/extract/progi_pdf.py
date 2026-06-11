"""
Extract point thresholds from 3 structured PDFs:
  2023 — 6 cols: dzielnica, nazwa, symbol, nazwa_oddzialu, prog_min, prog_max
  2024 — 6 cols: dzielnica, typ, nazwa, adres, nazwa_krotka (symbol embedded), prog_min
  2025 — no proper column split; parsed via x-position of words

Output: stg_progi (rok, dzielnica, nazwa_szkoly, symbol_oddzialu, nazwa_oddzialu,
                    prog_min, prog_max)
"""
import re
from collections import defaultdict
from typing import Optional

import pandas as pd
import pdfplumber
from sqlalchemy import Engine

from etl.config import PROGI_2023_PDF, PROGI_2024_PDF, PROGI_2025_PDF

_IS_NUMERIC = re.compile(r"^\d{2,3}[.,]\d{1,2}$")


def _is_prog(val: str) -> bool:
    return bool(_IS_NUMERIC.match(val.strip())) if val else False


def _norm_prog(val) -> Optional[float]:
    if not val:
        return None
    s = str(val).strip().replace(",", ".")
    try:
        return float(s)
    except ValueError:
        return None


def _parse_2023(path) -> list[dict]:
    rows = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            for table in page.extract_tables():
                for row in table:
                    if not row or len(row) < 6:
                        continue
                    dzielnica, nazwa, symbol, nazwa_odd, p_min, p_max = row[:6]
                    if not _is_prog(str(p_min or "")):
                        continue
                    rows.append({
                        "rok":           2023,
                        "dzielnica":     str(dzielnica or "").strip(),
                        "nazwa_szkoly":  str(nazwa or "").strip().replace("\n", " "),
                        "symbol_oddzialu": str(symbol or "").strip().replace("\n", ""),
                        "nazwa_oddzialu": str(nazwa_odd or "").strip().replace("\n", " "),
                        "prog_min":      _norm_prog(p_min),
                        "prog_max":      _norm_prog(p_max),
                    })
    return rows


def _parse_2024(path) -> list[dict]:
    rows = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            for table in page.extract_tables():
                for row in table:
                    if not row or len(row) < 6:
                        continue
                    dzielnica, _, nazwa, _, nazwa_krotka, p_min = row[:6]
                    if not _is_prog(str(p_min or "")):
                        continue
                    nk = str(nazwa_krotka or "").strip()
                    symbol = nk.split()[0] if nk else ""
                    rows.append({
                        "rok":           2024,
                        "dzielnica":     str(dzielnica or "").strip(),
                        "nazwa_szkoly":  str(nazwa or "").strip().replace("\n", " "),
                        "symbol_oddzialu": symbol,
                        "nazwa_oddzialu": nk,
                        "prog_min":      _norm_prog(p_min),
                        "prog_max":      None,
                    })
    return rows


def _parse_2025(path) -> list[dict]:
    # Column x-boundaries (empirical; symbol col starts at x≈339.7, oddzial at x≈397.8, prog at x≈612.4)
    COL_NAZWA   = 47.0
    COL_SYMBOL  = 320.0
    COL_ODDZIAL = 395.0
    COL_PROG    = 610.0

    rows = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            words = page.extract_words()
            lines: dict[int, list] = defaultdict(list)
            for w in words:
                lines[round(w["top"] / 3) * 3].append(w)

            for y_key in sorted(lines):
                line = sorted(lines[y_key], key=lambda w: w["x0"])
                dzielnica_t, nazwa_t, symbol_t, oddzial_t, prog_t = [], [], [], [], []
                for w in line:
                    x, text = w["x0"], w["text"]
                    if x < COL_NAZWA:
                        dzielnica_t.append(text)
                    elif x < COL_SYMBOL:
                        nazwa_t.append(text)
                    elif x < COL_ODDZIAL:
                        symbol_t.append(text)
                    elif x < COL_PROG:
                        oddzial_t.append(text)
                    else:
                        prog_t.append(text)

                prog_raw = " ".join(prog_t).strip()
                if not _is_prog(prog_raw):
                    continue
                rows.append({
                    "rok":           2025,
                    "dzielnica":     " ".join(dzielnica_t),
                    "nazwa_szkoly":  " ".join(nazwa_t),
                    "symbol_oddzialu": " ".join(symbol_t),
                    "nazwa_oddzialu": " ".join(oddzial_t),
                    "prog_min":      _norm_prog(prog_raw),
                    "prog_max":      None,
                })
    return rows


def extract_progi(engine: Engine) -> int:
    parsers = [
        (PROGI_2023_PDF, _parse_2023),
        (PROGI_2024_PDF, _parse_2024),
        (PROGI_2025_PDF, _parse_2025),
    ]
    all_rows: list[dict] = []
    for path, parser in parsers:
        if path.exists():
            found = parser(path)
            print(f"[progi_pdf] {path.name}: {len(found)} rows")
            all_rows.extend(found)
        else:
            print(f"[progi_pdf] SKIP (not found): {path.name}")

    cols = ["rok", "dzielnica", "nazwa_szkoly", "symbol_oddzialu",
            "nazwa_oddzialu", "prog_min", "prog_max"]
    df = pd.DataFrame(all_rows, columns=cols) if all_rows else pd.DataFrame(columns=cols)

    df.to_sql("stg_progi", engine, if_exists="replace", index=False, method="multi", chunksize=500)
    print(f"[stg_progi] {len(df)} rows (2023={sum(1 for r in all_rows if r['rok']==2023)}, "
          f"2024={sum(1 for r in all_rows if r['rok']==2024)}, "
          f"2025={sum(1 for r in all_rows if r['rok']==2025)})")
    return len(df)

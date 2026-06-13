"""
Extract and load CKE/OKE per-school matura results from the wide XLSX format
published at mapa.wyniki.edu.pl/MapaEgzaminow/ into dbo.stg_matura.

The file uses a 3-row header:
  row 0 – section label (ignored)
  row 1 – subject name + level, e.g. "język angielski poziom podstawowy (M)"
  row 2 – metric name, e.g. "* liczba zdających", "średni wynik (%)"
  row 3+ – data (one school per row)

Info columns (0-11): ID OKE, województwo, powiat, gmina, typ_gminy, kod_teryt,
  RSPO szkoły (col 6), Nazwa szkoły (col 7), Miejscowość (col 8), ulica, typ_placówki (col 10)

Only subjects already in Wymiar_Przedmiot_Maturalny are loaded (22 subjects).
Subject names in the XLSX use Unicode; they are remapped to the DB encoding
(? for Polish diacritics) to match existing stg_matura and Wymiar_Przedmiot_Maturalny rows.

Usage (standalone):
    python -m etl.extract.em_xlsx --file "Data/EM2023 - szkoły (aktualizacja 09.2024).xlsx" --rok 2024

Usage (from ETL pipeline):
    from etl.extract.em_xlsx import load_em_xlsx
    load_em_xlsx(engine, rok=2024)
"""

import argparse
import re
import sys
from pathlib import Path

import pandas as pd
from sqlalchemy import text
from sqlalchemy.engine import Engine


# ── Subject remapping: XLSX Unicode → DB encoding ────────────────────────────
# The DB was populated with mangled Polish characters (? instead of diacritics).
# This map translates XLSX subject labels to the exact strings used in
# Wymiar_Przedmiot_Maturalny and existing stg_matura rows.
SUBJECT_REMAP = {
    ("język angielski",        "podstawowy"):   ("j?zyk angielski",       "podstawowy"),
    ("język angielski",        "rozszerzony"):  ("j?zyk angielski",       "rozszerzony"),
    ("język angielski",        "dwujęzyczny"):  ("j?zyk angielski",       "dwuj?zyczny"),
    ("język francuski",        "podstawowy"):   ("j?zyk francuski",       "podstawowy"),
    ("język francuski",        "rozszerzony"):  ("j?zyk francuski",       "rozszerzony"),
    ("język hiszpański",       "podstawowy"):   ("j?zyk hiszpa?sk",       "podstawowy"),
    ("język hiszpański",       "rozszerzony"):  ("j?zyk hiszpa?ski",      "rozszerzony"),
    ("język niemiecki",        "podstawowy"):   ("j?zyk niemiecki",       "podstawowy"),
    ("język niemiecki",        "rozszerzony"):  ("j?zyk niemiecki",       "rozszerzony"),
    ("język polski",           "podstawowy"):   ("jezyk polski",          "podstawowy"),
    ("język polski",           "rozszerzony"):  ("j?zyk polski",          "rozszerzony"),
    ("wiedza o społeczeństwie","rozszerzony"):  ("wiedza o spo?ecze?stwie","rozszerzony"),
    ("biologia",               "rozszerzony"):  ("biologia",              "rozszerzony"),
    ("chemia",                 "rozszerzony"):  ("chemia",                "rozszerzony"),
    ("filozofia",              "rozszerzony"):  ("filozofia",             "rozszerzony"),
    ("fizyka",                 "rozszerzony"):  ("fizyka",                "rozszerzony"),
    ("geografia",              "rozszerzony"):  ("geografia",             "rozszerzony"),
    ("historia",               "rozszerzony"):  ("historia",              "rozszerzony"),
    ("historia sztuki",        "rozszerzony"):  ("historia sztuki",       "rozszerzony"),
    ("informatyka",            "rozszerzony"):  ("informatyka",           "rozszerzony"),
    ("matematyka",             "podstawowy"):   ("matematyka",            "podstawowy"),
    ("matematyka",             "rozszerzony"):  ("matematyka",            "rozszerzony"),
}

METRIC_MAP = {
    "* liczba zdających":            "liczba_zdajacych",
    "* liczba laureatów/finalistów": "liczba_laureatow_finalistow",
    "* zdawalność (%)":              "zdawalnosc_proc",
    "średni wynik (%)":              "sredni_wynik_proc",
    "odchylenie standardowe (%)":    "odchylenie_standardowe_proc",
    "mediana (%)":                   "mediana_proc",
    "modalna (%)":                   "modalna_proc",
}

# Info columns: RSPO is at index 6, Miejscowość at 8, typ_placówki at 10
COL_RSPO      = 6
COL_MIEJSCOWOSC = 8
COL_TYP       = 10
INFO_COLS_END = 12


def _parse_subject(label: str):
    """Return (nazwa, poziom) or None if oral/special/unrecognised."""
    if re.search(r"ustny|zestaw zada[nń]", label, re.I):
        return None
    m = re.search(r"poziom\s+(\w+)", label, re.I)
    if not m:
        return None
    poziom = m.group(1).lower()
    nazwa = re.sub(r"\s*poziom\s+\w+.*", "", label, flags=re.I)
    nazwa = re.sub(r"\s*\(M\)\s*$", "", nazwa).strip().lower()
    return (nazwa, poziom)


def _build_col_groups(raw: pd.DataFrame):
    """Return list of (col_index, em_nazwa, em_poziom, stg_field) for data cols."""
    row1 = raw.iloc[1].tolist()
    row2 = raw.iloc[2].tolist()

    cur_subject = None
    groups = []
    for i, (s, m) in enumerate(zip(row1, row2)):
        if not pd.isna(s):
            cur_subject = str(s).strip()
        if i < INFO_COLS_END:
            continue
        parsed = _parse_subject(cur_subject or "")
        if parsed is None:
            continue
        stg_field = METRIC_MAP.get(str(m).strip() if not pd.isna(m) else "")
        if stg_field is None:
            continue
        groups.append((i, parsed[0], parsed[1], stg_field))
    return groups


def load_em_xlsx(engine: Engine, rok: int, file_path: str | None = None) -> int:
    """
    Load one EM XLSX into stg_matura for the given rok_kalendarzowy.
    Existing rows for that rok are deleted first.
    Returns number of rows inserted.
    """
    if file_path is None:
        from etl.config import EM_XLSX_FILE
        file_path = str(EM_XLSX_FILE)

    rok_szkolny = f"{rok - 1}/{rok}"
    print(f"[em_xlsx] Loading {file_path}  rok={rok}  rok_szkolny={rok_szkolny}")

    raw = pd.read_excel(file_path, sheet_name=0, header=None)
    col_groups = _build_col_groups(raw)
    print(f"[em_xlsx] {len(col_groups)} subject×metric columns mapped")

    # Load data rows (skip 3-row header)
    df = pd.read_excel(file_path, sheet_name=0, header=None, skiprows=3)
    df.columns = range(len(df.columns))

    # Filter Warsaw liceums from raw header rows
    waw = raw.iloc[3:, COL_MIEJSCOWOSC].reset_index(drop=True).astype(str).str.lower() == "warszawa"
    lic = raw.iloc[3:, COL_TYP].reset_index(drop=True).astype(str).str.lower().str.contains("liceum")
    df = df[waw & lic].reset_index(drop=True)
    print(f"[em_xlsx] {len(df)} Warsaw liceum rows")

    with engine.connect() as c:
        dwh_rspo = set(
            r[0] for r in c.execute(text("SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola")).fetchall()
        )

    stg_rows = []
    for _, school_row in df.iterrows():
        try:
            rspo = int(school_row[COL_RSPO])
        except (ValueError, TypeError):
            continue
        if rspo not in dwh_rspo:
            continue

        subj_data: dict = {}
        for col_i, nazwa, poziom, stg_field in col_groups:
            if col_i >= len(school_row):
                continue
            val = school_row[col_i]
            if pd.notna(val):
                key = (nazwa, poziom)
                subj_data.setdefault(key, {})[stg_field] = val

        for (nazwa, poziom), metrics in subj_data.items():
            if not metrics.get("liczba_zdajacych"):
                continue
            mapped = SUBJECT_REMAP.get((nazwa, poziom))
            if mapped is None:
                continue
            db_nazwa, db_poziom = mapped

            def _fmt(v):
                return str(round(float(v), 2)) if v is not None else None

            stg_rows.append({
                "rspo_szkoly":                str(rspo),
                "nazwa_przedmiotu":           db_nazwa,
                "poziom":                     db_poziom,
                "liczba_zdajacych":           str(int(metrics["liczba_zdajacych"])),
                "liczba_laureatow_finalistow": str(int(metrics["liczba_laureatow_finalistow"]))
                                              if metrics.get("liczba_laureatow_finalistow") else None,
                "zdawalnosc_proc":            _fmt(metrics.get("zdawalnosc_proc")),
                "sredni_wynik_proc":          _fmt(metrics.get("sredni_wynik_proc")),
                "odchylenie_standardowe_proc":_fmt(metrics.get("odchylenie_standardowe_proc")),
                "mediana_proc":               _fmt(metrics.get("mediana_proc")),
                "modalna_proc":               _fmt(metrics.get("modalna_proc")),
                "rok_kalendarzowy":           str(rok),
                "rok_szkolny":               rok_szkolny,
                "poziom_src":                db_poziom,
            })

    df_long = pd.DataFrame(stg_rows)
    print(f"[em_xlsx] {len(df_long)} long-format rows for {df_long['rspo_szkoly'].nunique()} schools")

    with engine.begin() as c:
        deleted = c.execute(
            text("DELETE FROM dbo.stg_matura WHERE rok_kalendarzowy = :r"), {"r": str(rok)}
        ).rowcount
        print(f"[em_xlsx] Deleted {deleted} existing rok={rok} rows")

    df_long.to_sql("stg_matura", engine, if_exists="append", index=False,
                   method="multi", chunksize=500)
    print(f"[em_xlsx] Inserted {len(df_long)} rows into stg_matura")
    return len(df_long)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load EM XLSX matura data into stg_matura")
    parser.add_argument("--file", required=True, help="Path to EM XLSX file")
    parser.add_argument("--rok",  required=True, type=int, help="rok_kalendarzowy of the exam (e.g. 2024)")
    args = parser.parse_args()

    from etl.config import create_engine_connection
    eng = create_engine_connection()
    n = load_em_xlsx(eng, rok=args.rok, file_path=args.file)
    print(f"Done — {n} rows loaded.")
    sys.exit(0)

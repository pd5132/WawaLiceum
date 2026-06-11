import unicodedata
import pandas as pd
from sqlalchemy import Engine
from etl.config import PLAN_NABORU_FILE


def _asc(s: str) -> str:
    return unicodedata.normalize("NFD", s).encode("ascii", "ignore").decode().lower()


def extract_plan_naboru(engine: Engine) -> int:
    df = pd.read_excel(PLAN_NABORU_FILE, dtype=str)
    df.columns = [
        c.strip().replace("\n", " ").replace("  ", " ").strip()
        for c in df.columns
    ]
    # Normalize verbose column names (use ASCII-folded match to handle Polish chars)
    rename = {}
    for c in df.columns:
        cl = _asc(c)
        if "dzielnica" in cl:               rename[c] = "dzielnica"
        elif "typ" in cl and "szko" in cl:  rename[c] = "typ_szkoly"
        elif "nazwa" in cl:                 rename[c] = "nazwa_szkoly"
        elif "ulica" in cl:                 rename[c] = "ulica"
        elif "typ" in cl and "oddz" in cl:  rename[c] = "typ_oddzialu"
        elif "zawod" in cl or "jezyk" in cl: rename[c] = "jezyk_lub_zawod"
        elif "liczba" in cl and "oddz" in cl: rename[c] = "liczba_oddzialow"
        elif "miejsc" in cl:                rename[c] = "liczba_miejsc"
        elif "rok" in cl:                   rename[c] = "rok_szkolny"
    df = df.rename(columns=rename)
    df.to_sql("stg_plan_naboru", engine, if_exists="replace", index=False, method="multi", chunksize=500)
    print(f"[stg_plan_naboru] {len(df)} rows loaded")
    return len(df)

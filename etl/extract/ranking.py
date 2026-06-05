import pandas as pd
from sqlalchemy import Engine
from etl.config import RANKING_FILE

YEAR_COLS = [2023, 2024, 2025, 2026]


def extract_ranking(engine: Engine) -> int:
    df = pd.read_excel(RANKING_FILE, dtype=str)
    # Columns: 2026, Nazwa szkoły, Dzielnica, 2025, 2024, 2023, WSK, Znak jakości
    # Rename for clarity
    df.columns = [str(c).strip() for c in df.columns]
    df = df.rename(columns={
        "Nazwa szkoły": "nazwa_szkoly",
        "Dzielnica": "dzielnica",
        "WSK": "wsk",
        "Znak jakości": "znak_jakosci",
    })
    # Unpivot year-rank columns → (rok, pozycja) per row
    id_cols = ["nazwa_szkoly", "dzielnica", "wsk", "znak_jakosci"]
    year_cols_present = [c for c in df.columns if c in [str(y) for y in YEAR_COLS]]
    long = df.melt(id_vars=id_cols, value_vars=year_cols_present,
                   var_name="rok_rankingu", value_name="pozycja")
    long["rok_rankingu"] = long["rok_rankingu"].astype(int)
    long = long.dropna(subset=["pozycja"])
    long.to_sql("stg_ranking", engine, if_exists="replace", index=False, method="multi")
    print(f"[stg_ranking] {len(long)} rows loaded")
    return len(long)

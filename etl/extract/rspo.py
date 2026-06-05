import re
import unicodedata
import pandas as pd
from sqlalchemy import Engine
from etl.config import RSPO_FILE


def clean_col(col: str) -> str:
    col = unicodedata.normalize("NFD", col).encode("ascii", "ignore").decode()
    col = re.sub(r"[^\w]", "_", col)
    col = re.sub(r"__+", "_", col).strip("_").lower()
    return col


def extract_rspo(engine: Engine) -> int:
    df = pd.read_excel(RSPO_FILE, dtype=str)
    df.columns = [clean_col(c) for c in df.columns]
    df.to_sql("stg_rspo", engine, if_exists="replace", index=False, method="multi")
    print(f"[stg_rspo] {len(df)} rows loaded")
    return len(df)

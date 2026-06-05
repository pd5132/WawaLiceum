import pandas as pd
from sqlalchemy import Engine
from etl.config import MATURA_POD_FILE, MATURA_ROZ_FILE

_CSV_OPTS = dict(sep=";", encoding="cp1250", decimal=",", dtype=str)


def _clean_col(col: str) -> str:
    import re, unicodedata
    col = unicodedata.normalize("NFD", col).encode("ascii", "ignore").decode()
    col = re.sub(r"[^\w]", "_", col)
    col = re.sub(r"__+", "_", col).strip("_").lower()
    return col


def _read(path, poziom: str) -> pd.DataFrame:
    df = pd.read_csv(path, **_CSV_OPTS)
    df.columns = [_clean_col(c) for c in df.columns]
    # normalise RSPO column name (source has question-marks / garbled chars)
    rspo_col = next(c for c in df.columns if "rspo" in c or "szkol" in c)
    df = df.rename(columns={rspo_col: "rspo_szkoly"})
    df["poziom_src"] = poziom  # tag source file level
    return df


def extract_matury(engine: Engine) -> int:
    pod = _read(MATURA_POD_FILE, "podstawowy")
    roz = _read(MATURA_ROZ_FILE, "rozszerzony")
    df = pd.concat([pod, roz], ignore_index=True)
    df.to_sql("stg_matura", engine, if_exists="replace", index=False, method="multi")
    print(f"[stg_matura] {len(df)} rows loaded ({len(pod)} pod + {len(roz)} roz)")
    return len(df)

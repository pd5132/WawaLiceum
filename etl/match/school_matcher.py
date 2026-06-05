"""
Match school names from ranking/plan-naboru to RSPO ids.

Normalises names (strip "LO", "Liceum Ogólnokształcące", patron, punctuation)
then uses rapidfuzz token_sort_ratio.  Manual overrides in overrides.csv win.

Writes:
  stg_school_xref(source, source_name, id_szkoly_rspo, score, match_name)
  match/unresolved_names.csv  — rows below THRESHOLD
"""
import re
import unicodedata
import pandas as pd
from rapidfuzz import process, fuzz
from sqlalchemy import Engine
from etl.config import MATCH_DIR

THRESHOLD  = 75   # minimum match score (0–100)
OVERRIDES  = MATCH_DIR / "overrides.csv"


def _norm(name: str) -> str:
    """Normalise a school name for fuzzy matching."""
    s = str(name)
    # Remove diacritics
    s = unicodedata.normalize("NFD", s).encode("ascii", "ignore").decode()
    s = s.lower()
    # Strip common noise
    s = re.sub(r"\bim\.?\b", "", s)
    s = re.sub(r"\b(liceum ogolnoksztalcace|liceum oglnoksztalcace|lo|lg)\b", "", s)
    s = re.sub(r"\b(z oddz(ialami?)?\.?|z oddzialami)\b", "", s)
    s = re.sub(r"\b(dwujez(yczne)?|mistrzostwa sportowego)\b", "", s)
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def build_xref(sources: dict[str, list[str]], rspo_df: pd.DataFrame, engine: Engine) -> int:
    """
    sources: {source_name: [list of school name strings]}
    rspo_df: DataFrame with numer_rspo, nazwa columns (from stg_rspo)
    """
    # Load overrides
    overrides: dict[str, int] = {}
    if OVERRIDES.exists():
        ov = pd.read_csv(OVERRIDES, dtype=str)
        for _, r in ov.iterrows():
            overrides[str(r["source_name"]).strip()] = int(r["id_szkoly_rspo"])

    rspo_names   = rspo_df["nazwa"].tolist()
    rspo_ids     = rspo_df["numer_rspo"].tolist()
    rspo_normed  = [_norm(n) for n in rspo_names]

    rows = []
    unresolved = []

    for source, names in sources.items():
        for raw_name in names:
            raw_name = str(raw_name).strip()
            if not raw_name:
                continue

            # Manual override wins
            if raw_name in overrides:
                rows.append({
                    "source": source, "source_name": raw_name,
                    "id_szkoly_rspo": overrides[raw_name],
                    "score": 100, "match_name": "OVERRIDE",
                })
                continue

            normed = _norm(raw_name)
            result = process.extractOne(
                normed, rspo_normed,
                scorer=fuzz.token_sort_ratio,
                score_cutoff=THRESHOLD,
            )
            if result:
                match_idx  = rspo_normed.index(result[0])
                rows.append({
                    "source":        source,
                    "source_name":   raw_name,
                    "id_szkoly_rspo": int(rspo_ids[match_idx]),
                    "score":         result[1],
                    "match_name":    rspo_names[match_idx],
                })
            else:
                unresolved.append({"source": source, "source_name": raw_name, "normed": normed})

    df = pd.DataFrame(rows)
    df.to_sql("stg_school_xref", engine, if_exists="replace", index=False, method="multi")
    print(f"[stg_school_xref] {len(df)} matched | {len(unresolved)} unresolved")

    if unresolved:
        pd.DataFrame(unresolved).to_csv(MATCH_DIR / "unresolved_names.csv", index=False)
        print(f"  ⚠ See {MATCH_DIR / 'unresolved_names.csv'} — add to overrides.csv and re-run")

    return len(df)

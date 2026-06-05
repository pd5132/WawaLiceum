"""
Extract point thresholds (progi punktowe) from PDF files.
PDFs: Informator Licea_2026.pdf, ranking-licea-matura-2026.pdf

Strategy:
  - pdfplumber extracts tables page by page
  - Keep rows that look like: school name | class symbol | threshold value
  - Write to stg_progi
"""
import re
import pdfplumber
import pandas as pd
from sqlalchemy import Engine
from etl.config import INFORMATOR_PDF, RANKING_PDF


def _looks_like_threshold(val: str) -> bool:
    """True if string is a plausible point threshold (e.g. 158.00, 132, 95,5)."""
    if not val:
        return False
    return bool(re.fullmatch(r"\d{2,3}([.,]\d{1,2})?", val.strip()))


def _extract_from_pdf(path) -> list[dict]:
    rows = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            tables = page.extract_tables()
            for table in tables:
                for row in table:
                    if not row:
                        continue
                    cells = [str(c or "").strip() for c in row]
                    # Heuristic: find cell with threshold-like value
                    for i, cell in enumerate(cells):
                        if _looks_like_threshold(cell):
                            rows.append({
                                "source_pdf":    path.name,
                                "page":          page.page_number,
                                "col0":          cells[0] if len(cells) > 0 else "",
                                "col1":          cells[1] if len(cells) > 1 else "",
                                "col2":          cells[2] if len(cells) > 2 else "",
                                "threshold_raw": cell,
                                "threshold_col": i,
                                "raw_row":       "|".join(cells),
                            })
                            break  # take first threshold-like cell per row
    return rows


def extract_progi(engine: Engine) -> int:
    all_rows = []
    for pdf_path in [INFORMATOR_PDF, RANKING_PDF]:
        if pdf_path.exists():
            all_rows.extend(_extract_from_pdf(pdf_path))
            print(f"[progi_pdf] {pdf_path.name}: {len(all_rows)} candidate rows so far")
        else:
            print(f"[progi_pdf] SKIP (not found): {pdf_path}")

    if not all_rows:
        print("[progi_pdf] No threshold rows found — stg_progi will be empty")
        df = pd.DataFrame(columns=["source_pdf","page","col0","col1","col2",
                                   "threshold_raw","threshold_col","raw_row"])
    else:
        df = pd.DataFrame(all_rows)

    df.to_sql("stg_progi", engine, if_exists="replace", index=False, method="multi")
    print(f"[stg_progi] {len(df)} candidate rows loaded (needs manual review)")
    return len(df)

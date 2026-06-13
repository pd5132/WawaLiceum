from pathlib import Path
from sqlalchemy import create_engine, Engine

DATA_DIR = Path(__file__).parent.parent / "Data"
CACHE_DIR = Path(__file__).parent / "scrape" / "_cache"
MATCH_DIR = Path(__file__).parent / "match"

# Source file paths
RSPO_FILE        = DATA_DIR / "RSPO.xlsx"
MATURA_POD_FILE  = DATA_DIR / "Matury 2025 poziom podstawowy-do zaladowania.csv"
MATURA_ROZ_FILE  = DATA_DIR / "Matury 2025 poziom rozszerzony-do zaladowania.csv"
RANKING_FILE     = DATA_DIR / "2026 Ranking Perspektyw.xlsx"
PLAN_NABORU_FILE = DATA_DIR / "Plan naboru DO LICEUM 16.04.26.xlsx"
PROGI_2023_PDF   = DATA_DIR / "minimalna liczba punktów 2023.pdf"
PROGI_2024_PDF   = DATA_DIR / "Minimalna liczba punktów 2024 r..pdf"
PROGI_2025_PDF   = DATA_DIR / "Minimalna liczba punktów_zakwalifikowani_2025.pdf"
EM_XLSX_FILE     = DATA_DIR / "EM2023 - szkoły (aktualizacja 09.2024).xlsx"  # matura 2024 (rok_szkolny 2023/2024)

SQL_SERVER   = r"LaptopAgi\MSSQLSERVER1"
DATABASE     = "WawaLiceumDB"

REQUEST_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    )
}
SCRAPE_DELAY_SEC = 1.5


def create_engine_connection() -> Engine:
    """Connect to SQL Server.

    Try order:
      1. Local Docker / Azure SQL Edge on localhost:1433 via pymssql
         (SA password from MSSQL_SA_PASSWORD env var or hardcoded dev default)
      2. Windows MSSQLSERVER1 via pyodbc ODBC 18 / 17 (Windows box)
    """
    import os

    # --- Option 1: local Docker (pymssql, no ODBC driver required) ---
    sa_pass = os.environ.get("MSSQL_SA_PASSWORD", "Admini$tr@tor1208")
    try:
        import pymssql  # noqa: F401
        from urllib.parse import quote_plus
        conn_str = (
            f"mssql+pymssql://SA:{quote_plus(sa_pass)}"
            f"@localhost:1433/{DATABASE}"
        )
        engine = create_engine(conn_str)
        with engine.connect():
            pass
        print(f"[DB] Connected via pymssql → localhost:1433/{DATABASE}")
        return engine
    except Exception:
        pass

    # --- Option 2: Windows SQL Server via pyodbc ---
    drivers = ["ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server"]
    for driver in drivers:
        conn_str = (
            f"mssql+pyodbc://@{SQL_SERVER}/{DATABASE}"
            f"?driver={driver.replace(' ', '+')}"
            "&trusted_connection=yes"
            "&TrustServerCertificate=yes"
        )
        try:
            engine = create_engine(conn_str, fast_executemany=True)
            with engine.connect():
                pass
            print(f"[DB] Connected via pyodbc → {SQL_SERVER}/{DATABASE}")
            return engine
        except Exception:
            continue

    raise RuntimeError(
        "Cannot connect to SQL Server. "
        "On Mac: ensure Docker container 'azuresqledge' is running. "
        "On Windows: ensure ODBC Driver 17 or 18 is installed."
    )

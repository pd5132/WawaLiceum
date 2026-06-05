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
INFORMATOR_PDF   = DATA_DIR / "Informator Licea_2026.pdf"
RANKING_PDF      = DATA_DIR / "ranking-licea-matura-2026.pdf"

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
    """Connect to SQL Server using Windows auth. Tries ODBC 18 then 17."""
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
            return engine
        except Exception:
            continue
    raise RuntimeError(
        "Cannot connect to SQL Server. "
        "Ensure ODBC Driver 17 or 18 is installed and the server is running."
    )

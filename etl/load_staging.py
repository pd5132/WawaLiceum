"""
ETL orchestrator — Phase 6
Runs: extract → scrape → match → (SQL transforms invoked separately)
"""
import sys
import pandas as pd
from etl.config import create_engine_connection, MATCH_DIR

def run():
    print("=" * 60)
    print("WawaLiceum ETL — Staging Load")
    print("=" * 60)

    try:
        engine = create_engine_connection()
        print("[OK] Connected to WawaLiceumDB\n")
    except RuntimeError as e:
        print(f"[ERROR] {e}")
        sys.exit(1)

    results = []

    # --- Phase 2: file extracts ---
    from etl.extract.rspo         import extract_rspo
    from etl.extract.matury       import extract_matury
    from etl.extract.ranking      import extract_ranking
    from etl.extract.plan_naboru  import extract_plan_naboru
    from etl.extract.progi_pdf    import extract_progi
    from etl.extract.informator_pdf import extract_informator

    for name, fn in [
        ("RSPO",         lambda: extract_rspo(engine)),
        ("Matura",       lambda: extract_matury(engine)),
        ("Ranking",      lambda: extract_ranking(engine)),
        ("Plan naboru",  lambda: extract_plan_naboru(engine)),
        ("Progi PDF",    lambda: extract_progi(engine)),
        ("Informator PDF", lambda: sum(extract_informator(engine))),
    ]:
        try:
            n = fn()
            results.append((name, n, "OK"))
        except Exception as e:
            print(f"[ERROR] {name}: {e}")
            results.append((name, 0, f"ERROR: {e}"))

    # --- Phase 3: scrapers ---
    rspo_df = pd.read_sql("SELECT numer_rspo, nazwa FROM stg_rspo", engine)

    from etl.scrape.ewd              import scrape_ewd
    from etl.scrape.atmosfera        import scrape_atmosfera
    from etl.scrape.wikipedia_coords import scrape_wikipedia_coords

    for name, fn in [
        ("EWD scraper",        lambda: scrape_ewd(rspo_df, engine)),
        ("Atmosfera scraper",  lambda: scrape_atmosfera(rspo_df, engine)),
        ("Wikipedia coords",   lambda: scrape_wikipedia_coords(rspo_df, engine)),
    ]:
        try:
            n = fn()
            results.append((name, n, "OK"))
        except Exception as e:
            print(f"[ERROR] {name}: {e}")
            results.append((name, 0, f"ERROR: {e}"))

    # --- Phase 4: school name matching ---
    from etl.match.school_matcher import build_xref

    try:
        ranking_df    = pd.read_sql("SELECT DISTINCT nazwa_szkoly FROM stg_ranking",    engine)
        plan_df       = pd.read_sql("SELECT DISTINCT nazwa_szkoly FROM stg_plan_naboru", engine)
        progi_df      = pd.read_sql("SELECT DISTINCT nazwa_szkoly FROM stg_progi",       engine)
        info_df       = pd.read_sql("SELECT DISTINCT nazwa_szkoly_informator AS nazwa_szkoly FROM stg_informator_flags", engine)

        sources = {
            "ranking":     ranking_df["nazwa_szkoly"].dropna().tolist(),
            "plan_naboru": plan_df["nazwa_szkoly"].dropna().tolist(),
            "progi":       progi_df["nazwa_szkoly"].dropna().tolist(),
            "informator":  info_df["nazwa_szkoly"].dropna().tolist(),
        }
        n = build_xref(sources, rspo_df, engine)
        results.append(("School matcher", n, "OK"))
    except Exception as e:
        print(f"[ERROR] School matcher: {e}")
        results.append(("School matcher", 0, f"ERROR: {e}"))

    # --- Summary ---
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    for name, n, status in results:
        print(f"  {name:25s} {n:6d} rows   {status}")

    print("\nNext step: run SQL transforms in SSMS or sqlcmd:")
    print("  sql/10_transform_dims.sql")
    print("  sql/20_transform_facts.sql")
    print("  sql/90_validation.sql")


if __name__ == "__main__":
    run()

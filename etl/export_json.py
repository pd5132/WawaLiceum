"""
Eksport danych z WawaLiceumDB → app/data/*.json

Uruchomienie (Windows, z folderu repozytorium):
    python -m etl.export_json

Generuje 8 plików JSON do app/data/ używanych przez PWA.
"""

import json
from pathlib import Path

import pandas as pd

from etl.config import create_engine_connection

OUT_DIR = Path(__file__).parent.parent / "app" / "data"


def _dump(data: list, filename: str) -> None:
    path = OUT_DIR / filename
    path.write_text(json.dumps(data, ensure_ascii=False, default=str), encoding="utf-8")
    print(f"  [OK] {filename}  ({len(data)} wierszy)")


def export_schools(engine) -> None:
    df = pd.read_sql(
        """
        SELECT
            id_szkoly_rspo   AS id,
            nazwa_liceum     AS nazwa,
            adres,
            dzielnica,
            telefon,
            email,
            strona_www,
            CAST(wspolrzedne_lat  AS FLOAT) AS lat,
            CAST(wspolrzedne_long AS FLOAT) AS lon,
            organ_prowadzacy,
            czy_publiczna
        FROM dbo.Wymiar_Szkola
        ORDER BY nazwa_liceum
        """,
        engine,
    )
    _dump(df.where(df.notna(), None).to_dict(orient="records"), "schools.json")


def export_thresholds(engine) -> None:
    df = pd.read_sql(
        """
        SELECT
            f.id_szkoly_rspo,
            c.rok_kalendarzowy,
            f.symbol_oddzialu,
            f.nazwa_oddzialu,
            f.typ_oddzialu,
            CAST(f.prog_punktowy_min AS FLOAT) AS prog_punktowy_min,
            CAST(f.prog_punktowy_max AS FLOAT) AS prog_punktowy_max
        FROM dbo.Fakt_Rekrutacja_Wyniki f
        JOIN dbo.Wymiar_Czas c ON c.id_czas = f.id_czas
        ORDER BY f.id_szkoly_rspo, c.rok_kalendarzowy DESC, f.prog_punktowy_min DESC
        """,
        engine,
    )
    _dump(df.where(df.notna(), None).to_dict(orient="records"), "thresholds.json")


def export_ewd(engine) -> None:
    df = pd.read_sql(
        """
        SELECT
            f.id_szkoly_rspo,
            c.rok_kalendarzowy,
            t.nazwa_egzaminu,
            t.rodzaj_zapisu,
            CAST(f.ewd_oszacowanie_punktowe        AS FLOAT) AS ewd_oszacowanie_punktowe,
            CAST(f.ewd_gorna_granica_ufnosci       AS FLOAT) AS ewd_upper,
            CAST(f.ewd_dolna_granica_ufnosci       AS FLOAT) AS ewd_lower,
            CAST(f.egzamin_oszacowanie_punktowe    AS FLOAT) AS egzamin_oszacowanie,
            CAST(f.egzamin_gorna_granica_ufnosci   AS FLOAT) AS egzamin_upper,
            CAST(f.egzamin_dolna_granica_ufnosci   AS FLOAT) AS egzamin_lower
        FROM dbo.Fakt_Matura_EWD f
        JOIN dbo.Wymiar_Czas    c ON c.id_czas     = f.id_czas
        JOIN dbo.Wymiar_Typ_EWD t ON t.id_typu_ewd = f.id_typu_ewd
        ORDER BY f.id_szkoly_rspo, c.rok_kalendarzowy DESC
        """,
        engine,
    )
    _dump(df.where(df.notna(), None).to_dict(orient="records"), "ewd.json")


def export_ranking(engine) -> None:
    df = pd.read_sql(
        """
        SELECT
            f.id_szkoly_rspo,
            c.rok_kalendarzowy,
            f.pozycja_w_rankingu,
            CAST(f.wskaznik_sumaryczny AS FLOAT) AS wskaznik_sumaryczny
        FROM dbo.Fakt_Ranking_Perspektywy f
        JOIN dbo.Wymiar_Czas c ON c.id_czas = f.id_czas
        ORDER BY f.id_szkoly_rspo, c.rok_kalendarzowy DESC
        """,
        engine,
    )
    _dump(df.where(df.notna(), None).to_dict(orient="records"), "ranking.json")


def export_matura(engine) -> None:
    df = pd.read_sql(
        """
        SELECT
            f.id_szkoly_rspo,
            c.rok_kalendarzowy,
            p.nazwa_przedmiotu,
            p.poziom,
            f.liczba_zdajacych,
            CAST(f.zdawalnosc_proc    AS FLOAT) AS zdawalnosc_proc,
            CAST(f.sredni_wynik_proc  AS FLOAT) AS sredni_wynik_proc
        FROM dbo.Fakt_Matura_Statystyki_Szczegolowe f
        JOIN dbo.Wymiar_Czas               c ON c.id_czas      = f.id_czas
        JOIN dbo.Wymiar_Przedmiot_Maturalny p ON p.id_przedmiotu = f.id_przedmiotu
        ORDER BY f.id_szkoly_rspo, c.rok_kalendarzowy DESC, p.nazwa_przedmiotu
        """,
        engine,
    )
    _dump(df.where(df.notna(), None).to_dict(orient="records"), "matura.json")


def export_atmosfera(engine) -> None:
    df = pd.read_sql(
        """
        SELECT
            id_szkoly_rspo,
            atmosfera_proc,
            przyjemnosc_nauki_proc,
            relacje_uczniow_proc,
            relacja_nauczyciel_proc,
            nowoczesnosc_zajec_proc,
            polecanie_szkoly_proc,
            jakosc_odpoczynku_proc,
            liczba_ankiet,
            -- flagi infrastrukturalne (27 bitów)
            czy_strefa_ciszy, czy_miejsce_odpoczynku, czy_ciche_dzwonki,
            czy_rozowa_skrzyneczka, czy_szafki_uczniow, czy_stojak_na_rowery,
            czy_teren_zielony, czy_otwarte_boiska, czy_sklepik_szkolny,
            czy_bufet_stolowka, czy_posilki_wegetarianskie, czy_posilki_weganskie,
            czy_zrodlo_wody_pitnej, czy_monitoring, czy_wejscie_na_karty,
            czy_rejestracja_gosci, czy_rzecznik_praw_ucznia, czy_pielegniarka,
            czy_psycholog_na_etacie, czy_pedagog_specjalny, czy_osoba_zaufania,
            czy_zajecia_tus, czy_rewalidacja, czy_winda, czy_podjazd_dla_wozkow,
            czy_petla_indukcyjna, czy_schodolaz,
            czy_wifi_dla_uczniow, czy_metoda_projektu, czy_gry_edukacyjne,
            czy_ai_nowe_technologie, czy_mapy_mysli,
            czy_edukacja_antydyskryminacyjna, czy_metoda_steam,
            czy_drukarka_dla_uczniow, czy_przystanek_mpk, czy_silownia,
            liczba_uczniow, czas_nauki_po_lekcjach_min
        FROM dbo.Wymiar_Atmosfera
        ORDER BY id_szkoly_rspo
        """,
        engine,
    )
    # Zamień BIT (0/1) na bool
    bit_cols = [c for c in df.columns if c.startswith("czy_")]
    df[bit_cols] = df[bit_cols].astype(bool)
    _dump(df.where(df.notna(), None).to_dict(orient="records"), "atmosfera.json")


def export_inicjatywy(engine) -> None:
    df = pd.read_sql(
        """
        SELECT
            m.id_szkoly_rspo,
            i.nazwa_elementu,
            i.typ_inicjatywy
        FROM dbo.Mostek_Szkola_Inicjatywy m
        JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i ON i.id_inicjatywy = m.id_inicjatywy
        ORDER BY m.id_szkoly_rspo, i.typ_inicjatywy, i.nazwa_elementu
        """,
        engine,
    )
    _dump(df.where(df.notna(), None).to_dict(orient="records"), "inicjatywy.json")


def export_plan_naboru(engine) -> None:
    df = pd.read_sql(
        """
        SELECT
            f.id_szkoly_rspo,
            c.rok_kalendarzowy,
            f.typ_oddzialu,
            f.jezyk_dwujezyczny,
            f.liczba_oddzialow,
            f.liczba_miejsc
        FROM dbo.Fakt_Plan_Naboru f
        JOIN dbo.Wymiar_Czas c ON c.id_czas = f.id_czas
        ORDER BY f.id_szkoly_rspo, f.typ_oddzialu
        """,
        engine,
    )
    _dump(df.where(df.notna(), None).to_dict(orient="records"), "plan_naboru.json")


def main() -> None:
    print("=== Eksport WawaLiceumDB → app/data/ ===")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    engine = create_engine_connection()

    export_schools(engine)
    export_thresholds(engine)
    export_ewd(engine)
    export_ranking(engine)
    export_matura(engine)
    export_atmosfera(engine)
    export_inicjatywy(engine)
    export_plan_naboru(engine)

    print(f"\nGotowe. Pliki w: {OUT_DIR.resolve()}")
    print("Następny krok: git add app/data/*.json && git push")


if __name__ == "__main__":
    main()

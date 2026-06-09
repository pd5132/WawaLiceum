-- Phase 5: staging → dimension tables
-- Run AFTER 00_create_warehouse.sql and after all staging tables are loaded.
USE [WawaLiceumDB];
GO

-- ============================================================
-- Pre-clean: empty referencing tables so TRUNCATE on dims succeeds.
-- SQL Server blocks TRUNCATE on any table referenced by FK constraints.
-- ============================================================
TRUNCATE TABLE dbo.Fakt_Matura_EWD;
TRUNCATE TABLE dbo.Fakt_Matura_Statystyki_Szczegolowe;
TRUNCATE TABLE dbo.Fakt_Rekrutacja_Wyniki;
TRUNCATE TABLE dbo.Fakt_Plan_Naboru;
TRUNCATE TABLE dbo.Fakt_Ranking_Perspektywy;
DELETE  FROM  dbo.Mostek_Szkola_Inicjatywy;
TRUNCATE TABLE dbo.Wymiar_Atmosfera;
GO

-- ============================================================
-- Wymiar_Czas
-- Years from: matura (2025), ranking (2023-2026), progi PDFs (2023-2025),
-- plan naboru (2026/2027 → rok 2026)
-- ============================================================
DELETE FROM dbo.Wymiar_Czas;

INSERT INTO dbo.Wymiar_Czas (id_czas, rok_kalendarzowy, rok_szkolny)
SELECT rok, rok, CONCAT(rok - 1, '/', rok)
FROM (
    SELECT DISTINCT TRY_CAST(rok_kalendarzowy AS int) AS rok
    FROM dbo.stg_matura
    WHERE TRY_CAST(rok_kalendarzowy AS int) IS NOT NULL

    UNION

    SELECT DISTINCT rok_rankingu
    FROM dbo.stg_ranking
    WHERE rok_rankingu IS NOT NULL

    UNION

    SELECT DISTINCT rok
    FROM dbo.stg_progi
    WHERE rok IS NOT NULL

    UNION

    SELECT DISTINCT TRY_CAST(rok AS int)
    FROM dbo.stg_ewd
    WHERE rok IS NOT NULL

    UNION SELECT 2026
) years
WHERE rok IS NOT NULL;


-- ============================================================
-- Wymiar_Szkola  (from stg_rspo)
-- ============================================================
DELETE FROM dbo.Wymiar_Szkola;

INSERT INTO dbo.Wymiar_Szkola (
    id_szkoly_rspo, regon, nazwa_liceum, adres, dzielnica,
    organ_prowadzacy, dyrektor_imie_nazwisko, data_zalozenia,
    czy_samodzielna, czy_publiczna, rodzaj_placowki,
    kod_teryt_gminy, telefon, email, strona_www,
    wspolrzedne_lat, wspolrzedne_long
)
SELECT
    TRY_CAST(r.numer_rspo AS int),
    LEFT(ISNULL(r.regon, ''), 14),
    r.nazwa,
    CONCAT(ISNULL(r.ulica,''), ' ', ISNULL(r.numer_budynku,''), ', ',
           ISNULL(r.kod_pocztowy,''), ' ', ISNULL(r.miejscowosc,'')),
    ISNULL(r.gmina, r.miejscowosc),
    ISNULL(r.nazwa_organu_prowadzacego, ''),
    r.imie_i_nazwisko_dyrektora,
    TRY_CAST(r.data_zaozenia AS date),
    CASE WHEN LOWER(ISNULL(r.miejsce_w_strukturze,'')) = 'samodzielna' THEN 1 ELSE 0 END,
    CASE WHEN LOWER(ISNULL(r.publicznosc_status,'')) = 'publiczna'     THEN 1 ELSE 0 END,
    r.specyfika_placowki,
    CAST(r.kod_terytorialny_gmina AS varchar(10)),
    LEFT(ISNULL(r.telefon,''), 30),
    LEFT(ISNULL(r.e_mail,''), 100),
    LEFT(ISNULL(r.strona_www,''), 255),
    TRY_CAST(w.lat  AS decimal(9,6)),
    TRY_CAST(w.lon  AS decimal(9,6))
FROM dbo.stg_rspo r
LEFT JOIN dbo.stg_wiki_coords w ON w.numer_rspo = r.numer_rspo
WHERE TRY_CAST(r.numer_rspo AS int) IS NOT NULL;


-- ============================================================
-- Wymiar_Przedmiot_Maturalny  (from stg_matura distinct pairs)
-- ============================================================
DELETE FROM dbo.Wymiar_Przedmiot_Maturalny;

INSERT INTO dbo.Wymiar_Przedmiot_Maturalny (nazwa_przedmiotu, poziom)
SELECT DISTINCT
    LOWER(TRIM(nazwa_przedmiotu)),
    LOWER(TRIM(ISNULL(poziom, poziom_src)))
FROM dbo.stg_matura
WHERE nazwa_przedmiotu IS NOT NULL;


-- ============================================================
-- Wymiar_Typ_EWD  (humanistyczny / matematyczny / combined)
-- ============================================================
DELETE FROM dbo.Wymiar_Typ_EWD;

INSERT INTO dbo.Wymiar_Typ_EWD (nazwa_egzaminu, rodzaj_zapisu)
SELECT DISTINCT
    LOWER(TRIM(ISNULL(e.nazwa_wskaznika, e.typ_ewd))),   -- human name, e.g. "matematyka – od 2024"
    LOWER(TRIM(ISNULL(e.typ_ewd, '')))                   -- indicator code, e.g. "mlm_bk23l"
FROM dbo.stg_ewd e
WHERE e.typ_ewd IS NOT NULL AND e.typ_ewd <> '';


-- ============================================================
-- Wymiar_Atmosfera  (from stg_atmosfera, one row per school)
-- ============================================================
TRUNCATE TABLE dbo.Wymiar_Atmosfera;

INSERT INTO dbo.Wymiar_Atmosfera (
    id_szkoly_rspo,
    atmosfera_proc, przyjemnosc_nauki_proc, relacje_uczniow_proc,
    relacja_nauczyciel_proc, nowoczesnosc_zajec_proc, polecanie_szkoly_proc,
    jakosc_odpoczynku_proc, liczba_ankiet,
    czy_strefa_ciszy, czy_miejsce_odpoczynku, czy_ciche_dzwonki,
    czy_rozowa_skrzyneczka, czy_szafki_uczniow, czy_stojak_na_rowery,
    czy_teren_zielony, czy_otwarte_boiska, czy_sklepik_szkolny,
    czy_bufet_stolowka, czy_psycholog_na_etacie, czy_pedagog_specjalny,
    czy_winda, czy_podjazd_dla_wozkow, czy_monitoring,
    czy_posilki_wegetarianskie, czy_posilki_weganskie,
    czy_zrodlo_wody_pitnej, czy_wejscie_na_karty,
    czy_rejestracja_gosci, czy_rzecznik_praw_ucznia,
    czy_pielegniarka, czy_osoba_zaufania, czy_zajecia_tus,
    czy_rewalidacja, czy_petla_indukcyjna, czy_schodolaz
)
SELECT
    TRY_CAST(rspo_szkoly AS int),
    TRY_CAST(atmosfera_proc           AS decimal(5,2)),
    TRY_CAST(przyjemnosc_nauki_proc   AS decimal(5,2)),
    TRY_CAST(relacje_uczniow_proc     AS decimal(5,2)),
    TRY_CAST(relacja_nauczyciel_proc  AS decimal(5,2)),
    TRY_CAST(nowoczesnosc_zajec_proc  AS decimal(5,2)),
    TRY_CAST(polecanie_szkoly_proc    AS decimal(5,2)),
    TRY_CAST(jakosc_odpoczynku_proc   AS decimal(5,2)),
    TRY_CAST(liczba_ankiet            AS int),
    ISNULL(TRY_CAST(czy_strefa_ciszy          AS bit), 0),
    ISNULL(TRY_CAST(czy_miejsce_odpoczynku    AS bit), 0),
    ISNULL(TRY_CAST(czy_ciche_dzwonki        AS bit), 0),
    ISNULL(TRY_CAST(czy_rozowa_skrzyneczka    AS bit), 0),
    ISNULL(TRY_CAST(czy_szafki_uczniow        AS bit), 0),
    ISNULL(TRY_CAST(czy_stojak_na_rowery      AS bit), 0),
    ISNULL(TRY_CAST(czy_teren_zielony         AS bit), 0),
    ISNULL(TRY_CAST(czy_otwarte_boiska        AS bit), 0),
    ISNULL(TRY_CAST(czy_sklepik_szkolny       AS bit), 0),
    ISNULL(TRY_CAST(czy_bufet_stolowka        AS bit), 0),
    ISNULL(TRY_CAST(czy_psycholog_na_etacie   AS bit), 0),
    ISNULL(TRY_CAST(czy_pedagog_specjalny     AS bit), 0),
    ISNULL(TRY_CAST(czy_winda                 AS bit), 0),
    ISNULL(TRY_CAST(czy_podjazd_dla_wozkow    AS bit), 0),
    ISNULL(TRY_CAST(czy_monitoring            AS bit), 0),
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  -- remaining flags default 0
FROM dbo.stg_atmosfera;

-- Insert Wymiar_Atmosfera rows for schools that have Informator data but no swiadomiewybieram entry
INSERT INTO dbo.Wymiar_Atmosfera (id_szkoly_rspo)
SELECT x.id_szkoly_rspo
FROM dbo.stg_school_xref x
WHERE x.source = 'informator'
  AND x.id_szkoly_rspo IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Wymiar_Atmosfera a WHERE a.id_szkoly_rspo = x.id_szkoly_rspo);

-- Overlay bit flags from Informator PDF (higher authority than web-scraped swiadomiewybieram data)
UPDATE a SET
    a.czy_strefa_ciszy              = CASE WHEN f.czy_strefa_ciszy             = 1 THEN 1 ELSE a.czy_strefa_ciszy              END,
    a.czy_miejsce_odpoczynku        = CASE WHEN f.czy_miejsce_odpoczynku       = 1 THEN 1 ELSE a.czy_miejsce_odpoczynku        END,
    a.czy_ciche_dzwonki             = CASE WHEN f.czy_ciche_dzwonki            = 1 THEN 1 ELSE a.czy_ciche_dzwonki             END,
    a.czy_rozowa_skrzyneczka        = CASE WHEN f.czy_rozowa_skrzyneczka       = 1 THEN 1 ELSE a.czy_rozowa_skrzyneczka        END,
    a.czy_szafki_uczniow            = CASE WHEN f.czy_szafki_uczniow           = 1 THEN 1 ELSE a.czy_szafki_uczniow            END,
    a.czy_stojak_na_rowery          = CASE WHEN f.czy_stojak_na_rowery         = 1 THEN 1 ELSE a.czy_stojak_na_rowery          END,
    a.czy_teren_zielony             = CASE WHEN f.czy_teren_zielony            = 1 THEN 1 ELSE a.czy_teren_zielony             END,
    a.czy_otwarte_boiska            = CASE WHEN f.czy_otwarte_boiska           = 1 THEN 1 ELSE a.czy_otwarte_boiska            END,
    a.czy_sklepik_szkolny           = CASE WHEN f.czy_sklepik_szkolny          = 1 THEN 1 ELSE a.czy_sklepik_szkolny           END,
    a.czy_bufet_stolowka            = CASE WHEN f.czy_bufet_stolowka           = 1 THEN 1 ELSE a.czy_bufet_stolowka            END,
    a.czy_posilki_wegetarianskie    = CASE WHEN f.czy_posilki_wegetarianskie   = 1 THEN 1 ELSE a.czy_posilki_wegetarianskie    END,
    a.czy_posilki_weganskie         = CASE WHEN f.czy_posilki_weganskie        = 1 THEN 1 ELSE a.czy_posilki_weganskie         END,
    a.czy_zrodlo_wody_pitnej        = CASE WHEN f.czy_zrodlo_wody_pitnej       = 1 THEN 1 ELSE a.czy_zrodlo_wody_pitnej        END,
    a.czy_monitoring                = CASE WHEN f.czy_monitoring               = 1 THEN 1 ELSE a.czy_monitoring                END,
    a.czy_wejscie_na_karty          = CASE WHEN f.czy_wejscie_na_karty         = 1 THEN 1 ELSE a.czy_wejscie_na_karty          END,
    a.czy_rejestracja_gosci         = CASE WHEN f.czy_rejestracja_gosci        = 1 THEN 1 ELSE a.czy_rejestracja_gosci         END,
    a.czy_winda                     = CASE WHEN f.czy_winda                    = 1 THEN 1 ELSE a.czy_winda                     END,
    a.czy_podjazd_dla_wozkow        = CASE WHEN f.czy_podjazd_dla_wozkow       = 1 THEN 1 ELSE a.czy_podjazd_dla_wozkow        END,
    a.czy_petla_indukcyjna          = CASE WHEN f.czy_petla_indukcyjna         = 1 THEN 1 ELSE a.czy_petla_indukcyjna          END,
    a.czy_schodolaz                 = CASE WHEN f.czy_schodolaz                = 1 THEN 1 ELSE a.czy_schodolaz                 END,
    a.czy_rzecznik_praw_ucznia      = CASE WHEN f.czy_rzecznik_praw_ucznia     = 1 THEN 1 ELSE a.czy_rzecznik_praw_ucznia      END,
    a.czy_pielegniarka              = CASE WHEN f.czy_pielegniarka             = 1 THEN 1 ELSE a.czy_pielegniarka              END,
    a.czy_psycholog_na_etacie       = CASE WHEN f.czy_psycholog_na_etacie      = 1 THEN 1 ELSE a.czy_psycholog_na_etacie       END,
    a.czy_pedagog_specjalny         = CASE WHEN f.czy_pedagog_specjalny        = 1 THEN 1 ELSE a.czy_pedagog_specjalny         END,
    a.czy_osoba_zaufania            = CASE WHEN f.czy_osoba_zaufania           = 1 THEN 1 ELSE a.czy_osoba_zaufania            END,
    a.czy_zajecia_tus               = CASE WHEN f.czy_zajecia_tus              = 1 THEN 1 ELSE a.czy_zajecia_tus               END,
    a.czy_rewalidacja               = CASE WHEN f.czy_rewalidacja              = 1 THEN 1 ELSE a.czy_rewalidacja               END
FROM dbo.Wymiar_Atmosfera a
JOIN dbo.stg_school_xref x ON x.id_szkoly_rspo = a.id_szkoly_rspo AND x.source = 'informator'
JOIN dbo.stg_informator_flags f ON f.nazwa_szkoly_informator = x.source_name;


-- ============================================================
-- Wymiar_Inicjatywy_Zewnetrzne + Mostek_Szkola_Inicjatywy
-- Source: stg_informator_inicjatywy (text items from Informator PDF)
-- ============================================================
DELETE FROM dbo.Mostek_Szkola_Inicjatywy;
DELETE FROM dbo.Wymiar_Inicjatywy_Zewnetrzne;

INSERT INTO dbo.Wymiar_Inicjatywy_Zewnetrzne (nazwa_elementu, typ_inicjatywy)
SELECT DISTINCT
    LEFT(TRIM(element), 255),
    sekcja
FROM dbo.stg_informator_inicjatywy
WHERE element IS NOT NULL AND TRIM(element) <> '';

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT DISTINCT
    x.id_szkoly_rspo,
    i.id_inicjatywy
FROM dbo.stg_informator_inicjatywy ini
JOIN dbo.stg_school_xref x
    ON x.source = 'informator' AND x.source_name = ini.nazwa_szkoly_informator
JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
    ON i.nazwa_elementu = LEFT(TRIM(ini.element), 255)
   AND i.typ_inicjatywy = ini.sekcja
WHERE x.id_szkoly_rspo IS NOT NULL;
GO

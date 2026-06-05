-- Phase 5: staging → dimension tables
-- Run AFTER 00_create_warehouse.sql and after all staging tables are loaded.
USE [WawaLiceumDB];
GO

-- ============================================================
-- Wymiar_Czas
-- Populated from distinct years found in matura data + ranking
-- ============================================================
TRUNCATE TABLE dbo.Wymiar_Czas;

INSERT INTO dbo.Wymiar_Czas (id_czas, rok_kalendarzowy, rok_szkolny)
SELECT DISTINCT
    TRY_CAST(rok_kalendarzowy AS int)                        AS id_czas,
    TRY_CAST(rok_kalendarzowy AS int)                        AS rok_kalendarzowy,
    ISNULL(rok_szkolny, CONCAT(TRY_CAST(rok_kalendarzowy AS int)-1, '/', TRY_CAST(rok_kalendarzowy AS int))) AS rok_szkolny
FROM dbo.stg_matura
WHERE TRY_CAST(rok_kalendarzowy AS int) IS NOT NULL
UNION
SELECT DISTINCT
    rok_rankingu, rok_rankingu,
    CONCAT(rok_rankingu-1, '/', rok_rankingu)
FROM dbo.stg_ranking
WHERE rok_rankingu IS NOT NULL;


-- ============================================================
-- Wymiar_Szkola  (from stg_rspo)
-- ============================================================
TRUNCATE TABLE dbo.Wymiar_Szkola;

INSERT INTO dbo.Wymiar_Szkola (
    id_szkoly_rspo, regon, nazwa_liceum, adres, dzielnica,
    organ_prowadzacy, dyrektor_imie_nazwisko, data_zalozenia,
    czy_samodzielna, czy_publiczna, rodzaj_placowki,
    kod_teryt_gminy, telefon, email, strona_www
)
SELECT
    TRY_CAST(numer_rspo AS int),
    LEFT(ISNULL(regon, ''), 14),
    nazwa,
    CONCAT(ISNULL(ulica,''), ' ', ISNULL(numer_budynku,''), ', ',
           ISNULL(kod_pocztowy,''), ' ', ISNULL(miejscowosc,'')),
    -- Dzielnica derived from gmina column
    ISNULL(gmina, miejscowosc),
    ISNULL(nazwa_organu_prowadzacego, ''),
    imie_i_nazwisko_dyrektora,
    TRY_CAST(data_zalozenia AS date),
    CASE WHEN LOWER(ISNULL(miejsce_w_strukturze,'')) = 'samodzielna' THEN 1 ELSE 0 END,
    CASE WHEN LOWER(ISNULL(publicznosc_status,'')) = 'publiczna'    THEN 1 ELSE 0 END,
    specyfika_placowki,
    CAST(kod_terytorialny_gmina AS varchar(10)),
    LEFT(ISNULL(telefon,''), 30),
    LEFT(ISNULL(e_mail,''), 100),
    LEFT(ISNULL(strona_www,''), 255)
FROM dbo.stg_rspo
WHERE TRY_CAST(numer_rspo AS int) IS NOT NULL;


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
    LOWER(TRIM(ISNULL(typ_ewd, ''))),
    LOWER(TRIM(ISNULL(typ_ewd, '')))
FROM dbo.stg_ewd
WHERE typ_ewd IS NOT NULL AND typ_ewd <> '';


-- ============================================================
-- Wymiar_Profil  (from stg_plan_naboru)
-- ============================================================
DELETE FROM dbo.Wymiar_Profil;

INSERT INTO dbo.Wymiar_Profil (symbol_oddzialu, nazwa_oddzialu, typ_oddzialu)
SELECT DISTINCT
    ISNULL(jezyk_lub_zawod, typ_oddzialu),
    ISNULL(jezyk_lub_zawod, typ_oddzialu),
    LEFT(ISNULL(typ_oddzialu, 'O'), 2)
FROM dbo.stg_plan_naboru;


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
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  -- remaining flags default 0
FROM dbo.stg_atmosfera;
GO

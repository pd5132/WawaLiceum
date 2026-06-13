-- ============================================================
-- WawaLiceumDB — PELNY SKRYPT SQL
-- Hurtownia danych dla projektu WawaLiceum
--
-- Zawiera:
--   CZESC 1: DDL — tworzenie schematu bazy (schemat gwiazdkowy)
--   CZESC 2: ETL WYMIARY — ladowanie stagingu do tabel wymiarow
--   CZESC 3: ETL FAKTY — ladowanie stagingu do tabel faktow
--   CZESC 4: CZYSZCZENIE — usuniecie szkol nieistotnych
--             (specjalne, zaoczne, dla doroslych)
--   CZESC 5: INICJATYWY MIEDZYNARODOWE — metadane szkol bez danych CKE
--   CZESC 6: WALIDACJA I ZAPYTANIA ANALITYCZNE
--
-- Wymagania wstepne:
--   - Baza WawaLiceumDB musi istniec: CREATE DATABASE WawaLiceumDB
--   - Tabele staging (stg_*) musza byc zaladowane przez Python ETL
--     (python -m etl.load_staging) przed uruchomieniem CZESCI 2-5
--
-- Kolejnosc uruchomienia:
--   1. Uruchom CZESC 1 (jednorazowo lub przy przebudowie schematu)
--   2. Uruchom Python ETL: python -m etl.load_staging
--   3. Uruchom CZESCI 2-6 po kolei
-- ============================================================

USE [WawaLiceumDB];
GO


-- ============================================================
-- CZESC 1: DDL — SCHEMAT BAZY DANYCH
-- ============================================================

-- ------------------------------------------------------------
-- DROP (odwrotna kolejnosc FK)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dbo.Fakt_Matura_EWD;
DROP TABLE IF EXISTS dbo.Wymiar_Profil;
DROP TABLE IF EXISTS dbo.Fakt_Matura_Statystyki_Szczegolowe;
DROP TABLE IF EXISTS dbo.Fakt_Rekrutacja_Wyniki;
DROP TABLE IF EXISTS dbo.Fakt_Plan_Naboru;
DROP TABLE IF EXISTS dbo.Fakt_Ranking_Perspektywy;
DROP TABLE IF EXISTS dbo.Mostek_Szkola_Inicjatywy;
DROP TABLE IF EXISTS dbo.Wymiar_Inicjatywy_Zewnetrzne;
DROP TABLE IF EXISTS dbo.Wymiar_Typ_EWD;
DROP TABLE IF EXISTS dbo.Wymiar_Przedmiot_Maturalny;
DROP TABLE IF EXISTS dbo.Wymiar_Atmosfera;
DROP TABLE IF EXISTS dbo.Wymiar_Szkola;
DROP TABLE IF EXISTS dbo.Wymiar_Czas;
GO

-- ------------------------------------------------------------
-- WYMIARY
-- ------------------------------------------------------------

CREATE TABLE dbo.Wymiar_Czas (
    id_czas           int          NOT NULL,
    rok_kalendarzowy  int          NOT NULL,
    rok_szkolny       nvarchar(20) NOT NULL,
    CONSTRAINT PK_Wymiar_Czas PRIMARY KEY (id_czas)
);

CREATE TABLE dbo.Wymiar_Szkola (
    id_szkoly_rspo          int           NOT NULL,
    id_zespolu_rspo         int           NULL,
    id_oke                  int           NULL,
    regon                   char(14)      NOT NULL,
    nazwa_liceum            nvarchar(255) NOT NULL,
    nazwa_zespolu_szkol     nvarchar(255) NULL,
    adres                   nvarchar(255) NOT NULL,
    dzielnica               nvarchar(50)  NOT NULL,
    organ_prowadzacy        nvarchar(255) NOT NULL,
    dyrektor_imie_nazwisko  nvarchar(150) NULL,
    data_zalozenia          date          NULL,
    czy_samodzielna         bit           NOT NULL,
    czy_publiczna           bit           NULL,
    rodzaj_placowki         nvarchar(100) NULL,
    kod_teryt_gminy         varchar(10)   NULL,
    telefon                 varchar(30)   NULL,
    email                   varchar(100)  NULL,
    strona_www              varchar(255)  NULL,
    wspolrzedne_lat         decimal(9,6)  NULL,
    wspolrzedne_long        decimal(9,6)  NULL,
    CONSTRAINT PK_Wymiar_Szkola PRIMARY KEY (id_szkoly_rspo)
);

CREATE TABLE dbo.Wymiar_Atmosfera (
    id_atmosfera                int          IDENTITY(1,1) NOT NULL,
    id_szkoly_rspo              int          NOT NULL,
    -- Flagi infrastruktury (zrodlo: swiadomiewybieram.pl + Informator PDF)
    czy_strefa_ciszy            bit          NOT NULL DEFAULT 0,
    czy_miejsce_odpoczynku      bit          NOT NULL DEFAULT 0,
    czy_ciche_dzwonki           bit          NOT NULL DEFAULT 0,
    czy_rozowa_skrzyneczka      bit          NOT NULL DEFAULT 0,
    czy_szafki_uczniow          bit          NOT NULL DEFAULT 0,
    czy_stojak_na_rowery        bit          NOT NULL DEFAULT 0,
    czy_teren_zielony           bit          NOT NULL DEFAULT 0,
    czy_otwarte_boiska          bit          NOT NULL DEFAULT 0,
    czy_wifi_dla_uczniow        bit          NOT NULL DEFAULT 0,
    czy_sklepik_szkolny         bit          NOT NULL DEFAULT 0,
    czy_bufet_stolowka          bit          NOT NULL DEFAULT 0,
    czy_posilki_wegetarianskie  bit          NOT NULL DEFAULT 0,
    czy_posilki_weganskie       bit          NOT NULL DEFAULT 0,
    czy_zrodlo_wody_pitnej      bit          NOT NULL DEFAULT 0,
    czy_monitoring              bit          NOT NULL DEFAULT 0,
    czy_wejscie_na_karty        bit          NOT NULL DEFAULT 0,
    czy_rejestracja_gosci       bit          NOT NULL DEFAULT 0,
    czy_rzecznik_praw_ucznia    bit          NOT NULL DEFAULT 0,
    czy_pielegniarka            bit          NOT NULL DEFAULT 0,
    czy_psycholog_na_etacie     bit          NOT NULL DEFAULT 0,
    czy_pedagog_specjalny       bit          NOT NULL DEFAULT 0,
    czy_osoba_zaufania          bit          NOT NULL DEFAULT 0,
    czy_zajecia_tus             bit          NOT NULL DEFAULT 0,
    czy_rewalidacja             bit          NOT NULL DEFAULT 0,
    czy_winda                   bit          NOT NULL DEFAULT 0,
    czy_podjazd_dla_wozkow      bit          NOT NULL DEFAULT 0,
    czy_petla_indukcyjna        bit          NOT NULL DEFAULT 0,
    czy_schodolaz               bit          NOT NULL DEFAULT 0,
    -- Oceny atmosfery (% z ankiet uczniow)
    atmosfera_proc              decimal(5,2) NULL,
    przyjemnosc_nauki_proc      decimal(5,2) NULL,
    relacje_uczniow_proc        decimal(5,2) NULL,
    relacja_nauczyciel_proc     decimal(5,2) NULL,
    nowoczesnosc_zajec_proc     decimal(5,2) NULL,
    polecanie_szkoly_proc       decimal(5,2) NULL,
    jakosc_odpoczynku_proc      decimal(5,2) NULL,
    czas_nauki_po_lekcjach_min  int          NULL,
    liczba_ankiet               int          NULL,
    liczba_uczniow              int          NULL,
    czy_drukarka_dla_uczniow    bit          NOT NULL DEFAULT 0,
    czy_przystanek_mpk          bit          NOT NULL DEFAULT 0,
    czy_silownia                bit          NOT NULL DEFAULT 0,
    -- Aktywne metody nauczania (z Informatora PDF)
    czy_metoda_projektu             bit          NOT NULL DEFAULT 0,
    czy_gry_edukacyjne              bit          NOT NULL DEFAULT 0,
    czy_ai_nowe_technologie         bit          NOT NULL DEFAULT 0,
    czy_mapy_mysli                  bit          NOT NULL DEFAULT 0,
    czy_edukacja_antydyskryminacyjna bit         NOT NULL DEFAULT 0,
    czy_metoda_steam                bit          NOT NULL DEFAULT 0,
    CONSTRAINT PK_Wymiar_Atmosfera PRIMARY KEY (id_atmosfera),
    CONSTRAINT UQ_Atmosfera_Szkola UNIQUE (id_szkoly_rspo)
);

CREATE TABLE dbo.Wymiar_Przedmiot_Maturalny (
    id_przedmiotu    int           IDENTITY(1,1) NOT NULL,
    nazwa_przedmiotu nvarchar(100) NOT NULL,
    poziom           nvarchar(50)  NOT NULL,
    CONSTRAINT PK_Wymiar_Przedmiot PRIMARY KEY (id_przedmiotu),
    CONSTRAINT UQ_Przedmiot UNIQUE (nazwa_przedmiotu, poziom)
);

CREATE TABLE dbo.Wymiar_Typ_EWD (
    id_typu_ewd    int           IDENTITY(1,1) NOT NULL,
    nazwa_egzaminu nvarchar(100) NOT NULL,
    rodzaj_zapisu  nvarchar(50)  NOT NULL,
    CONSTRAINT PK_Wymiar_Typ_EWD PRIMARY KEY (id_typu_ewd),
    CONSTRAINT UQ_Typ_EWD UNIQUE (nazwa_egzaminu, rodzaj_zapisu)
);

CREATE TABLE dbo.Wymiar_Inicjatywy_Zewnetrzne (
    id_inicjatywy  int           IDENTITY(1,1) NOT NULL,
    nazwa_elementu nvarchar(255) NOT NULL,
    typ_inicjatywy nvarchar(50)  NOT NULL,
    CONSTRAINT PK_Wymiar_Inicjatywy PRIMARY KEY (id_inicjatywy)
);

-- ------------------------------------------------------------
-- MOSTEK (tabela pomostowa)
-- ------------------------------------------------------------

CREATE TABLE dbo.Mostek_Szkola_Inicjatywy (
    id_szkoly_rspo int NOT NULL,
    id_inicjatywy  int NOT NULL,
    CONSTRAINT PK_Mostek_Szkola_Inicjatywy PRIMARY KEY (id_szkoly_rspo, id_inicjatywy)
);

-- ------------------------------------------------------------
-- FAKTY
-- ------------------------------------------------------------

CREATE TABLE dbo.Fakt_Ranking_Perspektywy (
    id_rankingu         int           IDENTITY(1,1) NOT NULL,
    id_czas             int           NOT NULL,
    id_szkoly_rspo      int           NOT NULL,
    pozycja_w_rankingu  int           NULL,
    wskaznik_sumaryczny decimal(5,2)  NULL,
    CONSTRAINT PK_Fakt_Ranking_Perspektywy PRIMARY KEY (id_rankingu),
    CONSTRAINT UQ_Ranking UNIQUE (id_czas, id_szkoly_rspo)
);

-- Historyczne progi punktowe — 1 wiersz na (szkola, oddzial, rok).
-- Zrodlo: PDF-y z progami 2023-2025.
CREATE TABLE dbo.Fakt_Rekrutacja_Wyniki (
    id_fakt            int           IDENTITY(1,1) NOT NULL,
    id_szkoly_rspo     int           NOT NULL,
    id_czas            int           NOT NULL,
    symbol_oddzialu    nvarchar(50)  NOT NULL,
    nazwa_oddzialu     nvarchar(255) NOT NULL,
    typ_oddzialu       char(2)       NOT NULL,   -- O / D / MS
    prog_punktowy_min  decimal(5,2)  NULL,
    prog_punktowy_max  decimal(5,2)  NULL,
    CONSTRAINT PK_Fakt_Rekrutacja_Wyniki PRIMARY KEY (id_fakt),
    CONSTRAINT UQ_Rekrutacja UNIQUE (id_szkoly_rspo, id_czas, symbol_oddzialu)
);

-- Plan naboru 2026 — agregowane liczby miejsc per szkola i typ oddzialu.
CREATE TABLE dbo.Fakt_Plan_Naboru (
    id_plan            int          IDENTITY(1,1) NOT NULL,
    id_szkoly_rspo     int          NOT NULL,
    id_czas            int          NOT NULL,
    typ_oddzialu       char(2)      NOT NULL,   -- O / D / MS
    jezyk_dwujezyczny  nvarchar(50) NULL,
    liczba_oddzialow   int          NOT NULL,
    liczba_miejsc      int          NOT NULL,
    CONSTRAINT PK_Fakt_Plan_Naboru PRIMARY KEY (id_plan),
    CONSTRAINT UQ_Plan UNIQUE (id_szkoly_rspo, id_czas, typ_oddzialu, jezyk_dwujezyczny)
);

CREATE TABLE dbo.Fakt_Matura_Statystyki_Szczegolowe (
    id_fakt_matura                int          IDENTITY(1,1) NOT NULL,
    id_szkoly_rspo                int          NOT NULL,
    id_czas                       int          NOT NULL,
    id_przedmiotu                 int          NOT NULL,
    liczba_zdajacych              int          NULL,
    liczba_laureatow_finalistow   int          NULL,
    zdawalnosc_proc               decimal(5,2) NULL,
    sredni_wynik_proc             decimal(5,2) NULL,
    odchylenie_standardowe_proc   decimal(5,2) NULL,
    mediana_proc                  decimal(5,2) NULL,
    modalna_proc                  decimal(5,2) NULL,
    CONSTRAINT PK_Fakt_Matura_Szczegoly PRIMARY KEY (id_fakt_matura),
    CONSTRAINT UQ_Matura UNIQUE (id_szkoly_rspo, id_czas, id_przedmiotu)
);

CREATE TABLE dbo.Fakt_Matura_EWD (
    id_fakt_ewd                    int          IDENTITY(1,1) NOT NULL,
    id_szkoly_rspo                 int          NOT NULL,
    id_czas                        int          NOT NULL,
    id_typu_ewd                    int          NOT NULL,
    ewd_oszacowanie_punktowe       decimal(5,2) NULL,
    ewd_gorna_granica_ufnosci      decimal(5,2) NULL,
    ewd_dolna_granica_ufnosci      decimal(5,2) NULL,
    egzamin_oszacowanie_punktowe   decimal(5,2) NULL,
    egzamin_gorna_granica_ufnosci  decimal(5,2) NULL,
    egzamin_dolna_granica_ufnosci  decimal(5,2) NULL,
    typ_szkoly_ewd                 nvarchar(60) NULL,
    CONSTRAINT PK_Fakt_Matura_EWD PRIMARY KEY (id_fakt_ewd),
    CONSTRAINT UQ_EWD UNIQUE (id_szkoly_rspo, id_czas, id_typu_ewd)
);

-- ------------------------------------------------------------
-- KLUCZE OBCE
-- ------------------------------------------------------------

ALTER TABLE dbo.Wymiar_Atmosfera          ADD CONSTRAINT FK_Atmosfera_Szkola      FOREIGN KEY (id_szkoly_rspo) REFERENCES dbo.Wymiar_Szkola (id_szkoly_rspo);

ALTER TABLE dbo.Mostek_Szkola_Inicjatywy  ADD CONSTRAINT FK_Mostek_Szkola         FOREIGN KEY (id_szkoly_rspo) REFERENCES dbo.Wymiar_Szkola (id_szkoly_rspo);
ALTER TABLE dbo.Mostek_Szkola_Inicjatywy  ADD CONSTRAINT FK_Mostek_Inicjatywa     FOREIGN KEY (id_inicjatywy)  REFERENCES dbo.Wymiar_Inicjatywy_Zewnetrzne (id_inicjatywy);

ALTER TABLE dbo.Fakt_Ranking_Perspektywy  ADD CONSTRAINT FK_Ranking_Czas          FOREIGN KEY (id_czas)        REFERENCES dbo.Wymiar_Czas (id_czas);
ALTER TABLE dbo.Fakt_Ranking_Perspektywy  ADD CONSTRAINT FK_Ranking_Szkola        FOREIGN KEY (id_szkoly_rspo) REFERENCES dbo.Wymiar_Szkola (id_szkoly_rspo);

ALTER TABLE dbo.Fakt_Rekrutacja_Wyniki    ADD CONSTRAINT FK_Rekrutacja_Czas        FOREIGN KEY (id_czas)        REFERENCES dbo.Wymiar_Czas (id_czas);
ALTER TABLE dbo.Fakt_Rekrutacja_Wyniki    ADD CONSTRAINT FK_Rekrutacja_Szkola      FOREIGN KEY (id_szkoly_rspo) REFERENCES dbo.Wymiar_Szkola (id_szkoly_rspo);

ALTER TABLE dbo.Fakt_Plan_Naboru          ADD CONSTRAINT FK_Plan_Czas              FOREIGN KEY (id_czas)        REFERENCES dbo.Wymiar_Czas (id_czas);
ALTER TABLE dbo.Fakt_Plan_Naboru          ADD CONSTRAINT FK_Plan_Szkola            FOREIGN KEY (id_szkoly_rspo) REFERENCES dbo.Wymiar_Szkola (id_szkoly_rspo);

ALTER TABLE dbo.Fakt_Matura_Statystyki_Szczegolowe ADD CONSTRAINT FK_Szczegoly_Szkola    FOREIGN KEY (id_szkoly_rspo) REFERENCES dbo.Wymiar_Szkola (id_szkoly_rspo);
ALTER TABLE dbo.Fakt_Matura_Statystyki_Szczegolowe ADD CONSTRAINT FK_Szczegoly_Czas      FOREIGN KEY (id_czas)        REFERENCES dbo.Wymiar_Czas (id_czas);
ALTER TABLE dbo.Fakt_Matura_Statystyki_Szczegolowe ADD CONSTRAINT FK_Szczegoly_Przedmiot FOREIGN KEY (id_przedmiotu)  REFERENCES dbo.Wymiar_Przedmiot_Maturalny (id_przedmiotu);

ALTER TABLE dbo.Fakt_Matura_EWD           ADD CONSTRAINT FK_EWD_Szkola            FOREIGN KEY (id_szkoly_rspo) REFERENCES dbo.Wymiar_Szkola (id_szkoly_rspo);
ALTER TABLE dbo.Fakt_Matura_EWD           ADD CONSTRAINT FK_EWD_Czas              FOREIGN KEY (id_czas)        REFERENCES dbo.Wymiar_Czas (id_czas);
ALTER TABLE dbo.Fakt_Matura_EWD           ADD CONSTRAINT FK_EWD_Typ               FOREIGN KEY (id_typu_ewd)    REFERENCES dbo.Wymiar_Typ_EWD (id_typu_ewd);
GO


-- ============================================================
-- CZESC 2: ETL WYMIARY — stg_* → tabele wymiarow
-- Uruchom po zaladowaniu stagingu przez Python ETL
-- ============================================================

-- Oproznienie tabel faktow przed przebudowa wymiarow
-- (SQL Server blokuje TRUNCATE na tabelach z FK — DELETE omija to ograniczenie)
TRUNCATE TABLE dbo.Fakt_Matura_EWD;
TRUNCATE TABLE dbo.Fakt_Matura_Statystyki_Szczegolowe;
TRUNCATE TABLE dbo.Fakt_Rekrutacja_Wyniki;
TRUNCATE TABLE dbo.Fakt_Plan_Naboru;
TRUNCATE TABLE dbo.Fakt_Ranking_Perspektywy;
DELETE  FROM  dbo.Mostek_Szkola_Inicjatywy;
TRUNCATE TABLE dbo.Wymiar_Atmosfera;
GO

-- ------------------------------------------------------------
-- Wymiar_Czas
-- ------------------------------------------------------------
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


-- ------------------------------------------------------------
-- Wymiar_Szkola  (zrodlo: stg_rspo)
-- ------------------------------------------------------------
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


-- ------------------------------------------------------------
-- Wymiar_Przedmiot_Maturalny  (distinct pary z stg_matura)
-- ------------------------------------------------------------
DELETE FROM dbo.Wymiar_Przedmiot_Maturalny;

INSERT INTO dbo.Wymiar_Przedmiot_Maturalny (nazwa_przedmiotu, poziom)
SELECT DISTINCT
    LOWER(TRIM(nazwa_przedmiotu)),
    LOWER(TRIM(ISNULL(poziom, poziom_src)))
FROM dbo.stg_matura
WHERE nazwa_przedmiotu IS NOT NULL;


-- ------------------------------------------------------------
-- Wymiar_Typ_EWD
-- ------------------------------------------------------------
DELETE FROM dbo.Wymiar_Typ_EWD;

INSERT INTO dbo.Wymiar_Typ_EWD (nazwa_egzaminu, rodzaj_zapisu)
SELECT DISTINCT
    LOWER(TRIM(ISNULL(e.nazwa_wskaznika, e.typ_ewd))),
    LOWER(TRIM(ISNULL(e.typ_ewd, '')))
FROM dbo.stg_ewd e
WHERE e.typ_ewd IS NOT NULL AND e.typ_ewd <> '';


-- ------------------------------------------------------------
-- Wymiar_Atmosfera
-- Zrodlo: stg_atmosfera (swiadomiewybieram.pl)
-- Nakladka: stg_informator_flags (Informator PDF — wyzszy priorytet)
-- ------------------------------------------------------------
TRUNCATE TABLE dbo.Wymiar_Atmosfera;

INSERT INTO dbo.Wymiar_Atmosfera (
    id_szkoly_rspo,
    czy_strefa_ciszy, czy_miejsce_odpoczynku, czy_ciche_dzwonki,
    czy_rozowa_skrzyneczka, czy_szafki_uczniow, czy_stojak_na_rowery,
    czy_teren_zielony, czy_otwarte_boiska,
    czy_sklepik_szkolny, czy_bufet_stolowka,
    czy_posilki_wegetarianskie, czy_posilki_weganskie, czy_zrodlo_wody_pitnej,
    czy_monitoring, czy_wejscie_na_karty, czy_rejestracja_gosci,
    czy_rzecznik_praw_ucznia, czy_pielegniarka,
    czy_psycholog_na_etacie, czy_pedagog_specjalny,
    czy_osoba_zaufania, czy_zajecia_tus, czy_rewalidacja,
    czy_winda, czy_podjazd_dla_wozkow,
    czy_petla_indukcyjna, czy_schodolaz,
    atmosfera_proc, przyjemnosc_nauki_proc, relacje_uczniow_proc,
    relacja_nauczyciel_proc, nowoczesnosc_zajec_proc,
    polecanie_szkoly_proc, jakosc_odpoczynku_proc,
    czas_nauki_po_lekcjach_min, liczba_ankiet,
    czy_wifi_dla_uczniow,
    czy_metoda_projektu, czy_gry_edukacyjne, czy_ai_nowe_technologie,
    czy_mapy_mysli, czy_edukacja_antydyskryminacyjna, czy_metoda_steam,
    liczba_uczniow, czy_drukarka_dla_uczniow, czy_przystanek_mpk, czy_silownia
)
SELECT
    TRY_CAST(rspo_szkoly AS int),
    ISNULL(TRY_CAST(czy_strefa_ciszy         AS bit), 0),
    ISNULL(TRY_CAST(czy_miejsce_odpoczynku   AS bit), 0),
    ISNULL(TRY_CAST(czy_ciche_dzwonki        AS bit), 0),
    ISNULL(TRY_CAST(czy_rozowa_skrzyneczka   AS bit), 0),
    ISNULL(TRY_CAST(czy_szafki_uczniow       AS bit), 0),
    ISNULL(TRY_CAST(czy_stojak_na_rowery     AS bit), 0),
    ISNULL(TRY_CAST(czy_teren_zielony        AS bit), 0),
    ISNULL(TRY_CAST(czy_otwarte_boiska       AS bit), 0),
    ISNULL(TRY_CAST(czy_sklepik_szkolny      AS bit), 0),
    ISNULL(TRY_CAST(czy_bufet_stolowka       AS bit), 0),
    CAST(0 AS bit), CAST(0 AS bit), CAST(0 AS bit),  -- posilki_wege/wegan/zrodlo_wody: via Informator overlay
    ISNULL(TRY_CAST(czy_monitoring           AS bit), 0),
    CAST(0 AS bit), CAST(0 AS bit),                   -- wejscie_na_karty, rejestracja_gosci: via Informator
    ISNULL(TRY_CAST(czy_rzecznik_praw_ucznia AS bit), 0),
    ISNULL(TRY_CAST(czy_pielegniarka         AS bit), 0),
    ISNULL(TRY_CAST(czy_psycholog_na_etacie  AS bit), 0),
    ISNULL(TRY_CAST(czy_pedagog_specjalny    AS bit), 0),
    CAST(0 AS bit), CAST(0 AS bit), CAST(0 AS bit),  -- osoba_zaufania, zajecia_tus, rewalidacja
    ISNULL(TRY_CAST(czy_winda                AS bit), 0),
    ISNULL(TRY_CAST(czy_podjazd_dla_wozkow   AS bit), 0),
    CAST(0 AS bit), CAST(0 AS bit),                   -- petla_indukcyjna, schodolaz
    TRY_CAST(atmosfera_proc AS decimal(5,2)),
    TRY_CAST(przyjemnosc_nauki_proc AS decimal(5,2)),
    TRY_CAST(relacje_uczniow_proc AS decimal(5,2)),
    TRY_CAST(REPLACE(CAST(relacja_nauczyciel_proc AS varchar(20)), ',', '.') AS decimal(5,2)),
    TRY_CAST(REPLACE(CAST(nowoczesnosc_zajec_proc AS varchar(20)), ',', '.') AS decimal(5,2)),
    TRY_CAST(polecanie_szkoly_proc AS decimal(5,2)),
    TRY_CAST(jakosc_odpoczynku_proc AS decimal(5,2)),
    TRY_CAST(czas_nauki_po_lekcjach_min AS int),
    TRY_CAST(liczba_ankiet AS int),
    ISNULL(TRY_CAST(czy_wifi_dla_uczniow     AS bit), 0),
    CAST(0 AS bit), CAST(0 AS bit), CAST(0 AS bit),  -- active methods: via Informator overlay
    CAST(0 AS bit), CAST(0 AS bit), CAST(0 AS bit),
    TRY_CAST(liczba_uczniow AS int),
    ISNULL(TRY_CAST(czy_drukarka_dla_uczniow AS bit), 0),
    ISNULL(TRY_CAST(czy_przystanek_mpk       AS bit), 0),
    ISNULL(TRY_CAST(czy_silownia             AS bit), 0)
FROM dbo.stg_atmosfera
WHERE TRY_CAST(rspo_szkoly AS int) IN (SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola);

-- Wstaw puste wiersze dla szkol z Informatora bez danych ze swiadomiewybieram
INSERT INTO dbo.Wymiar_Atmosfera (id_szkoly_rspo)
SELECT x.id_szkoly_rspo
FROM dbo.stg_school_xref x
WHERE x.source = 'informator'
  AND x.id_szkoly_rspo IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.Wymiar_Atmosfera a WHERE a.id_szkoly_rspo = x.id_szkoly_rspo);

-- Nakladka flag z Informatora PDF (wyzszy priorytet niz swiadomiewybieram)
UPDATE a SET
    a.czy_strefa_ciszy              = CASE WHEN f.czy_strefa_ciszy             = 1 THEN 1 ELSE a.czy_strefa_ciszy              END,
    a.czy_miejsce_odpoczynku        = CASE WHEN f.czy_miejsce_odpoczynku       = 1 THEN 1 ELSE a.czy_miejsce_odpoczynku        END,
    a.czy_ciche_dzwonki             = CASE WHEN f.czy_ciche_dzwonki            = 1 THEN 1 ELSE a.czy_ciche_dzwonki             END,
    a.czy_rozowa_skrzyneczka        = CASE WHEN f.czy_rozowa_skrzyneczka       = 1 THEN 1 ELSE a.czy_rozowa_skrzyneczka        END,
    a.czy_szafki_uczniow            = CASE WHEN f.czy_szafki_uczniow           = 1 THEN 1 ELSE a.czy_szafki_uczniow            END,
    a.czy_stojak_na_rowery          = CASE WHEN f.czy_stojak_na_rowery         = 1 THEN 1 ELSE a.czy_stojak_na_rowery          END,
    a.czy_teren_zielony             = CASE WHEN f.czy_teren_zielony            = 1 THEN 1 ELSE a.czy_teren_zielony             END,
    a.czy_otwarte_boiska            = CASE WHEN f.czy_otwarte_boiska           = 1 THEN 1 ELSE a.czy_otwarte_boiska            END,
    a.czy_wifi_dla_uczniow          = CASE WHEN f.czy_wifi_dla_uczniow         = 1 THEN 1 ELSE a.czy_wifi_dla_uczniow          END,
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
    a.czy_rewalidacja               = CASE WHEN f.czy_rewalidacja              = 1 THEN 1 ELSE a.czy_rewalidacja               END,
    a.czy_metoda_projektu           = CASE WHEN f.czy_metoda_projektu          = 1 THEN 1 ELSE a.czy_metoda_projektu           END,
    a.czy_gry_edukacyjne            = CASE WHEN f.czy_gry_edukacyjne           = 1 THEN 1 ELSE a.czy_gry_edukacyjne            END,
    a.czy_ai_nowe_technologie       = CASE WHEN f.czy_ai_nowe_technologie      = 1 THEN 1 ELSE a.czy_ai_nowe_technologie       END,
    a.czy_mapy_mysli                = CASE WHEN f.czy_mapy_mysli               = 1 THEN 1 ELSE a.czy_mapy_mysli                END,
    a.czy_edukacja_antydyskryminacyjna = CASE WHEN f.czy_edukacja_antydyskryminacyjna = 1 THEN 1 ELSE a.czy_edukacja_antydyskryminacyjna END,
    a.czy_metoda_steam              = CASE WHEN f.czy_metoda_steam             = 1 THEN 1 ELSE a.czy_metoda_steam              END
FROM dbo.Wymiar_Atmosfera a
JOIN dbo.stg_school_xref x ON x.id_szkoly_rspo = a.id_szkoly_rspo AND x.source = 'informator'
JOIN dbo.stg_informator_flags f ON f.nazwa_szkoly_informator = x.source_name;


-- ------------------------------------------------------------
-- Wymiar_Inicjatywy_Zewnetrzne + Mostek_Szkola_Inicjatywy
-- Zrodlo: stg_informator_inicjatywy (elementy tekstowe z Informatora PDF)
-- UWAGA: skrypt 40 doladowuje pozniej dodatkowe wpisy Program_miedzynarodowy
--        i Brak_danych_CKE — nie uruchamiac CZESCI 5 wczesniej niz po CZESCI 2
-- ------------------------------------------------------------
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


-- ============================================================
-- CZESC 3: ETL FAKTY — stg_* → tabele faktow
-- ============================================================

-- ------------------------------------------------------------
-- Fakt_Ranking_Perspektywy
-- ------------------------------------------------------------
TRUNCATE TABLE dbo.Fakt_Ranking_Perspektywy;

INSERT INTO dbo.Fakt_Ranking_Perspektywy (id_czas, id_szkoly_rspo, pozycja_w_rankingu, wskaznik_sumaryczny)
SELECT
    c.id_czas,
    x.id_szkoly_rspo,
    TRY_CAST(r.pozycja AS int),
    TRY_CAST(r.wsk AS decimal(5,2))
FROM dbo.stg_ranking r
JOIN dbo.stg_school_xref x ON x.source = 'ranking' AND x.source_name = r.nazwa_szkoly
JOIN dbo.Wymiar_Czas c     ON c.rok_kalendarzowy = r.rok_rankingu
WHERE x.id_szkoly_rspo IS NOT NULL;


-- ------------------------------------------------------------
-- Fakt_Rekrutacja_Wyniki
-- Zrodlo: stg_progi (PDF-y z progami 2023-2025)
-- GROUP BY chroni przed duplikatami z roznych PDF-ow tej samej szkoly
-- ------------------------------------------------------------
TRUNCATE TABLE dbo.Fakt_Rekrutacja_Wyniki;

INSERT INTO dbo.Fakt_Rekrutacja_Wyniki (
    id_szkoly_rspo, id_czas, symbol_oddzialu, nazwa_oddzialu, typ_oddzialu,
    prog_punktowy_min, prog_punktowy_max
)
SELECT
    x.id_szkoly_rspo,
    c.id_czas,
    p.symbol_oddzialu,
    ISNULL(MIN(p.nazwa_oddzialu), p.symbol_oddzialu),
    CASE
        WHEN MIN(p.nazwa_oddzialu) LIKE '%[[]DW]%' THEN 'D'
        WHEN MIN(p.nazwa_oddzialu) LIKE '%[[]D]%'  THEN 'D'
        WHEN MIN(p.nazwa_oddzialu) LIKE '%[[]MS]%' THEN 'MS'
        WHEN MIN(p.nazwa_oddzialu) LIKE '%[[]S]%'  THEN 'S'
        WHEN MIN(p.nazwa_oddzialu) LIKE '%[[]M]%'  THEN 'M'
        ELSE 'O'
    END,
    MIN(p.prog_min),
    MAX(p.prog_max)
FROM dbo.stg_progi p
JOIN dbo.stg_school_xref x ON x.source = 'progi' AND x.source_name = p.nazwa_szkoly
JOIN dbo.Wymiar_Czas c     ON c.rok_kalendarzowy = p.rok
WHERE x.id_szkoly_rspo IS NOT NULL
  AND p.symbol_oddzialu IS NOT NULL
  AND p.symbol_oddzialu <> ''
GROUP BY x.id_szkoly_rspo, c.id_czas, p.symbol_oddzialu;


-- ------------------------------------------------------------
-- Fakt_Plan_Naboru
-- Zrodlo: stg_plan_naboru (plan naboru 2026/2027)
-- ------------------------------------------------------------
TRUNCATE TABLE dbo.Fakt_Plan_Naboru;

INSERT INTO dbo.Fakt_Plan_Naboru (
    id_szkoly_rspo, id_czas, typ_oddzialu, jezyk_dwujezyczny,
    liczba_oddzialow, liczba_miejsc
)
SELECT
    x.id_szkoly_rspo,
    c.id_czas,
    LEFT(ISNULL(n.typ_oddzialu, 'O'), 2),
    NULLIF(TRIM(n.jezyk_lub_zawod), ''),
    TRY_CAST(n.liczba_oddzialow AS int),
    TRY_CAST(n.liczba_miejsc    AS int)
FROM dbo.stg_plan_naboru n
JOIN dbo.stg_school_xref x ON x.source = 'plan_naboru' AND x.source_name = n.nazwa_szkoly
JOIN dbo.Wymiar_Czas c     ON c.rok_kalendarzowy = TRY_CAST(LEFT(TRIM(ISNULL(n.rok_szkolny,'')), 4) AS int)
WHERE x.id_szkoly_rspo IS NOT NULL
  AND TRY_CAST(n.liczba_miejsc AS int) IS NOT NULL;


-- ------------------------------------------------------------
-- Fakt_Matura_Statystyki_Szczegolowe
-- Zrodlo: stg_matura (OKE CSV 2025 + OKE XLSX 2024 z mapa.wyniki.edu.pl)
-- RSPO bezposrednio w danych — brak potrzeby stg_school_xref
-- ------------------------------------------------------------
TRUNCATE TABLE dbo.Fakt_Matura_Statystyki_Szczegolowe;

INSERT INTO dbo.Fakt_Matura_Statystyki_Szczegolowe (
    id_szkoly_rspo, id_czas, id_przedmiotu,
    liczba_zdajacych, liczba_laureatow_finalistow,
    zdawalnosc_proc, sredni_wynik_proc,
    odchylenie_standardowe_proc, mediana_proc, modalna_proc
)
SELECT
    TRY_CAST(m.rspo_szkoly AS int),
    c.id_czas,
    pr.id_przedmiotu,
    TRY_CAST(m.liczba_zdajacych AS int),
    TRY_CAST(m.liczba_laureatow_finalistow AS int),
    TRY_CAST(REPLACE(m.zdawalnosc_proc, ',', '.') AS decimal(5,2)),
    TRY_CAST(REPLACE(m.sredni_wynik_proc, ',', '.') AS decimal(5,2)),
    TRY_CAST(REPLACE(m.odchylenie_standardowe_proc, ',', '.') AS decimal(5,2)),
    TRY_CAST(REPLACE(m.mediana_proc, ',', '.') AS decimal(5,2)),
    TRY_CAST(REPLACE(m.modalna_proc, ',', '.') AS decimal(5,2))
FROM dbo.stg_matura m
JOIN dbo.Wymiar_Czas c ON c.rok_kalendarzowy = TRY_CAST(m.rok_kalendarzowy AS int)
JOIN dbo.Wymiar_Przedmiot_Maturalny pr
     ON LOWER(TRIM(pr.nazwa_przedmiotu)) = LOWER(TRIM(m.nazwa_przedmiotu))
    AND LOWER(TRIM(pr.poziom))           = LOWER(TRIM(ISNULL(m.poziom, m.poziom_src)))
WHERE TRY_CAST(m.rspo_szkoly AS int) IN (SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola);


-- ------------------------------------------------------------
-- Fakt_Matura_EWD
-- Zrodlo: stg_ewd (API ewd.edu.pl, skrobot etl/scrape/ewd.py)
-- AVG() chroni przed duplikatami (ten sam wskaznik, ten sam rok)
-- ------------------------------------------------------------
TRUNCATE TABLE dbo.Fakt_Matura_EWD;

INSERT INTO dbo.Fakt_Matura_EWD (
    id_szkoly_rspo, id_czas, id_typu_ewd,
    ewd_oszacowanie_punktowe, ewd_gorna_granica_ufnosci, ewd_dolna_granica_ufnosci,
    egzamin_oszacowanie_punktowe, egzamin_gorna_granica_ufnosci, egzamin_dolna_granica_ufnosci
)
SELECT
    TRY_CAST(e.rspo_szkoly AS int),
    c.id_czas,
    t.id_typu_ewd,
    AVG(TRY_CAST(e.ewd_oszacowanie    AS decimal(5,2))),
    AVG(TRY_CAST(e.ewd_upper          AS decimal(5,2))),
    AVG(TRY_CAST(e.ewd_lower          AS decimal(5,2))),
    AVG(TRY_CAST(e.egzamin_oszacowanie AS decimal(5,2))),
    AVG(TRY_CAST(e.egzamin_upper      AS decimal(5,2))),
    AVG(TRY_CAST(e.egzamin_lower      AS decimal(5,2)))
FROM dbo.stg_ewd e
JOIN dbo.Wymiar_Czas c    ON c.rok_kalendarzowy = TRY_CAST(e.rok AS int)
JOIN dbo.Wymiar_Typ_EWD t ON LOWER(TRIM(t.rodzaj_zapisu)) = LOWER(TRIM(e.typ_ewd))
WHERE TRY_CAST(e.rspo_szkoly AS int) IN (SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola)
GROUP BY TRY_CAST(e.rspo_szkoly AS int), c.id_czas, t.id_typu_ewd;


-- Klasyfikacja cwiartki EWD (typ_szkoly_ewd)
WITH avg_egz AS (
    SELECT id_typu_ewd,
           id_czas,
           AVG(egzamin_oszacowanie_punktowe) AS sredni_egzamin
    FROM dbo.Fakt_Matura_EWD
    WHERE egzamin_oszacowanie_punktowe IS NOT NULL
    GROUP BY id_typu_ewd, id_czas
)
UPDATE f
SET f.typ_szkoly_ewd = CASE
    WHEN f.ewd_oszacowanie_punktowe IS NULL
      OR f.egzamin_oszacowanie_punktowe IS NULL               THEN NULL
    WHEN f.ewd_oszacowanie_punktowe > 0
     AND f.egzamin_oszacowanie_punktowe >= a.sredni_egzamin   THEN N'Szkoła sukcesu'
    WHEN f.ewd_oszacowanie_punktowe > 0
     AND f.egzamin_oszacowanie_punktowe <  a.sredni_egzamin   THEN N'Szkoła wspierająca'
    WHEN f.ewd_oszacowanie_punktowe < 0
     AND f.egzamin_oszacowanie_punktowe >= a.sredni_egzamin   THEN N'Szkoła niewykorzystanych możliwości'
    WHEN f.ewd_oszacowanie_punktowe < 0
     AND f.egzamin_oszacowanie_punktowe <  a.sredni_egzamin   THEN N'Szkoła wymagająca pomocy'
    ELSE N'Szkoła neutralna'
END
FROM dbo.Fakt_Matura_EWD f
JOIN avg_egz a ON a.id_typu_ewd = f.id_typu_ewd
              AND a.id_czas     = f.id_czas;
GO


-- ============================================================
-- CZESC 4: CZYSZCZENIE — usuniecie szkol nieistotnych
-- Usuwa: DLA DOROSLYCH, SPECJALNE, ZAOCZNE
-- ============================================================

DELETE FROM dbo.Fakt_Rekrutacja_Wyniki
WHERE id_szkoly_rspo IN (
    SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola
    WHERE nazwa_liceum LIKE N'%SPECJALNE%'
       OR nazwa_liceum LIKE N'%DLA DOROSLYCH%'
       OR nazwa_liceum LIKE N'%ZAOCZNE%'
);

DELETE FROM dbo.Fakt_Plan_Naboru
WHERE id_szkoly_rspo IN (
    SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola
    WHERE nazwa_liceum LIKE N'%SPECJALNE%'
       OR nazwa_liceum LIKE N'%DLA DOROSLYCH%'
       OR nazwa_liceum LIKE N'%ZAOCZNE%'
);

DELETE FROM dbo.Fakt_Matura_Statystyki_Szczegolowe
WHERE id_szkoly_rspo IN (
    SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola
    WHERE nazwa_liceum LIKE N'%SPECJALNE%'
       OR nazwa_liceum LIKE N'%DLA DOROSLYCH%'
       OR nazwa_liceum LIKE N'%ZAOCZNE%'
);

DELETE FROM dbo.Fakt_Matura_EWD
WHERE id_szkoly_rspo IN (
    SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola
    WHERE nazwa_liceum LIKE N'%SPECJALNE%'
       OR nazwa_liceum LIKE N'%DLA DOROSLYCH%'
       OR nazwa_liceum LIKE N'%ZAOCZNE%'
);

DELETE FROM dbo.Fakt_Ranking_Perspektywy
WHERE id_szkoly_rspo IN (
    SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola
    WHERE nazwa_liceum LIKE N'%SPECJALNE%'
       OR nazwa_liceum LIKE N'%DLA DOROSLYCH%'
       OR nazwa_liceum LIKE N'%ZAOCZNE%'
);

DELETE FROM dbo.Mostek_Szkola_Inicjatywy
WHERE id_szkoly_rspo IN (
    SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola
    WHERE nazwa_liceum LIKE N'%SPECJALNE%'
       OR nazwa_liceum LIKE N'%DLA DOROSLYCH%'
       OR nazwa_liceum LIKE N'%ZAOCZNE%'
);

DELETE FROM dbo.Wymiar_Atmosfera
WHERE id_szkoly_rspo IN (
    SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola
    WHERE nazwa_liceum LIKE N'%SPECJALNE%'
       OR nazwa_liceum LIKE N'%DLA DOROSLYCH%'
       OR nazwa_liceum LIKE N'%ZAOCZNE%'
);

DELETE FROM dbo.Wymiar_Szkola
WHERE nazwa_liceum LIKE N'%SPECJALNE%'
   OR nazwa_liceum LIKE N'%DLA DOROSLYCH%'
   OR nazwa_liceum LIKE N'%ZAOCZNE%';

GO

SELECT COUNT(*) AS wymiar_szkola_count FROM dbo.Wymiar_Szkola;
GO


-- ============================================================
-- CZESC 5: INICJATYWY MIEDZYNARODOWE
-- Dodaje metadane dla szkol bez danych CKE:
--   Program_miedzynarodowy  (A-Levels, IB, Abitur, itd.)
--   Brak_danych_CKE         (anonimizacja, brak klasy, szkola terapeutyczna)
-- ============================================================

INSERT INTO dbo.Wymiar_Inicjatywy_Zewnetrzne (nazwa_elementu, typ_inicjatywy) VALUES
('A-Levels',                                            'Program_miedzynarodowy'),
('IGCSE',                                               'Program_miedzynarodowy'),
('IB Diploma Programme',                                'Program_miedzynarodowy'),
('American High School Diploma (Cognia)',               'Program_miedzynarodowy'),
('Abitur',                                              'Program_miedzynarodowy'),
('Program wielojezyczny - certyfikaty jezykowe',        'Program_miedzynarodowy'),
('Brak danych CKE - mala liczba zdajacych (anonimizacja)', 'Brak_danych_CKE'),
('Brak klasy maturalnej w roku sprawozdawczym',         'Brak_danych_CKE'),
('Szkola terapeutyczna / osrodek wsparcia psychicznego','Brak_danych_CKE');
GO

-- Group 1 – International programmes
INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'A-Levels'
  AND s.id_szkoly_rspo IN (278899, 262819);

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'IGCSE'
  AND s.id_szkoly_rspo IN (278899);

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'IB Diploma Programme'
  AND s.id_szkoly_rspo IN (84871, 270480, 133632, 84862, 25463);

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'American High School Diploma (Cognia)'
  AND s.id_szkoly_rspo IN (84871);

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'Abitur'
  AND s.id_szkoly_rspo IN (106173);

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'Program wielojezyczny - certyfikaty jezykowe'
  AND s.id_szkoly_rspo IN (482471);
GO

-- Group 2 – CKE anonymization
INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'Brak danych CKE - mala liczba zdajacych (anonimizacja)'
  AND s.id_szkoly_rspo IN (279474, 480515, 479210, 271713, 130689, 478866);
GO

-- Group 3 – No graduating class
INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'Brak klasy maturalnej w roku sprawozdawczym'
  AND s.id_szkoly_rspo IN (480767, 478575, 277478, 275387, 483685, 485061, 484168);
GO

-- Group 4 – Therapeutic schools
INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'Szkola terapeutyczna / osrodek wsparcia psychicznego'
  AND s.id_szkoly_rspo IN (484245, 482237, 483441);
GO


-- ============================================================
-- CZESC 6: WALIDACJA I ZAPYTANIA ANALITYCZNE
-- ============================================================

-- ------------------------------------------------------------
-- 1. Liczba wierszy per tabela
-- Oczekiwane minimum: Wymiar_Szkola ~196, Fakt_Rekrutacja_Wyniki >= 1500
-- ------------------------------------------------------------
SELECT 'Wymiar_Czas'                       AS tabela, COUNT(*) AS wiersze FROM dbo.Wymiar_Czas
UNION ALL SELECT 'Wymiar_Szkola',                      COUNT(*) FROM dbo.Wymiar_Szkola
UNION ALL SELECT 'Wymiar_Atmosfera',                   COUNT(*) FROM dbo.Wymiar_Atmosfera
UNION ALL SELECT 'Wymiar_Przedmiot_Maturalny',         COUNT(*) FROM dbo.Wymiar_Przedmiot_Maturalny
UNION ALL SELECT 'Wymiar_Typ_EWD',                     COUNT(*) FROM dbo.Wymiar_Typ_EWD
UNION ALL SELECT 'Wymiar_Inicjatywy_Zewnetrzne',       COUNT(*) FROM dbo.Wymiar_Inicjatywy_Zewnetrzne
UNION ALL SELECT 'Mostek_Szkola_Inicjatywy',           COUNT(*) FROM dbo.Mostek_Szkola_Inicjatywy
UNION ALL SELECT 'Fakt_Ranking_Perspektywy',           COUNT(*) FROM dbo.Fakt_Ranking_Perspektywy
UNION ALL SELECT 'Fakt_Rekrutacja_Wyniki',             COUNT(*) FROM dbo.Fakt_Rekrutacja_Wyniki
UNION ALL SELECT 'Fakt_Plan_Naboru',                   COUNT(*) FROM dbo.Fakt_Plan_Naboru
UNION ALL SELECT 'Fakt_Matura_Statystyki_Szczegolowe', COUNT(*) FROM dbo.Fakt_Matura_Statystyki_Szczegolowe
UNION ALL SELECT 'Fakt_Matura_EWD',                   COUNT(*) FROM dbo.Fakt_Matura_EWD
ORDER BY tabela;


-- ------------------------------------------------------------
-- 2. Kontrola sierotkow — fakty bez pasujacego wymiaru (wszystkie = 0)
-- ------------------------------------------------------------
SELECT 'Matura_brak_szkoly' AS problem, COUNT(*) AS n
FROM dbo.Fakt_Matura_Statystyki_Szczegolowe f
WHERE NOT EXISTS (SELECT 1 FROM dbo.Wymiar_Szkola s WHERE s.id_szkoly_rspo = f.id_szkoly_rspo)
UNION ALL
SELECT 'EWD_brak_szkoly', COUNT(*)
FROM dbo.Fakt_Matura_EWD f
WHERE NOT EXISTS (SELECT 1 FROM dbo.Wymiar_Szkola s WHERE s.id_szkoly_rspo = f.id_szkoly_rspo)
UNION ALL
SELECT 'Rekrutacja_brak_szkoly', COUNT(*)
FROM dbo.Fakt_Rekrutacja_Wyniki f
WHERE NOT EXISTS (SELECT 1 FROM dbo.Wymiar_Szkola s WHERE s.id_szkoly_rspo = f.id_szkoly_rspo)
UNION ALL
SELECT 'Plan_brak_szkoly', COUNT(*)
FROM dbo.Fakt_Plan_Naboru f
WHERE NOT EXISTS (SELECT 1 FROM dbo.Wymiar_Szkola s WHERE s.id_szkoly_rspo = f.id_szkoly_rspo);


-- ------------------------------------------------------------
-- 3. Pokrycie progami: ile lat danych per szkola
-- ------------------------------------------------------------
SELECT coverage AS liczba_lat, COUNT(*) AS liczba_szkol
FROM (
    SELECT id_szkoly_rspo, COUNT(DISTINCT id_czas) AS coverage
    FROM dbo.Fakt_Rekrutacja_Wyniki
    GROUP BY id_szkoly_rspo
) t
GROUP BY coverage
ORDER BY coverage DESC;


-- ------------------------------------------------------------
-- 4. Rozklad cwiartki EWD (weryfikacja poprawnosci klasyfikacji)
-- ------------------------------------------------------------
SELECT
    t.rodzaj_zapisu        AS wskaznik,
    c.rok_kalendarzowy     AS rok,
    f.typ_szkoly_ewd,
    COUNT(*)               AS liczba_szkol
FROM dbo.Fakt_Matura_EWD f
JOIN dbo.Wymiar_Typ_EWD  t ON t.id_typu_ewd   = f.id_typu_ewd
JOIN dbo.Wymiar_Czas     c ON c.id_czas        = f.id_czas
WHERE f.typ_szkoly_ewd IS NOT NULL
GROUP BY t.rodzaj_zapisu, c.rok_kalendarzowy, f.typ_szkoly_ewd
ORDER BY t.rodzaj_zapisu, c.rok_kalendarzowy, f.typ_szkoly_ewd;


-- ------------------------------------------------------------
-- 5. SHOWCASE: "Ukryty diament"
--    Oddzial humanistyczny z progiem < 165 pkt I dodatnim EWD humanistycznym
-- ------------------------------------------------------------
SELECT
    s.nazwa_liceum,
    s.dzielnica,
    r.symbol_oddzialu,
    r.nazwa_oddzialu,
    MIN(r.prog_punktowy_min)             AS min_prog_3lat,
    MAX(r.prog_punktowy_min)             AS max_prog_3lat,
    e.ewd_oszacowanie_punktowe           AS ewd_humanistyczne,
    t.rodzaj_zapisu                      AS typ_ewd,
    c.rok_kalendarzowy                   AS rok_ewd
FROM dbo.Fakt_Rekrutacja_Wyniki r
JOIN dbo.Wymiar_Szkola  s ON s.id_szkoly_rspo = r.id_szkoly_rspo
JOIN dbo.Fakt_Matura_EWD e ON e.id_szkoly_rspo = r.id_szkoly_rspo
JOIN dbo.Wymiar_Typ_EWD  t ON t.id_typu_ewd   = e.id_typu_ewd
JOIN dbo.Wymiar_Czas     c ON c.id_czas        = e.id_czas
WHERE e.ewd_oszacowanie_punktowe > 0
  AND t.nazwa_egzaminu LIKE '%humanist%'
  AND (r.nazwa_oddzialu LIKE '%human%'
    OR r.nazwa_oddzialu LIKE '%praw%'
    OR r.nazwa_oddzialu LIKE '%ang%'
    OR r.nazwa_oddzialu LIKE '%pol%')
GROUP BY s.nazwa_liceum, s.dzielnica, r.symbol_oddzialu, r.nazwa_oddzialu,
         e.ewd_oszacowanie_punktowe, t.rodzaj_zapisu, c.rok_kalendarzowy
HAVING MAX(r.prog_punktowy_min) < 165
ORDER BY e.ewd_oszacowanie_punktowe DESC;


-- ------------------------------------------------------------
-- 6. SHOWCASE: "Szkola zmarnowanych szans"
--    Wysoki sredni prog ALE ujemne EWD
-- ------------------------------------------------------------
SELECT
    s.nazwa_liceum,
    s.dzielnica,
    AVG(r.prog_punktowy_min)             AS sredni_prog_3lat,
    e.ewd_oszacowanie_punktowe           AS ewd,
    t.rodzaj_zapisu
FROM dbo.Fakt_Rekrutacja_Wyniki r
JOIN dbo.Wymiar_Szkola  s ON s.id_szkoly_rspo = r.id_szkoly_rspo
JOIN dbo.Fakt_Matura_EWD e ON e.id_szkoly_rspo = r.id_szkoly_rspo
JOIN dbo.Wymiar_Typ_EWD  t ON t.id_typu_ewd   = e.id_typu_ewd
GROUP BY s.nazwa_liceum, s.dzielnica, e.ewd_oszacowanie_punktowe, t.rodzaj_zapisu
HAVING AVG(r.prog_punktowy_min) > 160
   AND e.ewd_oszacowanie_punktowe < 0
ORDER BY e.ewd_oszacowanie_punktowe ASC;


-- ------------------------------------------------------------
-- 7. SHOWCASE: Trend progow 2023-2025 dla konkretnego liceum
-- ------------------------------------------------------------
SELECT
    s.nazwa_liceum,
    r.symbol_oddzialu,
    r.nazwa_oddzialu,
    c.rok_kalendarzowy,
    r.prog_punktowy_min,
    r.prog_punktowy_max
FROM dbo.Fakt_Rekrutacja_Wyniki r
JOIN dbo.Wymiar_Szkola s ON s.id_szkoly_rspo = r.id_szkoly_rspo
JOIN dbo.Wymiar_Czas   c ON c.id_czas        = r.id_czas
WHERE s.nazwa_liceum LIKE '%Staszic%'
ORDER BY s.nazwa_liceum, r.symbol_oddzialu, c.rok_kalendarzowy;


-- ------------------------------------------------------------
-- 8. Najlepsze szkoly wg EWD humanistycznego w ostatnim roku
-- ------------------------------------------------------------
SELECT TOP 20
    s.nazwa_liceum,
    s.dzielnica,
    c.rok_kalendarzowy,
    f.ewd_oszacowanie_punktowe,
    f.ewd_gorna_granica_ufnosci,
    f.ewd_dolna_granica_ufnosci,
    f.egzamin_oszacowanie_punktowe,
    f.typ_szkoly_ewd
FROM dbo.Fakt_Matura_EWD f
JOIN dbo.Wymiar_Szkola  s ON s.id_szkoly_rspo = f.id_szkoly_rspo
JOIN dbo.Wymiar_Typ_EWD t ON t.id_typu_ewd    = f.id_typu_ewd
JOIN dbo.Wymiar_Czas    c ON c.id_czas        = f.id_czas
WHERE t.nazwa_egzaminu LIKE '%humanist%'
  AND c.rok_kalendarzowy = (SELECT MAX(rok_kalendarzowy) FROM dbo.Wymiar_Czas
                             WHERE id_czas IN (SELECT DISTINCT id_czas FROM dbo.Fakt_Matura_EWD))
ORDER BY f.ewd_oszacowanie_punktowe DESC;


-- ------------------------------------------------------------
-- 9. Szkoly z psychologiem/pedagogiem specjalnym
-- ------------------------------------------------------------
SELECT
    s.nazwa_liceum,
    s.dzielnica,
    a.czy_psycholog_na_etacie,
    a.czy_pedagog_specjalny,
    a.czy_osoba_zaufania,
    a.czy_pielegniarka,
    a.atmosfera_proc,
    a.liczba_ankiet
FROM dbo.Wymiar_Atmosfera a
JOIN dbo.Wymiar_Szkola    s ON s.id_szkoly_rspo = a.id_szkoly_rspo
WHERE a.czy_psycholog_na_etacie = 1
ORDER BY s.dzielnica, s.nazwa_liceum;
GO

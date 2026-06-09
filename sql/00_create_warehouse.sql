-- WawaLiceum Data Warehouse — star schema
-- Changes from original docs/db/SkryptDDL.sql:
--   * USE WawaLiceumDB (was WawaLiceum)
--   * Wymiar_Profil removed — plan naboru has no individual class symbols;
--     class info stored as degenerate dims in Fakt_Rekrutacja_Wyniki
--   * Fakt_Rekrutacja_Wyniki rebuilt: sourced from progi PDFs (2023-2025),
--     symbol/nazwa/typ as inline columns, prog_punktowy_max added
--   * Fakt_Plan_Naboru added: plan naboru 2026 at (school, typ) aggregate grain
--   * Wymiar_Czas covers 2023-2026 (populated from stg_progi + stg_ranking + stg_matura)
--   * poziom_halasu_otoczenia removed (no data source)
--   * wspolrzedne_lat/long from Wikipedia geotag scraper (etl/scrape/wikipedia_coords.py)
--   * url_facebook, url_instagram removed (no source)
--   * Staging tables auto-created by Python; not in this script

USE [WawaLiceumDB];
GO

-- ============================================================
-- DROP (reverse FK order)
-- ============================================================
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

-- ============================================================
-- DIMENSIONS
-- ============================================================

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
    wspolrzedne_lat         decimal(9,6)  NULL,   -- from Wikipedia geotag (etl/scrape/wikipedia_coords.py)
    wspolrzedne_long        decimal(9,6)  NULL,   -- from Wikipedia geotag
    CONSTRAINT PK_Wymiar_Szkola PRIMARY KEY (id_szkoly_rspo)
);

CREATE TABLE dbo.Wymiar_Atmosfera (
    id_atmosfera                int          IDENTITY(1,1) NOT NULL,
    id_szkoly_rspo              int          NOT NULL,
    -- Infrastructure flags (from swiadomiewybieram.pl)
    czy_strefa_ciszy            bit          NOT NULL DEFAULT 0,
    czy_miejsce_odpoczynku      bit          NOT NULL DEFAULT 0,
    czy_ciche_dzwonki           bit          NOT NULL DEFAULT 0,
    czy_rozowa_skrzyneczka      bit          NOT NULL DEFAULT 0,
    czy_szafki_uczniow          bit          NOT NULL DEFAULT 0,
    czy_stojak_na_rowery        bit          NOT NULL DEFAULT 0,
    czy_teren_zielony           bit          NOT NULL DEFAULT 0,
    czy_otwarte_boiska          bit          NOT NULL DEFAULT 0,
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
    -- Atmosphere ratings (% from student surveys)
    atmosfera_proc              decimal(5,2) NULL,
    przyjemnosc_nauki_proc      decimal(5,2) NULL,
    relacje_uczniow_proc        decimal(5,2) NULL,
    relacja_nauczyciel_proc     decimal(5,2) NULL,
    nowoczesnosc_zajec_proc     decimal(5,2) NULL,
    polecanie_szkoly_proc       decimal(5,2) NULL,
    jakosc_odpoczynku_proc      decimal(5,2) NULL,
    czas_nauki_po_lekcjach_min  int          NULL,
    liczba_ankiet               int          NULL,
    CONSTRAINT PK_Wymiar_Atmosfera PRIMARY KEY (id_atmosfera),
    CONSTRAINT UQ_Atmosfera_Szkola UNIQUE (id_szkoly_rspo)
);

CREATE TABLE dbo.Wymiar_Przedmiot_Maturalny (
    id_przedmiotu    int           IDENTITY(1,1) NOT NULL,
    nazwa_przedmiotu nvarchar(100) NOT NULL,
    poziom           nvarchar(50)  NOT NULL,    -- podstawowy / rozszerzony
    CONSTRAINT PK_Wymiar_Przedmiot PRIMARY KEY (id_przedmiotu),
    CONSTRAINT UQ_Przedmiot UNIQUE (nazwa_przedmiotu, poziom)
);

CREATE TABLE dbo.Wymiar_Typ_EWD (
    id_typu_ewd    int          IDENTITY(1,1) NOT NULL,
    nazwa_egzaminu nvarchar(100) NOT NULL,
    rodzaj_zapisu  nvarchar(50)  NOT NULL,    -- humanistyczny / matematyczny
    CONSTRAINT PK_Wymiar_Typ_EWD PRIMARY KEY (id_typu_ewd),
    CONSTRAINT UQ_Typ_EWD UNIQUE (nazwa_egzaminu, rodzaj_zapisu)
);

CREATE TABLE dbo.Wymiar_Inicjatywy_Zewnetrzne (
    id_inicjatywy  int           IDENTITY(1,1) NOT NULL,
    nazwa_elementu nvarchar(255) NOT NULL,
    typ_inicjatywy nvarchar(50)  NOT NULL,
    CONSTRAINT PK_Wymiar_Inicjatywy PRIMARY KEY (id_inicjatywy)
);

-- ============================================================
-- BRIDGE
-- ============================================================

CREATE TABLE dbo.Mostek_Szkola_Inicjatywy (
    id_szkoly_rspo int NOT NULL,
    id_inicjatywy  int NOT NULL,
    CONSTRAINT PK_Mostek_Szkola_Inicjatywy PRIMARY KEY (id_szkoly_rspo, id_inicjatywy)
);

-- ============================================================
-- FACTS
-- ============================================================

CREATE TABLE dbo.Fakt_Ranking_Perspektywy (
    id_rankingu         int           IDENTITY(1,1) NOT NULL,
    id_czas             int           NOT NULL,
    id_szkoly_rspo      int           NOT NULL,
    pozycja_w_rankingu  int           NULL,
    wskaznik_sumaryczny decimal(5,2)  NULL,
    CONSTRAINT PK_Fakt_Ranking_Perspektywy PRIMARY KEY (id_rankingu),
    CONSTRAINT UQ_Ranking UNIQUE (id_czas, id_szkoly_rspo)
);

-- Historical recruitment thresholds — one row per (school, class, year).
-- Sourced from progi PDFs 2023-2025.  Class info stored as degenerate dims
-- because Wymiar_Profil cannot exist at this grain (plan naboru is aggregate).
CREATE TABLE dbo.Fakt_Rekrutacja_Wyniki (
    id_fakt            int           IDENTITY(1,1) NOT NULL,
    id_szkoly_rspo     int           NOT NULL,
    id_czas            int           NOT NULL,
    symbol_oddzialu    nvarchar(50)  NOT NULL,   -- e.g. "1A", "1Ah"
    nazwa_oddzialu     nvarchar(255) NOT NULL,   -- e.g. "[O] geogr-hist-ang (ang-hisz*)"
    typ_oddzialu       char(2)       NOT NULL,   -- O / D / MS
    prog_punktowy_min  decimal(5,2)  NULL,
    prog_punktowy_max  decimal(5,2)  NULL,       -- available in 2023 only
    CONSTRAINT PK_Fakt_Rekrutacja_Wyniki PRIMARY KEY (id_fakt),
    CONSTRAINT UQ_Rekrutacja UNIQUE (id_szkoly_rspo, id_czas, symbol_oddzialu)
);

-- 2026 plan naboru — aggregate seat counts per school and class type.
-- No individual class symbols available in source data.
CREATE TABLE dbo.Fakt_Plan_Naboru (
    id_plan            int          IDENTITY(1,1) NOT NULL,
    id_szkoly_rspo     int          NOT NULL,
    id_czas            int          NOT NULL,
    typ_oddzialu       char(2)      NOT NULL,   -- O / D / MS
    jezyk_dwujezyczny  nvarchar(50) NULL,       -- NULL for O-type classes
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
    -- Quadrant label from EWD chart (set after insert, based on EWD=0 and mean exam per indicator×year)
    typ_szkoly_ewd                 nvarchar(60) NULL,
    CONSTRAINT PK_Fakt_Matura_EWD PRIMARY KEY (id_fakt_ewd),
    CONSTRAINT UQ_EWD UNIQUE (id_szkoly_rspo, id_czas, id_typu_ewd)
);

-- ============================================================
-- FOREIGN KEYS
-- ============================================================

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

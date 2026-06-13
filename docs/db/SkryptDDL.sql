-- ============================================================
-- WawaLiceumDB  –  Skrypt DDL (auto-wygenerowany)
-- Baza danych: Star Schema dla systemu WawaLiceum
-- Silnik: MS SQL Server (Azure SQL Edge, Docker)
--
-- Kolejność tworzenia:
--   1. Wymiary (Wymiar_*)
--   2. Tablice faktów (Fakt_*)
--   3. Mostek (Mostek_Szkola_Inicjatywy)
--   4. Tabele staging (stg_*)
-- ============================================================
USE [WawaLiceumDB];
GO

CREATE TABLE dbo.[Wymiar_Szkola] (
    [id_szkoly_rspo] INT NOT NULL,
    [id_zespolu_rspo] INT NULL,
    [id_oke] INT NULL,
    [regon] CHAR(14) NOT NULL,
    [nazwa_liceum] NVARCHAR(255) NOT NULL,
    [nazwa_zespolu_szkol] NVARCHAR(255) NULL,
    [adres] NVARCHAR(255) NOT NULL,
    [dzielnica] NVARCHAR(50) NOT NULL,
    [organ_prowadzacy] NVARCHAR(255) NOT NULL,
    [dyrektor_imie_nazwisko] NVARCHAR(150) NULL,
    [data_zalozenia] DATE NULL,
    [czy_samodzielna] BIT NOT NULL,
    [czy_publiczna] BIT NULL,
    [rodzaj_placowki] NVARCHAR(100) NULL,
    [kod_teryt_gminy] VARCHAR(10) NULL,
    [telefon] VARCHAR(30) NULL,
    [email] VARCHAR(100) NULL,
    [strona_www] VARCHAR(255) NULL,
    [wspolrzedne_lat] DECIMAL(9,6) NULL,
    [wspolrzedne_long] DECIMAL(9,6) NULL,
    CONSTRAINT [PK_Wymiar_Szkola] PRIMARY KEY ([id_szkoly_rspo])
);
GO

CREATE TABLE dbo.[Wymiar_Atmosfera] (
    [id_atmosfera] INT IDENTITY(1,1) NOT NULL,
    [id_szkoly_rspo] INT NOT NULL,
    [czy_strefa_ciszy] BIT DEFAULT ((0)) NOT NULL,
    [czy_miejsce_odpoczynku] BIT DEFAULT ((0)) NOT NULL,
    [czy_ciche_dzwonki] BIT DEFAULT ((0)) NOT NULL,
    [czy_rozowa_skrzyneczka] BIT DEFAULT ((0)) NOT NULL,
    [czy_szafki_uczniow] BIT DEFAULT ((0)) NOT NULL,
    [czy_stojak_na_rowery] BIT DEFAULT ((0)) NOT NULL,
    [czy_teren_zielony] BIT DEFAULT ((0)) NOT NULL,
    [czy_otwarte_boiska] BIT DEFAULT ((0)) NOT NULL,
    [czy_sklepik_szkolny] BIT DEFAULT ((0)) NOT NULL,
    [czy_bufet_stolowka] BIT DEFAULT ((0)) NOT NULL,
    [czy_posilki_wegetarianskie] BIT DEFAULT ((0)) NOT NULL,
    [czy_posilki_weganskie] BIT DEFAULT ((0)) NOT NULL,
    [czy_zrodlo_wody_pitnej] BIT DEFAULT ((0)) NOT NULL,
    [czy_monitoring] BIT DEFAULT ((0)) NOT NULL,
    [czy_wejscie_na_karty] BIT DEFAULT ((0)) NOT NULL,
    [czy_rejestracja_gosci] BIT DEFAULT ((0)) NOT NULL,
    [czy_rzecznik_praw_ucznia] BIT DEFAULT ((0)) NOT NULL,
    [czy_pielegniarka] BIT DEFAULT ((0)) NOT NULL,
    [czy_psycholog_na_etacie] BIT DEFAULT ((0)) NOT NULL,
    [czy_pedagog_specjalny] BIT DEFAULT ((0)) NOT NULL,
    [czy_osoba_zaufania] BIT DEFAULT ((0)) NOT NULL,
    [czy_zajecia_tus] BIT DEFAULT ((0)) NOT NULL,
    [czy_rewalidacja] BIT DEFAULT ((0)) NOT NULL,
    [czy_winda] BIT DEFAULT ((0)) NOT NULL,
    [czy_podjazd_dla_wozkow] BIT DEFAULT ((0)) NOT NULL,
    [czy_petla_indukcyjna] BIT DEFAULT ((0)) NOT NULL,
    [czy_schodolaz] BIT DEFAULT ((0)) NOT NULL,
    [atmosfera_proc] DECIMAL(5,2) NULL,
    [przyjemnosc_nauki_proc] DECIMAL(5,2) NULL,
    [relacje_uczniow_proc] DECIMAL(5,2) NULL,
    [relacja_nauczyciel_proc] DECIMAL(5,2) NULL,
    [nowoczesnosc_zajec_proc] DECIMAL(5,2) NULL,
    [polecanie_szkoly_proc] DECIMAL(5,2) NULL,
    [jakosc_odpoczynku_proc] DECIMAL(5,2) NULL,
    [czas_nauki_po_lekcjach_min] INT NULL,
    [liczba_ankiet] INT NULL,
    [czy_wifi_dla_uczniow] BIT DEFAULT ((0)) NOT NULL,
    [czy_metoda_projektu] BIT DEFAULT ((0)) NOT NULL,
    [czy_gry_edukacyjne] BIT DEFAULT ((0)) NOT NULL,
    [czy_ai_nowe_technologie] BIT DEFAULT ((0)) NOT NULL,
    [czy_mapy_mysli] BIT DEFAULT ((0)) NOT NULL,
    [czy_edukacja_antydyskryminacyjna] BIT DEFAULT ((0)) NOT NULL,
    [czy_metoda_steam] BIT DEFAULT ((0)) NOT NULL,
    [liczba_uczniow] INT NULL,
    [czy_drukarka_dla_uczniow] BIT DEFAULT ((0)) NOT NULL,
    [czy_przystanek_mpk] BIT DEFAULT ((0)) NOT NULL,
    [czy_silownia] BIT DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_Wymiar_Atmosfera] PRIMARY KEY ([id_atmosfera]),
    CONSTRAINT [UQ_Atmosfera_Szkola] UNIQUE ([id_szkoly_rspo]),
    CONSTRAINT [FK_Atmosfera_Szkola] FOREIGN KEY ([id_szkoly_rspo])
        REFERENCES dbo.[Wymiar_Szkola] ([id_szkoly_rspo])
);
GO

CREATE TABLE dbo.[Wymiar_Czas] (
    [id_czas] INT NOT NULL,
    [rok_kalendarzowy] INT NOT NULL,
    [rok_szkolny] NVARCHAR(20) NOT NULL,
    CONSTRAINT [PK_Wymiar_Czas] PRIMARY KEY ([id_czas])
);
GO

CREATE TABLE dbo.[Wymiar_Przedmiot_Maturalny] (
    [id_przedmiotu] INT IDENTITY(1,1) NOT NULL,
    [nazwa_przedmiotu] NVARCHAR(100) NOT NULL,
    [poziom] NVARCHAR(50) NOT NULL,
    CONSTRAINT [PK_Wymiar_Przedmiot_Maturalny] PRIMARY KEY ([id_przedmiotu]),
    CONSTRAINT [UQ_Przedmiot] UNIQUE ([nazwa_przedmiotu], [poziom])
);
GO

CREATE TABLE dbo.[Wymiar_Typ_EWD] (
    [id_typu_ewd] INT IDENTITY(1,1) NOT NULL,
    [nazwa_egzaminu] NVARCHAR(100) NOT NULL,
    [rodzaj_zapisu] NVARCHAR(50) NOT NULL,
    CONSTRAINT [PK_Wymiar_Typ_EWD] PRIMARY KEY ([id_typu_ewd]),
    CONSTRAINT [UQ_Typ_EWD] UNIQUE ([nazwa_egzaminu], [rodzaj_zapisu])
);
GO

CREATE TABLE dbo.[Wymiar_Inicjatywy_Zewnetrzne] (
    [id_inicjatywy] INT IDENTITY(1,1) NOT NULL,
    [nazwa_elementu] NVARCHAR(255) NOT NULL,
    [typ_inicjatywy] NVARCHAR(50) NOT NULL,
    CONSTRAINT [PK_Wymiar_Inicjatywy_Zewnetrzne] PRIMARY KEY ([id_inicjatywy])
);
GO

CREATE TABLE dbo.[Fakt_Rekrutacja_Wyniki] (
    [id_fakt] INT IDENTITY(1,1) NOT NULL,
    [id_szkoly_rspo] INT NOT NULL,
    [id_czas] INT NOT NULL,
    [symbol_oddzialu] NVARCHAR(50) NOT NULL,
    [nazwa_oddzialu] NVARCHAR(255) NOT NULL,
    [typ_oddzialu] CHAR(2) NOT NULL,
    [prog_punktowy_min] DECIMAL(5,2) NULL,
    [prog_punktowy_max] DECIMAL(5,2) NULL,
    CONSTRAINT [PK_Fakt_Rekrutacja_Wyniki] PRIMARY KEY ([id_fakt]),
    CONSTRAINT [UQ_Rekrutacja] UNIQUE ([id_szkoly_rspo], [id_czas], [symbol_oddzialu]),
    CONSTRAINT [FK_Rekrutacja_Czas] FOREIGN KEY ([id_czas])
        REFERENCES dbo.[Wymiar_Czas] ([id_czas]),
    CONSTRAINT [FK_Rekrutacja_Szkola] FOREIGN KEY ([id_szkoly_rspo])
        REFERENCES dbo.[Wymiar_Szkola] ([id_szkoly_rspo])
);
GO

CREATE TABLE dbo.[Fakt_Plan_Naboru] (
    [id_plan] INT IDENTITY(1,1) NOT NULL,
    [id_szkoly_rspo] INT NOT NULL,
    [id_czas] INT NOT NULL,
    [typ_oddzialu] CHAR(2) NOT NULL,
    [jezyk_dwujezyczny] NVARCHAR(50) NULL,
    [liczba_oddzialow] INT NOT NULL,
    [liczba_miejsc] INT NOT NULL,
    CONSTRAINT [PK_Fakt_Plan_Naboru] PRIMARY KEY ([id_plan]),
    CONSTRAINT [UQ_Plan] UNIQUE ([id_szkoly_rspo], [id_czas], [typ_oddzialu], [jezyk_dwujezyczny]),
    CONSTRAINT [FK_Plan_Czas] FOREIGN KEY ([id_czas])
        REFERENCES dbo.[Wymiar_Czas] ([id_czas]),
    CONSTRAINT [FK_Plan_Szkola] FOREIGN KEY ([id_szkoly_rspo])
        REFERENCES dbo.[Wymiar_Szkola] ([id_szkoly_rspo])
);
GO

CREATE TABLE dbo.[Fakt_Matura_Statystyki_Szczegolowe] (
    [id_fakt_matura] INT IDENTITY(1,1) NOT NULL,
    [id_szkoly_rspo] INT NOT NULL,
    [id_czas] INT NOT NULL,
    [id_przedmiotu] INT NOT NULL,
    [liczba_zdajacych] INT NULL,
    [liczba_laureatow_finalistow] INT NULL,
    [zdawalnosc_proc] DECIMAL(5,2) NULL,
    [sredni_wynik_proc] DECIMAL(5,2) NULL,
    [odchylenie_standardowe_proc] DECIMAL(5,2) NULL,
    [mediana_proc] DECIMAL(5,2) NULL,
    [modalna_proc] DECIMAL(5,2) NULL,
    CONSTRAINT [PK_Fakt_Matura_Statystyki_Szczegolowe] PRIMARY KEY ([id_fakt_matura]),
    CONSTRAINT [UQ_Matura] UNIQUE ([id_szkoly_rspo], [id_czas], [id_przedmiotu]),
    CONSTRAINT [FK_Szczegoly_Czas] FOREIGN KEY ([id_czas])
        REFERENCES dbo.[Wymiar_Czas] ([id_czas]),
    CONSTRAINT [FK_Szczegoly_Przedmiot] FOREIGN KEY ([id_przedmiotu])
        REFERENCES dbo.[Wymiar_Przedmiot_Maturalny] ([id_przedmiotu]),
    CONSTRAINT [FK_Szczegoly_Szkola] FOREIGN KEY ([id_szkoly_rspo])
        REFERENCES dbo.[Wymiar_Szkola] ([id_szkoly_rspo])
);
GO

CREATE TABLE dbo.[Fakt_Matura_EWD] (
    [id_fakt_ewd] INT IDENTITY(1,1) NOT NULL,
    [id_szkoly_rspo] INT NOT NULL,
    [id_czas] INT NOT NULL,
    [id_typu_ewd] INT NOT NULL,
    [ewd_oszacowanie_punktowe] DECIMAL(5,2) NULL,
    [ewd_gorna_granica_ufnosci] DECIMAL(5,2) NULL,
    [ewd_dolna_granica_ufnosci] DECIMAL(5,2) NULL,
    [egzamin_oszacowanie_punktowe] DECIMAL(5,2) NULL,
    [egzamin_gorna_granica_ufnosci] DECIMAL(5,2) NULL,
    [egzamin_dolna_granica_ufnosci] DECIMAL(5,2) NULL,
    [typ_szkoly_ewd] NVARCHAR(60) NULL,
    CONSTRAINT [PK_Fakt_Matura_EWD] PRIMARY KEY ([id_fakt_ewd]),
    CONSTRAINT [UQ_EWD] UNIQUE ([id_szkoly_rspo], [id_czas], [id_typu_ewd]),
    CONSTRAINT [FK_EWD_Czas] FOREIGN KEY ([id_czas])
        REFERENCES dbo.[Wymiar_Czas] ([id_czas]),
    CONSTRAINT [FK_EWD_Szkola] FOREIGN KEY ([id_szkoly_rspo])
        REFERENCES dbo.[Wymiar_Szkola] ([id_szkoly_rspo]),
    CONSTRAINT [FK_EWD_Typ] FOREIGN KEY ([id_typu_ewd])
        REFERENCES dbo.[Wymiar_Typ_EWD] ([id_typu_ewd])
);
GO

CREATE TABLE dbo.[Fakt_Ranking_Perspektywy] (
    [id_rankingu] INT IDENTITY(1,1) NOT NULL,
    [id_czas] INT NOT NULL,
    [id_szkoly_rspo] INT NOT NULL,
    [pozycja_w_rankingu] INT NULL,
    [wskaznik_sumaryczny] DECIMAL(5,2) NULL,
    CONSTRAINT [PK_Fakt_Ranking_Perspektywy] PRIMARY KEY ([id_rankingu]),
    CONSTRAINT [UQ_Ranking] UNIQUE ([id_czas], [id_szkoly_rspo]),
    CONSTRAINT [FK_Ranking_Czas] FOREIGN KEY ([id_czas])
        REFERENCES dbo.[Wymiar_Czas] ([id_czas]),
    CONSTRAINT [FK_Ranking_Szkola] FOREIGN KEY ([id_szkoly_rspo])
        REFERENCES dbo.[Wymiar_Szkola] ([id_szkoly_rspo])
);
GO

CREATE TABLE dbo.[Mostek_Szkola_Inicjatywy] (
    [id_szkoly_rspo] INT NOT NULL,
    [id_inicjatywy] INT NOT NULL,
    CONSTRAINT [PK_Mostek_Szkola_Inicjatywy] PRIMARY KEY ([id_szkoly_rspo], [id_inicjatywy]),
    CONSTRAINT [FK_Mostek_Inicjatywa] FOREIGN KEY ([id_inicjatywy])
        REFERENCES dbo.[Wymiar_Inicjatywy_Zewnetrzne] ([id_inicjatywy]),
    CONSTRAINT [FK_Mostek_Szkola] FOREIGN KEY ([id_szkoly_rspo])
        REFERENCES dbo.[Wymiar_Szkola] ([id_szkoly_rspo])
);
GO

CREATE TABLE dbo.[stg_rspo] (
    [numer_rspo] VARCHAR(MAX) NULL,
    [regon] VARCHAR(MAX) NULL,
    [nip] VARCHAR(MAX) NULL,
    [typ] VARCHAR(MAX) NULL,
    [nazwa] VARCHAR(MAX) NULL,
    [kod_terytorialny_wojewodztwo] VARCHAR(MAX) NULL,
    [kod_terytorialny_powiat] VARCHAR(MAX) NULL,
    [kod_terytorialny_gmina] VARCHAR(MAX) NULL,
    [kod_terytorialny_miejscowosc] VARCHAR(MAX) NULL,
    [kod_terytorialny_ulica] VARCHAR(MAX) NULL,
    [wojewodztwo] VARCHAR(MAX) NULL,
    [powiat] VARCHAR(MAX) NULL,
    [gmina] VARCHAR(MAX) NULL,
    [miejscowosc] VARCHAR(MAX) NULL,
    [rodzaj_miejscowosci] VARCHAR(MAX) NULL,
    [ulica] VARCHAR(MAX) NULL,
    [numer_budynku] VARCHAR(MAX) NULL,
    [numer_lokalu] VARCHAR(MAX) NULL,
    [kod_pocztowy] VARCHAR(MAX) NULL,
    [poczta] VARCHAR(MAX) NULL,
    [telefon] VARCHAR(MAX) NULL,
    [faks] VARCHAR(MAX) NULL,
    [e_mail] VARCHAR(MAX) NULL,
    [strona_www] VARCHAR(MAX) NULL,
    [publicznosc_status] VARCHAR(MAX) NULL,
    [kategoria_uczniow] VARCHAR(MAX) NULL,
    [specyfika_placowki] VARCHAR(MAX) NULL,
    [imie_i_nazwisko_dyrektora] VARCHAR(MAX) NULL,
    [data_zaozenia] VARCHAR(MAX) NULL,
    [data_rozpoczecia_dziaalnosci] VARCHAR(MAX) NULL,
    [data_likwidacji] VARCHAR(MAX) NULL,
    [typ_organu_prowadzacego] VARCHAR(MAX) NULL,
    [nazwa_organu_prowadzacego] VARCHAR(MAX) NULL,
    [regon_organu_prowadzacego] VARCHAR(MAX) NULL,
    [nip_organu_prowadzacego] VARCHAR(MAX) NULL,
    [wojewodztwo_organu_prowadzacego] VARCHAR(MAX) NULL,
    [powiat_organu_prowadzacego] VARCHAR(MAX) NULL,
    [gmina_organu_prowadzacego] VARCHAR(MAX) NULL,
    [miejsce_w_strukturze] VARCHAR(MAX) NULL,
    [rspo_podmiotu_nadrzednego] VARCHAR(MAX) NULL,
    [typ_podmiotu_nadrzednego] VARCHAR(MAX) NULL,
    [nazwa_podmiotu_nadrzednego] VARCHAR(MAX) NULL,
    [liczba_uczniow] VARCHAR(MAX) NULL,
    [tereny_sportowe] VARCHAR(MAX) NULL,
    [jezyki_nauczane] VARCHAR(MAX) NULL,
    [czy_zatrudnia_logopede] VARCHAR(MAX) NULL,
    [czy_zatrudnia_psychologa] VARCHAR(MAX) NULL,
    [czy_zatrudnia_pedagoga] VARCHAR(MAX) NULL,
    [oddziay_podstawowe_wg_specyfiki] VARCHAR(MAX) NULL,
    [oddziay_dodatkowe] VARCHAR(MAX) NULL,
    [zawod] VARCHAR(MAX) NULL,
    [zawod_artystyczny] VARCHAR(MAX) NULL,
    [zawod_w_kpss] VARCHAR(MAX) NULL,
    [dziedzina_bcu] VARCHAR(MAX) NULL
);
GO

CREATE TABLE dbo.[stg_atmosfera] (
    [rspo_szkoly] VARCHAR(MAX) NULL,
    [site_id] VARCHAR(MAX) NULL,
    [nazwa_szkoly] VARCHAR(MAX) NULL,
    [matura_proc] FLOAT NULL,
    [atmosfera_proc] FLOAT NULL,
    [przyjemnosc_nauki_proc] FLOAT NULL,
    [relacje_uczniow_proc] FLOAT NULL,
    [relacja_nauczyciel_proc] FLOAT NULL,
    [nowoczesnosc_zajec_proc] FLOAT NULL,
    [polecanie_szkoly_proc] FLOAT NULL,
    [jakosc_odpoczynku_proc] FLOAT NULL,
    [czas_nauki_po_lekcjach_min] FLOAT NULL,
    [liczba_ankiet] BIGINT NULL,
    [liczba_uczniow] BIGINT NULL,
    [zdawalnosc_matur_proc] FLOAT NULL,
    [czy_strefa_ciszy] BIGINT NULL,
    [czy_miejsce_odpoczynku] BIGINT NULL,
    [czy_ciche_dzwonki] BIGINT NULL,
    [czy_rozowa_skrzyneczka] BIGINT NULL,
    [czy_szafki_uczniow] BIGINT NULL,
    [czy_stojak_na_rowery] BIGINT NULL,
    [czy_teren_zielony] BIGINT NULL,
    [czy_otwarte_boiska] BIGINT NULL,
    [czy_wifi_dla_uczniow] BIGINT NULL,
    [czy_sklepik_szkolny] BIGINT NULL,
    [czy_bufet_stolowka] BIGINT NULL,
    [czy_psycholog_na_etacie] BIGINT NULL,
    [czy_pedagog_specjalny] BIGINT NULL,
    [czy_winda] BIGINT NULL,
    [czy_podjazd_dla_wozkow] BIGINT NULL,
    [czy_monitoring] BIGINT NULL,
    [czy_pielegniarka] BIGINT NULL,
    [czy_rzecznik_praw_ucznia] BIGINT NULL,
    [czy_drukarka_dla_uczniow] BIGINT NULL,
    [czy_przystanek_mpk] BIGINT NULL,
    [czy_silownia] BIGINT NULL
);
GO

CREATE TABLE dbo.[stg_informator_flags] (
    [nazwa_szkoly_informator] VARCHAR(MAX) NULL,
    [czy_strefa_ciszy] BIGINT NULL,
    [czy_miejsce_odpoczynku] BIGINT NULL,
    [czy_ciche_dzwonki] BIGINT NULL,
    [czy_rozowa_skrzyneczka] BIGINT NULL,
    [czy_szafki_uczniow] BIGINT NULL,
    [czy_stojak_na_rowery] BIGINT NULL,
    [czy_teren_zielony] BIGINT NULL,
    [czy_otwarte_boiska] BIGINT NULL,
    [czy_wifi_dla_uczniow] BIGINT NULL,
    [czy_sklepik_szkolny] BIGINT NULL,
    [czy_bufet_stolowka] BIGINT NULL,
    [czy_posilki_wegetarianskie] BIGINT NULL,
    [czy_posilki_weganskie] BIGINT NULL,
    [czy_zrodlo_wody_pitnej] BIGINT NULL,
    [czy_monitoring] BIGINT NULL,
    [czy_wejscie_na_karty] BIGINT NULL,
    [czy_rejestracja_gosci] BIGINT NULL,
    [czy_winda] BIGINT NULL,
    [czy_podjazd_dla_wozkow] BIGINT NULL,
    [czy_petla_indukcyjna] BIGINT NULL,
    [czy_schodolaz] BIGINT NULL,
    [czy_rzecznik_praw_ucznia] BIGINT NULL,
    [czy_pielegniarka] BIGINT NULL,
    [czy_psycholog_na_etacie] BIGINT NULL,
    [czy_pedagog_specjalny] BIGINT NULL,
    [czy_osoba_zaufania] BIGINT NULL,
    [czy_zajecia_tus] BIGINT NULL,
    [czy_rewalidacja] BIGINT NULL,
    [czy_metoda_projektu] BIGINT NULL,
    [czy_gry_edukacyjne] BIGINT NULL,
    [czy_ai_nowe_technologie] BIGINT NULL,
    [czy_mapy_mysli] BIGINT NULL,
    [czy_edukacja_antydyskryminacyjna] BIGINT NULL,
    [czy_metoda_steam] BIGINT NULL
);
GO

CREATE TABLE dbo.[stg_informator_inicjatywy] (
    [nazwa_szkoly_informator] VARCHAR(MAX) NULL,
    [sekcja] VARCHAR(MAX) NULL,
    [element] VARCHAR(MAX) NULL
);
GO

CREATE TABLE dbo.[stg_progi] (
    [rok] BIGINT NULL,
    [dzielnica] VARCHAR(MAX) NULL,
    [nazwa_szkoly] VARCHAR(MAX) NULL,
    [symbol_oddzialu] VARCHAR(MAX) NULL,
    [nazwa_oddzialu] VARCHAR(MAX) NULL,
    [prog_min] FLOAT NULL,
    [prog_max] FLOAT NULL
);
GO

CREATE TABLE dbo.[stg_matura] (
    [rspo_szkoly] VARCHAR(MAX) NULL,
    [nazwa_przedmiotu] VARCHAR(MAX) NULL,
    [poziom] VARCHAR(MAX) NULL,
    [liczba_zdajacych] VARCHAR(MAX) NULL,
    [liczba_laureatow_finalistow] VARCHAR(MAX) NULL,
    [zdawalnosc_proc] VARCHAR(MAX) NULL,
    [sredni_wynik_proc] VARCHAR(MAX) NULL,
    [odchylenie_standardowe_proc] VARCHAR(MAX) NULL,
    [mediana_proc] VARCHAR(MAX) NULL,
    [modalna_proc] VARCHAR(MAX) NULL,
    [rok_kalendarzowy] VARCHAR(MAX) NULL,
    [rok_szkolny] VARCHAR(MAX) NULL,
    [poziom_src] VARCHAR(MAX) NULL
);
GO

CREATE TABLE dbo.[stg_ewd] (
    [rspo_szkoly] VARCHAR(MAX) NULL,
    [rok] VARCHAR(MAX) NULL,
    [okres] VARCHAR(MAX) NULL,
    [typ_ewd] VARCHAR(MAX) NULL,
    [nazwa_wskaznika] VARCHAR(MAX) NULL,
    [grupa] VARCHAR(MAX) NULL,
    [ewd_oszacowanie] VARCHAR(MAX) NULL,
    [ewd_upper] VARCHAR(MAX) NULL,
    [ewd_lower] VARCHAR(MAX) NULL,
    [egzamin_oszacowanie] VARCHAR(MAX) NULL,
    [egzamin_upper] VARCHAR(MAX) NULL,
    [egzamin_lower] VARCHAR(MAX) NULL,
    [liczba_uczniow] VARCHAR(MAX) NULL
);
GO

CREATE TABLE dbo.[stg_ranking] (
    [nazwa_szkoly] VARCHAR(MAX) NULL,
    [dzielnica] VARCHAR(MAX) NULL,
    [wsk] VARCHAR(MAX) NULL,
    [znak_jakosci] VARCHAR(MAX) NULL,
    [rok_rankingu] BIGINT NULL,
    [pozycja] VARCHAR(MAX) NULL
);
GO

CREATE TABLE dbo.[stg_plan_naboru] (
    [dzielnica] VARCHAR(MAX) NULL,
    [typ_szkoly] VARCHAR(MAX) NULL,
    [nazwa_szkoly] VARCHAR(MAX) NULL,
    [ulica] VARCHAR(MAX) NULL,
    [typ_oddzialu] VARCHAR(MAX) NULL,
    [jezyk_lub_zawod] VARCHAR(MAX) NULL,
    [liczba_oddzialow] VARCHAR(MAX) NULL,
    [liczba_miejsc] VARCHAR(MAX) NULL,
    [rok_szkolny] VARCHAR(MAX) NULL
);
GO

CREATE TABLE dbo.[stg_school_xref] (
    [source] VARCHAR(MAX) NULL,
    [source_name] VARCHAR(MAX) NULL,
    [id_szkoly_rspo] BIGINT NULL,
    [score] FLOAT NULL,
    [match_name] VARCHAR(MAX) NULL
);
GO

CREATE TABLE dbo.[stg_nominatim_coords] (
    [numer_rspo] VARCHAR(MAX) NULL,
    [lat] FLOAT NULL,
    [lon] FLOAT NULL,
    [display_name] VARCHAR(MAX) NULL,
    [match_type] VARCHAR(MAX) NULL
);
GO

CREATE TABLE dbo.[stg_wiki_coords] (
    [numer_rspo] VARCHAR(MAX) NULL,
    [wiki_title] VARCHAR(MAX) NULL,
    [lat] FLOAT NULL,
    [lon] FLOAT NULL
);
GO

-- Phase 6: Remove schools irrelevant to standard Vulcan recruitment.
-- Deletes adult education (DLA DOROSLYCH), special needs (SPECJALNE),
-- and extramural (ZAOCZNE) schools from all fact/dimension tables.
--
-- Run AFTER 20_transform_facts.sql.
USE [WawaLiceumDB];
GO

-- Identify schools to remove
-- (used as subquery below to avoid temp table dependency)

-- ── Dependent tables (FK → Wymiar_Szkola) ────────────────────────────────────

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

-- ── Remove from dimension ─────────────────────────────────────────────────────

DELETE FROM dbo.Wymiar_Szkola
WHERE nazwa_liceum LIKE N'%SPECJALNE%'
   OR nazwa_liceum LIKE N'%DLA DOROSLYCH%'
   OR nazwa_liceum LIKE N'%ZAOCZNE%';

GO

-- Expected result: ~34 schools removed, Wymiar_Szkola remaining ~196
SELECT COUNT(*) AS wymiar_szkola_count FROM dbo.Wymiar_Szkola;
GO

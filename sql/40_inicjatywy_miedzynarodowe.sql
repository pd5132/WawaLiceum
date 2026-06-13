-- Phase 7: Insert metadata for schools without standard CKE matura data.
-- Adds two new typ_inicjatywy categories to Wymiar_Inicjatywy_Zewnetrzne:
--
--   Program_miedzynarodowy  – school uses A-Levels / IB DP / Abitur instead of Polish matura
--   Brak_danych_CKE         – CKE data absent: anonymization (< threshold takers),
--                             no graduating class yet, or therapeutic school
--
-- Then links each school via Mostek_Szkola_Inicjatywy.
-- Run AFTER 30_cleanup_schools.sql.
USE [WawaLiceumDB];
GO

-- ── Insert program entries (id_inicjatywy is IDENTITY – auto-assigned) ────────

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

-- ── Helper: resolve initiative ID by name ────────────────────────────────────
-- All Mostek inserts use subqueries to avoid hardcoding generated IDs.

-- Group 1 – International programmes
INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'A-Levels'
  AND s.id_szkoly_rspo IN (
      278899,  -- BRITISH INTERNATIONAL SCHOOL NR 326 (A-Levels + IGCSE)
      262819   -- LICEUM AKADEMEIA HIGH SCHOOL (A-Levels)
  );

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'IGCSE'
  AND s.id_szkoly_rspo IN (278899);  -- BRITISH INTERNATIONAL SCHOOL NR 326

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'IB Diploma Programme'
  AND s.id_szkoly_rspo IN (
      84871,   -- INTERNATIONAL AMERICAN SCHOOL NR 72 "IAS"
      270480,  -- MIEDZYNARODOWE EUROPEJSKIE LICEUM (IES WARSAW)
      133632,  -- MIEDZYNARODOWE LICEUM NIEPUBLICZNE
      84862,   -- MIEDZYNARODOWE LICEUM THAMES BRITISH SCHOOL
      25463    -- PRYWATNE LICEUM NR 32 IM. JEANA MONNETA
  );

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'American High School Diploma (Cognia)'
  AND s.id_szkoly_rspo IN (84871);  -- INTERNATIONAL AMERICAN SCHOOL NR 72

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'Abitur'
  AND s.id_szkoly_rspo IN (106173);  -- POLSKO-NIEMIECKA SZKOLA BRANDTA

INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'Program wielojezyczny - certyfikaty jezykowe'
  AND s.id_szkoly_rspo IN (482471);  -- MIEDZYNARODOWE LICEUM TE VIZJA
GO

-- Group 2 – CKE anonymization (too few takers for published statistics)
INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'Brak danych CKE - mala liczba zdajacych (anonimizacja)'
  AND s.id_szkoly_rspo IN (
      279474,  -- CLXVI LICEUM Z ODDZIALAMI SPORTOWYMI
      480515,  -- LICEUM EDUKACJI WIELOJEZYCZNEJ
      479210,  -- LICEUM FILMOWE I KREACJI GIER WIDEO
      271713,  -- LICEUM NIEPUBLICZNE FUNDACJI AMICUS
      130689,  -- LICEUM OGÓLNOKSZTALCACE "MULTIMEDIA"
      478866   -- LIGHTHOUSE LICEUM STEVENSONA
  );
GO

-- Group 3 – No graduating class in the reporting year
INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'Brak klasy maturalnej w roku sprawozdawczym'
  AND s.id_szkoly_rspo IN (
      480767,  -- II PRYWATNE LICEUM IM. MORACZEWSKICH
      478575,  -- LICEUM TEB EDUKACJA
      277478,  -- LICEUM ZAKLADU DOSKONALENIA ZAWODOWEGO
      275387,  -- LICEUM SZTUK PLASTYCZNYCH COSINUS IM. NITSCHOWEJ
      483685,  -- NIEPUBLICZNE LICEUM INDYGO
      485061,  -- NIEPUBLICZNE LICEUM SAPIENS INNOVATIVE SCHOOL
      484168   -- NIEPUBLICZNE LICEUM "NOWA SZKOLA"
  );
GO

-- Group 4 – Therapeutic / psychosocial support schools
INSERT INTO dbo.Mostek_Szkola_Inicjatywy (id_szkoly_rspo, id_inicjatywy)
SELECT s.id_szkoly_rspo, i.id_inicjatywy
FROM dbo.Wymiar_Szkola s
CROSS JOIN dbo.Wymiar_Inicjatywy_Zewnetrzne i
WHERE i.nazwa_elementu = 'Szkola terapeutyczna / osrodek wsparcia psychicznego'
  AND s.id_szkoly_rspo IN (
      484245,  -- NIEPUBLICZNE LICEUM BEZPIECZNA PRZYSTAN
      482237,  -- NIEPUBLICZNE LICEUM LUMANAI
      483441   -- NIEPUBLICZNE LICEUM W OSRODKU PSYCHOTERAPII ETUAL
  );
GO

-- Verification
SELECT i.typ_inicjatywy, i.nazwa_elementu,
       COUNT(m.id_szkoly_rspo) AS linked_schools
FROM dbo.Wymiar_Inicjatywy_Zewnetrzne i
LEFT JOIN dbo.Mostek_Szkola_Inicjatywy m ON m.id_inicjatywy = i.id_inicjatywy
WHERE i.typ_inicjatywy IN ('Program_miedzynarodowy', 'Brak_danych_CKE')
GROUP BY i.typ_inicjatywy, i.nazwa_elementu
ORDER BY i.typ_inicjatywy, i.nazwa_elementu;
GO

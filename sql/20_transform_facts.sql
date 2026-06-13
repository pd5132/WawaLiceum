-- Phase 5: staging → fact tables
-- Run AFTER 10_transform_dims.sql
USE [WawaLiceumDB];
GO

-- ============================================================
-- Fakt_Ranking_Perspektywy
-- ============================================================
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


-- ============================================================
-- Fakt_Rekrutacja_Wyniki
-- Source: stg_progi (2023, 2024, 2025 threshold PDFs)
-- School name resolved via stg_school_xref (source = 'progi')
-- typ_oddzialu extracted from nazwa_oddzialu: "[D]" → D, else O
-- ============================================================
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
        WHEN MIN(p.nazwa_oddzialu) LIKE '%[[]D]%'  THEN 'D'
        WHEN MIN(p.nazwa_oddzialu) LIKE '%[[]MS]%' THEN 'MS'
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


-- ============================================================
-- Fakt_Plan_Naboru
-- Source: stg_plan_naboru (2026/2027 aggregate seat counts)
-- Grain: school × typ_oddzialu × jezyk_dwujezyczny
-- ============================================================
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


-- ============================================================
-- Fakt_Matura_Statystyki_Szczegolowe
-- ============================================================
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


-- ============================================================
-- Fakt_Matura_EWD
-- ============================================================
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


-- ============================================================
-- EWD quadrant classification (typ_szkoly_ewd)
-- X-axis: mean exam score per (indicator × year) in our dataset
-- Y-axis: EWD = 0 is always the national average
--
-- Quadrants:
--   EWD > 0, egzamin >= avg  → Szkoła sukcesu               (top-right)
--   EWD > 0, egzamin <  avg  → Szkoła wspierająca            (top-left)
--   EWD < 0, egzamin >= avg  → Szkoła niewykorzystanych możliwości (bottom-right)
--   EWD < 0, egzamin <  avg  → Szkoła wymagająca pomocy      (bottom-left)
--   EWD = 0 or NULL          → Szkoła neutralna
-- ============================================================
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
      OR f.egzamin_oszacowanie_punktowe IS NULL           THEN NULL
    WHEN f.ewd_oszacowanie_punktowe > 0
     AND f.egzamin_oszacowanie_punktowe >= a.sredni_egzamin THEN N'Szkoła sukcesu'
    WHEN f.ewd_oszacowanie_punktowe > 0
     AND f.egzamin_oszacowanie_punktowe <  a.sredni_egzamin THEN N'Szkoła wspierająca'
    WHEN f.ewd_oszacowanie_punktowe < 0
     AND f.egzamin_oszacowanie_punktowe >= a.sredni_egzamin THEN N'Szkoła niewykorzystanych możliwości'
    WHEN f.ewd_oszacowanie_punktowe < 0
     AND f.egzamin_oszacowanie_punktowe <  a.sredni_egzamin THEN N'Szkoła wymagająca pomocy'
    ELSE N'Szkoła neutralna'
END
FROM dbo.Fakt_Matura_EWD f
JOIN avg_egz a ON a.id_typu_ewd = f.id_typu_ewd
              AND a.id_czas     = f.id_czas;
GO

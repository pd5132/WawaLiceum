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
-- Fakt_Rekrutacja_Wyniki  (plan naboru + progi from PDF)
-- prog_punktowy_min joined from stg_progi where possible
-- ============================================================
TRUNCATE TABLE dbo.Fakt_Rekrutacja_Wyniki;

INSERT INTO dbo.Fakt_Rekrutacja_Wyniki (
    id_profilu, id_czas, id_szkoly_rspo,
    prog_punktowy_min, liczba_oddzialow, liczba_miejsc
)
SELECT
    p.id_profilu,
    c.id_czas,
    x.id_szkoly_rspo,
    TRY_CAST(pr.threshold_raw AS decimal(5,2)),
    TRY_CAST(n.liczba_oddzialow AS int),
    TRY_CAST(n.liczba_miejsc    AS int)
FROM dbo.stg_plan_naboru n
JOIN dbo.stg_school_xref x   ON x.source = 'plan_naboru' AND x.source_name = n.nazwa_szkoly
JOIN dbo.Wymiar_Czas c       ON c.rok_szkolny = n.rok_szkolny
JOIN dbo.Wymiar_Profil p     ON p.symbol_oddzialu = ISNULL(n.jezyk_lub_zawod, n.typ_oddzialu)
                             AND p.typ_oddzialu = LEFT(ISNULL(n.typ_oddzialu,'O'), 2)
LEFT JOIN dbo.stg_progi pr   ON pr.col0 LIKE '%' + LEFT(n.nazwa_szkoly, 15) + '%'
                             AND pr.col1 LIKE '%' + ISNULL(n.jezyk_lub_zawod, '') + '%'
WHERE x.id_szkoly_rspo IS NOT NULL;


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
    TRY_CAST(m.liczba_laureat_w_finalist_w AS int),
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
    TRY_CAST(REPLACE(e.ewd_oszacowanie, ',', '.') AS decimal(5,2)),
    TRY_CAST(REPLACE(e.ewd_upper,       ',', '.') AS decimal(5,2)),
    TRY_CAST(REPLACE(e.ewd_lower,       ',', '.') AS decimal(5,2)),
    TRY_CAST(REPLACE(e.egzamin_oszacowanie, ',', '.') AS decimal(5,2)),
    TRY_CAST(REPLACE(e.egzamin_upper,   ',', '.') AS decimal(5,2)),
    TRY_CAST(REPLACE(e.egzamin_lower,   ',', '.') AS decimal(5,2))
FROM dbo.stg_ewd e
JOIN dbo.Wymiar_Czas c   ON c.rok_kalendarzowy = TRY_CAST(e.rok AS int)
JOIN dbo.Wymiar_Typ_EWD t ON LOWER(TRIM(t.rodzaj_zapisu)) = LOWER(TRIM(e.typ_ewd))
WHERE TRY_CAST(e.rspo_szkoly AS int) IN (SELECT id_szkoly_rspo FROM dbo.Wymiar_Szkola);
GO

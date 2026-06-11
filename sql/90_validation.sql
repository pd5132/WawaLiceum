-- Validation queries — run after full ETL
USE [WawaLiceumDB];
GO

-- ============================================================
-- 1. Row counts per table
-- ============================================================
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

-- Expected minimums: Fakt_Rekrutacja_Wyniki >= 2000 (970+670+819 raw minus unmatched)


-- ============================================================
-- 2. Orphan check — facts without matching dimension
-- ============================================================
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
-- All counts should be 0


-- ============================================================
-- 3. Progi coverage: how many years per school
-- (schools with all 3 years = good coverage for trend chart)
-- ============================================================
SELECT coverage, COUNT(*) AS szkoly
FROM (
    SELECT id_szkoly_rspo, COUNT(DISTINCT id_czas) AS coverage
    FROM dbo.Fakt_Rekrutacja_Wyniki
    GROUP BY id_szkoly_rspo
) t
GROUP BY coverage
ORDER BY coverage DESC;


-- ============================================================
-- 4. EWD quadrant distribution (sanity check for typ_szkoly_ewd)
-- ============================================================
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


-- ============================================================
-- 5. SHOWCASE: "Ukryty diament"
--    Humanities class with próg < 165 pts AND positive humanities EWD
--    (low-threshold school that actually grows student potential)
-- ============================================================
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


-- ============================================================
-- 5. SHOWCASE: "Szkoła zmarnowanych szans"
--    High average threshold BUT negative EWD (school lowers potential)
-- ============================================================
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


-- ============================================================
-- 6. SHOWCASE: Threshold trend 2023→2025 for a specific class
--    (shows 5-year trend data backing Screen 3 of mobile app)
-- ============================================================
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
GO

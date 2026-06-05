-- Validation queries — run after full ETL
USE [WawaLiceumDB];
GO

-- ============================================================
-- 1. Row counts per table
-- ============================================================
SELECT 'Wymiar_Czas'                     AS tabela, COUNT(*) AS wiersze FROM dbo.Wymiar_Czas
UNION ALL SELECT 'Wymiar_Szkola',                    COUNT(*) FROM dbo.Wymiar_Szkola
UNION ALL SELECT 'Wymiar_Atmosfera',                 COUNT(*) FROM dbo.Wymiar_Atmosfera
UNION ALL SELECT 'Wymiar_Profil',                    COUNT(*) FROM dbo.Wymiar_Profil
UNION ALL SELECT 'Wymiar_Przedmiot_Maturalny',       COUNT(*) FROM dbo.Wymiar_Przedmiot_Maturalny
UNION ALL SELECT 'Wymiar_Typ_EWD',                   COUNT(*) FROM dbo.Wymiar_Typ_EWD
UNION ALL SELECT 'Wymiar_Inicjatywy_Zewnetrzne',     COUNT(*) FROM dbo.Wymiar_Inicjatywy_Zewnetrzne
UNION ALL SELECT 'Fakt_Ranking_Perspektywy',         COUNT(*) FROM dbo.Fakt_Ranking_Perspektywy
UNION ALL SELECT 'Fakt_Rekrutacja_Wyniki',           COUNT(*) FROM dbo.Fakt_Rekrutacja_Wyniki
UNION ALL SELECT 'Fakt_Matura_Statystyki_Szczegolowe', COUNT(*) FROM dbo.Fakt_Matura_Statystyki_Szczegolowe
UNION ALL SELECT 'Fakt_Matura_EWD',                 COUNT(*) FROM dbo.Fakt_Matura_EWD
ORDER BY tabela;

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
WHERE NOT EXISTS (SELECT 1 FROM dbo.Wymiar_Szkola s WHERE s.id_szkoly_rspo = f.id_szkoly_rspo);

-- ============================================================
-- 3. SHOWCASE: "Ukryty diament"
--    Humanities profile with próg < 165 pts AND positive humanities EWD
-- ============================================================
SELECT
    s.nazwa_liceum,
    s.dzielnica,
    r.prog_punktowy_min,
    e.ewd_oszacowanie_punktowe          AS ewd_humanistyczne,
    t.rodzaj_zapisu                     AS typ_ewd
FROM dbo.Fakt_Rekrutacja_Wyniki r
JOIN dbo.Wymiar_Szkola  s ON s.id_szkoly_rspo = r.id_szkoly_rspo
JOIN dbo.Wymiar_Profil  p ON p.id_profilu     = r.id_profilu
JOIN dbo.Fakt_Matura_EWD e ON e.id_szkoly_rspo = r.id_szkoly_rspo
JOIN dbo.Wymiar_Typ_EWD  t ON t.id_typu_ewd   = e.id_typu_ewd
WHERE r.prog_punktowy_min < 165
  AND e.ewd_oszacowanie_punktowe > 0
  AND t.rodzaj_zapisu LIKE '%humanist%'
  AND (p.nazwa_oddzialu LIKE '%human%' OR p.nazwa_oddzialu LIKE '%praw%' OR p.nazwa_oddzialu LIKE '%angielski%')
ORDER BY e.ewd_oszacowanie_punktowe DESC;

-- ============================================================
-- 4. SHOWCASE: "Szkoła zmarnowanych szans"
--    High entry threshold BUT negative EWD (school lowers potential)
-- ============================================================
SELECT
    s.nazwa_liceum,
    s.dzielnica,
    AVG(r.prog_punktowy_min)                AS sredni_prog,
    e.ewd_oszacowanie_punktowe              AS ewd,
    t.rodzaj_zapisu
FROM dbo.Fakt_Rekrutacja_Wyniki r
JOIN dbo.Wymiar_Szkola  s ON s.id_szkoly_rspo = r.id_szkoly_rspo
JOIN dbo.Fakt_Matura_EWD e ON e.id_szkoly_rspo = r.id_szkoly_rspo
JOIN dbo.Wymiar_Typ_EWD  t ON t.id_typu_ewd   = e.id_typu_ewd
GROUP BY s.nazwa_liceum, s.dzielnica, e.ewd_oszacowanie_punktowe, t.rodzaj_zapisu
HAVING AVG(r.prog_punktowy_min) > 160
   AND e.ewd_oszacowanie_punktowe < 0
ORDER BY e.ewd_oszacowanie_punktowe ASC;
GO

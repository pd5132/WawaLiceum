# CLAUDE.md

## What This Repo Is

**WawaLiceum** — Decision Support System (DSS/BI) helping Warsaw 8th-graders choose a liceum. Currently in design/planning phase: DB schema done, UX mockups done, no application code yet.

## Project Stack

| Layer | Tech |
|-------|------|
| Database | MS SQL Server (`WawaLiceumDB`), Star Schema |
| ETL | Stitch (no-code pipeline), source CSVs/XLSX |
| Frontend | Mobile app, Material Design 3, HTML/Tailwind CSS |
| Query language | T-SQL / DAX |

## Data Sources

- **RSPO** — school registry (addresses, types)
- **dane.gov.pl (CKE/OKE)** — matura results (basic/extended) + EWD indicators
- **Klimatyczna Mapa Szkół m.st. Warszawy** — noise level, green space %, class size, infrastructure
- **Ranking Szkół Przyjaznych (Mapa Równości)** — openness/safety index

## Database Schema (Star Schema)

```
Fakt_Rekrutacja_Wyniki (id_fakt PK, id_szkoly FK, id_profilu FK, id_atmosfera FK, id_czas FK,
  prog_punktowy, ewd_humanistyczne_proc, wynik_matura_polski_proc, wynik_matura_wos_proc,
  czas_dojazdu_min)

Wymiar_Szkola    (id_szkoly PK/RSPO, nazwa_liceum, adres, dzielnica, typ_placowki)
Wymiar_Atmosfera (id_atmosfera PK, id_szkoly FK, ranking_rownosci_poz, etat_psychologa_100os,
  liczebnosc_klas_srednia, poziom_halasu_otoczenia, tereny_zielone_procent, czy_cisza_przerwa)
Wymiar_Profil    (id_profilu PK, nazwa_klasy, rozszerzenia, czy_lacina, patronat_uczelni)
Wymiar_Czas      (id_czas PK, rok_szkolny, czy_reforma_rocznik)
```

Wide matura data from OKE is normalized via `UNPIVOT` + subject lookup table.

## Recruitment Point Algorithm (max 200 pts)

```
Exam score (max 100 pts):
  Polish:       result_% x 0.35
  Math:         result_% x 0.35
  Foreign lang: result_% x 0.30

Certificate (max 100 pts):
  4 subject grades (Polish, Math + 2 profile-specific):
    Celujacy=18, Bdb=17, Dobry=14, Dostateczny=8, Dopuszczajacy=2
  Red stripe (wyroznienie): 7 pts
  Volunteering: 3 pts
  Kuratorium competitions: actual pts, CAP at 18 pts
```

## UI Screens (6)

| # | Screen | Key feature |
|---|--------|-------------|
| 0 | Splash | Async dictionary load from DB |
| 1 | Kalkulator | Exam/grade inputs → 158.00 pt result + "Twoja Analiza" card |
| 2 | Lista Liceow | Filters (Dzielnica/Profil/Jezyk) + dynamic chance status vs. Screen 1 score |
| 3 | Karta Liceum | EWD, class offers, 5-year threshold trend chart per profile |
| 4 | Moja Lista | Drag & Drop preference ranking (1-5) for Vulcan registration |
| 5 | Porowywarka | Side-by-side: hard criteria (thresholds, EWD, matura) + soft (noise, class size, psychologist) |

Nav: persistent bottom bar — Kalkulator | Szukaj | Moja Lista | Porownaj

## Key Files

| Path | Purpose |
|------|---------|
| `docs/README.md` | Full project specification (Polish) |
| `docs/db/SkryptDDL.sql` | DB creation script for `WawaLiceumDB` |
| `docs/db/Diagram_encji.png` | ER diagram |
| `docs/ux/` | 6 Figma mockup exports (numbered 1-6) |

## Working Conventions

- T-SQL queries must follow star schema above — join through fact table, filter on dimension tables.
- Score from Screen 1 (Kalkulator) propagates to Screen 2 (Lista) for chance status — treat as shared session state.
- EWD in Karta Liceum splits into humanistyczne and matematyczne blocks.
- No application code exists yet — when generating code, match Material Design 3 and Tailwind CSS conventions.

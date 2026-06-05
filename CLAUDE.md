# CLAUDE.md

## What This Repo Is

**WawaLiceum** — two-project data ecosystem for Warsaw 8th-graders choosing a liceum:

- **Project 1 — DWH/BI:** Star schema data warehouse + Power BI analytics
- **Project 2 — Mobile App (DSS):** Mobile decision-support app consuming DWH data

Currently in design/planning phase: DB schema done, UX mockups done, no application code yet.

## Project Stack

| Layer | Tech |
|-------|------|
| Database | MS SQL Server (`WawaLiceumDB`), Star Schema (modeled in DataModeller) |
| ETL | Stitch (no-code pipeline), source CSVs/XLSX/PDF/RSPO registry |
| BI reporting | Power BI |
| Mobile app IDE | JetBrains Rider |
| Frontend | Material Design 3, HTML/Tailwind CSS |
| Query language | T-SQL / DAX |

## Data Sources

- **RSPO** — school registry (addresses, types)
- **dane.gov.pl (CKE/OKE)** — matura results (basic/extended) + EWD indicators
- **ewd.edu.pl / naszaszkola.edu.pl** — EWD per school (Educational Value Added charts)
- **Klimatyczna Mapa Szkół m.st. Warszawy** — noise level, green space %, class size, infrastructure (PDF)
- **swiadomywybieram.pl** — atmosphere ratings, soft indicators
- **Ranking Perspektyw** — national school ranking
- **waszaedukacja.pl** — supplemental school data

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

Wide matura data from OKE normalized via `UNPIVOT` + subject lookup table.

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
| 1 | Kalkulator | Exam/grade inputs → score + "Twoja Analiza" card (decile level, suggested profiles) |
| 2 | Lista Liceow | Filters (Dzielnica/Profil/Jezyk) + 3-tier chance badge: high / medium / dream school |
| 3 | Karta Liceum | EWD (hum + mat blocks), class offers, 5-year threshold trend chart per profile |
| 4 | Moja Lista | Drag & Drop preference ranking (1-5) + PDF export for Vulcan + safety school warning |
| 5 | Porownywarka | Side-by-side (up to 4 schools): hard criteria (thresholds, EWD, matura) + soft (noise, class size, psychologist) |

Nav: persistent bottom bar — Kalkulator | Szukaj | Moja Lista | Porownaj

**Chance tiers (Screen 2 badge logic):**
- High chance: score comfortably above historical threshold
- Medium/realistic: score within range of threshold
- Dream school: score below threshold (high risk)

**Vulcan warning (Screen 4):** warn user when list has too many dream schools at top without safety schools at the end.

## Key Files

| Path | Purpose |
|------|---------|
| `docs/README.md` | Project specification (Polish) |
| `Data/Project description .docx` | Project description (English, authoritative) |
| `docs/db/SkryptDDL.sql` | DB creation script for `WawaLiceumDB` |
| `docs/db/Diagram_encji.png` | ER diagram |
| `docs/ux/` | 6 Figma mockup exports (numbered 1-6) |
| `Data/skrypt_etl.py` | ETL script |
| `Data/Matury 2025 *.csv` | Raw matura data (basic + extended) |

## Power BI Analytics Goals (Project 1)

Key analytical questions the DWH must support:
- "Schools of wasted opportunities": high entry thresholds but negative EWD (school lowers student potential)
- Humanities profile schools with threshold <165 pts but positive humanities EWD ("hidden gems")
- Correlation between modern infrastructure (Climate Map) and atmosphere ratings

## Working Conventions

- T-SQL queries must follow star schema above — join through fact table, filter on dimension tables.
- Score from Screen 1 (Kalkulator) propagates to Screen 2 (Lista) for chance badge — treat as shared session state.
- EWD in Karta Liceum splits into humanistyczne and matematyczne blocks.
- No application code exists yet — when generating code, match Material Design 3 and Tailwind CSS conventions.
- IDE: JetBrains Rider.

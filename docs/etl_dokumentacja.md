# Dokumentacja procesu ETL — WawaLiceumDB

## 1. Cel i zakres

Proces ETL (Extract–Transform–Load) buduje hurtownię danych **WawaLiceumDB** — gwiaździsty schemat (star schema) zawierający dane o 196 warszawskich liceach ogólnokształcących dla rocznika rekrutacji 2023–2026.

Hurtownia zasila:
- **Projekt 1:** raporty analityczne Power BI (BI/DWH)
- **Projekt 2:** mobilna aplikacja wspomagania decyzji (DSS) dla 8-klasisty wybierającego liceum

---

## 2. Architektura i przepływ danych

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                        ŹRÓDŁA DANYCH                                        ║
╠══════════════╦══════════════╦══════════════╦══════════════╦══════════════════╣
║  RSPO.xlsx   ║ Matury CSV   ║ Ranking      ║ Progi PDF    ║ Plan naboru xlsx ║
║ (rejestr MEN)║ (CKE/OKE)   ║ Perspektyw   ║ 2023/24/25   ║ 2026             ║
║              ║              ║ xlsx 2023-26 ║              ║                  ║
╠══════════════╩══════════════╩══════════════╩══════════════╩══════════════════╣
║  Informator PDF              ║  ewd.edu.pl API  ║  swiadomiewybieram.pl      ║
║  (Klimatyczna Mapa Szkół)    ║  (REST, scraper) ║  (web scraper, login)      ║
╚══════════════════════════════╩══════════════════╩════════════════════════════╝
                    │                   │                   │
                    ▼                   ▼                   ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║                    FAZA 1: EXTRACT → TABELE STAGING                          ║
║                                                                              ║
║  stg_rspo        (230 wierszy)   ← RSPO.xlsx                                ║
║  stg_matura      (3 850 wierszy) ← Matury 2025 CSV (podst. + rozsz.)        ║
║  stg_ranking     (404 wiersze)   ← Ranking Perspektyw xlsx                  ║
║  stg_plan_naboru (157 wierszy)   ← Plan naboru xlsx                         ║
║  stg_progi       (2 495 wierszy) ← 3 × PDF (2023, 2024, 2025)              ║
║  stg_informator_flags (98 wierszy)  ← Informator PDF (flagi infrastruktury) ║
║  stg_informator_inicjatywy (567)    ← Informator PDF (programy szkół)       ║
║  stg_ewd         (2 318 wierszy) ← api-ewd.men.gov.pl (scraper REST)        ║
║  stg_atmosfera   (148 wierszy)   ← swiadomiewybieram.pl (web scraper)       ║
║  stg_nominatim_coords (230 wierszy) ← Nominatim OSM API (geokodowanie)      ║
╚══════════════════════════════════════════════════════════════════════════════╝
                                   │
                                   ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║                    FAZA 2: DOPASOWANIE NAZW SZKÓŁ                            ║
║                                                                              ║
║  stg_school_xref (467 wierszy)                                              ║
║                                                                              ║
║  Problem: każde źródło używa innej formy nazwy szkoły (skróty, numeracja,  ║
║  różne znaki). Moduł school_matcher.py łączy nazwy z różnych źródeł         ║
║  (ranking, plan_naboru, progi, informator) z kanoniczną nazwą z RSPO        ║
║  metodą dopasowania rozmytego (fuzzy matching) + słownik overrides.csv.     ║
║                                                                              ║
║  Wynik: tabela xref [source | source_name | id_szkoly_rspo]                 ║
╚══════════════════════════════════════════════════════════════════════════════╝
                                   │
                                   ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║                    FAZA 3: TRANSFORM → WYMIARY (SQL)                         ║
║                    Skrypt: sql/10_transform_dims.sql                         ║
║                                                                              ║
║  stg_rspo           → Wymiar_Szkola        (196 szkół)                      ║
║  stg_ewd            → Wymiar_Typ_EWD       (14 typów egzaminów EWD)         ║
║  stg_matura         → Wymiar_Przedmiot_Maturalny (22 przedmioty)            ║
║  lata z wszystkich  → Wymiar_Czas          (15 lat: 2012–2026)              ║
║  stg_atmosfera      → Wymiar_Atmosfera     (149 szkół, 49 kolumn)           ║
║  stg_nominatim      → Wymiar_Szkola        (aktualizacja: lat/lon)          ║
║  stg_informator_    → Wymiar_Inicjatywy_Zewnetrzne (559 pozycji)            ║
║                        + Mostek_Szkola_Inicjatywy  (466 par)                ║
╚══════════════════════════════════════════════════════════════════════════════╝
                                   │
                                   ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║                    FAZA 4: TRANSFORM → FAKTY (SQL)                           ║
║                    Skrypt: sql/20_transform_facts.sql                        ║
║                                                                              ║
║  stg_ewd            → Fakt_Matura_EWD                (2 128 wierszy)        ║
║  stg_matura         → Fakt_Matura_Statystyki_Szczeg. (3 740 wierszy)        ║
║  stg_progi + xref   → Fakt_Rekrutacja_Wyniki         (1 784 wiersze)        ║
║  stg_plan_naboru    → Fakt_Plan_Naboru               (144 wiersze)          ║
║  stg_ranking + xref → Fakt_Ranking_Perspektywy       (400 wierszy)          ║
╚══════════════════════════════════════════════════════════════════════════════╝
                                   │
                                   ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║                    FAZA 5: OCZYSZCZANIE I WALIDACJA (SQL)                    ║
║                                                                              ║
║  sql/30_cleanup_schools.sql   — usunięcie szkół bez danych rekrutacyjnych   ║
║  sql/40_inicjatywy_miedzynarodowe.sql — klasyfikacja programów IB/MM        ║
║  sql/90_validation.sql        — zapytania kontrolne (ukryte diamenty,        ║
║                                  zmarnowane szanse, liczebnościowe checks)  ║
╚══════════════════════════════════════════════════════════════════════════════╝
                                   │
                                   ▼
╔══════════════════════════════════════════════════════════════════════════════╗
║                         WawaLiceumDB — HURTOWNIA DANYCH                      ║
║                         Microsoft SQL Server 2022                            ║
║                         Schemat gwiazdowy (Star Schema)                      ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 3. Źródła danych — szczegóły

| # | Źródło | Format | Moduł ETL | Zakres |
|---|--------|--------|-----------|--------|
| 1 | **RSPO** — Rejestr Szkół i Placówek Oświatowych (MEN) | XLSX | `extract/rspo.py` | Dane rejestrowe: adres, REGON, dyrektor, data założenia, 230 liceów warszawskich |
| 2 | **CKE/OKE** — wyniki matur 2025 | CSV (cp1250, sep=;) | `extract/matury.py` | Zdawalność, średni wynik, liczba zdających per szkoła × przedmiot × poziom |
| 3 | **Ranking Perspektyw** 2023–2026 | XLSX | `extract/ranking.py` | Pozycja i wskaźnik sumaryczny per szkoła per rok |
| 4 | **Plan naboru** 2026 (m.st. Warszawa) | XLSX | `extract/plan_naboru.py` | Liczba klas, miejsc, język dwujęzyczny per szkoła per typ oddziału |
| 5 | **Progi punktowe** 2023/2024/2025 | PDF (3 pliki) | `extract/progi_pdf.py` | Minimalne progi rekrutacyjne per klasa per rok |
| 6 | **Klimatyczna Mapa Szkół** (Informator) | PDF | `extract/informator_pdf.py` | 27 flag infrastruktury (WiFi, psycholog, siłownia…), aktywne metody, inicjatywy |
| 7 | **ewd.edu.pl** (API REST MEN) | JSON (scraper) | `scrape/ewd.py` | EWD per szkoła per typ egzaminu per rok (2012–2022 i 2025) |
| 8 | **swiadomiewybieram.pl** | HTML (scraper) | `scrape/atmosfera.py` | 7 ocen procentowych atmosfery, 27 flag, czas nauki, liczba ankiet |
| 9 | **Nominatim OSM** | REST API | `scrape/nominatim_coords.py` | Geokodowanie adresów → współrzędne GPS (lat/lon) dla 196 szkół |

---

## 4. Schemat hurtowni danych

### Tabele wymiarów (Dimensions)

| Tabela | Wiersze | Klucz główny | Opis |
|--------|---------|--------------|------|
| `Wymiar_Szkola` | 196 | `id_szkoly_rspo` | Dane rejestrowe szkoły (adres, dzielnica, GPS, organ prowadzący) |
| `Wymiar_Czas` | 15 | `id_czas` | Lata 2012–2026, rok kalendarzowy i szkolny |
| `Wymiar_Atmosfera` | 149 | `id_atmosfera` | 27 flag infrastruktury + 7 ocen procentowych uczniów |
| `Wymiar_Przedmiot_Maturalny` | 22 | `id_przedmiotu` | Przedmiot × poziom (podstawowy/rozszerzony) |
| `Wymiar_Typ_EWD` | 14 | `id_typu_ewd` | Typ egzaminu EWD (humanistyczny, mat-przyr, per-subject od 2024) |
| `Wymiar_Inicjatywy_Zewnetrzne` | 559 | `id_inicjatywy` | Programy, inicjatywy, aktywności szkoły (9 kategorii) |

### Tabele faktów (Facts)

| Tabela | Wiersze | Ziarnistość | Opis |
|--------|---------|-------------|------|
| `Fakt_Matura_EWD` | 2 128 | szkoła × typ EWD × rok | Edukacyjna Wartość Dodana, przedziały ufności, klasyfikacja szkoły |
| `Fakt_Matura_Statystyki_Szczegolowe` | 3 740 | szkoła × przedmiot × rok | Zdawalność, średni wynik, liczba zdających, laureaci |
| `Fakt_Rekrutacja_Wyniki` | 1 784 | klasa × rok | Progi punktowe min. (2023–2025) per klasa |
| `Fakt_Plan_Naboru` | 144 | szkoła × typ klasy | Oferta miejsc na rok szkolny 2026/2027 |
| `Fakt_Ranking_Perspektywy` | 400 | szkoła × rok | Pozycja w rankingu, wskaźnik sumaryczny (2023–2026) |

### Tabela mostkowa (Bridge)

| Tabela | Wiersze | Opis |
|--------|---------|------|
| `Mostek_Szkola_Inicjatywy` | 466 | Relacja wiele-do-wielu: szkoła ↔ inicjatywa |

---

## 5. Technologia i narzędzia

| Warstwa | Technologia |
|---------|-------------|
| Język ETL | Python 3.12 |
| Biblioteki | pandas, SQLAlchemy 2.x, pymssql, pdfplumber, BeautifulSoup4, rapidfuzz |
| Baza docelowa | Microsoft SQL Server 2022 (Docker na Mac / natywny na Windows) |
| Transformacje SQL | T-SQL (wykonywane w SSMS lub sqlcmd) |
| Geokodowanie | Nominatim OSM API (z cache JSON) |
| Zarządzanie konfiguracją | `.env` (hasło SA, dane logowania do scraperów) |

---

## 6. Uruchomienie ETL — kolejność kroków

```
Krok 1   sql/00_create_warehouse.sql    Tworzenie schematu (DDL)
Krok 2   python -m etl.load_staging     Extract → staging + matching
Krok 3   sql/10_transform_dims.sql      Staging → wymiary
Krok 4   sql/20_transform_facts.sql     Staging → fakty
Krok 5   sql/30_cleanup_schools.sql     Oczyszczanie
Krok 6   sql/40_inicjatywy_...sql       Klasyfikacja inicjatyw
Krok 7   python -m etl.scrape.nominatim_coords   Geokodowanie GPS
Krok 8   sql/90_validation.sql          Walidacja (opcjonalnie)
```

---

## 7. Wyzwania i decyzje projektowe

| Problem | Rozwiązanie |
|---------|-------------|
| Różne formy nazw szkół w każdym źródle | `school_matcher.py` — fuzzy matching (rapidfuzz) + ręczne override'y w `overrides.csv` |
| SQL Server limit 2100 parametrów per INSERT | `insertmanyvalues_page_size=35` w SQLAlchemy 2.x |
| Kodowanie polskich znaków w CSV | `encoding="cp1250"` przy odczycie; `charset=utf8` w połączeniu pymssql |
| EWD: agregaty dostępne do 2022, per-subject od 2024 | Miary DAX z COALESCE: agregat jeśli dostępny, fallback na per-subject |
| Geokodowanie: 230 szkół × API rate limit | Cache JSON (`_cache/nominatim_coords.json`) + opóźnienie 1,5 s między zapytaniami |
| Progi PDF: brak struktury tabelarycznej | `pdfplumber` + regex ekstrakcja wzorców numerycznych |
| Tylko 62/196 szkół ma dane EWD | Dane EWD publikowane tylko dla szkół z ≥30 zdającymi — ograniczenie źródła |

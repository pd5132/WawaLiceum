# Technologie stosowane w projekcie WawaLiceum

Projekt składa się z dwóch warstw: hurtowni danych z raportowaniem BI (Projekt 1) oraz mobilnej aplikacji wspomagania decyzji (Projekt 2 — DSS).

---

## 1. Hurtownia danych (DWH)

| Technologia | Zastosowanie |
|-------------|-------------|
| **MS SQL Server** | Relacyjna baza danych `WawaLiceumDB` (instancja `LaptopAgi\MSSQLSERVER1`) |
| **Star Schema** | Architektura hurtowni: 5 tabel faktów, 7 tabel wymiarów, 1 tabela mostkowa |
| **T-SQL** | DDL (tworzenie i modyfikacja schematu), transformacje staging → warehouse, zapytania walidacyjne |
| **sqlcmd** | CLI do uruchamiania skryptów SQL na SQL Server |
| **DataModeller** | Narzędzie do wizualnego projektowania schematu gwiazdy |

### Schemat hurtowni (tabele)

```
Tabele faktów:   Fakt_Rekrutacja_Wyniki, Fakt_Plan_Naboru,
                 Fakt_Matura_EWD, Fakt_Matura_Statystyki_Szczegolowe,
                 Fakt_Ranking_Perspektywy
Tabele wymiarów: Wymiar_Szkola, Wymiar_Atmosfera, Wymiar_Czas,
                 Wymiar_Przedmiot_Maturalny, Wymiar_Typ_EWD,
                 Wymiar_Inicjatywy_Zewnetrzne
Mostek:          Mostek_Szkola_Inicjatywy
```

---

## 2. ETL (pipeline danych)

### Środowisko

| Technologia | Wersja | Zastosowanie |
|-------------|--------|-------------|
| **Python** | 3.12+ | Język skryptów ETL |
| **uv** | — | Menedżer pakietów Python (pyproject.toml + uv.lock) |

### Biblioteki Python

| Biblioteka | Wersja | Zastosowanie |
|-----------|--------|-------------|
| **pandas** | 3.0+ | Manipulacja danymi tabelarycznymi, transformacje |
| **openpyxl** | 3.1+ | Parsowanie plików XLSX (RSPO, Ranking Perspektyw, Plan naboru) |
| **SQLAlchemy** | 2.0+ | ORM i połączenie z SQL Server |
| **pyodbc** | 5.0+ | ODBC bridge dla SQL Server (Windows) |
| **requests** | 2.31+ | Zapytania HTTP do scrapowanych witryn |
| **beautifulsoup4** | 4.12+ | Parsowanie HTML (waszaedukacja.pl, swiadomiewybieram.pl) |
| **lxml** | 5.0+ | Parser XML/HTML używany przez BeautifulSoup |
| **pdfplumber** | 0.11+ | Parsowanie plików PDF (progi punktowe 2023/2024/2025, Informator Licea 2026) |
| **rapidfuzz** | 3.6+ | Fuzzy matching nazw szkół do identyfikatorów RSPO |

### Przepływ ETL

```
Źródła danych
    │
    ▼
Staging (stg_*) — tabele tymczasowe w SQL Server, ładowane przez Python
    │
    ▼
Warehouse (Wymiar_* + Fakt_*) — transformacje T-SQL
```

Szczegółowy opis przepływu: [`docs/ETL.md`](ETL.md)

---

## 3. Raportowanie BI

| Technologia | Zastosowanie |
|-------------|-------------|
| **Power BI** | Raporty analityczne na danych hurtowni (Projekt 1) |
| **DAX** | Język miar i kalkulacji w Power BI |

---

## 4. Aplikacja mobilna DSS (Projekt 2)

| Technologia | Zastosowanie |
|-------------|-------------|
| **JetBrains Rider** | IDE do tworzenia aplikacji |
| **Material Design 3** | System komponentów UI — przyciski, karty, nawigacja, formularze |
| **Tailwind CSS** | Utility-first CSS — layout, spacing, kolory, typografia |
| **HTML** | Markup widoków aplikacji |
| **Plus Jakarta Sans** | Krój pisma (Google Fonts) — zastępuje domyślne Roboto |
| **Leaflet + OpenStreetMap** | Interaktywna mapa szkół (widok Mapa w ekranie Szukaj) |

### Paleta kolorów (design system)

| Token | Kolor | Hex |
|-------|-------|-----|
| Primary | Emerald | `#059669` |
| Tło aplikacji | Mint cream | `#F0FDF9` |
| Akcent / Ranking | Amber | `#F59E0B` |
| Wysokie szanse | Zielony | `#22C55E` |
| Realistyczna | Pomarańczowy | `#FB923C` |
| Szkoła marzeń | Czerwony | `#EF4444` |

Pełna specyfikacja: [`docs/ux/design-system.md`](ux/design-system.md)

---

## 5. Kontrola wersji i narzędzia projektowe

| Narzędzie | Zastosowanie |
|-----------|-------------|
| **Git** | Kontrola wersji kodu |
| **GitHub** | Repozytorium zdalne (`pd5132/WawaLiceum`), branch `dev` |
| **Figma** | Prototypy UX — 6 ekranów aplikacji mobilnej |

---

## 6. Zewnętrzne źródła danych

| Źródło | Format | Dane |
|--------|--------|------|
| **RSPO** (rejestr szkół) | XLSX | Nazwy, adresy, identyfikatory RSPO liceów warszawskich |
| **CKE / OKE** (mapa.wyniki.edu.pl) | CSV, XLSX | Wyniki egzaminów maturalnych (podstawowy + rozszerzony) |
| **ewd.edu.pl / waszaedukacja.pl** | Web scraping (HTML) | Wskaźniki EWD (Edukacyjna Wartość Dodana) per szkoła |
| **Ranking Perspektyw 2026** | XLSX | Pozycja rankingowa i wskaźnik sumaryczny (multi-year) |
| **Plan naboru 2026** | XLSX | Liczba oddziałów i miejsc per typ oddziału |
| **Progi punktowe 2023–2025** | PDF (3 różne formaty) | Minimalne i maksymalne progi rekrutacyjne per oddział |
| **Informator Licea 2026** | PDF | 27 flag infrastrukturalnych + inicjatywy zewnętrzne (98 szkół) |
| **swiadomiewybieram.pl** | Web scraping (HTML) | Oceny atmosfery szkolnej (%), wskaźniki miękkie |
| **pl.wikipedia.org** | Web scraping (geotagi) | Współrzędne geograficzne szkół (lat/long) |

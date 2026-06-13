# SPECYFIKACJA PROJEKTU WawaLiceum

## 1. Cel i charakterystyka systemu
Nazwa systemu: WawaLiceum
Typ systemu: System Wspomagania Decyzji (DSS) / Platforma Analityczna Business Intelligence (BI).
Cel biznesowy: Kompleksowe, wielokryterialne wspomaganie ósmoklasistów i ich rodziców w procesie wyboru liceum ogólnokształcącego na terenie m.st. Warszawy. 
Filozofia projektowa: Uniwersalność i personalizacja. System odchodzi od jednowymiarowych rankingów na rzecz integracji danych twardych (wyniki egzaminów, progi) z parametrami miękkimi (dobrostan, infrastruktura, otoczenie, wielkość klas), dopasowując wyniki do profilu psychofizycznego i naukowego każdego ucznia.

## 2. Architektura danych i potok ETL
System integruje rozproszone dane z publicznych, legalnych rejestrów rządowych, miejskich oraz społecznych:
- Rejestr Szkół i Placówek Oświatowych (RSPO) – baza teleadresowa, typy placówek.
- Dane.gov.pl (CKE/OKE) – historyczne wyniki egzaminów maturalnych (poziom podstawowy i rozszerzony) oraz wskaźniki Edukacyjnej Wartości Dodanej (EWD).
- ewd.edu.pl / naszaszkola.edu.pl – wskaźniki EWD per szkoła (wykresy EWD maturalnych).
- Klimatyczna Mapa Szkół m.st. Warszawy – parametry fizyczne otoczenia (poziom hałasu, odsetek terenów zielonych wokół budynku, wielkość klas pierwszych, infrastruktura) – plik PDF.
- swiadomywybiorem.pl – oceny atmosfery, wskaźniki miękkie.
- Ranking Perspektyw – ogólnopolski ranking szkół.
- waszaedukacja.pl – uzupełniające dane o szkołach.
- Mapa Wyników Egzaminów (mapa.wyniki.edu.pl/MapaEgzaminow/) – szczegółowe wyniki maturalne per szkoła (OKE), pliki XLSX per rok szkolny; źródło danych EM2023 załadowanych do stg_matura.

Potok danych (Data Pipeline):
Surowe zbiory danych (CSV/XLSX) są konsolidowane w repozytorium chmurowym, a następnie mapowane i ładowane za pomocą narzędzia Stitch (no-code data pipeline) do centralnej bazy danych.

## 3. Model Hurtowni Danych (MS SQL Server - Model Gwiazdy)
Silnik bazy danych implementuje architekturę Star Schema z centralną tabelą faktów i czterema tabelami wymiarów:

- Wymiar_Szkola (id_szkoly [PK/RSPO], nazwa_liceum, adres, dzielnica, typ_placowki)
- Wymiar_Atmosfera (id_atmosfera [PK], id_szkoly [FK], ranking_rownosci_poz, etat_psychologa_100os, liczebnosc_klas_srednia, tereny_zielone_procent, czy_cisza_przerwa)
- Wymiar_Profil (id_profilu [PK], nazwa_klasy, rozszerzenia, czy_lacina, patronat_uczelni)
- Wymiar_Czas (id_czas [PK], rok_szkolny, czy_reforma_rocznik)
- Fakt_Rekrutacja_Wyniki (id_fakt [PK], id_szkoly [FK], id_profilu [FK], id_atmosfera [FK], id_czas [FK], prog_punktowy, ewd_humanistyczne_proc, wynik_matura_polski_proc, wynik_matura_wos_proc, czas_dojazdu_min)

Logika transformacji (UNPIVOT): Szerokie struktury danych maturalnych z OKE są w bazie normalizowane za pomocą operatora `UNPIVOT` i łączone z tabelą słownikową przedmiotów, umożliwiając dynamiczne filtrowanie.

## 4. Logika Biznesowa (Algorytm Rekrutacyjny)
Aplikacja implementuje oficjalny algorytm przeliczania punktów rekrutacyjnych Kuratorium Oświaty (maks. 200 pkt):
1. Punkty za egzamin ósmoklasisty (maks. 100 pkt):
   - Język polski: wynik % * 0.35
   - Matematyka: wynik % * 0.35
   - Język obcy: wynik % * 0.30
2. Punkty za świadectwo i osiągnięcia (maks. 100 pkt):
   - Oceny z 4 przedmiotów (Polski, Matematyka + 2 przedmioty wskazane przez dyrekcję zależnie od profilu klasy): Celujący = 18 pkt, Bdobry = 17 pkt, Dobry = 14 pkt, Dostateczny = 8 pkt, Dopuszczający = 2 pkt.
   - Świadectwo z wyróżnieniem (czerwony pasek): 7 pkt.
   - Wolontariat = 3 pkt
   - Konkursy kuratoryjne: suma punktów rzeczywistych, zablokowana systemowym limitem górnym (CAP) do maks. 18 pkt.

## 5. Struktura Interfejsu Użytkownika (UI/UX - 6 Ekranów)
Interfejs mobilny oparty jest na standardzie Material Design 3 i zorganizowany w stały dolny pasek nawigacyjny (Kalkulator, Szukaj, Moja Lista, Porównaj):

- Ekran 0: Splash Screen – Ekran powitalny inicjujący sesję i asynchroniczne pobieranie słowników z bazy danych. zawiera logo i hasło przewodnie.
- Ekran 1: Kalkulator – Formularz wejściowy. Uczeń wybiera dzielnicę Warszawy, wprowadza wyniki egzaminów (%) oraz oceny ze świadectwa (dropdowny dla 4 przedmiotów), zaznacza obecność paska (Switch) i dodatkowe punkty. System dynamicznie wylicza łączny wynik (np. 158.00 pkt) i generuje kartę "Twoja Analiza" (poziom decyli, sugerowane profile).
- Ekran 2: Lista Liceów – Wyszukiwarka z horyzontalnym paskiem filtrów (Dzielnica, Profil, Język). Prezentuje pionową listę kart szkół (1:1 z makietą Figmy). Każda karta zawiera logo, nazwę, próg punktowy oraz dynamiczny status szans (np. "Wysoki próg" / "Masz szansę") obliczany na podstawie danych z Ekranu 1.
- Ekran 3: Karta Liceum – Pełna analityka szkoły. Zawiera przełącznik tła maturalnego (Podstawowe/Rozszerzone), wskaźnik EWD, ofertę klas oraz unikalny wykres trendu progów punktowych z ostatnich 5 lat dla poszczególnych profili klas.
- Ekran 4: Moja Lista – Panel układania własnej listy preferencji rekrutacyjnych (od 1 do 5) z interfejsem Drag & Drop, ułatwiający przygotowanie do rejestracji w oficjalnym systemie Vulcan.
- Ekran 5: Porównywarka – Tabela zestawiająca wybrane szkoły kolumnowo pod kątem kryteriów twardych (progi na profile, 3-letnie EWD bloku humanistycznego/matematycznego, wyniki matur) i miękkich (hałas z mapy klimatycznej m.st. Warszawy, wielkość klas pierwszych, dostępność psychologa).

## 6. Instrukcje dla Agenta AI
Agent AI wykorzystujący ten kontekst powinien:
1. Generować zapytania T-SQL/DAX zgodnie z podanym modelem gwiazdy i logiką algorytmu rekrutacyjnego (mnożniki, limity punktów).
2. Wspierać rozwój kodu HTML/Tailwind dla wymienionych ekranów, dbając o spójność danych (np. przenoszenie wyniku 158.00 pkt).
3. Analizować zapytania pod kątem optymalizacji relacyjnej i wydajności w środowisku MS SQL Server.
# SPECYFIKACJA PROJEKTU WawaLiceum

## 1. Cel i charakterystyka systemu
Nazwa systemu: WawaLiceum
Typ systemu: System Wspomagania Decyzji (DSS) / Platforma Analityczna Business Intelligence (BI).
Cel biznesowy: Kompleksowe, wielokryterialne wspomaganie ósmoklasistów i ich rodziców w procesie wyboru liceum ogólnokształcącego na terenie m.st. Warszawy. 
Filozofia projektowa: Uniwersalność i personalizacja. System odchodzi od jednowymiarowych rankingów na rzecz integracji danych twardych (wyniki egzaminów, progi) z parametrami miękkimi (dobrostan, infrastruktura, otoczenie, wielkość klas), dopasowując wyniki do profilu psychofizycznego i naukowego każdego ucznia.

## 2. Architektura danych i potok ETL
System integruje rozproszone dane z publicznych, legalnych rejestrów rządowych, miejskich oraz społecznych:
- Rejestr Szkół i Placówek Oświatowych (RSPO) – baza teleadresowa, typy placówek.
- Dane.gov.pl (CKE/OKE) – historyczne wyniki egzaminów maturalnych (poziom podstawowy i rozszerzony) oraz wskaźniki Edukacyjnej Wartości Dodanej (EWD).
- Klimatyczna Mapa Szkół m.st. Warszawy – parametry fizyczne otoczenia (poziom hałasu, odsetek terenów zielonych wokół budynku, wielkość klas pierwszych, infrastruktura).
- waszaedukacja.pl – wskaźniki EWD
- Mapa Wyników Egzaminów (mapa.wyniki.edu.pl/MapaEgzaminow/) – szczegółowe wyniki maturalne per szkoła (OKE), pliki XLSX per rok szkolny; źródło danych EM2023 załadowanych do stg_matura.

Potok danych (Data Pipeline):
Surowe zbiory danych (CSV/XLSX) są konsolidowane w repozytorium chmurowym, a następnie mapowane i ładowane za pomocą narzędzia Stitch (no-code data pipeline) do centralnej bazy danych.

## 3. Model Hurtowni Danych (MS SQL Server - Model Gwiazdy)
Silnik bazy danych implementuje architekturę Star Schema z centralną tabelą faktów i czterema tabelami wymiarów:

- Wymiar_Szkola (id_szkoly [PK/RSPO], nazwa_liceum, adres, dzielnica, typ_placowki)
- Wymiar_Atmosfera (id_atmosfera [PK], id_szkoly [FK], ranking_rownosci_poz, etat_psychologa_100os, liczebnosc_klas_srednia, poziom_halasu_otoczenia, tereny_zielone_procent, czy_cisza_przerwa)
- Wymiar_Profil (id_profilu [PK], nazwa_klasy, rozszerzenia, czy_lacina, patronat_uczelni)
- Wymiar_Czas (id_czas [PK], rok_szkolny, czy_reforma_rocznik)
- Fakt_Rekrutacja_Wyniki (id_fakt [PK], id_szkoly [FK], id_profilu [FK], id_atmosfera [FK], id_czas [FK], prog_punktowy, ewd_humanistyczne_proc, wynik_matura_polski_proc, wynik_matura_wos_proc, czas_dojazdu_min)

Logika transformacji (UNPIVOT): Szerokie struktury danych maturalnych z OKE są w bazie normalizowane za pomocą operatora `UNPIVOT` i łączone z tabelą słownikową przedmiotów, umożliwiając dynamiczne filtrowanie.

## 4. Logika Biznesowa (Algorytm Rekrutacyjny)
Aplikacja implementuje oficjalny algorytm przeliczania punktów rekrutacyjnych Kuratorium Oświaty (maks. 200 pkt):
1. Punkty za egzamin ósmoklasisty (maks. 100 pkt):
   - Język polski: wynik % * 0.35
   - Matematyka: wynik % * 0.35
   - Język obcy: wynik % * 0.30
2. Punkty za świadectwo i osiągnięcia (maks. 100 pkt):
   - Oceny z 4 przedmiotów (Polski, Matematyka + 2 przedmioty wskazane przez dyrekcję zależnie od profilu klasy): Celujący = 18 pkt, Bdobry = 17 pkt, Dobry = 14 pkt, Dostateczny = 8 pkt, Dopuszczający = 2 pkt.
   - Świadectwo z wyróżnieniem (czerwony pasek): 7 pkt.
   - Wolontariat = 3 pkt
   - Konkursy kuratoryjne: suma punktów rzeczywistych, zablokowana systemowym limitem górnym (CAP) do maks. 18 pkt.

## 5. Struktura Interfejsu Użytkownika (UI/UX - 6 Ekranów)
Interfejs mobilny oparty jest na standardzie Material Design 3 i zorganizowany w stały dolny pasek nawigacyjny (Kalkulator, Szukaj, Moja Lista, Porównaj):

- Ekran 0: Splash Screen – Ekran powitalny inicjujący sesję i asynchroniczne pobieranie słowników z bazy danych. zawiera logo i hasło przewodnie.
- Ekran 1: Kalkulator – Formularz wejściowy. Uczeń wybiera dzielnicę Warszawy, wprowadza wyniki egzaminów (%) oraz oceny ze świadectwa (dropdowny dla 4 przedmiotów), zaznacza obecność paska (Switch) i dodatkowe punkty. System dynamicznie wylicza łączny wynik (np. 158.00 pkt) i generuje kartę "Twoja Analiza" (poziom decyli, sugerowane profile).
- Ekran 2: Lista Liceów – Wyszukiwarka z horyzontalnym paskiem filtrów (Dzielnica, Profil, Język). Prezentuje pionową listę kart szkół (1:1 z makietą Figmy). Każda karta zawiera logo, nazwę, próg punktowy oraz dynamiczny status szans (np. "Wysoki próg" / "Masz szansę") obliczany na podstawie danych z Ekranu 1.
- Ekran 3: Karta Liceum – Pełna analityka szkoły. Zawiera przełącznik tła maturalnego (Podstawowe/Rozszerzone), wskaźnik EWD, ofertę klas oraz unikalny wykres trendu progów punktowych z ostatnich 5 lat dla poszczególnych profili klas.
- Ekran 4: Moja Lista – Panel układania własnej listy preferencji rekrutacyjnych (od 1 do 5) z interfejsem Drag & Drop, ułatwiający przygotowanie do rejestracji w oficjalnym systemie Vulcan.
- Ekran 5: Porównywarka – Tabela zestawiająca wybrane szkoły kolumnowo pod kątem kryteriów twardych (progi na profile, 3-letnie EWD bloku humanistycznego/matematycznego, wyniki matur) i miękkich (hałas z mapy klimatycznej m.st. Warszawy, wielkość klas pierwszych, dostępność psychologa).


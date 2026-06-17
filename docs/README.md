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
Silnik bazy danych implementuje architekturę Star Schema z 4 tabelami faktów, 1 tabelą mostkową i 7 tabelami wymiarów:

**Tabele wymiarów:**
- Wymiar_Szkola (id_szkoly_rspo [PK], id_zespolu_rspo, id_oke, regon, nazwa_liceum, nazwa_zespolu_szkol, adres, dzielnica, organ_prowadzacy, dyrektor_imie_nazwisko, data_zalozenia, czy_samodzielna, czy_publiczna, rodzaj_placowki, telefon, email, strona_www, url_facebook, url_instagram, wspolrzedne_lat, wspolrzedne_long)
- Wymiar_Atmosfera (id_atmosfera [PK], poziom_halasu_otoczenia, 27× czy_* [bit flags: czy_strefa_ciszy, czy_miejsce_odpoczynku, czy_ciche_dzwonki, czy_rozowa_skrzyneczka, czy_szafki_uczniow, czy_stojak_na_rowery, czy_teren_zielony, czy_otwarte_boiska, czy_sklepik_szkolny, czy_bufet_stolowka, czy_posilki_wegetarianskie, czy_posilki_weganskie, czy_zrodlo_wody_pitnej, czy_monitoring, czy_wejscie_na_karty, czy_rejestracja_gosci, czy_rzecznik_praw_ucznia, czy_pielegniarka, czy_psycholog_na_etacie, czy_pedagog_specjalny, czy_osoba_zaufania, czy_zajecia_tus, czy_rewalidacja, czy_winda, czy_podjazd_dla_wozkow, czy_petla_indukcyjna, czy_schodolaz], 7× *_proc [atmosfera_proc, przyjemnosc_nauki_proc, relacje_uczniow_proc, relacja_nauczyciel_proc, nowoczesnosc_zajec_proc, polecanie_szkoly_proc, jakosc_odpoczynku_proc], czas_nauki_po_lekcjach_min, liczba_ankiet)
- Wymiar_Profil (id_profilu [PK], symbol_oddzialu, nazwa_oddzialu, typ_oddzialu)
- Wymiar_Czas (id_czas [PK], rok_kalendarzowy, rok_szkolny)
- Wymiar_Przedmiot_Maturalny (id_przedmiotu [PK], nazwa_przedmiotu, poziom)
- Wymiar_Typ_EWD (id_typu_ewd [PK], nazwa_egzaminu, rodzaj_zapisu)
- Wymiar_Inicjatywy_Zewnetrzne (id_inicjatywy [PK], nazwa_elementu, typ_inicjatywy)

**Tabela mostkowa:**
- Mostek_Szkola_Inicjatywy (id_szkoly_rspo [FK], id_inicjatywy [FK])

**Tabele faktów:**
- Fakt_Rekrutacja_Wyniki (id_fakt [PK], id_profilu [FK], id_atmosfera [FK], id_czas [FK], id_szkoly_rspo [FK], prog_punktowy_min, liczba_oddzialow, liczba_miejsc, liczba_uczniow_ogolem)
- Fakt_Matura_EWD (id_fakt_ewd [PK], id_szkoly_rspo [FK], id_czas [FK], id_typu_ewd [FK], ewd_oszacowanie_punktowe, ewd_gorna_granica_ufnosci, ewd_dolna_granica_ufnosci, egzamin_oszacowanie_punktowe, egzamin_gorna_granica_ufnosci, egzamin_dolna_granica_ufnosci)
- Fakt_Matura_Statystyki_Szczegolowe (id_fakt_matura [PK], id_szkoly_rspo [FK], id_czas [FK], id_przedmiotu [FK], liczba_zdajacych, liczba_laureatow_finalistow, zdawalnosc_proc, sredni_wynik_proc, odchylenie_standardowe_proc, mediana_proc, modalna_proc)
- Fakt_Ranking_Perspektywy (id_rankingu [PK], id_czas [FK], id_szkoly_rspo [FK], pozycja_w_rankingu, wskaznik_sumaryczny)

Dane maturalne z mapa.wyniki.edu.pl są już w formacie długim (jeden wiersz na szkołę × przedmiot × poziom) – bez konieczności stosowania operatora UNPIVOT.

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

- Ekran 0: Splash Screen – Ekran powitalny inicjujący sesję i asynchroniczne pobieranie słowników z bazy danych. Zawiera logo i hasło przewodnie.
- Ekran 1: Kalkulator – Formularz wejściowy. Uczeń wybiera dzielnicę Warszawy, wprowadza wyniki egzaminów (%) oraz oceny ze świadectwa (dropdowny dla 4 przedmiotów), zaznacza obecność paska (Switch) i dodatkowe punkty. System dynamicznie wylicza łączny wynik (np. 158.00 pkt) i generuje kartę "Twoja Analiza" (poziom decyli, sugerowane profile).
- Ekran 2: Lista Liceów – Wyszukiwarka z horyzontalnym paskiem filtrów (Dzielnica, Profil, Język). Prezentuje pionową listę kart szkół (1:1 z makietą Figmy). Każda karta zawiera logo, nazwę, próg punktowy oraz dynamiczny 3-poziomowy status szans (Wysoka szansa / Realna szansa / Szkoła marzeń) obliczany na podstawie wyniku z Ekranu 1.
- Ekran 3: Karta Liceum – Pełna analityka szkoły. Zawiera przełącznik tła maturalnego (Podstawowe/Rozszerzone), wskaźnik EWD, ofertę klas oraz unikalny wykres trendu progów punktowych z ostatnich 5 lat dla poszczególnych profili klas.
- Ekran 4: Moja Lista – Panel układania własnej listy preferencji rekrutacyjnych (od 1 do 5) z interfejsem Drag & Drop, ułatwiający przygotowanie do rejestracji w oficjalnym systemie Vulcan. Umożliwia eksport listy do PDF (format Vulcan). System ostrzega użytkownika, gdy lista zawiera zbyt wiele szkół marzeń bez szkół bezpiecznych na końcu.
- Ekran 5: Porównywarka – Tabela zestawiająca do 4 wybranych szkół kolumnowo pod kątem kryteriów twardych (progi na profile, 3-letnie EWD bloku humanistycznego/matematycznego, wyniki matur) i miękkich (hałas z mapy klimatycznej m.st. Warszawy, wielkość klas pierwszych, dostępność psychologa).
Ekranu 2).
3. Analizować zapytania pod kątem optymalizacji relacyjnej i wydajności w środowisku MS SQL Server.

# WawaLiceum — Opis przypadków użycia aplikacji mobilnej

## Kontekst systemu

WawaLiceum to mobilna aplikacja wspomagania decyzji (DSS) dla uczniów kończących klasę ósmą w Warszawie. Pomaga wybrać liceum ogólnokształcące dopasowane do wyników egzaminów, preferencji profilowych i stylu nauki. Dane pochodzą z hurtowni danych WawaLiceumDB (dane RSPO, progi punktowe 2023–2025, wyniki matur, wskaźniki EWD, plan naboru 2026).

---

## Aktorzy

| Aktor | Opis |
|-------|------|
| **Uczeń** | Główny użytkownik — ósmoklasista planujący rekrutację do liceum |
| **WawaLiceumDB** | Hurtownia danych — źródło progów, EWD, wyników matur, oferty edukacyjnej |

---

## UC-01: Uruchomienie aplikacji

**Ekran:** Ekran powitalny (`1.Ekran_powitalny.png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik uruchamia aplikację. Wyświetlany jest ekran powitalny z logotypem WawaLiceum i hasłem „Twój spersonalizowany przewodnik po warszawskich szkołach średnich." Użytkownik naciska przycisk **„Znajdź swoją szkołę"**, co inicjuje ładowanie słowników z bazy danych i przejście do Kalkulatora Punktów.

**Warunki wstępne:** Aplikacja zainstalowana, połączenie z bazą danych dostępne.

**Kroki:**
1. Użytkownik otwiera aplikację.
2. System asynchronicznie ładuje dane słownikowe (dzielnice, profile, języki, progi).
3. Użytkownik klika „Znajdź swoją szkołę".
4. System przechodzi do ekranu Kalkulatora Punktów.

---

## UC-02: Obliczenie wyniku rekrutacyjnego

**Ekran:** Kalkulator Punktów (`2.Kalkulator_punktow.png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik wprowadza wyniki egzaminu ósmoklasisty i oceny ze świadectwa. System oblicza wynik punktowy (maks. 200 pkt) i wyświetla personalizowaną analizę z informacją o decylu i sugerowanymi profilami.

**Warunki wstępne:** Użytkownik zna swoje wyniki egzaminu i oceny końcowe.

**Kroki:**
1. Użytkownik wprowadza wyniki egzaminu ósmoklasisty:
   - Język polski (%)
   - Matematyka (%)
   - Język obcy (%)
2. Użytkownik wprowadza oceny ze świadectwa:
   - Polski (ocena 2–6)
   - Matematyka (ocena 2–6)
   - Przedmiot dodatkowy 1 + ocena
   - Przedmiot dodatkowy 2 + ocena
3. Opcjonalnie: świadectwo z wyróżnieniem (+7 pkt), wolontariat, konkursy kuratoryjne (maks. 18 pkt).
4. System na bieżąco oblicza wynik i wyświetla go w karcie **„Twój wynik"**.
5. System generuje sekcję **„Twoja Analiza"** — informację o decylu kandydata (np. „Top 25% kandydatów") i sugerowany profil (np. „Profil Uniwersalny").
6. Użytkownik klika **„Zapisz wynik"** — wynik przechowywany jako stan sesji i używany w ekranie Szukaj do generowania oznaczeń szans.
7. Opcjonalnie: klika „Progi punktowe — Sprawdź statystyki z 2023 roku" → przejście do ekranu Szukaj.

**Algorytm punktowy (maks. 200 pkt):**
- Egzamin (maks. 100 pkt): Polski × 0,35 + Matematyka × 0,35 + Język obcy × 0,30
- Świadectwo (maks. 100 pkt): 4 oceny (Celujący=18, Bdb=17, Dobry=14, Dst=8, Dop=2) + wyróżnienie 7 pkt + wolontariat 3 pkt + konkursy (maks. 18 pkt)

---

## UC-03: Przeglądanie i filtrowanie listy liceów

**Ekran:** Szukaj (`3.Szukaj .png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik przegląda listę warszawskich liceów posortowaną według progów punktowych. Każde liceum posiada oznaczenie szans rekrutacyjnych wyliczone na podstawie wyniku z Kalkulatora. Użytkownik może zawęzić listę filtrami.

**Warunki wstępne:** Wynik z UC-02 zapisany w sesji.

**Kroki:**
1. System wyświetla listę liceów z progiem 2023 i oznaczeniem szans.
2. Użytkownik opcjonalnie stosuje filtry:
   - **Dzielnica** — wybór dzielnicy Warszawy
   - **Profil** — typ oddziału (mat-fiz, humanistyczny, biol-chem itd.)
   - **Język obcy** — preferowany język nauczany w szkole
3. Użytkownik opcjonalnie wpisuje nazwę szkoły w pole wyszukiwania.
4. System aktualizuje listę w czasie rzeczywistym.
5. Użytkownik klika wybraną szkołę → przejście do UC-04.

**Oznaczenia szans (badge):**

| Badge | Warunek | Kolor |
|-------|---------|-------|
| Wysoki próg | Wynik użytkownika poniżej progu | Czerwony |
| Masz szanse | Wynik w zasięgu progu | Niebieski |
| Bezpieczny wybór | Wynik wyraźnie powyżej progu | Zielony |

---

## UC-04: Przeglądanie karty liceum

**Ekran:** Ekran szkoły (`4.Ekran_szkoly.png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik zapoznaje się ze szczegółowymi danymi wybranego liceum: wynikami matur, wskaźnikiem EWD, trendem progów punktowych z ostatnich lat oraz ofertą oddziałów na rok 2026.

**Warunki wstępne:** Użytkownik wybrał szkołę z listy (UC-03).

**Kroki:**
1. System wyświetla nagłówek szkoły (nazwa, adres, linki: strona WWW, Klimatyczna Mapa Szkół, Wskaźniki EWD).
2. Wyświetlany jest pasek porównania: **Twój wynik vs próg szkoły** z etykietą (np. „Wysoki próg – szkoła marzeń").
3. Sekcja **Egzaminy Maturalne** — zakładki Podstawowe / Rozszerzone:
   - Ogólna zdawalność, wyniki z matematyki i języka polskiego (podstawa)
   - Wyniki przedmiotów rozszerzonych zbieżnych z profilem użytkownika
4. Sekcja **Poziom EWD** — wykres pozycjonujący szkołę w jednej z czterech cwiartki:
   - Szkoła sukcesu / Szkoła wspierająca / Szkoła niewykorzystanych możliwości / Szkoła wymagająca pomocy
   - Osobno: EWD humanistyczne i matematyczno-przyrodnicze
5. Sekcja **Progi Punktowe** — wykres liniowy trendu progów 2020–2025 per profil oddziału.
6. Sekcja **Oferta Edukacyjna** — lista oddziałów na rok 2026 z rozwinięciem przedmiotów i języków.
7. Użytkownik klika **„Dodaj do Mojej Listy"** → szkoła trafia do UC-05.
8. Użytkownik klika **„Porównaj"** → szkoła dodawana do UC-06.

---

## UC-05: Zarządzanie Moją Listą

**Ekran:** Twoja selekcja edukacyjna (`6.Twoja_selekcja_edukacyjna.png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik układa spersonalizowany ranking priorytetów liceów (maks. 5 szkół), a następnie eksportuje go do systemu Vulcan lub jako PDF.

**Warunki wstępne:** Co najmniej jedna szkoła dodana z UC-04.

**Kroki:**
1. System wyświetla listę wybranych szkół z numerami priorytetu (1–5) i etykietami charakteru szkoły (np. „Szkoła Marzeń", „Wysoki Standard", „Solidna Renoma", „Bezpieczny Wybór").
2. Użytkownik przeciąga i upuszcza (drag & drop) szkoły zmieniając kolejność priorytetów.
3. System waliduje listę i wyświetla ostrzeżenie, gdy zbyt wiele „szkół marzeń" jest na początku listy bez szkoły bezpiecznej na końcu.
4. Użytkownik klika **„Zapisz i eksportuj listę"**:
   - Eksport do PDF lub bezpośrednio do systemu rekrutacyjnego Vulcan.

**Reguły biznesowe:**
- Maks. 5 szkół na liście.
- Ostrzeżenie, gdy brak szkoły „bezpiecznej" (próg wyraźnie poniżej wyniku użytkownika) w dolnej części listy.

---

## UC-06: Porównywarka szkół

**Ekran:** Porównywarka Szkół (`5.Porownywarka.png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik porównuje do 4 liceów jednocześnie w trzech kategoriach: rekrutacja i logistyka, wyniki edukacyjne oraz środowisko i atmosfera.

**Warunki wstępne:** Co najmniej 2 szkoły dodane do porównania z UC-04.

**Kroki:**
1. System wyświetla nagłówki wybranych szkół (maks. 4) z możliwością usunięcia każdej.
2. Sekcja **Rekrutacja i Logistyka**:
   - Średni próg punktowy (2023)
   - Status użytkownika dla każdej szkoły (Ryzykowna / Bezpieczna)
   - Progi per profil oddziału (Mat-Fiz, Biol-Chem, Humanistyczny) z językami nauczania
3. Sekcja **Wyniki Edukacyjne**:
   - Wskaźniki EWD (3-letnie): humanistyczne, matematyczne, przyrodnicze z etykietą poziomu (Bardzo Wysokie / Wysokie / Dodatnie itd.)
   - Średnie wyniki matur 2023: przedmioty obowiązkowe i rozszerzone
4. Sekcja **Środowisko i Atmosfera**:
   - Średnia wielkość klas pierwszych
   - Rozwinięcie: dodatkowe parametry infrastruktury (psycholog, winda, monitoring itd.)
5. Użytkownik klika **„Zobacz więcej parametrów"** → rozwinięcie pełnej listy flag infrastrukturalnych.

---

## Nawigacja globalna

Aplikacja posiada stały dolny pasek nawigacyjny z 4 zakładkami:

| Ikona | Ekran | UC |
|-------|-------|----|
| Kalkulator | Kalkulator Punktów | UC-02 |
| Szukaj | Lista liceów | UC-03 |
| Moja Lista | Twoja selekcja edukacyjna | UC-05 |
| Porównaj | Porównywarka szkół | UC-06 |

---

## Przepływ danych między ekranami

```
UC-01 Ekran powitalny
    │  ładowanie słowników z DB
    ▼
UC-02 Kalkulator
    │  wynik_sesji (punkty 0–200)
    ▼
UC-03 Szukaj ──── klik szkoły ───► UC-04 Karta Liceum
                                         │
                              ┌──────────┴──────────┐
                              ▼                     ▼
                         UC-05 Moja           UC-06 Porów-
                         Lista                nywarka
                              │
                     Eksport PDF / Vulcan
```

---

## Powiązanie ekranów z danymi WawaLiceumDB

| Ekran | Tabele hurtowni |
|-------|----------------|
| Kalkulator — „Twoja Analiza" (decyl) | `Fakt_Rekrutacja_Wyniki` |
| Szukaj — badge szans, lista | `Fakt_Rekrutacja_Wyniki`, `Wymiar_Szkola` |
| Karta — wyniki matur | `Fakt_Matura_Statystyki_Szczegolowe`, `Wymiar_Przedmiot_Maturalny` |
| Karta — wykres EWD i cwiartka | `Fakt_Matura_EWD`, `Wymiar_Typ_EWD` |
| Karta — trend progów 2020–2025 | `Fakt_Rekrutacja_Wyniki`, `Wymiar_Czas` |
| Karta — oferta oddziałów 2026 | `Fakt_Plan_Naboru` |
| Porównywarka — ranking Perspektyw | `Fakt_Ranking_Perspektywy` |
| Porównywarka — infrastruktura, atmosfera | `Wymiar_Atmosfera`, `Mostek_Szkola_Inicjatywy` |

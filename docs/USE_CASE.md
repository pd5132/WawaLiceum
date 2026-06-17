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

## System badge'y szans — UJEDNOLICONY

We wszystkich ekranach obowiązuje jeden system oznaczeń szans rekrutacyjnych:

| Etykieta | Kolor | Hex | Warunek |
|----------|-------|-----|---------|
| **Wysokie szanse** | Zielony | `#22C55E` | wynik użytkownika > próg + 10 pkt |
| **Realistyczna** | Pomarańczowy | `#FB923C` | wynik w przedziale ±10 pkt od progu |
| **Szkoła marzeń** | Czerwony | `#EF4444` | wynik użytkownika < próg − 10 pkt |

Próg = `prog_punktowy_min` z `Fakt_Rekrutacja_Wyniki`, zawsze z najnowszego dostępnego roku (`MAX rok_kalendarzowy` dla danej szkoły).

---

## UC-01: Uruchomienie aplikacji

**Ekran:** Ekran powitalny (`1.Ekran_powitalny.png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik uruchamia aplikację. Wyświetlany jest ekran powitalny z logotypem WawaLiceum i hasłem „Twój spersonalizowany przewodnik po warszawskich szkołach średnich." Użytkownik naciska przycisk **„Znajdź swoją szkołę"**, co inicjuje ładowanie słowników z bazy danych i przejście do Kalkulatora Punktów.

**Warunki wstępne:** Aplikacja zainstalowana, połączenie z bazą danych dostępne.

**Kroki:**
1. Użytkownik otwiera aplikację.
2. System asynchronicznie ładuje dane słownikowe: dzielnice, typy oddziałów (`Fakt_Plan_Naboru.typ_oddzialu`), języki, progi.
3. Użytkownik klika „Znajdź swoją szkołę".
4. System przechodzi do ekranu Kalkulatora Punktów.

**Design:** Tło gradient `#F0FDF9` → `#DCFCE7`. Logo emerald `#059669`. Animacja: logo scale 0.8→1.0 (600ms), tagline slide-up (400ms delay), przycisk fade-in (700ms delay).

---

## UC-02: Obliczenie wyniku rekrutacyjnego

**Ekran:** Kalkulator Punktów (`2.Kalkulator_punktow.png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik wprowadza wyniki egzaminu ósmoklasisty i oceny ze świadectwa. System oblicza wynik punktowy (maks. 200 pkt) i wyświetla personalizowaną analizę z informacją o liczbie szkół w każdym tierze szans.

**Warunki wstępne:** Użytkownik zna swoje wyniki egzaminu i oceny końcowe.

**Kroki:**
1. Użytkownik wprowadza wyniki egzaminu ósmoklasisty:
   - Język polski (%)
   - Matematyka (%)
   - Język obcy (%)
2. Użytkownik wprowadza oceny ze świadectwa:
   - Polski (ocena 2–6)
   - Matematyka (ocena 2–6)
   - Przedmiot dodatkowy 1 + ocena (dropdown z listą przedmiotów)
   - Przedmiot dodatkowy 2 + ocena (dropdown z listą przedmiotów)
3. Opcjonalnie: świadectwo z wyróżnieniem (+7 pkt), wolontariat, konkursy kuratoryjne (maks. 18 pkt).
4. System na bieżąco oblicza wynik i wyświetla go w karcie **„Twój wynik"** (licznik animowany).
5. **Opcjonalnie:** Uczeń wybiera profil w sekcji **„Jaki profil Cię interesuje?"**:
   - Opcje z `Fakt_Plan_Naboru.typ_oddzialu`: Mat-Fiz, Bio-Chem, Humanistyczny, Językowy, Ogólny/Dowolny
   - Wartość przekazywana do Szukaj (pre-fill filtra Profil) i Karty Liceum (filtruje sekcję „Zbieżne z Twoim profilem")
6. System generuje sekcję **„Twoja Analiza"**:
   - „Przy [X] pkt masz **Wysokie szanse** w [N] szkołach, **Realistyczna** w [M], **Szkoła marzeń** w [K]"
   - Dane: `Fakt_Rekrutacja_Wyniki.prog_punktowy_min` × wynik użytkownika (najnowszy rok)
   - Jeśli profil wybrany: lista najlepiej dopasowanych profili
7. Użytkownik klika **„Zapisz wynik"** → wynik przechowywany jako stan sesji.

**Algorytm punktowy (maks. 200 pkt):**
- Egzamin (maks. 100 pkt): Polski × 0,35 + Matematyka × 0,35 + Język obcy × 0,30
- Świadectwo (maks. 100 pkt): 4 oceny (Celujący=18, Bdb=17, Dobry=14, Dst=8, Dop=2) + wyróżnienie 7 pkt + wolontariat 3 pkt + konkursy (maks. 18 pkt)

**Design:** Karta wyniku emerald `#059669`. Licznik animuje się w czasie rzeczywistym. Focus na inputach: border `#059669`.

---

## UC-03: Przeglądanie i filtrowanie listy liceów

**Ekran:** Szukaj (`3.Szukaj .png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik przegląda listę warszawskich liceów z oznaczeniami szans rekrutacyjnych. Może przełączyć się na widok mapy z pinami kolorowanymi wg tieru szans.

**Warunki wstępne:** Wynik z UC-02 zapisany w sesji.

**Kroki:**
1. System wyświetla listę liceów z najnowszym dostępnym progiem i oznaczeniem szans (badge z systemu unified).
2. Użytkownik opcjonalnie stosuje filtry:
   - **Dzielnica** — wybór dzielnicy Warszawy
   - **Profil** — typ oddziału (pre-filled z UC-02 jeśli wybrano profil)
   - **Język obcy** — preferowany język
3. Użytkownik opcjonalnie wpisuje nazwę szkoły w pole wyszukiwania.
4. **Toggle Lista/Mapa** (przycisk w nagłówku):
   - **Widok Lista** (domyślny): karty szkół z badge'ami
   - **Widok Mapa**: interaktywna mapa (OpenStreetMap/Google Maps), piny kolorowane wg chance-tier:
     - Zielony `#22C55E` → Wysokie szanse
     - Pomarańczowy `#FB923C` → Realistyczna
     - Czerwony `#EF4444` → Szkoła marzeń
     - Dane: `Wymiar_Szkola.wspolrzedne_lat`, `wspolrzedne_long`
     - Klik pinu → bottom sheet z mini-kartą szkoły → tap → Karta Liceum
5. Użytkownik klika wybraną szkołę → przejście do UC-04.

**Oznaczenia szans (badge):** zgodnie z systemem unified — patrz tabela na początku dokumentu.

**Design:** Chip filtry emerald border + fill przy aktywnym. Karty slide-in staggered (50ms per karta) przy zmianie filtra.

---

## UC-04: Przeglądanie karty liceum

**Ekran:** Ekran szkoły (`4.Ekran_szkoly.png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik zapoznaje się ze szczegółowymi danymi wybranego liceum: wynikami matur, wskaźnikami EWD (osobno humanistyczny i matematyczny), trendem progów, rankingiem Perspektyw, ofertą oddziałów i inicjatywami zewnętrznymi.

**Warunki wstępne:** Użytkownik wybrał szkołę z listy (UC-03).

**Kroki:**
1. System wyświetla nagłówek szkoły:
   - Nazwa, adres, dzielnica
   - Linki kontaktowe: ikona globe → `strona_www`, ikona phone → `telefon`, ikona mail → `email` (dane: `Wymiar_Szkola`)
   - Badge **Ranking Perspektyw**: np. „#14 w Polsce" — dane: `Fakt_Ranking_Perspektywy.pozycja_w_rankingu` (najnowszy rok), kolor amber `#F59E0B`
2. Pasek porównania: **Twój wynik [X] vs próg [Y]** z etykietą chance-tier (unified system).
3. Sekcja **Egzaminy Maturalne** — zakładki Podstawowe / Rozszerzone:
   - Ogólna zdawalność, wyniki z matematyki i języka polskiego (podstawa)
   - Sekcja **„Zbieżne z Twoim profilem"**:
     - Jeśli profil wybrany w UC-02 → filtruj po `typ_oddzialu`
     - Jeśli nie → pokaż top 3 profile wg najwyższego `prog_punktowy_min`
     - Etykieta sekcji: „Profil: Mat-Fiz" (jeśli wybrany) lub „Najpopularniejsze profile"
4. Sekcja **Poziom EWD** — **dwa osobne bloki**:
   - Blok Humanistyczny (`id_typu_ewd` = humanistyczny): pasek + confidence bounds
   - Blok Matematyczny (`id_typu_ewd` = matematyczny): pasek + confidence bounds
   - Dane: `Fakt_Matura_EWD.ewd_oszacowanie_punktowe`, `ewd_gorna_granica_ufnosci`, `ewd_dolna_granica_ufnosci`
   - Cztery ćwiartki interpretacji: Szkoła Sukcesu / Wspierająca / Niewykorzystanych Możliwości / Wymagająca Pomocy
   - Animacja: pasek wypełnia się od środka (800ms ease-out)
5. Sekcja **Progi Punktowe** — wykres liniowy per profil oddziału, wszystkie dostępne lata (2023–2025):
   - Animacja: linie rysują się L→R (1s)
6. Sekcja **Oferta Edukacyjna** — lista oddziałów z `Fakt_Plan_Naboru` na rok 2026.
7. Sekcja **Inicjatywy Zewnętrzne** (na dole karty):
   - Chips/tagi: Erasmus+, IB, UNESCO, itp.
   - Dane: `Mostek_Szkola_Inicjatywy` JOIN `Wymiar_Inicjatywy_Zewnetrzne`
8. Użytkownik klika **„Dodaj do Mojej Listy"** → szkoła trafia do UC-05.
9. Użytkownik klika **„Porównaj"** → szkoła dodawana do UC-06.

**Design:** Header z emerald gradient strip. Ranking badge amber pill w rogu headera. EWD bars emerald (dodatnie) / czerwony (ujemne) / szary (neutralne). Inicjatywy: chips emerald outline.

---

## UC-05: Zarządzanie Moją Listą

**Ekran:** Twoja selekcja edukacyjna (`6.Twoja_selekcja_edukacyjna.png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik układa spersonalizowany ranking priorytetów liceów (maks. 5 szkół), a następnie eksportuje go do systemu Vulcan lub jako PDF.

**Warunki wstępne:** Co najmniej jedna szkoła dodana z UC-04.

**Kroki:**
1. System wyświetla listę wybranych szkół z numerami priorytetu (1–5) i badge'ami szans (unified system: Wysokie szanse / Realistyczna / Szkoła marzeń).
2. Użytkownik przeciąga i upuszcza (drag & drop) szkoły zmieniając kolejność priorytetów.
   - Animacja: spring physics (overshoot 5%, settle 200ms)
3. System waliduje listę i wyświetla **banner ostrzegawczy** (amber `#F59E0B`) gdy top 3 pozycje to „Szkoła marzeń" bez żadnej „Wysokie szanse" na liście.
4. Użytkownik klika **„Zapisz i eksportuj listę"**:
   - Eksport do PDF lub bezpośrednio do systemu rekrutacyjnego Vulcan.

**Reguły biznesowe:**
- Maks. 5 szkół na liście.
- Ostrzeżenie: brak „Wysokie szanse" przy ≥3 „Szkoła marzeń" w top 3.

---

## UC-06: Porównywarka szkół

**Ekran:** Porównywarka Szkół (`5.Porownywarka.png`)

**Aktor:** Uczeń

**Opis:**
Użytkownik porównuje do 4 liceów jednocześnie w kategoriach: rekrutacja i logistyka, wyniki edukacyjne, środowisko i atmosfera, inicjatywy zewnętrzne.

**Warunki wstępne:** Co najmniej 2 szkoły dodane do porównania z UC-04.

**Kroki:**
1. System wyświetla nagłówki wybranych szkół (maks. 4) z możliwością usunięcia każdej.
2. Sekcja **Rekrutacja i Logistyka**:
   - Najnowszy próg punktowy per szkoła
   - Status użytkownika (badge unified: Wysokie szanse / Realistyczna / Szkoła marzeń)
   - **Ranking Perspektyw**: `pozycja_w_rankingu` (amber badge) — dane: `Fakt_Ranking_Perspektywy`, najnowszy rok
   - Progi per profil oddziału (Mat-Fiz, Biol-Chem, Humanistyczny) z językami nauczania
3. Sekcja **Wyniki Edukacyjne**:
   - Wskaźniki EWD (3-letnie): humanistyczne, matematyczne, przyrodnicze z etykietą poziomu
   - Średnie wyniki matur: przedmioty obowiązkowe i rozszerzone (najnowszy rok)
4. Sekcja **Środowisko i Atmosfera**:
   - Średnia wielkość klas
   - Rozwinięcie: pełna lista flag z `Wymiar_Atmosfera` (psycholog, winda, monitoring itp.)
5. Sekcja **Inicjatywy Zewnętrzne**:
   - Tagi programów (Erasmus+, IB, UNESCO, itp.) per szkoła
   - Dane: `Mostek_Szkola_Inicjatywy` JOIN `Wymiar_Inicjatywy_Zewnetrzne`
6. Użytkownik klika „Zobacz więcej parametrów" → rozwinięcie pełnej infrastruktury.

**Design:** Wiersze fade-in staggered przy scroll (60ms per wiersz). EWD: emerald (dodatnie) / czerwony (ujemne). Ranking: amber pill.

---

## Nawigacja globalna

Aplikacja posiada stały dolny pasek nawigacyjny z 4 zakładkami:

| Ikona | Ekran | UC |
|-------|-------|----|
| Kalkulator | Kalkulator Punktów | UC-02 |
| Szukaj | Lista liceów / Mapa | UC-03 |
| Moja Lista | Twoja selekcja edukacyjna | UC-05 |
| Porównaj | Porównywarka szkół | UC-06 |

Animacja: ikona scale 1.0→1.15 + ripple (150ms) przy tap.

---

## Przepływ danych między ekranami

```
UC-01 Ekran powitalny
    │  ładowanie słowników z DB
    ▼
UC-02 Kalkulator
    │  wynik_sesji (punkty 0–200) + opcjonalnie: wybrany_profil
    ▼
UC-03 Szukaj (Lista lub Mapa) ──── klik szkoły ───► UC-04 Karta Liceum
                                                          │
                                             ┌────────────┴────────────┐
                                             ▼                         ▼
                                        UC-05 Moja               UC-06 Porów-
                                        Lista                    nywarka
                                             │
                                    Eksport PDF / Vulcan
```

---

## Powiązanie ekranów z danymi WawaLiceumDB

| Ekran | Tabele hurtowni |
|-------|----------------|
| Kalkulator — „Twoja Analiza" (liczba szkół per tier) | `Fakt_Rekrutacja_Wyniki` |
| Kalkulator — dropdown profilu (słownik) | `Fakt_Plan_Naboru` (DISTINCT typ_oddzialu) |
| Szukaj — badge szans, lista, mapa piny | `Fakt_Rekrutacja_Wyniki`, `Wymiar_Szkola` |
| Karta — wyniki matur, sekcja profilu | `Fakt_Matura_Statystyki_Szczegolowe`, `Wymiar_Przedmiot_Maturalny` |
| Karta — EWD blok humanistyczny i matematyczny | `Fakt_Matura_EWD`, `Wymiar_Typ_EWD` |
| Karta — trend progów (wszystkie lata) | `Fakt_Rekrutacja_Wyniki`, `Wymiar_Czas` |
| Karta — oferta oddziałów 2026 | `Fakt_Plan_Naboru` |
| Karta — ranking Perspektyw badge | `Fakt_Ranking_Perspektywy` |
| Karta — linki kontaktowe | `Wymiar_Szkola.strona_www`, `telefon`, `email` |
| Karta + Porównywarka — inicjatywy zewnętrzne | `Mostek_Szkola_Inicjatywy`, `Wymiar_Inicjatywy_Zewnetrzne` |
| Porównywarka — ranking Perspektyw | `Fakt_Ranking_Perspektywy` |
| Porównywarka — infrastruktura, atmosfera | `Wymiar_Atmosfera` |

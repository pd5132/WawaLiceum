# WawaLiceum — Design System

Referncja dla implementacji w JetBrains Rider (Tailwind CSS / Material Design 3).

---

## Kolory — tokeny

### CSS Custom Properties

```css
:root {
  /* Primary — Emerald */
  --color-primary:        #059669;
  --color-primary-dark:   #047857;
  --color-primary-light:  #A7F3D0;

  /* Backgrounds */
  --color-bg:             #F0FDF9;  /* mint cream — tło całej app */
  --color-surface:        #FFFFFF;  /* karty, inputy */
  --color-border:         #D1FAE5;  /* delikatne obramowania kart */

  /* Accent */
  --color-accent:         #F59E0B;  /* ranking badge, gwiazdki, akcenty */

  /* Chance tiers — UNIFIED */
  --color-high-chance:    #22C55E;  /* Wysokie szanse */
  --color-medium:         #FB923C;  /* Realistyczna */
  --color-dream:          #EF4444;  /* Szkoła marzeń */

  /* Text */
  --color-text-primary:   #064E3B;
  --color-text-secondary: #6B7280;
  --color-text-on-primary:#FFFFFF;

  /* EWD bars */
  --color-ewd-positive:   #059669;  /* dodatnie EWD */
  --color-ewd-negative:   #EF4444;  /* ujemne EWD */
  --color-ewd-neutral:    #9CA3AF;  /* neutralne */
}
```

### Tailwind config (tailwind.config.js)

```js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary:     { DEFAULT: '#059669', dark: '#047857', light: '#A7F3D0' },
        accent:      '#F59E0B',
        'high-chance': '#22C55E',
        medium:      '#FB923C',
        dream:       '#EF4444',
        bg:          '#F0FDF9',
        surface:     '#FFFFFF',
        border:      '#D1FAE5',
        text: {
          primary:   '#064E3B',
          secondary: '#6B7280',
        },
      },
    },
  },
}
```

---

## Typografia

**Font:** Plus Jakarta Sans (Google Fonts)

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
```

```css
body {
  font-family: 'Plus Jakarta Sans', sans-serif;
}
```

### Skala typografii

| Rola | Klasa Tailwind | px | Weight |
|------|---------------|----|--------|
| Display (wynik 158 pkt) | `text-4xl font-bold` | 36 | 700 |
| Heading (nazwa szkoły) | `text-xl font-semibold` | 20 | 600 |
| Subheading (sekcje) | `text-base font-semibold` | 16 | 600 |
| Body | `text-sm font-normal` | 14 | 400 |
| Caption (metadane) | `text-xs font-normal` | 12 | 400 |
| Badge | `text-xs font-medium` | 12 | 500 |

---

## Komponenty — badge'y szans

```html
<!-- Wysokie szanse -->
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
  Wysokie szanse
</span>

<!-- Realistyczna -->
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-orange-100 text-orange-800">
  Realistyczna
</span>

<!-- Szkoła marzeń -->
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
  Szkoła marzeń
</span>

<!-- Ranking Perspektyw -->
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800">
  #14 w Polsce
</span>
```

---

## Komponenty — karty szkół (Szukaj)

```html
<div class="bg-white rounded-2xl border border-[#D1FAE5] p-4 shadow-sm">
  <div class="flex items-center gap-3">
    <img class="w-12 h-12 rounded-full object-cover" src="logo.png" alt="Logo szkoły">
    <div class="flex-1 min-w-0">
      <h3 class="text-base font-semibold text-[#064E3B] truncate">XIV LO im. Stanisława Staszica</h3>
      <p class="text-xs text-[#6B7280]">Ochota</p>
    </div>
    <!-- badge -->
    <span class="... bg-red-100 text-red-800">Szkoła marzeń</span>
  </div>
  <div class="mt-2 flex items-center gap-2">
    <span class="text-xs text-[#6B7280]">Próg 2025</span>
    <span class="text-sm font-semibold text-[#059669]">188.40 pkt</span>
  </div>
</div>
```

---

## Animacje

### CSS Keyframes

```css
/* Logo splash */
@keyframes scaleIn {
  from { transform: scale(0.8); opacity: 0; }
  to   { transform: scale(1);   opacity: 1; }
}

/* Slide up (tagline, przycisk splash) */
@keyframes slideUp {
  from { transform: translateY(20px); opacity: 0; }
  to   { transform: translateY(0);    opacity: 1; }
}

/* EWD bar fill (od środka) */
@keyframes barFill {
  from { transform: scaleX(0); transform-origin: center; }
  to   { transform: scaleX(1); transform-origin: center; }
}

/* Counter (wynik w Kalkulatorze) — obsługiwany JS, nie CSS */
```

### Tabela animacji

| Element | Animacja | Czas | Easing |
|---------|----------|------|--------|
| Splash logo | scaleIn | 600ms | ease-out |
| Splash tagline | slideUp | 400ms delay 200ms | ease-out |
| Splash przycisk | slideUp | 400ms delay 400ms | ease-out |
| Splash → Kalkulator | slide-up page | 350ms | ease-in-out |
| Score counter | JS counter +/- | instant per keystroke | easeOutQuad |
| Badge color change | `transition-colors` | 300ms | ease |
| Szukaj → Karta (shared element) | logo flies to header | 400ms | ease-in-out |
| Karty Szukaj (staggered) | slide-in-from-bottom | 50ms per karta | ease-out |
| EWD bar | barFill | 800ms delay 200ms | ease-out |
| Wykres progów | draw L→R (SVG stroke-dashoffset) | 1000ms | ease-in-out |
| Moja Lista drag | spring physics | overshoot ~5% | spring |
| Porównywarka wiersze | fadeIn staggered | 60ms per wiersz | ease |
| Bottom nav tap | scale 1.0→1.15 + Material ripple | 150ms | ease |

### Tailwind utility przykłady

```html
<!-- Karta wchodząca staggered (inline style delay) -->
<div class="animate-[slideUp_0.3s_ease-out_both]" style="animation-delay: 100ms">...</div>

<!-- Badge color transition -->
<span class="transition-colors duration-300 ...">...</span>

<!-- EWD bar -->
<div class="origin-center animate-[barFill_0.8s_ease-out_0.2s_both] h-2 rounded-full bg-[#059669]"
     style="width: 75%"></div>
```

---

## Nawigacja dolna (Bottom Nav)

```html
<nav class="fixed bottom-0 left-0 right-0 bg-white border-t border-[#D1FAE5] flex justify-around items-center h-16 z-50">
  <button class="flex flex-col items-center gap-1 transition-transform active:scale-115">
    <svg .../><!-- ikona -->
    <span class="text-[10px] font-medium text-[#059669]">Kalkulator</span>
  </button>
  <!-- Szukaj, Moja Lista, Porównaj -->
</nav>
```

Active state: ikona + label kolor `#059669`, background `#ECFDF5` (lekki emerald pill pod ikoną).

---

## Ekran 2 — toggle Lista/Mapa

```html
<!-- Toggle w headerze Szukaj -->
<div class="flex rounded-lg overflow-hidden border border-[#D1FAE5]">
  <button class="px-3 py-1.5 text-sm font-medium bg-[#059669] text-white">Lista</button>
  <button class="px-3 py-1.5 text-sm font-medium text-[#6B7280]">Mapa</button>
</div>
```

Widok mapa: embedded map library (Leaflet + OpenStreetMap lub Google Maps JS API).
Piny: custom SVG ikony w kolorach chance-tier.
Po kliknięciu pinu: Material bottom sheet z mini-kartą szkoły (nazwa, próg, badge, przycisk „Zobacz →").

---

## Ekran 3 — EWD (dwa bloki)

```html
<!-- Blok Humanistyczny -->
<div class="rounded-xl bg-white border border-[#D1FAE5] p-4">
  <h4 class="text-xs font-semibold text-[#6B7280] uppercase tracking-wide mb-2">EWD Humanistyczny</h4>
  <div class="flex items-center gap-2">
    <span class="text-sm text-[#6B7280]">-5</span>
    <div class="relative flex-1 h-3 bg-gray-100 rounded-full overflow-hidden">
      <!-- marker pozycji oszacowania + confidence interval -->
      <div class="absolute h-full bg-[#059669] rounded-full animate-[barFill_0.8s_ease-out_both]"
           style="left: 50%; width: 20%"></div>
    </div>
    <span class="text-sm text-[#6B7280]">+5</span>
  </div>
  <p class="text-xs text-[#064E3B] font-semibold mt-1">+2.4 (Wysoko)</p>
</div>

<!-- Blok Matematyczny — analogicznie -->
```

---

## Inicjatywy zewnętrzne — chips

```html
<div class="flex flex-wrap gap-2 mt-3">
  <span class="px-2.5 py-1 text-xs font-medium rounded-full border border-[#059669] text-[#059669]">
    Erasmus+
  </span>
  <span class="px-2.5 py-1 text-xs font-medium rounded-full border border-[#059669] text-[#059669]">
    UNESCO
  </span>
</div>
```

---

## Ranking badge (Karta Liceum header)

```html
<div class="absolute top-3 right-3">
  <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-100 text-amber-800">
    <svg class="w-3 h-3" .../><!-- trophy icon -->
    #14 w Polsce
  </span>
</div>
```

---

## Ostrzeżenie Vulcan (Moja Lista)

```html
<!-- Pojawia się gdy top 3 = Szkoła marzeń bez Wysokie szanse na liście -->
<div class="mx-4 mb-3 flex items-start gap-2 bg-amber-50 border border-amber-200 rounded-xl p-3">
  <svg class="w-4 h-4 text-amber-600 mt-0.5 flex-shrink-0" .../><!-- warning icon -->
  <p class="text-xs text-amber-800">
    Twoja lista ma zbyt wiele szkół marzeń na początku. Dodaj szkołę z <strong>Wysokimi szansami</strong> na końcu listy.
  </p>
</div>
```

---

## Accessibility

- Kontrast badge text/bg: zielony #22C55E na bg-green-100 → min 3:1 (large text) ✓
- Wszystkie interactive elementy: min touch target 44×44px
- Focus ring: `focus-visible:ring-2 focus-visible:ring-[#059669] focus-visible:ring-offset-2`
- Drag & Drop Moja Lista: alternatywne przyciski ▲▼ dla keyboard users

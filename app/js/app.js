'use strict';

const App = (() => {
  // --- Stan aplikacji ---
  let currentScreen = 'splash';
  let prevScreen = null;
  let userScore = 0;
  let userProfile = '';
  let mapInstance = null;
  let mapMarkers = [];
  let currentSchoolId = null;
  let myLista = JSON.parse(localStorage.getItem('wl-lista') || '[]');
  let porownajSet = JSON.parse(localStorage.getItem('wl-porownaj') || '[]');
  let currentView = 'lista';

  // --- Nawigacja ---
  function navigate(screen) {
    document.getElementById(`screen-${currentScreen}`).classList.remove('active');
    prevScreen = currentScreen;
    currentScreen = screen;
    document.getElementById(`screen-${screen}`).classList.add('active');

    const nav = document.getElementById('bottom-nav');
    if (screen === 'splash') {
      nav.classList.add('hidden');
    } else {
      nav.classList.remove('hidden');
    }

    // Podświetl aktywną ikonę w nawigacji
    document.querySelectorAll('.nav-btn').forEach(btn => {
      const isActive = btn.dataset.nav === screen;
      btn.classList.toggle('text-primary', isActive);
      btn.classList.toggle('text-muted', !isActive);
    });

    // Inicjalizacja widoku mapy przy pierwszym przejściu
    if (screen === 'szukaj' && currentView === 'mapa' && !mapInstance) {
      initMap();
    }

    // Odśwież listę przy wejściu
    if (screen === 'lista') renderLista();
    if (screen === 'porownywarka') renderPorownywarka();
  }

  function goBack() {
    navigate(prevScreen || 'szukaj');
  }

  // --- Widok Lista / Mapa ---
  function setView(view) {
    currentView = view;
    const listaEl = document.getElementById('view-lista');
    const mapaEl = document.getElementById('view-mapa');
    const btnLista = document.getElementById('toggle-lista');
    const btnMapa = document.getElementById('toggle-mapa');

    if (view === 'lista') {
      listaEl.classList.remove('hidden');
      mapaEl.classList.add('hidden');
      btnLista.classList.replace('text-muted', 'text-white');
      btnLista.classList.add('bg-primary');
      btnMapa.classList.remove('bg-primary');
      btnMapa.classList.replace('text-white', 'text-muted');
    } else {
      listaEl.classList.add('hidden');
      mapaEl.classList.remove('hidden');
      btnMapa.classList.replace('text-muted', 'text-white');
      btnMapa.classList.add('bg-primary');
      btnLista.classList.remove('bg-primary');
      btnLista.classList.replace('text-white', 'text-muted');
      if (!mapInstance) initMap(); else setTimeout(() => mapInstance.invalidateSize(), 100);
    }
  }

  // --- Mapa Leaflet ---
  function initMap() {
    if (!window.L) return;
    mapInstance = L.map('map').setView([52.23, 21.01], 12);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap',
      maxZoom: 18,
    }).addTo(mapInstance);
    renderMapMarkers(Data.getFiltered());
  }

  function renderMapMarkers(schools) {
    if (!mapInstance) return;
    mapMarkers.forEach(m => m.remove());
    mapMarkers = [];

    schools.forEach(s => {
      if (!s.lat || !s.lon) return;
      const tier = getTier(s.prog_min);
      const color = tierColor(tier);
      const icon = L.divIcon({
        className: '',
        html: `<div style="width:14px;height:14px;border-radius:50%;background:${color};border:2px solid white;box-shadow:0 1px 4px rgba(0,0,0,.3)"></div>`,
        iconSize: [14, 14],
        iconAnchor: [7, 7],
      });
      const marker = L.marker([s.lat, s.lon], { icon })
        .addTo(mapInstance)
        .on('click', () => showMapPopup(s));
      mapMarkers.push(marker);
    });
  }

  function showMapPopup(school) {
    const tier = getTier(school.prog_min);
    const popup = L.popup({ className: 'wl-popup' })
      .setLatLng([school.lat, school.lon])
      .setContent(`
        <div style="font-family:'Plus Jakarta Sans',sans-serif;min-width:180px;padding:4px">
          <p style="font-weight:600;font-size:13px;color:#064E3B;margin:0 0 4px">${school.nazwa}</p>
          <p style="font-size:11px;color:#6B7280;margin:0 0 6px">${school.dzielnica}</p>
          <div style="display:flex;align-items:center;gap:8px;justify-content:space-between">
            <span style="font-size:12px;font-weight:600;color:#059669">Próg: ${school.prog_min ?? '—'} pkt</span>
            <span style="font-size:11px;font-weight:500;padding:2px 8px;border-radius:99px;background:${tierBg(tier)};color:${tierColor(tier)}">${tierLabel(tier)}</span>
          </div>
          <button onclick="App.openKarta(${school.id})" style="margin-top:8px;width:100%;background:#059669;color:white;font-size:12px;font-weight:600;border:none;border-radius:10px;padding:6px;cursor:pointer">
            Zobacz →
          </button>
        </div>
      `)
      .openOn(mapInstance);
  }

  // --- Szanse (tier) ---
  function getTier(prog) {
    if (!prog || !userScore) return 'unknown';
    if (userScore > prog + 10) return 'high';
    if (userScore >= prog - 10) return 'medium';
    return 'dream';
  }

  function tierLabel(tier) {
    return { high: 'Wysokie szanse', medium: 'Realistyczna', dream: 'Szkoła marzeń', unknown: '—' }[tier] || '—';
  }

  function tierColor(tier) {
    return { high: '#22C55E', medium: '#FB923C', dream: '#EF4444', unknown: '#9CA3AF' }[tier];
  }

  function tierBg(tier) {
    return { high: '#dcfce7', medium: '#ffedd5', dream: '#fee2e2', unknown: '#f3f4f6' }[tier];
  }

  function tierTextClass(tier) {
    return { high: 'bg-green-100 text-green-800', medium: 'bg-orange-100 text-orange-800', dream: 'bg-red-100 text-red-800', unknown: 'bg-gray-100 text-gray-500' }[tier];
  }

  // --- Filtry i lista szkół ---
  function applyFilters() {
    const dzielnica = document.getElementById('filter-dzielnica').value;
    const profil = document.getElementById('filter-profil').value;
    const jezyk = document.getElementById('filter-jezyk').value;
    const filtered = Data.getFiltered({ dzielnica, profil, jezyk });
    renderSchoolList(filtered);
    if (currentView === 'mapa') renderMapMarkers(filtered);
  }

  function renderSchoolList(schools) {
    const el = document.getElementById('schools-list');
    if (!schools || schools.length === 0) {
      el.innerHTML = '<p class="text-center text-muted text-sm py-8">Brak wyników dla wybranych filtrów</p>';
      return;
    }
    el.innerHTML = schools.map((s, i) => {
      const tier = getTier(s.prog_min);
      return `
        <div class="bg-surface rounded-2xl border border-border p-4 shadow-sm active:scale-[0.98] transition-transform animate-fadeIn cursor-pointer"
             style="animation-delay:${i * 40}ms"
             onclick="App.openKarta(${s.id})">
          <div class="flex items-start gap-3">
            <div class="flex-1 min-w-0">
              <h3 class="text-sm font-semibold text-ink leading-tight">${s.nazwa}</h3>
              <p class="text-xs text-muted mt-0.5">${s.dzielnica}</p>
            </div>
            <span class="flex-shrink-0 text-xs font-medium px-2.5 py-0.5 rounded-full ${tierTextClass(tier)}">${tierLabel(tier)}</span>
          </div>
          <div class="flex items-center gap-4 mt-2">
            <div>
              <span class="text-xs text-muted">Próg ${s.prog_rok ?? ''}</span>
              <span class="ml-1.5 text-sm font-semibold text-primary">${s.prog_min != null ? s.prog_min + ' pkt' : '—'}</span>
            </div>
            ${s.ranking_pozycja ? `<div><span class="text-xs text-muted">Ranking</span><span class="ml-1.5 text-sm font-semibold text-amber-600">#${s.ranking_pozycja}</span></div>` : ''}
          </div>
        </div>`;
    }).join('');
  }

  // --- Karta Liceum ---
  function openKarta(schoolId) {
    currentSchoolId = schoolId;
    const school = Data.getSchool(schoolId);
    if (!school) return;

    document.getElementById('karta-nazwa').textContent = school.nazwa;
    document.getElementById('karta-dzielnica').textContent = school.dzielnica + (school.adres ? ' · ' + school.adres : '');

    // Ranking badge
    if (school.ranking_pozycja) {
      const rb = document.getElementById('karta-ranking-badge');
      document.getElementById('karta-ranking-text').textContent = `#${school.ranking_pozycja} w Polsce`;
      rb.classList.remove('hidden');
      rb.classList.add('inline-flex');
    }

    // Chance badge
    const tier = getTier(school.prog_min);
    if (tier !== 'unknown') {
      const cb = document.getElementById('karta-chance-badge');
      cb.textContent = tierLabel(tier);
      cb.className = `px-2.5 py-1 rounded-full text-xs font-semibold ${tierTextClass(tier)}`;
      cb.classList.remove('hidden');
    }

    // Progi
    const progiEl = document.getElementById('karta-progi');
    const progi = Data.getThresholds(schoolId);
    if (progi && progi.length > 0) {
      progiEl.innerHTML = progi.map(p => `
        <div class="flex items-center justify-between py-1.5 border-b border-border last:border-0">
          <div>
            <span class="text-xs font-medium text-ink">${p.nazwa_oddzialu ?? p.symbol_oddzialu}</span>
            <span class="ml-2 text-xs text-muted">${p.rok_kalendarzowy}</span>
          </div>
          <span class="text-sm font-semibold text-primary">${p.prog_min} pkt</span>
        </div>`).join('');
    } else {
      progiEl.innerHTML = '<p class="text-sm text-muted">Brak danych</p>';
    }

    // EWD
    renderEWD('karta-ewd-hum', Data.getEWD(schoolId, 'humanistyczny'));
    renderEWD('karta-ewd-mat', Data.getEWD(schoolId, 'matematyczny'));

    // Matura
    const matEl = document.getElementById('karta-matura');
    const matura = Data.getMatura(schoolId);
    if (matura && matura.length > 0) {
      matEl.innerHTML = matura.slice(0, 6).map(m => `
        <div class="flex items-center justify-between py-1 border-b border-border last:border-0">
          <span class="text-xs text-ink">${m.nazwa_przedmiotu} <span class="text-muted">${m.poziom}</span></span>
          <span class="text-xs font-semibold text-ink">${m.sredni_wynik_proc != null ? m.sredni_wynik_proc + '%' : '—'}</span>
        </div>`).join('');
    } else {
      matEl.innerHTML = '<p class="text-sm text-muted">Brak danych</p>';
    }

    // Atmosfera
    const atmEl = document.getElementById('karta-atmosfera');
    const atm = Data.getAtmosfera(schoolId);
    if (atm) {
      const ratings = [
        { label: 'Bezpieczeństwo', val: atm.bezpieczenstwo_proc },
        { label: 'Nauczyciele', val: atm.nauczyciele_proc },
        { label: 'Relacje w klasie', val: atm.relacje_proc },
        { label: 'Organizacja', val: atm.organizacja_proc },
      ].filter(r => r.val != null);
      atmEl.innerHTML = ratings.map(r => `
        <div class="flex items-center gap-3">
          <span class="text-xs text-muted w-32 flex-shrink-0">${r.label}</span>
          <div class="flex-1 h-2 bg-gray-100 rounded-full overflow-hidden">
            <div class="h-full bg-primary rounded-full origin-left animate-barFill" style="width:${r.val}%"></div>
          </div>
          <span class="text-xs font-semibold text-ink w-8 text-right">${r.val}%</span>
        </div>`).join('');
      if (!ratings.length) atmEl.innerHTML = '<p class="text-sm text-muted">Brak danych</p>';
    } else {
      atmEl.innerHTML = '<p class="text-sm text-muted">Brak danych</p>';
    }

    // Inicjatywy
    const inicjatywy = Data.getInicjatywy(schoolId);
    if (inicjatywy && inicjatywy.length > 0) {
      document.getElementById('karta-inicjatywy-section').classList.remove('hidden');
      document.getElementById('karta-inicjatywy').innerHTML = inicjatywy.map(i =>
        `<span class="px-2.5 py-1 text-xs font-medium rounded-full border border-primary text-primary">${i.nazwa_elementu}</span>`
      ).join('');
    }

    // Kontakt
    const kontaktEl = document.getElementById('karta-kontakt');
    kontaktEl.innerHTML = [
      school.adres ? `<p class="text-xs text-muted">${school.adres}</p>` : '',
      school.strona_www ? `<a href="${school.strona_www}" target="_blank" class="text-xs text-primary font-medium">${school.strona_www}</a>` : '',
      school.telefon ? `<p class="text-xs text-muted">${school.telefon}</p>` : '',
    ].join('') || '<p class="text-sm text-muted">Brak danych</p>';

    // Przyciski akcji
    updateKartaButtons(schoolId);
    navigate('karta');
  }

  function updateKartaButtons(schoolId) {
    const inLista = myLista.includes(schoolId);
    const inPor = porownajSet.includes(schoolId);
    const btnL = document.getElementById('karta-btn-lista');
    const btnP = document.getElementById('karta-btn-porownaj');
    btnL.textContent = inLista ? '✓ Na liście' : '+ Dodaj do listy';
    btnL.classList.toggle('bg-primary', inLista);
    btnL.classList.toggle('text-white', inLista);
    btnL.classList.toggle('text-primary', !inLista);
    btnP.textContent = inPor ? '✓ W porównaniu' : 'Porównaj';
    btnP.classList.toggle('border-primary', inPor);
    btnP.classList.toggle('text-primary', inPor);
    btnP.classList.toggle('border-border', !inPor);
    btnP.classList.toggle('text-muted', !inPor);
  }

  function renderEWD(elId, ewd) {
    const el = document.getElementById(elId);
    if (!ewd) { el.innerHTML = '<p class="text-sm text-muted">Brak danych</p>'; return; }
    const val = ewd.ewd_oszacowanie_punktowe;
    const isPos = val >= 0;
    const pct = Math.min(Math.abs(val) * 10, 50); // skala: 5pkt = 50% szerokości
    const color = isPos ? '#059669' : '#EF4444';
    el.innerHTML = `
      <div class="flex items-center gap-2">
        <span class="text-xs text-muted w-6 text-right">-5</span>
        <div class="relative flex-1 h-3 bg-gray-100 rounded-full overflow-hidden">
          <div class="absolute top-0 bottom-0 rounded-full animate-barFill origin-${isPos ? 'left' : 'right'}"
               style="background:${color};width:${pct}%;${isPos ? 'left:50%' : 'right:50%'}"></div>
          <div class="absolute top-0 bottom-0 w-px bg-gray-400" style="left:50%"></div>
        </div>
        <span class="text-xs text-muted w-6">+5</span>
      </div>
      <p class="text-sm font-semibold mt-1" style="color:${color}">${val > 0 ? '+' : ''}${val} pkt</p>
      ${ewd.ewd_upper != null ? `<p class="text-xs text-muted">Przedział: ${ewd.ewd_lower} do ${ewd.ewd_upper}</p>` : ''}`;
  }

  // --- Moja Lista ---
  function toggleLista() {
    if (!currentSchoolId) return;
    const idx = myLista.indexOf(currentSchoolId);
    if (idx === -1) {
      if (myLista.length >= 5) { alert('Lista może zawierać maksymalnie 5 szkół.'); return; }
      myLista.push(currentSchoolId);
    } else {
      myLista.splice(idx, 1);
    }
    localStorage.setItem('wl-lista', JSON.stringify(myLista));
    updateKartaButtons(currentSchoolId);
  }

  function togglePorownaj() {
    if (!currentSchoolId) return;
    const idx = porownajSet.indexOf(currentSchoolId);
    if (idx === -1) {
      if (porownajSet.length >= 4) { alert('Możesz porównać maksymalnie 4 szkoły.'); return; }
      porownajSet.push(currentSchoolId);
    } else {
      porownajSet.splice(idx, 1);
    }
    localStorage.setItem('wl-porownaj', JSON.stringify(porownajSet));
    updateKartaButtons(currentSchoolId);
  }

  function renderLista() {
    const el = document.getElementById('lista-items');
    const warning = document.getElementById('vulcan-warning');

    if (myLista.length === 0) {
      el.innerHTML = `<div class="text-center py-12 text-muted">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>
        </svg>
        <p class="text-sm">Lista jest pusta</p>
        <p class="text-xs mt-1">Dodaj szkoły w ekranie Szukaj lub Karta</p>
      </div>`;
      warning.classList.add('hidden');
      warning.classList.remove('flex');
      return;
    }

    // Vulcan warning: top 3 = same Szkoła marzeń + brak Wysokie szanse
    const tiers = myLista.map(id => getTier(Data.getSchool(id)?.prog_min));
    const top3Dream = tiers.slice(0, 3).every(t => t === 'dream');
    const anyHigh = tiers.some(t => t === 'high');
    if (top3Dream && !anyHigh) {
      warning.classList.remove('hidden');
      warning.classList.add('flex');
    } else {
      warning.classList.add('hidden');
      warning.classList.remove('flex');
    }

    el.innerHTML = myLista.map((id, i) => {
      const s = Data.getSchool(id);
      if (!s) return '';
      const tier = getTier(s.prog_min);
      return `
        <div class="bg-surface rounded-2xl border border-border p-3 flex items-center gap-3">
          <span class="text-lg font-bold text-muted w-6 text-center">${i + 1}</span>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-ink truncate">${s.nazwa}</p>
            <p class="text-xs text-muted">${s.dzielnica} · Próg: ${s.prog_min ?? '—'} pkt</p>
          </div>
          <span class="text-xs font-medium px-2 py-0.5 rounded-full ${tierTextClass(tier)}">${tierLabel(tier)}</span>
          <div class="flex flex-col gap-1">
            <button onclick="App.moveItem(${i}, -1)" ${i === 0 ? 'disabled' : ''} class="text-muted disabled:opacity-20 p-0.5">▲</button>
            <button onclick="App.moveItem(${i}, 1)" ${i === myLista.length - 1 ? 'disabled' : ''} class="text-muted disabled:opacity-20 p-0.5">▼</button>
          </div>
          <button onclick="App.removeFromLista(${id})" class="text-muted p-1">✕</button>
        </div>`;
    }).join('');
  }

  function moveItem(index, dir) {
    const newIdx = index + dir;
    if (newIdx < 0 || newIdx >= myLista.length) return;
    [myLista[index], myLista[newIdx]] = [myLista[newIdx], myLista[index]];
    localStorage.setItem('wl-lista', JSON.stringify(myLista));
    renderLista();
  }

  function removeFromLista(id) {
    myLista = myLista.filter(x => x !== id);
    localStorage.setItem('wl-lista', JSON.stringify(myLista));
    renderLista();
  }

  function exportPDF() {
    if (myLista.length === 0) { alert('Lista jest pusta.'); return; }

    // Buduj treść
    const lines = myLista.map((id, i) => {
      const s = Data.getSchool(id);
      if (!s) return '';
      const tier = tierLabel(getTier(s.prog_min));
      return `${i + 1}. ${s.nazwa}\n   Dzielnica: ${s.dzielnica ?? '—'} | Próg: ${s.prog_min ?? '—'} pkt | ${tier}`;
    }).filter(Boolean);

    const tekst = `Moja Lista Liceów — WawaLiceum\n${'─'.repeat(40)}\n\n${lines.join('\n\n')}\n\n─────────────────────────────────────\nWygenerowano: ${new Date().toLocaleDateString('pl-PL')}\nhttps://pd5132.github.io/WawaLiceum/app/`;

    // Próba Web Share API (telefon — udostępnij / zapisz / wyślij mailem)
    if (navigator.share) {
      navigator.share({ title: 'Moja Lista Liceów', text: tekst })
        .catch(() => {}); // użytkownik anulował — OK
      return;
    }

    // Fallback: otwórz okno drukowania (desktop / zapis PDF)
    const win = window.open('', '_blank');
    win.document.write(`<!DOCTYPE html><html><head>
      <meta charset="UTF-8"><title>Moja Lista Liceów</title>
      <style>
        body { font-family: sans-serif; padding: 2rem; color: #064E3B; }
        h1 { color: #059669; margin-bottom: 1rem; }
        .school { margin-bottom: 1.2rem; border-bottom: 1px solid #D1FAE5; padding-bottom: 0.8rem; }
        .rank { font-size: 1.1rem; font-weight: bold; color: #047857; }
        .meta { color: #6B7280; font-size: 0.85rem; margin-top: 0.25rem; }
        footer { margin-top: 2rem; font-size: 0.75rem; color: #9CA3AF; }
      </style></head><body>
      <h1>Moja Lista Liceów</h1>
      ${myLista.map((id, i) => {
        const s = Data.getSchool(id);
        if (!s) return '';
        const tier = tierLabel(getTier(s.prog_min));
        return `<div class="school">
          <div class="rank">${i + 1}. ${s.nazwa}</div>
          <div class="meta">Dzielnica: ${s.dzielnica ?? '—'} &nbsp;|&nbsp; Próg: ${s.prog_min ?? '—'} pkt &nbsp;|&nbsp; ${tier}</div>
        </div>`;
      }).join('')}
      <footer>Wygenerowano ${new Date().toLocaleDateString('pl-PL')} · WawaLiceum</footer>
      </body></html>`);
    win.document.close();
    win.print();
  }

  // --- Porównywarka ---
  function renderPorownywarka() {
    const el = document.getElementById('porownywarka-content');
    if (porownajSet.length === 0) {
      el.innerHTML = `<div class="text-center py-12 text-muted px-4">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
        </svg>
        <p class="text-sm">Brak szkół do porównania</p>
        <button onclick="App.navigate('szukaj')" class="mt-4 text-xs font-semibold text-primary border border-primary px-4 py-2 rounded-full">
          Szukaj szkół
        </button>
      </div>`;
      return;
    }

    const schools = porownajSet.map(id => Data.getSchool(id)).filter(Boolean);
    const cols = schools.length;
    const colW = `${100 / (cols + 1)}%`;

    const rows = [
      { label: 'Szanse', fn: s => { const t = getTier(s.prog_min); return `<span class="text-xs font-medium px-2 py-0.5 rounded-full ${tierTextClass(t)}">${tierLabel(t)}</span>`; } },
      { label: 'Próg min.', fn: s => s.prog_min != null ? `<span class="font-semibold text-primary">${s.prog_min} pkt</span>` : '—' },
      { label: 'Ranking PL', fn: s => s.ranking_pozycja ? `<span class="font-semibold text-amber-600">#${s.ranking_pozycja}</span>` : '—' },
      { label: 'EWD Hum.', fn: s => { const e = Data.getEWD(s.id, 'humanistyczny'); return e ? `<span class="${e.ewd_oszacowanie_punktowe >= 0 ? 'text-primary' : 'text-dream'} font-semibold">${e.ewd_oszacowanie_punktowe > 0 ? '+' : ''}${e.ewd_oszacowanie_punktowe}</span>` : '—'; } },
      { label: 'EWD Mat.', fn: s => { const e = Data.getEWD(s.id, 'matematyczny'); return e ? `<span class="${e.ewd_oszacowanie_punktowe >= 0 ? 'text-primary' : 'text-dream'} font-semibold">${e.ewd_oszacowanie_punktowe > 0 ? '+' : ''}${e.ewd_oszacowanie_punktowe}</span>` : '—'; } },
      { label: 'Dzielnica', fn: s => `<span class="text-xs">${s.dzielnica ?? '—'}</span>` },
    ];

    el.innerHTML = `
      <table class="w-full text-xs border-collapse">
        <thead>
          <tr class="bg-bg">
            <th class="sticky left-0 bg-bg text-left p-3 text-muted font-medium w-24">Szkoła</th>
            ${schools.map(s => `
              <th class="p-2 text-center">
                <p class="text-xs font-semibold text-ink leading-tight">${s.nazwa.replace(/^([\w\s]+)\s+im\./, '<span class="block">$1</span><span class="text-muted font-normal">im.')}</p>
                <button onclick="App.removePorownaj(${s.id})" class="text-muted text-[10px] mt-1">✕ usuń</button>
              </th>`).join('')}
          </tr>
        </thead>
        <tbody>
          ${rows.map((row, ri) => `
            <tr class="${ri % 2 === 0 ? 'bg-white' : 'bg-bg'}">
              <td class="sticky left-0 ${ri % 2 === 0 ? 'bg-white' : 'bg-bg'} p-3 text-muted font-medium">${row.label}</td>
              ${schools.map(s => `<td class="p-3 text-center">${row.fn(s)}</td>`).join('')}
            </tr>`).join('')}
        </tbody>
      </table>`;
  }

  function removePorownaj(id) {
    porownajSet = porownajSet.filter(x => x !== id);
    localStorage.setItem('wl-porownaj', JSON.stringify(porownajSet));
    renderPorownywarka();
  }

  // --- Profil dropdown ---
  function onProfileChange() {
    userProfile = document.getElementById('profile-select').value;
    document.getElementById('filter-profil').value = userProfile;
    calcScore();
  }

  // --- Kalkulator ---
  function calcScore() {
    const score = Calculator.compute({
      polPct: +document.getElementById('e-pol').value,
      matPct: +document.getElementById('e-mat').value,
      angPct: +document.getElementById('e-ang').value,
      gPol: +document.getElementById('g-pol').value,
      gMat: +document.getElementById('g-mat').value,
      gP1:  +document.getElementById('g-p1').value,
      gP2:  +document.getElementById('g-p2').value,
      stripe: document.getElementById('extra-stripe').checked,
      vol:    document.getElementById('extra-vol').checked,
      comp:   Math.min(+document.getElementById('extra-comp').value, 18),
    });

    document.getElementById('e-pol-val').textContent = document.getElementById('e-pol').value;
    document.getElementById('e-mat-val').textContent = document.getElementById('e-mat').value;
    document.getElementById('e-ang-val').textContent = document.getElementById('e-ang').value;

    userScore = score;
    document.getElementById('score-display').textContent = score.toFixed(1);

    // Analiza
    const schools = Data.getAll();
    if (schools.length > 0) {
      const thresholds = schools.map(s => s.prog_min).filter(p => p != null);
      const high = thresholds.filter(p => score > p + 10).length;
      const medium = thresholds.filter(p => score >= p - 10 && score <= p + 10).length;
      const dream = thresholds.filter(p => score < p - 10).length;
      document.getElementById('analiza-high').textContent = high;
      document.getElementById('analiza-medium').textContent = medium;
      document.getElementById('analiza-dream').textContent = dream;
      document.getElementById('analiza-block').classList.remove('hidden');
    }
  }

  // --- Init ---
  async function init() {
    if ('serviceWorker' in navigator) {
      // Wyrejestruj stare SW przed instalacją nowego (czyści zakeszowane błędy)
      const regs = await navigator.serviceWorker.getRegistrations();
      await Promise.all(regs.map(r => r.unregister()));
      navigator.serviceWorker.register('./sw.js').catch(() => {});
    }

    const status = document.getElementById('splash-status');
    try {
      await Data.load();
      status.textContent = 'Dane załadowane ✓';

      // Wypełnij dropdowny
      const schools = Data.getAll();
      const dzielnice = [...new Set(schools.map(s => s.dzielnica).filter(Boolean))].sort();
      const profile = [...new Set(schools.map(s => s.typ_oddzialu).filter(Boolean))].sort();
      const jezyki = [...new Set(schools.map(s => s.jezyk_dwujezyczny).filter(Boolean))].sort();

      const selDz = document.getElementById('filter-dzielnica');
      dzielnice.forEach(d => selDz.insertAdjacentHTML('beforeend', `<option value="${d}">${d}</option>`));

      const selPr = document.getElementById('filter-profil');
      profile.forEach(p => selPr.insertAdjacentHTML('beforeend', `<option value="${p}">${p}</option>`));

      const selMain = document.getElementById('profile-select');
      profile.forEach(p => selMain.insertAdjacentHTML('beforeend', `<option value="${p}">${p}</option>`));

      const selJez = document.getElementById('filter-jezyk');
      jezyki.forEach(j => selJez.insertAdjacentHTML('beforeend', `<option value="${j}">${j}</option>`));

      renderSchoolList(Data.getFiltered());

      setTimeout(() => navigate('kalkulator'), 800);
    } catch (err) {
      status.textContent = err.message || 'Błąd ładowania danych.';
      console.error(err);
    }
  }

  document.addEventListener('DOMContentLoaded', init);

  return { navigate, goBack, calcScore, setView, applyFilters, openKarta,
           toggleLista, togglePorownaj, moveItem, removeFromLista, removePorownaj,
           exportPDF, onProfileChange };
})();

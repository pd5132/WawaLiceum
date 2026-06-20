'use strict';

const App = (() => {
  // --- Stan aplikacji ---
  let currentScreen   = 'splash';
  let navHistory      = [];   // historia wstecz
  let navFuture       = [];   // historia wprzód
  let userScore       = 0;
  let userProfile     = '';
  let mapInstance     = null;
  let mapMarkers      = [];
  let currentSchoolId = null;
  let myLista         = JSON.parse(localStorage.getItem('wl-lista')   || '[]');
  let porownajSet     = JSON.parse(localStorage.getItem('wl-porownaj') || '[]');
  let currentView     = 'lista';
  let activeTierFilter = null;
  let ewdChart        = null; // instancja Chart.js

  // --- Nawigacja ---
  function navigate(screen, fromHistory = false) {
    if (screen === currentScreen) return;
    document.getElementById(`screen-${currentScreen}`)?.classList.remove('active');

    if (!fromHistory) {
      navHistory.push(currentScreen);
      navFuture = [];
    }

    currentScreen = screen;
    document.getElementById(`screen-${screen}`)?.classList.add('active');

    const nav = document.getElementById('bottom-nav');
    nav.classList.toggle('hidden', screen === 'splash');

    document.querySelectorAll('.nav-btn').forEach(btn => {
      const isActive = btn.dataset.nav === screen;
      btn.classList.toggle('text-primary', isActive);
      btn.classList.toggle('text-muted', !isActive);
    });

    if (screen === 'szukaj' && currentView === 'mapa' && !mapInstance) initMap();
    if (screen === 'lista') renderLista();
    if (screen === 'porownywarka') renderPorownywarka();

    updateNavArrows();
  }

  function goBack() {
    if (!navHistory.length) return;
    navFuture.push(currentScreen);
    const prev = navHistory.pop();
    navigate(prev, true);
  }

  function goForward() {
    if (!navFuture.length) return;
    navHistory.push(currentScreen);
    const next = navFuture.pop();
    navigate(next, true);
  }

  function updateNavArrows() {
    const canBack = navHistory.length > 0;
    const canFwd  = navFuture.length > 0;
    document.querySelectorAll('.nav-arrow-back').forEach(btn => {
      btn.disabled = !canBack;
      btn.classList.toggle('opacity-30', !canBack);
    });
    document.querySelectorAll('.nav-arrow-fwd').forEach(btn => {
      btn.disabled = !canFwd;
      btn.classList.toggle('opacity-30', !canFwd);
    });
  }

  // --- Widok Lista / Mapa ---
  function setView(view) {
    currentView = view;
    const listaEl = document.getElementById('view-lista');
    const mapaEl  = document.getElementById('view-mapa');
    const btnL    = document.getElementById('toggle-lista');
    const btnM    = document.getElementById('toggle-mapa');

    if (view === 'lista') {
      listaEl.classList.remove('hidden');
      mapaEl.classList.add('hidden');
      btnL.classList.replace('text-muted', 'text-white');
      btnL.classList.add('bg-primary');
      btnM.classList.remove('bg-primary');
      btnM.classList.replace('text-white', 'text-muted');
    } else {
      listaEl.classList.add('hidden');
      mapaEl.classList.remove('hidden');
      btnM.classList.replace('text-muted', 'text-white');
      btnM.classList.add('bg-primary');
      btnL.classList.remove('bg-primary');
      btnL.classList.replace('text-white', 'text-muted');
      if (!mapInstance) initMap();
      else setTimeout(() => mapInstance.invalidateSize(), 100);
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

    // Legenda
    const legend = L.control({ position: 'topright' });
    legend.onAdd = () => {
      const div = L.DomUtil.create('div');
      div.style.cssText = 'background:rgba(255,255,255,0.95);border:1px solid #D1FAE5;border-radius:12px;padding:8px 12px;font-family:"Plus Jakarta Sans",sans-serif;font-size:11px;line-height:1.9;box-shadow:0 2px 8px rgba(0,0,0,.1);color:#064E3B';
      div.innerHTML = `
        <div style="font-weight:700;margin-bottom:3px">Szanse</div>
        <div><span style="color:#22C55E;font-size:16px;line-height:1">●</span>&nbsp;Wysokie szanse</div>
        <div><span style="color:#FB923C;font-size:16px;line-height:1">●</span>&nbsp;Realistyczna</div>
        <div><span style="color:#EF4444;font-size:16px;line-height:1">●</span>&nbsp;Szkoła marzeń</div>
        <div><span style="color:#9CA3AF;font-size:16px;line-height:1">●</span>&nbsp;Brak progu</div>`;
      return div;
    };
    legend.addTo(mapInstance);

    renderMapMarkers(Data.getFiltered());
  }

  function renderMapMarkers(schools) {
    if (!mapInstance) return;
    mapMarkers.forEach(m => m.remove());
    mapMarkers = [];
    schools.forEach(s => {
      if (!s.lat || !s.lon) return;
      // Szkoły bez progu → szara kropka
      const tier  = s.prog_min != null ? getTier(s.prog_min) : 'unknown';
      const color = tierColor(tier);
      const icon  = L.divIcon({
        className: '',
        html: `<div style="width:14px;height:14px;border-radius:50%;background:${color};border:2px solid white;box-shadow:0 1px 4px rgba(0,0,0,.3)"></div>`,
        iconSize: [14, 14], iconAnchor: [7, 7],
      });
      const marker = L.marker([s.lat, s.lon], { icon })
        .addTo(mapInstance)
        .on('click', () => showMapPopup(s));
      mapMarkers.push(marker);
    });
  }

  function showMapPopup(school) {
    const tier = getTier(school.prog_min);
    L.popup({ className: 'wl-popup' })
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
        </div>`)
      .openOn(mapInstance);
  }

  // --- Szanse (tier) ---
  function getTier(prog) {
    if (prog == null || !userScore) return 'unknown';
    if (userScore > prog + 10) return 'high';
    if (userScore >= prog - 10) return 'medium';
    return 'dream';
  }
  function tierLabel(t) { return { high:'Wysokie szanse', medium:'Realistyczna', dream:'Szkoła marzeń', unknown:'—' }[t] || '—'; }
  function tierColor(t) { return { high:'#22C55E', medium:'#FB923C', dream:'#EF4444', unknown:'#9CA3AF' }[t]; }
  function tierBg(t)    { return { high:'#dcfce7', medium:'#ffedd5', dream:'#fee2e2', unknown:'#f3f4f6' }[t]; }
  function tierTextClass(t) { return { high:'bg-green-100 text-green-800', medium:'bg-orange-100 text-orange-800', dream:'bg-red-100 text-red-800', unknown:'bg-gray-100 text-gray-500' }[t]; }

  // --- Dzielnica multi-select ---
  function toggleDzielnicaDropdown(e) {
    if (e) e.stopPropagation();
    const panel = document.getElementById('dzielnica-panel');
    panel.classList.toggle('hidden');
  }

  function getSelectedDzielnice() {
    return [...document.querySelectorAll('#dzielnica-panel input[type=checkbox]:checked')].map(cb => cb.value);
  }

  function updateDzielnicaLabel() {
    const selected = getSelectedDzielnice();
    const label = document.getElementById('dzielnica-btn-label');
    if (!label) return;
    label.textContent = selected.length === 0 ? 'Dzielnica'
      : selected.length === 1 ? selected[0]
      : `${selected.length} dzielnic`;
  }

  // --- Filtry i lista szkół ---
  function applyFilters() {
    const dzielnice = getSelectedDzielnice();
    const profil    = document.getElementById('filter-profil')?.value || '';
    const jezyk     = document.getElementById('filter-jezyk')?.value  || '';
    let filtered    = Data.getFiltered({ dzielnice, profil, jezyk });
    if (activeTierFilter) filtered = filtered.filter(s => getTier(s.prog_min) === activeTierFilter);
    renderSchoolList(filtered);
    if (currentView === 'mapa') renderMapMarkers(filtered);
  }

  function showTierSchools(tier) {
    activeTierFilter = tier;
    const chip   = document.getElementById('tier-filter-chip');
    const label  = document.getElementById('tier-filter-label');
    const colors = { high:'#dcfce7', medium:'#ffedd5', dream:'#fee2e2' };
    const text   = { high:'#166534', medium:'#9a3412', dream:'#991b1b' };
    chip.style.display = 'block';
    label.textContent  = 'Filtr: ' + tierLabel(tier) + '  ×';
    label.style.background = colors[tier];
    label.style.color      = text[tier];
    navigate('szukaj');
    applyFilters();
  }

  function clearTierFilter() {
    activeTierFilter = null;
    document.getElementById('tier-filter-chip').style.display = 'none';
    applyFilters();
  }

  function renderSchoolList(schools) {
    const el = document.getElementById('schools-list');
    if (!schools || !schools.length) {
      el.innerHTML = '<p class="text-center text-muted text-sm py-8">Brak wyników dla wybranych filtrów</p>';
      return;
    }
    el.innerHTML = schools.map((s, i) => {
      const tier  = getTier(s.prog_min);
      const inPor = porownajSet.includes(s.id);
      const img   = Data.getImage(s.id);
      return `
        <div class="relative bg-surface rounded-2xl border border-border p-4 shadow-sm active:scale-[0.98] transition-transform animate-fadeIn cursor-pointer"
             style="animation-delay:${i * 40}ms"
             onclick="App.openKarta(${s.id})">
          <div class="flex items-start gap-3">
            ${img ? `<img src="${img}" alt="" class="w-10 h-10 rounded-xl object-cover flex-shrink-0 mt-0.5">` : ''}
            <div class="flex-1 min-w-0">
              <h3 class="text-sm font-semibold text-ink leading-tight pr-8">${s.nazwa}</h3>
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
          <!-- Przycisk Dodaj do porównania -->
          <button onclick="event.stopPropagation();App.togglePorownajFromList(${s.id})"
            id="pwr-list-${s.id}"
            title="Dodaj do porównania"
            class="absolute top-3 right-3 w-7 h-7 flex items-center justify-center rounded-full border transition-colors ${inPor ? 'bg-primary border-primary text-white' : 'border-border text-muted bg-surface'}">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
            </svg>
          </button>
        </div>`;
    }).join('');
  }

  // --- Karta Liceum ---
  function openKarta(schoolId) {
    currentSchoolId = Number(schoolId);
    const school = Data.getSchool(currentSchoolId);
    if (!school) return;

    document.getElementById('karta-nazwa').textContent = school.nazwa;
    document.getElementById('karta-dzielnica').textContent = school.dzielnica + (school.adres ? ' · ' + school.adres : '');

    // Miniatura
    const imgEl = document.getElementById('karta-img');
    if (imgEl) {
      const img = Data.getImage(currentSchoolId);
      if (img) { imgEl.src = img; imgEl.classList.remove('hidden'); }
      else imgEl.classList.add('hidden');
    }

    // Ranking badge
    const rb = document.getElementById('karta-ranking-badge');
    if (school.ranking_pozycja) {
      document.getElementById('karta-ranking-text').textContent = `#${school.ranking_pozycja} w Polsce`;
      rb.classList.remove('hidden'); rb.classList.add('inline-flex');
    } else {
      rb.classList.add('hidden'); rb.classList.remove('inline-flex');
    }

    // Chance badge
    const tier = getTier(school.prog_min);
    const cb = document.getElementById('karta-chance-badge');
    if (tier !== 'unknown') {
      cb.textContent = tierLabel(tier);
      cb.className = `px-2.5 py-1 rounded-full text-xs font-semibold ${tierTextClass(tier)}`;
      cb.classList.remove('hidden');
    } else {
      cb.classList.add('hidden');
    }

    // --- Nabór 2026 (przed progami historycznymi) ---
    renderNabor2026(currentSchoolId);

    // --- Progi historyczne ---
    const progiEl = document.getElementById('karta-progi');
    const progi   = Data.getThresholds(currentSchoolId);
    progiEl.innerHTML = progi.length
      ? progi.map(p => `
          <div class="flex items-center justify-between py-1.5 border-b border-border last:border-0">
            <div>
              <span class="text-xs font-medium text-ink">${p.nazwa_oddzialu ?? p.symbol_oddzialu}</span>
              <span class="ml-2 text-xs text-muted">${p.rok_kalendarzowy}</span>
            </div>
            <span class="text-sm font-semibold text-primary">${p.prog_punktowy_min != null ? p.prog_punktowy_min + ' pkt' : '—'}</span>
          </div>`).join('')
      : '<p class="text-sm text-muted">Brak danych</p>';

    // --- EWD (3 bloki) ---
    renderEWD('karta-ewd-hum',      Data.getEWD(currentSchoolId, 'humanistyczny'));
    renderEWD('karta-ewd-mat',      Data.getEWD(currentSchoolId, 'matematyczny'));
    renderEWD('karta-ewd-biolchem', Data.getEWD(currentSchoolId, 'biolchem'));

    // --- Wykres EWD ---
    renderEWDChart(currentSchoolId);

    // --- Matura ---
    const matEl    = document.getElementById('karta-matura');
    const maturaAll = Data.getMatura(currentSchoolId);
    if (maturaAll.length) {
      const maxRok = maturaAll[0].rok_kalendarzowy;
      const latest = maturaAll.filter(m => m.rok_kalendarzowy === maxRok);
      const colHeader = `<div class="flex items-center gap-1 pb-1 text-[10px] text-muted">
        <span class="flex-1">Przedmiot</span>
        <span class="w-14 text-right">Zdawal.</span>
        <span class="w-14 text-right">Śr. wynik</span></div>`;
      const renderGroup = items => items.map(m => `
        <div class="flex items-center gap-1 py-1 border-b border-border last:border-0">
          <span class="text-xs text-ink flex-1 min-w-0 truncate">${m.nazwa_przedmiotu}</span>
          <span class="text-xs text-muted w-14 text-right flex-shrink-0">${m.zdawalnosc_proc != null ? m.zdawalnosc_proc.toFixed(1)+'%' : '—'}</span>
          <span class="text-xs font-semibold text-primary w-14 text-right flex-shrink-0">${m.sredni_wynik_proc != null ? m.sredni_wynik_proc.toFixed(1)+'%' : '—'}</span>
        </div>`).join('');
      let html = `<p class="text-xs text-muted mb-2">Rok szkolny ${maxRok}</p>`;
      let hasAny = false;
      [{ key:'podstawowy', label:'Poziom podstawowy' },
       { key:'rozszerzony', label:'Poziom rozszerzony' },
       { key:'dwujęzyczny', label:'Poziom dwujęzyczny' }].forEach(({ key, label }) => {
        const items = latest.filter(m => m.poziom === key && (m.zdawalnosc_proc != null || m.sredni_wynik_proc != null));
        if (!items.length) return;
        hasAny = true;
        html += `<p class="text-xs font-semibold text-muted uppercase tracking-wide mt-3 mb-1">${label}</p>${colHeader}${renderGroup(items)}`;
      });
      matEl.innerHTML = hasAny ? html : '<p class="text-sm text-muted">Brak danych</p>';
    } else {
      matEl.innerHTML = '<p class="text-sm text-muted">Brak danych</p>';
    }

    // --- Atmosfera ---
    const atmEl = document.getElementById('karta-atmosfera');
    const atm   = Data.getAtmosfera(currentSchoolId);
    if (atm) {
      const ratings = [
        { label:'Atmosfera',      val: atm.atmosfera_proc },
        { label:'Nauczyciele',    val: atm.relacja_nauczyciel_proc },
        { label:'Relacje uczniów',val: atm.relacje_uczniow_proc },
        { label:'Nauka',          val: atm.przyjemnosc_nauki_proc },
        { label:'Nowoczesność',   val: atm.nowoczesnosc_zajec_proc },
        { label:'Polecanie',      val: atm.polecanie_szkoly_proc },
      ].filter(r => r.val != null);
      if (ratings.length) {
        atmEl.innerHTML = ratings.map(r => `
          <div class="flex items-center gap-3">
            <span class="text-xs text-muted w-32 flex-shrink-0">${r.label}</span>
            <div class="flex-1 h-2 bg-gray-100 rounded-full overflow-hidden">
              <div class="h-full bg-primary rounded-full origin-left animate-barFill" style="width:${r.val}%"></div>
            </div>
            <span class="text-xs font-semibold text-ink w-8 text-right">${r.val}%</span>
          </div>`).join('');
      } else {
        atmEl.innerHTML = '<p class="text-sm text-muted">Brak danych liczbowych</p>';
      }
    } else {
      atmEl.innerHTML = '<p class="text-sm text-muted">Brak danych</p>';
    }

    // --- Inicjatywy ---
    const inits = Data.getInicjatywy(currentSchoolId);
    const initSec = document.getElementById('karta-inicjatywy-section');
    const initEl  = document.getElementById('karta-inicjatywy');
    if (inits.length) {
      initSec.classList.remove('hidden');
      initEl.innerHTML = inits.map(i =>
        `<span class="px-2.5 py-1 text-xs font-medium rounded-full border border-primary text-primary">${i.nazwa_elementu}</span>`
      ).join('');
    } else {
      initSec.classList.add('hidden');
    }

    // --- Kontakt ---
    const kontaktEl = document.getElementById('karta-kontakt');
    const www       = school.strona_www;
    const wwwHref   = www ? (www.startsWith('http') ? www : 'https://' + www) : null;
    const wwwDisplay = www ? www.replace(/^https?:\/\//, '') : null;
    kontaktEl.innerHTML = [
      school.adres      ? `<p class="text-xs text-muted">${school.adres}</p>` : '',
      wwwHref           ? `<a href="${wwwHref}" target="_blank" rel="noopener" class="text-xs text-primary font-medium">${wwwDisplay}</a>` : '',
      school.telefon    ? `<p class="text-xs text-muted">${school.telefon}</p>` : '',
      school.email      ? `<a href="mailto:${school.email}" class="text-xs text-primary">${school.email}</a>` : '',
    ].join('') || '<p class="text-sm text-muted">Brak danych</p>';

    updateKartaButtons(currentSchoolId);
    navigate('karta');
  }

  function renderNabor2026(schoolId) {
    const sec = document.getElementById('karta-nabor-2026-section');
    const el  = document.getElementById('karta-nabor-2026');
    if (!sec || !el) return;

    // Najpierw spróbuj danych ze stron szkół (fetch_rekrutacja_2026.py)
    const rek2026 = Data.getRekrutacja2026(schoolId);
    if (rek2026 && rek2026.length) {
      sec.classList.remove('hidden');
      el.innerHTML = rek2026.map(p => `
        <div class="py-1.5 border-b border-border last:border-0">
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium text-ink">${p.symbol ? `<span class="text-muted mr-1">${p.symbol}</span>` : ''}${p.nazwa_profilu}</span>
            ${p.miejsca ? `<span class="text-xs text-muted">${p.miejsca} miejsc</span>` : ''}
          </div>
          ${(p.jezyki||[]).length ? `<p class="text-xs text-muted mt-0.5">Języki: ${p.jezyki.join(', ')}</p>` : ''}
        </div>`).join('');
      return;
    }

    // Fallback: plan_naboru.json
    const plans = Data.getPlanNaboru2026(schoolId);
    if (plans.length) {
      sec.classList.remove('hidden');
      el.innerHTML = plans.map(p => `
        <div class="py-1.5 border-b border-border last:border-0">
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium text-ink">${p.typ_oddzialu_label}</span>
            ${p.liczba_miejsc ? `<span class="text-xs text-muted">${p.liczba_miejsc} miejsc</span>` : ''}
          </div>
          ${p.jezyk_label ? `<p class="text-xs text-muted mt-0.5">Język: ${p.jezyk_label}</p>` : ''}
        </div>`).join('');
    } else {
      sec.classList.add('hidden');
    }
  }

  function updateKartaButtons(schoolId) {
    const inLista = myLista.includes(schoolId);
    const inPor   = porownajSet.includes(schoolId);

    const btnL = document.getElementById('karta-btn-lista');
    if (btnL) {
      btnL.textContent = inLista ? '✓ Na liście' : '+ Dodaj do listy';
      btnL.classList.toggle('bg-primary',   inLista);
      btnL.classList.toggle('text-white',   inLista);
      btnL.classList.toggle('text-primary', !inLista);
    }

    // Przycisk porównaj w nagłówku karty
    const btnPH = document.getElementById('karta-btn-porownaj-header');
    if (btnPH) {
      btnPH.title = inPor ? 'W porównaniu (usuń)' : 'Dodaj do porównania';
      btnPH.classList.toggle('bg-primary',    inPor);
      btnPH.classList.toggle('text-white',    inPor);
      btnPH.classList.toggle('border-primary',inPor);
      btnPH.classList.toggle('border-border', !inPor);
      btnPH.classList.toggle('text-muted',    !inPor);
    }
  }

  function renderEWD(elId, ewd) {
    const el = document.getElementById(elId);
    if (!el) return;
    if (!ewd) { el.innerHTML = '<p class="text-sm text-muted">Brak danych</p>'; return; }
    const val = ewd.ewd_oszacowanie_punktowe;
    if (!Number.isFinite(val)) { el.innerHTML = '<p class="text-sm text-muted">Brak danych</p>'; return; }
    const isPos = val >= 0;
    const pct   = Math.min(Math.abs(val) * 10, 50);
    const color = isPos ? '#059669' : '#EF4444';
    const source = ewd.liczba_przedmiotow
      ? `Rok ${ewd.rok_kalendarzowy} · agregat z ${ewd.liczba_przedmiotow} przedm.`
      : `Rok ${ewd.rok_kalendarzowy}`;
    el.innerHTML = `
      <p class="text-xs text-muted">${source}</p>
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

  function renderEWDChart(schoolId) {
    const sec    = document.getElementById('karta-ewd-chart-section');
    const canvas = document.getElementById('ewd-chart-canvas');
    if (!sec || !canvas) return;

    const history = Data.getEWDHistory(schoolId);
    if (!history.length || !window.Chart) { sec.classList.add('hidden'); return; }

    sec.classList.remove('hidden');

    // Grupuj po nazwie egzaminu
    const subjectMap = {};
    history.forEach(r => {
      const key = r.nazwa_egzaminu;
      if (!subjectMap[key]) subjectMap[key] = [];
      subjectMap[key].push(r);
    });

    const years    = [...new Set(history.map(r => r.rok_kalendarzowy))].sort();
    const subjects = Object.keys(subjectMap);
    const COLORS   = ['#059669','#3B82F6','#F59E0B','#EF4444','#8B5CF6','#EC4899','#14B8A6','#F97316','#6366F1','#84CC16'];

    const datasets = subjects.map((subj, i) => ({
      label: subj,
      data: years.map(y => {
        const r = subjectMap[subj].find(x => x.rok_kalendarzowy === y);
        return r ? r.ewd_oszacowanie_punktowe : null;
      }),
      borderColor: COLORS[i % COLORS.length],
      backgroundColor: 'transparent',
      tension: 0.3,
      spanGaps: true,
      pointRadius: 4,
    }));

    if (ewdChart) ewdChart.destroy();
    ewdChart = new Chart(canvas, {
      type: 'line',
      data: { labels: years, datasets },
      options: {
        responsive: true,
        plugins: {
          legend: { position: 'bottom', labels: { font: { size: 9 }, boxWidth: 10, padding: 8 } },
          tooltip: { mode: 'index', intersect: false },
        },
        scales: {
          y: {
            grid: { color: '#f0f0f0' },
            ticks: { font: { size: 9 } },
            title: { display: true, text: 'EWD (pkt)', font: { size: 9 } },
          },
          x: { ticks: { font: { size: 9 } } },
        },
      },
    });
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

  function togglePorownaj(schoolId) {
    const id  = Number(schoolId ?? currentSchoolId);
    if (!id) return;
    const idx = porownajSet.indexOf(id);
    if (idx === -1) {
      if (porownajSet.length >= 4) { alert('Możesz porównać maksymalnie 4 szkoły.'); return; }
      porownajSet.push(id);
    } else {
      porownajSet.splice(idx, 1);
    }
    localStorage.setItem('wl-porownaj', JSON.stringify(porownajSet));
    if (id === currentSchoolId) updateKartaButtons(id);
    // Odśwież ikonę na liście
    _updateListPorownajIcon(id);
  }

  function togglePorownajFromList(schoolId) {
    togglePorownaj(schoolId);
  }

  function _updateListPorownajIcon(id) {
    const btn = document.getElementById(`pwr-list-${id}`);
    if (!btn) return;
    const inPor = porownajSet.includes(id);
    btn.className = `absolute top-3 right-3 w-7 h-7 flex items-center justify-center rounded-full border transition-colors ${inPor ? 'bg-primary border-primary text-white' : 'border-border text-muted bg-surface'}`;
  }

  function renderLista() {
    const el      = document.getElementById('lista-items');
    const warning = document.getElementById('vulcan-warning');
    if (!myLista.length) {
      el.innerHTML = `<div class="text-center py-12 text-muted">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>
        </svg>
        <p class="text-sm">Lista jest pusta</p>
        <p class="text-xs mt-1">Dodaj szkoły w ekranie Szukaj lub Karta</p></div>`;
      warning.classList.add('hidden'); warning.classList.remove('flex');
      return;
    }
    const tiers   = myLista.map(id => getTier(Data.getSchool(id)?.prog_min));
    const top3Dream = tiers.slice(0, 3).every(t => t === 'dream');
    const anyHigh   = tiers.some(t => t === 'high');
    warning.classList.toggle('hidden', !(top3Dream && !anyHigh));
    warning.classList.toggle('flex',     top3Dream && !anyHigh);

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
            <button onclick="App.moveItem(${i},-1)" ${i===0?'disabled':''} class="text-muted disabled:opacity-20 p-0.5">▲</button>
            <button onclick="App.moveItem(${i},1)"  ${i===myLista.length-1?'disabled':''} class="text-muted disabled:opacity-20 p-0.5">▼</button>
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
    if (!myLista.length) { alert('Lista jest pusta.'); return; }
    const lines = myLista.map((id, i) => {
      const s = Data.getSchool(id);
      if (!s) return '';
      return `${i+1}. ${s.nazwa}\n   Dzielnica: ${s.dzielnica ?? '—'} | Próg: ${s.prog_min ?? '—'} pkt | ${tierLabel(getTier(s.prog_min))}`;
    }).filter(Boolean);
    const tekst = `Moja Lista Liceów — WawaLiceum\n${'─'.repeat(40)}\n\n${lines.join('\n\n')}\n\n─────────────────────────────────────\nWygenerowano: ${new Date().toLocaleDateString('pl-PL')}\nhttps://pd5132.github.io/WawaLiceum/app/`;
    if (navigator.share) {
      navigator.share({ title: 'Moja Lista Liceów', text: tekst }).catch(() => {});
      return;
    }
    const win = window.open('', '_blank');
    win.document.write(`<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Moja Lista Liceów</title>
      <style>body{font-family:sans-serif;padding:2rem;color:#064E3B}h1{color:#059669}
      .school{margin-bottom:1.2rem;border-bottom:1px solid #D1FAE5;padding-bottom:.8rem}
      .rank{font-size:1.1rem;font-weight:bold;color:#047857}.meta{color:#6B7280;font-size:.85rem;margin-top:.25rem}
      footer{margin-top:2rem;font-size:.75rem;color:#9CA3AF}</style></head><body>
      <h1>Moja Lista Liceów</h1>
      ${myLista.map((id,i) => { const s=Data.getSchool(id);if(!s)return '';
        return `<div class="school"><div class="rank">${i+1}. ${s.nazwa}</div>
        <div class="meta">Dzielnica: ${s.dzielnica??'—'} &nbsp;|&nbsp; Próg: ${s.prog_min??'—'} pkt &nbsp;|&nbsp; ${tierLabel(getTier(s.prog_min))}</div></div>`;
      }).join('')}
      <footer>Wygenerowano ${new Date().toLocaleDateString('pl-PL')} · WawaLiceum</footer></body></html>`);
    win.document.close();
    win.print();
  }

  // --- Porównywarka ---
  function renderPorownywarka() {
    const el = document.getElementById('porownywarka-content');
    if (!porownajSet.length) {
      el.innerHTML = `<div class="text-center py-12 text-muted px-4">
        <svg class="w-12 h-12 mx-auto mb-3 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
        </svg>
        <p class="text-sm">Brak szkół do porównania</p>
        <p class="text-xs mt-1 text-muted">Dodaj szkoły do porównania — ikona ⊞ na liście lub przycisk w karcie szkoły</p>
        <button onclick="App.navigate('szukaj')" class="mt-4 text-xs font-semibold text-primary border border-primary px-4 py-2 rounded-full">
          Szukaj szkół
        </button>
      </div>`;
      return;
    }

    const schools = porownajSet.map(id => Data.getSchool(id)).filter(Boolean);

    const ewdCell = (sid, rodzaj) => {
      const e = Data.getEWD(sid, rodzaj);
      if (!e) return '<span class="text-muted">—</span>';
      const v = e.ewd_oszacowanie_punktowe;
      const cls = v >= 0 ? 'text-primary' : 'text-red-600';
      return `<span class="${cls} font-semibold">${v>0?'+':''}${v}</span>`;
    };

    const rows = [
      { label: 'Szanse',       fn: s => { const t=getTier(s.prog_min); return `<span class="text-xs font-medium px-2 py-0.5 rounded-full ${tierTextClass(t)}">${tierLabel(t)}</span>`; } },
      { label: 'Próg min.',    fn: s => s.prog_min != null ? `<span class="font-semibold text-primary">${s.prog_min} pkt</span>` : '—' },
      { label: 'Ranking PL',   fn: s => s.ranking_pozycja ? `<span class="font-semibold text-amber-600">#${s.ranking_pozycja}</span>` : '—' },
      { label: 'EWD hum.',     fn: s => ewdCell(s.id,'humanistyczny') },
      { label: 'EWD mat.',     fn: s => ewdCell(s.id,'matematyczny') },
      { label: 'EWD biol-ch.', fn: s => ewdCell(s.id,'biolchem') },
      { label: 'Atmosfera',    fn: s => { const a=Data.getAtmosfera(s.id); return a?.atmosfera_proc != null ? `${a.atmosfera_proc}%` : '—'; } },
      { label: 'Języki',       fn: s => (s.jezyki_dodatkowe||[]).map(j=>Data.jezyklabel(j)).join(', ')||'—' },
      { label: 'Dzielnica',    fn: s => `<span class="text-xs">${s.dzielnica??'—'}</span>` },
      { label: 'Nabór 2026',   fn: s => { const p=Data.getPlanNaboru2026(s.id); return p.length ? `${p.length} profilów` : '—'; } },
    ];

    el.innerHTML = `
      <div class="overflow-x-auto">
      <table class="w-full text-xs border-collapse min-w-[360px]">
        <thead>
          <tr class="bg-bg border-b border-border">
            <th class="sticky left-0 bg-bg text-left p-3 text-muted font-medium w-24 border-r border-border"></th>
            ${schools.map(s => {
              const img = Data.getImage(s.id);
              const inPor = porownajSet.includes(s.id);
              return `<th class="p-3 text-center min-w-[130px]">
                ${img ? `<img src="${img}" alt="" class="w-10 h-10 rounded-xl object-cover mx-auto mb-1">` : ''}
                <p class="text-xs font-semibold text-ink leading-tight">${s.nazwa}</p>
                <div class="flex gap-1 justify-center mt-1">
                  <button onclick="App.openKarta(${s.id})" class="text-[10px] text-primary border border-primary px-2 py-0.5 rounded-full">Karta</button>
                  <button onclick="App.removePorownaj(${s.id})" class="text-[10px] text-muted border border-border px-2 py-0.5 rounded-full">✕</button>
                </div>
              </th>`;
            }).join('')}
          </tr>
        </thead>
        <tbody>
          ${rows.map((row, ri) => `
            <tr class="${ri%2===0?'bg-white':'bg-bg'} border-b border-border">
              <td class="sticky left-0 ${ri%2===0?'bg-white':'bg-bg'} p-3 text-muted font-medium border-r border-border">${row.label}</td>
              ${schools.map(s => `<td class="p-3 text-center">${row.fn(s)}</td>`).join('')}
            </tr>`).join('')}
        </tbody>
      </table>
      </div>`;
  }

  function removePorownaj(id) {
    porownajSet = porownajSet.filter(x => x !== Number(id));
    localStorage.setItem('wl-porownaj', JSON.stringify(porownajSet));
    renderPorownywarka();
  }

  // --- Profil dropdown ---
  function onProfileChange() {
    userProfile = document.getElementById('profile-select').value;
    const fp = document.getElementById('filter-profil');
    if (fp) fp.value = userProfile;
    calcScore();
  }

  // --- Kalkulator ---
  function calcScore() {
    const score = Calculator.compute({
      polPct: +document.getElementById('e-pol').value,
      matPct: +document.getElementById('e-mat').value,
      angPct: +document.getElementById('e-ang').value,
      gPol:   +document.getElementById('g-pol').value,
      gMat:   +document.getElementById('g-mat').value,
      gP1:    +document.getElementById('g-p1').value,
      gP2:    +document.getElementById('g-p2').value,
      stripe: document.getElementById('extra-stripe').checked,
      vol:    document.getElementById('extra-vol').checked,
      comp:   Math.min(+document.getElementById('extra-comp').value, 18),
    });

    document.getElementById('e-pol-val').textContent = document.getElementById('e-pol').value;
    document.getElementById('e-mat-val').textContent = document.getElementById('e-mat').value;
    document.getElementById('e-ang-val').textContent = document.getElementById('e-ang').value;

    userScore = score;
    document.getElementById('score-display').textContent = score.toFixed(1);

    const allSchools = Data.getAll();
    if (allSchools.length) {
      const progi = allSchools.map(s => s.prog_min).filter(p => p != null);
      document.getElementById('analiza-high').textContent   = progi.filter(p => score > p+10).length;
      document.getElementById('analiza-medium').textContent = progi.filter(p => score >= p-10 && score <= p+10).length;
      document.getElementById('analiza-dream').textContent  = progi.filter(p => score < p-10).length;
      document.getElementById('analiza-block').classList.remove('hidden');
    }
  }

  // --- Init ---
  async function init() {
    if ('serviceWorker' in navigator) {
      const regs = await navigator.serviceWorker.getRegistrations();
      await Promise.all(regs.map(r => r.unregister()));
      navigator.serviceWorker.register('./sw.js').catch(() => {});
    }

    // Zamknij panel dzielnic przy kliknięciu poza nim
    document.addEventListener('click', e => {
      const container = document.getElementById('dzielnica-dropdown-container');
      if (container && !container.contains(e.target)) {
        document.getElementById('dzielnica-panel')?.classList.add('hidden');
      }
    });

    const status = document.getElementById('splash-status');
    try {
      await Data.load();
      status.textContent = 'Dane załadowane ✓';

      const allSchools = Data.getAll();

      // Dzielnica multi-select — wypełnij checkboxami
      const dzielnice = [...new Set(allSchools.map(s => s.dzielnica).filter(Boolean))].sort();
      const dzPanel   = document.getElementById('dzielnica-panel');
      if (dzPanel) {
        dzPanel.innerHTML = dzielnice.map(d => `
          <label class="flex items-center gap-2 px-1 py-0.5 cursor-pointer hover:bg-bg rounded">
            <input type="checkbox" value="${d}" onchange="App.updateDzielnicaLabel();App.applyFilters()"
              class="w-3.5 h-3.5 accent-primary rounded">
            <span class="text-xs text-ink">${d}</span>
          </label>`).join('');
      }

      // Profile dropdown
      const profile = Data.getProfiles();
      const selPr   = document.getElementById('filter-profil');
      const selMain = document.getElementById('profile-select');
      profile.forEach(p => {
        selPr?.insertAdjacentHTML('beforeend',  `<option value="${p}">${p}</option>`);
        selMain?.insertAdjacentHTML('beforeend', `<option value="${p}">${p}</option>`);
      });

      // Jezyki dropdown — z wszystkich jezyki_dodatkowe
      const jezyki  = Data.getAllJezyki();
      const selJez  = document.getElementById('filter-jezyk');
      jezyki.forEach(j => {
        selJez?.insertAdjacentHTML('beforeend', `<option value="${j}">${Data.jezyklabel(j)}</option>`);
      });

      renderSchoolList(Data.getFiltered());
      updateNavArrows();
      setTimeout(() => navigate('kalkulator'), 800);
    } catch (err) {
      status.textContent = err.message || 'Błąd ładowania danych.';
      console.error(err);
    }
  }

  document.addEventListener('DOMContentLoaded', init);

  return {
    navigate, goBack, goForward,
    calcScore, setView, applyFilters, openKarta,
    toggleLista, togglePorownaj, togglePorownajFromList,
    moveItem, removeFromLista, removePorownaj,
    exportPDF, onProfileChange, showTierSchools, clearTierFilter,
    toggleDzielnicaDropdown, updateDzielnicaLabel,
  };
})();

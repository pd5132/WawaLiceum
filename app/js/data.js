'use strict';

// Moduł ładowania i dostępu do danych z plików JSON
// JSON-i generuje skrypt ETL: etl/export_json.py
const Data = (() => {
  // Oblicz absolutny URL do folderu data/ niezależnie od trailing slash w URL
  const DATA_BASE = (() => {
    let path = window.location.pathname;
    if (!path.endsWith('/')) path = path.substring(0, path.lastIndexOf('/') + 1);
    return window.location.origin + path + 'data/';
  })();
  let schools     = [];  // Wymiar_Szkola (+ prog_min denormalizowany)
  let thresholds  = [];  // Fakt_Rekrutacja_Wyniki
  let ewd         = [];  // Fakt_Matura_EWD
  let ranking     = [];  // Fakt_Ranking_Perspektywy
  let matura      = [];  // Fakt_Matura_Statystyki_Szczegolowe
  let atmosfera   = [];  // Wymiar_Atmosfera
  let inicjatywy  = [];  // Wymiar_Inicjatywy_Zewnetrzne + Mostek
  let planNaboru  = [];  // Fakt_Plan_Naboru

  async function fetchJSON(name) {
    const url = DATA_BASE + name;
    const res = await fetch(url, { cache: 'no-cache' });
    if (!res.ok) throw new Error(`Nie można załadować: ${url} (status ${res.status})`);
    return res.json();
  }

  // Normalizacja profilu z nazwy oddziału.
  // Format danych: '{klasa} [{TYP}] {rozszerzenia} ({jezyki})'
  // Przykłady: '1A [O] biol-chem-mat (ang-niem)', '0A [DW] (fra-ang)', '1A [I-o] hist-pol (ang)'
  function normalizeProfile(nazwa) {
    if (!nazwa) return null;

    // Wyciągnij tag typu klasy: [O], [D], [DW], [S], [I-o], [MM], [KW] itp.
    const typeMatch = nazwa.match(/\[([^\]]+)\]/);
    const type = typeMatch ? typeMatch[1].toUpperCase() : '';

    // Typ klasy decyduje bez analizy rozszerzeń
    if (type === 'DW' || type === 'D') return 'dwujęzyczny';
    if (type === 'I-O' || type === 'I' || type === 'MM' || type === 'M' || type === 'MYP' || type === 'IB') return 'międzynarodowy';
    if (type === 'S') return 'sportowy';
    if (type === 'KW') return 'klasa wstępna';
    if (type === 'MS') return 'sportowy';

    // Dla [O] i innych: wyciągnij rozszerzenia (między tagiem a nawiasem)
    const extMatch = nazwa.match(/\[[^\]]+\]\s*([^(]*)/);
    if (!extMatch) return null;
    const exts = extMatch[1].trim().toLowerCase().split('-').map(e => e.trim()).filter(Boolean);
    if (!exts.length) return null;

    const has = (...items) => items.every(x => exts.includes(x));
    const any = (...items) => items.some(x => exts.includes(x));
    const noSci = () => !any('mat', 'fiz', 'biol', 'chem', 'inf');
    const FOREIGN = ['niem', 'franc', 'fra', 'hiszp', 'hisz', 'wlo', 'ros', 'kor', 'arab', 'lac', 'ang'];

    // Artystyczny: historia sztuki
    if (exts.some(e => e.startsWith('h.szt'))) return 'artystyczny';

    // Przedmioty przyrodniczo-matematyczne
    if (has('biol', 'chem')) return 'biologiczno-chemiczny';
    if (has('fiz', 'mat') && any('inf')) return 'matematyczno-informatyczny';
    if (has('mat', 'inf')) return 'matematyczno-informatyczny';
    if (has('fiz', 'mat')) return 'matematyczno-fizyczny';
    if (has('biol', 'fiz')) return 'biologiczno-fizyczny';
    if (exts.includes('biol') && !any('chem', 'fiz')) return 'biologiczny';
    if (exts.includes('chem') && exts.includes('mat')) return 'matematyczno-chemiczny';
    if (exts.includes('inf') && !any('mat', 'fiz', 'biol', 'chem')) return 'informatyczny';
    if (exts.includes('mat') && !any('fiz', 'biol', 'chem', 'inf', 'geogr')) return 'matematyczny';

    // Przedmioty humanistyczne
    if (any('hist', 'wos', 'filoz') && any('pol', 'ang')) return 'humanistyczny';
    if (has('hist', 'pol') || has('pol', 'wos') || has('hist', 'wos')) return 'humanistyczny';
    if (exts.includes('pol') && noSci()) return 'humanistyczny';
    if (exts.includes('filoz') && noSci()) return 'humanistyczny';
    if (exts.includes('hist') && noSci()) return 'humanistyczny';
    if (exts.includes('wos') && noSci()) return 'humanistyczny';

    // Językowy: klasy z samymi językami (ang+pol, niem, franc, itp.)
    if (has('ang', 'pol') && noSci()) return 'językowy';
    if (exts.every(e => FOREIGN.includes(e)) && exts.length <= 3) return 'językowy';

    // Inne
    if (any('biz', 'ek', 'ekon')) return 'ekonomiczny';
    if (exts.includes('geogr') && exts.includes('mat')) return 'geograficzno-matematyczny';
    if (exts.includes('geogr') && noSci()) return 'geograficzny';

    return null;
  }

  async function load() {
    schools    = await fetchJSON('schools.json');
    thresholds = await fetchJSON('thresholds.json');
    ewd        = await fetchJSON('ewd.json');
    ranking    = await fetchJSON('ranking.json');
    matura     = await fetchJSON('matura.json');
    atmosfera  = await fetchJSON('atmosfera.json');
    inicjatywy = await fetchJSON('inicjatywy.json');
    planNaboru = await fetchJSON('plan_naboru.json');

    // Denormalizuj: prog_min (max rok), ranking_pozycja (max rok), profiles z nazw oddziałów
    schools = schools.map(s => {
      const schoolThresholds = thresholds.filter(t => t.id_szkoly_rspo === s.id);
      const maxRok = schoolThresholds.length
        ? Math.max(...schoolThresholds.map(t => t.rok_kalendarzowy))
        : null;
      const progsLatest = schoolThresholds.filter(t => t.rok_kalendarzowy === maxRok);
      const prog_min = progsLatest.length
        ? Math.min(...progsLatest.map(t => t.prog_punktowy_min).filter(p => p != null))
        : null;
      const prog_rok = maxRok;

      const schoolRanking = ranking.filter(r => r.id_szkoly_rspo === s.id);
      const maxRokRank = schoolRanking.length
        ? Math.max(...schoolRanking.map(r => r.rok_kalendarzowy))
        : null;
      const rankLatest = schoolRanking.find(r => r.rok_kalendarzowy === maxRokRank);

      const plan = planNaboru.find(p => p.id_szkoly_rspo === s.id);

      // Profile z nazw oddziałów we wszystkich progach
      const profileSet = new Set();
      schoolThresholds.forEach(t => {
        const p = normalizeProfile(t.nazwa_oddzialu);
        if (p) profileSet.add(p);
      });

      return {
        ...s,
        prog_min,
        prog_rok,
        ranking_pozycja: rankLatest?.pozycja_w_rankingu ?? null,
        jezyk_dwujezyczny: plan?.jezyk_dwujezyczny ?? null,
        profiles: [...profileSet],
      };
    });
  }

  // --- Dostęp do danych ---

  function getAll() {
    return schools;
  }

  function getSchool(id) {
    return schools.find(s => s.id === id) ?? null;
  }

  function getFiltered({ dzielnica, profil, jezyk } = {}) {
    return schools.filter(s => {
      if (dzielnica && s.dzielnica !== dzielnica) return false;
      if (profil && !(s.profiles || []).includes(profil)) return false;
      if (jezyk && s.jezyk_dwujezyczny !== jezyk) return false;
      return true;
    }).sort((a, b) => (b.prog_min ?? 0) - (a.prog_min ?? 0));
  }

  function getProfiles() {
    const all = new Set();
    schools.forEach(s => (s.profiles || []).forEach(p => all.add(p)));
    return [...all].sort();
  }

  // Progi dla szkoły (max rok, wszystkie oddziały)
  function getThresholds(schoolId) {
    const rows = thresholds.filter(t => t.id_szkoly_rspo === schoolId);
    if (!rows.length) return [];
    const maxRok = Math.max(...rows.map(r => r.rok_kalendarzowy));
    return rows.filter(r => r.rok_kalendarzowy === maxRok)
               .sort((a, b) => (b.prog_punktowy_min ?? 0) - (a.prog_punktowy_min ?? 0));
  }

  // EWD dla szkoły i rodzaju ('humanistyczny' | 'matematyczny')
  function getEWD(schoolId, rodzaj) {
    const rows = ewd.filter(e =>
      e.id_szkoly_rspo === schoolId &&
      e.nazwa_egzaminu?.toLowerCase().includes(rodzaj === 'humanistyczny' ? 'hum' : 'mat')
    );
    if (!rows.length) return null;
    const maxRok = Math.max(...rows.map(r => r.rok_kalendarzowy));
    return rows.find(r => r.rok_kalendarzowy === maxRok) ?? null;
  }

  function getMatura(schoolId) {
    return matura
      .filter(m => m.id_szkoly_rspo === schoolId)
      .sort((a, b) => (b.rok_kalendarzowy ?? 0) - (a.rok_kalendarzowy ?? 0));
  }

  function getAtmosfera(schoolId) {
    return atmosfera.find(a => a.id_szkoly_rspo === schoolId) ?? null;
  }

  function getInicjatywy(schoolId) {
    return inicjatywy.filter(i => i.id_szkoly_rspo === schoolId);
  }

  return { load, getAll, getSchool, getFiltered, getProfiles, getThresholds, getEWD, getMatura, getAtmosfera, getInicjatywy };
})();

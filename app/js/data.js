'use strict';

// Moduł ładowania i dostępu do danych z plików JSON
const Data = (() => {
  const REMOTE_DATA_BASE = 'https://pd5132.github.io/WawaLiceum/app/data/';
  const DATA_BASES = (() => {
    const localBase = new URL('data/', window.location.href).href;
    return [...new Set([localBase, REMOTE_DATA_BASE].map(base => new URL(base, window.location.href).href))];
  })();

  let schools      = [];
  let thresholds   = [];
  let ewd          = [];
  let ranking      = [];
  let matura       = [];
  let atmosfera    = [];
  let inicjatywy   = [];
  let planNaboru   = [];
  let schoolImages = {};    // {id: url} — opcjonalny, z Wikipedia
  let rekrutacja2026 = {};  // {id: [{symbol,nazwa_profilu,jezyki,miejsca}]} — opcjonalny

  // Słownik kodów typów oddziałów z plan_naboru
  const TYP_ODDZIALU_LABEL = {
    'O ': 'Ogólny', 'O': 'Ogólny',
    'D ': 'Dwujęzyczny', 'D': 'Dwujęzyczny',
    'DW': 'Dwujęzyczny',
    'I ': 'Międzynarodowy (IB)', 'I': 'Międzynarodowy (IB)',
    'I-O': 'Międzynarodowy', 'MYP': 'Międzynarodowy', 'MM': 'Mundurowy',
    'KW': 'Klasa wstępna', 'MS': 'Mundurowy sportowy',
    'S ': 'Sportowy', 'S': 'Sportowy',
    'PW': 'Przygotowania wojskowego', 'OM': 'Olimpijski',
  };

  // Etykiety języków z plan_naboru.jezyk_dwujezyczny
  const JEZYK_LABEL = {
    'jez. angielski':  'Angielski',
    'jez.angielski':   'Angielski',
    'jez. niemiecki':  'Niemiecki',
    'jez.niemiecki':   'Niemiecki',
    'jez. francuski':  'Francuski',
    'jez.francuski':   'Francuski',
    'jez. hiszpanski': 'Hiszpański',
    'jez.hiszpanski':  'Hiszpański',
    'jez. wloski':     'Włoski',
    'jez.wloski':      'Włoski',
    'jez. rosyjski':   'Rosyjski',
    'jez.rosyjski':    'Rosyjski',
    'jez. arabski':    'Arabski',
    'jez.arabski':     'Arabski',
    'jez. koreanski':  'Koreański',
    'jez.koreanski':   'Koreański',
  };

  async function fetchJSON(name) {
    const errors = [];
    for (const base of DATA_BASES) {
      const url = base + name;
      try {
        const res = await fetch(url, { cache: 'no-cache' });
        if (!res.ok) throw new Error(`status ${res.status}`);
        return await res.json();
      } catch (err) {
        errors.push(`${url} (${err.message})`);
      }
    }
    throw new Error(`Nie można załadować ${name}. Próbowano: ${errors.join('; ')}`);
  }

  async function fetchJSONOptional(name) {
    try { return await fetchJSON(name); } catch { return null; }
  }

  // Normalizacja profilu z nazwy oddziału.
  // Format: '{klasa} [{TYP}] {rozszerzenia} ({jezyki})'
  function normalizeProfile(nazwa) {
    if (!nazwa) return null;
    const typeMatch = nazwa.match(/\[([^\]]+)\]/);
    const type = typeMatch ? typeMatch[1].toUpperCase() : '';

    if (type === 'DW' || type === 'D') return 'dwujęzyczny';
    if (type === 'I-O' || type === 'I' || type === 'MM' || type === 'M' || type === 'MYP' || type === 'IB') return 'międzynarodowy';
    if (type === 'S') return 'sportowy';
    if (type === 'KW') return 'klasa wstępna';
    if (type === 'MS') return 'sportowy';

    const extMatch = nazwa.match(/\[[^\]]+\]\s*([^(]*)/);
    if (!extMatch) return null;
    const exts = extMatch[1].trim().toLowerCase().split('-').map(e => e.trim()).filter(Boolean);
    if (!exts.length) return null;

    const has = (...items) => items.every(x => exts.includes(x));
    const any = (...items) => items.some(x => exts.includes(x));
    const noSci = () => !any('mat', 'fiz', 'biol', 'chem', 'inf');
    const FOREIGN = ['niem', 'franc', 'fra', 'hiszp', 'hisz', 'wlo', 'ros', 'kor', 'arab', 'lac', 'ang'];

    if (exts.some(e => e.startsWith('h.szt'))) return 'artystyczny';
    if (has('biol', 'chem')) return 'biologiczno-chemiczny';
    if (has('fiz', 'mat') && any('inf')) return 'matematyczno-informatyczny';
    if (has('mat', 'inf')) return 'matematyczno-informatyczny';
    if (has('fiz', 'mat')) return 'matematyczno-fizyczny';
    if (has('biol', 'fiz')) return 'biologiczno-fizyczny';
    if (exts.includes('biol') && !any('chem', 'fiz')) return 'biologiczny';
    if (exts.includes('chem') && exts.includes('mat')) return 'matematyczno-chemiczny';
    if (exts.includes('inf') && !any('mat', 'fiz', 'biol', 'chem')) return 'informatyczny';
    if (exts.includes('mat') && !any('fiz', 'biol', 'chem', 'inf', 'geogr')) return 'matematyczny';
    if (any('hist', 'wos', 'filoz') && any('pol', 'ang')) return 'humanistyczny';
    if (has('hist', 'pol') || has('pol', 'wos') || has('hist', 'wos')) return 'humanistyczny';
    if (exts.includes('pol') && noSci()) return 'humanistyczny';
    if (exts.includes('filoz') && noSci()) return 'humanistyczny';
    if (exts.includes('hist') && noSci()) return 'humanistyczny';
    if (exts.includes('wos') && noSci()) return 'humanistyczny';
    if (has('ang', 'pol') && noSci()) return 'językowy';
    if (exts.every(e => FOREIGN.includes(e)) && exts.length <= 3) return 'językowy';
    if (any('biz', 'ek', 'ekon')) return 'ekonomiczny';
    if (exts.includes('geogr') && exts.includes('mat')) return 'geograficzno-matematyczny';
    if (exts.includes('geogr') && noSci()) return 'geograficzny';
    return null;
  }

  // Normalizuj wartość jezyk_dwujezyczny: "jez.angielski" → "jez. angielski"
  function normalizeJezyk(raw) {
    if (!raw || raw === 'nan' || raw === 'None' || raw === 'null') return null;
    const j = String(raw).trim().replace(/^jez\.([^\s])/, 'jez. $1');
    return j.startsWith('jez.') ? j : null;
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

    const imgData  = await fetchJSONOptional('school_images.json');
    if (imgData)  schoolImages = imgData;

    const rek2026  = await fetchJSONOptional('rekrutacja_2026.json');
    if (rek2026)  rekrutacja2026 = rek2026;

    // Normalizuj ID do liczb (obrona przed niezgodnością typów string/int z ETL)
    schools    = schools.map(s => ({ ...s, id: Number(s.id) }));
    thresholds = thresholds.map(t => ({ ...t, id_szkoly_rspo: Number(t.id_szkoly_rspo) }));
    ewd        = ewd.map(e => ({ ...e, id_szkoly_rspo: Number(e.id_szkoly_rspo) }));
    ranking    = ranking.map(r => ({ ...r, id_szkoly_rspo: Number(r.id_szkoly_rspo) }));
    matura     = matura.map(m => ({ ...m, id_szkoly_rspo: Number(m.id_szkoly_rspo) }));
    atmosfera  = atmosfera.map(a => ({ ...a, id_szkoly_rspo: Number(a.id_szkoly_rspo) }));
    inicjatywy = inicjatywy.map(i => ({ ...i, id_szkoly_rspo: Number(i.id_szkoly_rspo) }));
    planNaboru = planNaboru.map(p => ({ ...p, id_szkoly_rspo: Number(p.id_szkoly_rspo) }));

    // Denormalizuj szkoły
    schools = schools.map(s => {
      const sid = s.id;

      const sThr = thresholds.filter(t => t.id_szkoly_rspo === sid);
      const maxRok = sThr.length ? Math.max(...sThr.map(t => t.rok_kalendarzowy)) : null;
      const latestThr = sThr.filter(t => t.rok_kalendarzowy === maxRok);
      const validProgi = latestThr.map(t => t.prog_punktowy_min).filter(p => p != null && isFinite(p));
      const prog_min = validProgi.length ? Math.min(...validProgi) : null;

      const sRank = ranking.filter(r => r.id_szkoly_rspo === sid);
      const maxRokR = sRank.length ? Math.max(...sRank.map(r => r.rok_kalendarzowy)) : null;
      const rankLatest = sRank.find(r => r.rok_kalendarzowy === maxRokR);

      // Wszystkie plany naboru dla szkoły
      const sPlans = planNaboru.filter(p => p.id_szkoly_rspo === sid);

      // Multi-value języki ze wszystkich planów (np. jedna szkoła ma i hiszp i niem)
      const jezyki_dodatkowe = [...new Set(
        sPlans.map(p => normalizeJezyk(p.jezyk_dwujezyczny)).filter(Boolean)
      )];

      // Profile z nazw oddziałów we wszystkich progach
      const profileSet = new Set();
      sThr.forEach(t => {
        const p = normalizeProfile(t.nazwa_oddzialu);
        if (p) profileSet.add(p);
      });

      return {
        ...s,
        prog_min,
        prog_rok: maxRok,
        ranking_pozycja: rankLatest?.pozycja_w_rankingu ?? null,
        jezyk_dwujezyczny: jezyki_dodatkowe[0] ?? null, // backward compat
        jezyki_dodatkowe,
        profiles: [...profileSet],
      };
    });
  }

  // --- Dostęp do danych ---

  function getAll() { return schools; }

  function getSchool(id) {
    return schools.find(s => s.id === Number(id)) ?? null;
  }

  function getFiltered({ dzielnice = [], dzielnica, profil, jezyk } = {}) {
    // dzielnice: tablica (nowy multi-select), dzielnica: string (backward compat)
    const dzList = dzielnice.length ? dzielnice : (dzielnica ? [dzielnica] : []);
    return schools.filter(s => {
      if (dzList.length > 0 && !dzList.includes(s.dzielnica)) return false;
      if (profil && !(s.profiles || []).includes(profil)) return false;
      if (jezyk && !(s.jezyki_dodatkowe || []).includes(jezyk)) return false;
      return true;
    }).sort((a, b) => (b.prog_min ?? 0) - (a.prog_min ?? 0));
  }

  function getProfiles() {
    const all = new Set();
    schools.forEach(s => (s.profiles || []).forEach(p => all.add(p)));
    return [...all].sort();
  }

  function getAllJezyki() {
    const all = new Set();
    schools.forEach(s => (s.jezyki_dodatkowe || []).forEach(j => all.add(j)));
    return [...all].sort();
  }

  // Progi dla szkoły (max rok, wszystkie oddziały), posortowane wg progu malejąco
  function getThresholds(schoolId) {
    const sid = Number(schoolId);
    const rows = thresholds.filter(t => t.id_szkoly_rspo === sid);
    if (!rows.length) return [];
    const maxRok = Math.max(...rows.map(r => r.rok_kalendarzowy));
    return rows.filter(r => r.rok_kalendarzowy === maxRok)
               .sort((a, b) => (b.prog_punktowy_min ?? 0) - (a.prog_punktowy_min ?? 0));
  }

  // Sprawdza czy rekord EWD pasuje do kategorii
  function matchesEWDKind(row, rodzaj) {
    const name = (row.nazwa_egzaminu || '').toLowerCase();
    const code = (row.rodzaj_zapisu || '').toLowerCase();

    if (rodzaj === 'humanistyczny') {
      return name.includes('humanistyczne') ||
        name.includes('jezyk polski') || name.includes('język polski') ||
        name.includes('historia') || name.includes('wiedza o spo') || name.includes('wos') ||
        code === 'mlh_2016' || code.startsWith('mljp_') || code.startsWith('mlh_') || code.startsWith('mlw_');
    }

    if (rodzaj === 'matematyczny') {
      // Tylko matematyka i fizyka — biologia/chemia trafiają do biolchem
      return name.includes('matematyczno-przyrodnicze') ||
        name.includes('matematyka') || name.includes('fizyka') ||
        code === 'mlmp_2016' || code.startsWith('mlm_') || code.startsWith('mlf_');
    }

    if (rodzaj === 'biolchem') {
      return name.includes('biologia') || name.includes('chemia') ||
        code.startsWith('mlb_') || code.startsWith('mlc_');
    }

    return false;
  }

  function averageEWD(rows, rodzaj) {
    const avg = key => {
      const vals = rows.map(r => r[key]).filter(v => Number.isFinite(v));
      if (!vals.length) return null;
      return Math.round(vals.reduce((s, v) => s + v, 0) / vals.length * 100) / 100;
    };
    const ewdVal = avg('ewd_oszacowanie_punktowe');
    if (ewdVal == null) return null;

    const labels = {
      humanistyczny: 'blok humanistyczny',
      matematyczny: 'blok matematyczno-przyrodniczy',
      biolchem: 'blok biologiczno-chemiczny',
    };

    return {
      ...rows[0],
      nazwa_egzaminu: labels[rodzaj] || rodzaj,
      rodzaj_zapisu: rodzaj,
      ewd_oszacowanie_punktowe: ewdVal,
      ewd_upper: avg('ewd_upper'),
      ewd_lower: avg('ewd_lower'),
      egzamin_oszacowanie: avg('egzamin_oszacowanie'),
      egzamin_upper: avg('egzamin_upper'),
      egzamin_lower: avg('egzamin_lower'),
      liczba_przedmiotow: rows.length,
    };
  }

  // EWD dla szkoły i kategorii: 'humanistyczny' | 'matematyczny' | 'biolchem'
  function getEWD(schoolId, rodzaj) {
    const sid = Number(schoolId);
    const rows = ewd.filter(e => e.id_szkoly_rspo === sid && matchesEWDKind(e, rodzaj));
    if (!rows.length) return null;
    const maxRok = Math.max(...rows.map(r => r.rok_kalendarzowy));
    const latest = rows.filter(r => r.rok_kalendarzowy === maxRok);

    // Szukaj gotowego agregatu blokowego
    const blockKeyword = rodzaj === 'humanistyczny' ? 'humanistyczne' :
                         rodzaj === 'matematyczny' ? 'matematyczno-przyrodnicze' : null;
    const aggregate = blockKeyword
      ? latest.find(r => Number.isFinite(r.ewd_oszacowanie_punktowe) && r.nazwa_egzaminu?.toLowerCase().includes(blockKeyword))
      : null;

    return aggregate ?? averageEWD(latest, rodzaj);
  }

  // Historia EWD per szkoła (wszystkie lata, wszystkie przedmioty) do wykresów
  function getEWDHistory(schoolId) {
    const sid = Number(schoolId);
    return ewd.filter(e => e.id_szkoly_rspo === sid && Number.isFinite(e.ewd_oszacowanie_punktowe));
  }

  function getMatura(schoolId) {
    const sid = Number(schoolId);
    return matura.filter(m => m.id_szkoly_rspo === sid)
      .sort((a, b) => (b.rok_kalendarzowy ?? 0) - (a.rok_kalendarzowy ?? 0));
  }

  function getAtmosfera(schoolId) {
    const sid = Number(schoolId);
    return atmosfera.find(a => a.id_szkoly_rspo === sid) ?? null;
  }

  function getInicjatywy(schoolId) {
    const sid = Number(schoolId);
    return inicjatywy.filter(i => i.id_szkoly_rspo === sid);
  }

  // Plan naboru 2026 dla szkoły (z plan_naboru.json)
  function getPlanNaboru2026(schoolId) {
    const sid = Number(schoolId);
    return planNaboru
      .filter(p => p.id_szkoly_rspo === sid)
      .map(p => ({
        ...p,
        typ_oddzialu_label: TYP_ODDZIALU_LABEL[p.typ_oddzialu?.trim()] || p.typ_oddzialu?.trim() || '—',
        jezyk_label: (() => {
          const jnorm = normalizeJezyk(p.jezyk_dwujezyczny);
          return jnorm ? (JEZYK_LABEL[jnorm] || jnorm) : null;
        })(),
      }));
  }

  // Dane ze stron szkół (opcjonalne, z fetch_rekrutacja_2026.py)
  function getRekrutacja2026(schoolId) {
    const sid = Number(schoolId);
    return rekrutacja2026[sid] ?? rekrutacja2026[String(sid)] ?? null;
  }

  // Miniatura zdjęcia szkoły (opcjonalna, z fetch_wikipedia_thumbnails.py)
  function getImage(schoolId) {
    const sid = Number(schoolId);
    return schoolImages[sid] ?? schoolImages[String(sid)] ?? null;
  }

  // Czytelna etykieta języka: "jez. angielski" → "Angielski"
  function jezyklabel(j) {
    return JEZYK_LABEL[j] || j;
  }

  return {
    load,
    getAll, getSchool, getFiltered, getProfiles, getAllJezyki,
    getThresholds, getEWD, getEWDHistory,
    getMatura, getAtmosfera, getInicjatywy,
    getPlanNaboru2026, getRekrutacja2026, getImage, jezyklabel,
    TYP_ODDZIALU_LABEL, JEZYK_LABEL,
  };
})();

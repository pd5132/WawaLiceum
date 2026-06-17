'use strict';

// Moduł ładowania i dostępu do danych z plików JSON
// JSON-i generuje skrypt ETL: etl/export_json.py
const Data = (() => {
  let schools     = [];  // Wymiar_Szkola (+ prog_min denormalizowany)
  let thresholds  = [];  // Fakt_Rekrutacja_Wyniki
  let ewd         = [];  // Fakt_Matura_EWD
  let ranking     = [];  // Fakt_Ranking_Perspektywy
  let matura      = [];  // Fakt_Matura_Statystyki_Szczegolowe
  let atmosfera   = [];  // Wymiar_Atmosfera
  let inicjatywy  = [];  // Wymiar_Inicjatywy_Zewnetrzne + Mostek
  let planNaboru  = [];  // Fakt_Plan_Naboru

  async function fetchJSON(path) {
    const res = await fetch(path);
    if (!res.ok) throw new Error(`Nie można załadować: ${path}`);
    return res.json();
  }

  async function load() {
    // Ładujemy pliki sekwencyjnie żeby łatwiej zlokalizować błąd
    schools    = await fetchJSON('./data/schools.json');
    thresholds = await fetchJSON('./data/thresholds.json');
    ewd        = await fetchJSON('./data/ewd.json');
    ranking    = await fetchJSON('./data/ranking.json');
    matura     = await fetchJSON('./data/matura.json');
    atmosfera  = await fetchJSON('./data/atmosfera.json');
    inicjatywy = await fetchJSON('./data/inicjatywy.json');
    planNaboru = await fetchJSON('./data/plan_naboru.json');

    // Denormalizuj: dołącz prog_min (max rok), ranking_pozycja (max rok) do każdej szkoły
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

      // Typ oddziału z planu naboru (dla filtra profil)
      const plan = planNaboru.find(p => p.id_szkoly_rspo === s.id);

      return {
        ...s,
        prog_min,
        prog_rok,
        ranking_pozycja: rankLatest?.pozycja_w_rankingu ?? null,
        typ_oddzialu: plan?.typ_oddzialu ?? null,
        jezyk_dwujezyczny: plan?.jezyk_dwujezyczny ?? null,
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
      if (profil && s.typ_oddzialu !== profil) return false;
      if (jezyk && s.jezyk_dwujezyczny !== jezyk) return false;
      return true;
    }).sort((a, b) => (b.prog_min ?? 0) - (a.prog_min ?? 0));
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

  return { load, getAll, getSchool, getFiltered, getThresholds, getEWD, getMatura, getAtmosfera, getInicjatywy };
})();

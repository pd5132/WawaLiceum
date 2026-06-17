'use strict';

// Algorytm punktowy rekrutacji do liceum (max 200 pkt)
// Źródło: CLAUDE.md / docs/README.md
const Calculator = (() => {

  // Egzamin ósmoklasisty — max 100 pkt
  function examScore({ polPct, matPct, angPct }) {
    return polPct * 0.35 + matPct * 0.35 + angPct * 0.30;
  }

  // Świadectwo — max 72 pkt (4 oceny × 18 pkt max)
  function gradesScore({ gPol, gMat, gP1, gP2 }) {
    return gPol + gMat + gP1 + gP2;
  }

  // Dodatkowe — max 28 pkt
  function extraScore({ stripe, vol, comp }) {
    return (stripe ? 7 : 0) + (vol ? 3 : 0) + Math.min(comp || 0, 18);
  }

  // Łączny wynik (max 200 pkt)
  function compute(inputs) {
    const exam   = examScore(inputs);
    const grades = gradesScore(inputs);
    const extra  = extraScore(inputs);
    return Math.min(Math.round((exam + grades + extra) * 10) / 10, 200);
  }

  return { compute, examScore, gradesScore, extraScore };
})();

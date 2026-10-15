/**
 * Titration – OOPA Virtual Labs / Chemistry
 *
 * Acid-base titrations at 25 C (Kw = 1e-14), acid and base reacting 1 : 1.
 *
 * pH is found from the exact charge balance for the mixed solution, so every part of the
 * curve (start, buffer region, equivalence point, excess titrant) comes from one equation:
 *
 *   A = analyte total concentration after mixing   = Ca * Va / (Va + Vb)
 *   B = titrant concentration after mixing         = Cb * Vb / (Va + Vb)
 *
 *   strong acid / strong base :  [H+] - [OH-] = (acid) - (base)         -> quadratic in [H+]
 *   weak acid (Ka) + NaOH     :  [H+] + B = [OH-] + A*Ka/([H+] + Ka)    -> solved by bisection on pH
 *   weak base (Kb) + HCl      :  [H+] + A*[H+]/([H+] + Kw/Kb) = [OH-] + B
 *
 * Indicators: the fraction in the "base" colour is  1 / (1 + 10^(pK_in - pH)),  and the flask
 * colour is a blend of the two colours by that fraction.
 * Activity effects are ignored, so very concentrated solutions differ slightly from a real meter.
 */
(function () {
  "use strict";

  var KW = 1e-14, VMAX = 50, DROP = 0.05;
  var WORLD_W = 400, WORLD_H = 350;
  var B = { cx: 150, xl: 139, xr: 161, top: 20, y0: 30, ppm: 2.8, bottom: 190, tipTop: 199, tipBottom: 214 };
  var FL = { nl: 137, nr: 163, ny0: 238, ny1: 262, bl: 95, br: 205, base: 300 };

  var SCEN = {
    sa_sb: { analyte: "HCl", titrant: "NaOH", acidAnalyte: true, weak: false,
             desc: "Hydrochloric acid in the flask, sodium hydroxide in the burette. Both are strong, so the equivalence point is at pH 7." },
    wa_sb: { analyte: "Ethanoic acid", titrant: "NaOH", acidAnalyte: true, weak: true, K: 1.8e-5,
             desc: "Ethanoic (acetic) acid in the flask, sodium hydroxide in the burette. The acid is weak (Ka = 1.8 × 10⁻⁵), so the equivalence point is above pH 7." },
    sb_sa: { analyte: "NaOH", titrant: "HCl", acidAnalyte: false, weak: false,
             desc: "Sodium hydroxide in the flask, hydrochloric acid in the burette. The pH falls as acid is added." },
    wb_sa: { analyte: "Ammonia", titrant: "HCl", acidAnalyte: false, weak: true, K: 1.8e-5,
             desc: "Ammonia solution in the flask, hydrochloric acid in the burette. The base is weak (Kb = 1.8 × 10⁻⁵), so the equivalence point is below pH 7." }
  };

  var IND = {
    none:            { name: "No indicator", pK: null },
    methylorange:    { name: "Methyl orange", pK: 3.7, lo: 3.1, hi: 4.4, acid: [224, 60, 49], base: [246, 215, 67], acidName: "red", baseName: "yellow" },
    methylred:       { name: "Methyl red", pK: 5.1, lo: 4.4, hi: 6.2, acid: [224, 60, 49], base: [242, 224, 74], acidName: "red", baseName: "yellow" },
    bromothymol:     { name: "Bromothymol blue", pK: 7.0, lo: 6.0, hi: 7.6, acid: [242, 224, 74], base: [47, 111, 214], acidName: "yellow", baseName: "blue" },
    phenolphthalein: { name: "Phenolphthalein", pK: 9.4, lo: 8.2, hi: 10.0, acid: [236, 242, 247], base: [224, 53, 154], acidName: "colourless", baseName: "pink" }
  };

  var $ = function (id) { return document.getElementById(id); };
  var cv = $("lab"), ctx = cv.getContext("2d");
  var gc = $("graph"), gx = gc.getContext("2d");
  var dpr = 1;

  var P = { sc: "sa_sb", ca: 0.1, va: 25, cb: 0.1, ind: "phenolphthalein", unknown: false };
  var S = { Vb: 0, pts: [], run: false, dropAcc: 0, drops: [], caHidden: 0.1, revealed: false, endpoint: null,
            last: 0, statT: 0, msg: null, cap: null };

  // ---------------------------------------------------------------- helpers
  function setText(id, t) { $(id).textContent = t; }
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }
  function tick(t) { return String(+t.toPrecision(6)); }
  function niceStep(span) {
    var raw = span / 6, p = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10)), f = raw / p;
    return (f < 1.5 ? 1 : f < 3.5 ? 2 : f < 7.5 ? 5 : 10) * p;
  }
  function niceCeil(v) {
    var p = Math.pow(10, Math.floor(Math.log(v) / Math.LN10)), f = v / p, steps = [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10];
    for (var i = 0; i < steps.length; i++) if (f <= steps[i] + 1e-9) return steps[i] * p;
    return 10 * p;
  }
  function setStatus(msg) { if (msg !== S.msg) { S.msg = msg; setText("ti-status", msg); } }

  // ---------------------------------------------------------------- chemistry
  function CA() { return P.unknown ? S.caHidden : P.ca; }      // the flask concentration actually used
  function veq() { return CA() * P.va / P.cb; }                // equivalence volume (mL), 1 : 1 reaction

  function phAt(Vb) {
    var sc = SCEN[P.sc], Vt = P.va + Vb;
    var A = CA() * P.va / Vt, Bc = P.cb * Vb / Vt;
    var E, s, h, f, Kac, lo = -1, hi = 15, mid, i;
    if (!sc.weak) {
      E = sc.acidAnalyte ? A - Bc : Bc - A;                    // (strong acid) - (strong base)
      s = Math.sqrt(E * E + 4 * KW);
      h = E >= 0 ? (E + s) / 2 : (2 * KW) / (s - E);           // stable form for either sign of E
      return -Math.log(h) / Math.LN10;
    }
    if (sc.acidAnalyte) {
      f = function (x) { return x + Bc - KW / x - A * sc.K / (x + sc.K); };
    } else {
      Kac = KW / sc.K;
      f = function (x) { return x + A * x / (x + Kac) - KW / x - Bc; };
    }
    for (i = 0; i < 70; i++) {                                 // f rises with [H+]; search on the pH scale
      mid = (lo + hi) / 2; h = Math.pow(10, -mid);
      if (f(h) > 0) lo = mid; else hi = mid;
    }
    return (lo + hi) / 2;
  }

  function endpointVolume(pK) {                                // volume at which pH = pK (null if never reached)
    var lo = 0, hi = 2 * veq(), glo = phAt(lo) - pK, ghi = phAt(hi) - pK, i, mid, gm;
    if (glo * ghi > 0) return null;
    for (i = 0; i < 60; i++) {
      mid = (lo + hi) / 2; gm = phAt(mid) - pK;
      if ((gm > 0) === (glo > 0)) { lo = mid; glo = gm; } else hi = mid;
    }
    return (lo + hi) / 2;
  }

  function indColor(pH) {
    var ind = IND[P.ind], a, c = [], i;
    if (!ind.pK) return { rgb: [225, 235, 245], name: "Colourless" };
    a = 1 / (1 + Math.pow(10, ind.pK - pH));
    for (i = 0; i < 3; i++) c.push(Math.round(ind.acid[i] + (ind.base[i] - ind.acid[i]) * a));
    return { rgb: c, name: a < 0.2 ? cap(ind.acidName) : a > 0.8 ? cap(ind.baseName) : "Changing colour" };
  }

  // ---------------------------------------------------------------- titration state
  function recordPoint(force) {
    var last = S.pts[S.pts.length - 1];
    if (last && Math.abs(last.v - S.Vb) < 1e-9) return;          // never store the same volume twice
    if (!force && last && S.Vb - last.v < 0.2 - 1e-9) return;
    S.pts.push({ v: S.Vb, ph: phAt(S.Vb) });
  }
  function setRun(on) {
    S.run = on;
    $("btn-run").setAttribute("aria-pressed", on ? "true" : "false");
    $("btn-run").textContent = on ? "Stop" : "Run";
  }
  function addVolume(dv, discrete) {
    var before = S.Vb, d;
    S.Vb = Math.min(VMAX, Math.round((S.Vb + dv) * 10000) / 10000);
    d = S.Vb - before;
    if (d > 0) { S.dropAcc = Math.min(30, S.dropAcc + d / DROP); recordPoint(!!discrete); }
    if (S.Vb >= VMAX) { if (S.run) { setRun(false); } recordPoint(true); }
  }
  function undo() {
    setRun(false);
    if (S.pts.length > 1) { S.pts.pop(); S.Vb = S.pts[S.pts.length - 1].v; }
  }
  function restart() {
    S.Vb = 0; S.pts = []; S.drops = []; S.dropAcc = 0; S.endpoint = null;
    setRun(false);
    setText("endpoint-note", "");
    S.pts.push({ v: 0, ph: phAt(0) });
    S.msg = null; S.cap = null;
    updateReadouts(); drawGraph();
  }

  // ---------------------------------------------------------------- unknown mode
  function newUnknown() {
    S.caHidden = Math.round((0.06 + Math.random() * 0.18) * 1000) / 1000;
    S.revealed = false;
    setText("unk-result", ""); $("c-guess").value = "";
    restart();
  }
  function checkAnswer() {
    var g = parseFloat($("c-guess").value), t = S.caHidden, err, msg;
    if (!(g > 0)) { setText("unk-result", "Type your answer first, in mol/L."); return; }
    err = (g - t) / t * 100; S.revealed = true;
    msg = "The true strength was " + t.toFixed(3) + " mol/L. Your answer was " + (err >= 0 ? "+" : "−") + Math.abs(err).toFixed(1) + "% off. ";
    if (Math.abs(err) <= 1) msg = "Excellent! " + msg;
    else if (Math.abs(err) <= 5) msg = "Close. " + msg;
    else msg += "Check that you used the volume at the colour change: flask strength = burette strength × volume added ÷ flask volume.";
    setText("unk-result", msg);
    updateReadouts(); drawGraph();
  }

  // ---------------------------------------------------------------- readouts and texts
  function indicatorText() {
    var ind = IND[P.ind], vq, ve, err, verdict;
    if (P.unknown && !S.revealed) return "Hidden until you check your answer.";
    if (!ind.pK) return "Choose an indicator to see where its colour change falls.";
    vq = veq(); ve = endpointVolume(ind.pK);
    if (ve === null) return ind.name + " changes colour at about pH " + ind.pK + ", which this titration never reaches, so it would show no endpoint.";
    err = (ve - vq) / vq * 100;
    verdict = Math.abs(err) <= 1 ? "Good choice." : Math.abs(err) <= 5 ? "Acceptable, but not ideal." : "Poor choice for this titration.";
    return ind.name + " changes colour at about " + ve.toFixed(2) + " mL, which is " + (err >= 0 ? "+" : "−") + Math.abs(err).toFixed(1) +
           "% from the equivalence point (" + vq.toFixed(2) + " mL). " + verdict;
  }
  function captionText() {
    var sc = SCEN[P.sc], vq, t, pK;
    t = "pH against volume of titrant added. The shaded band is where the chosen indicator changes colour.";
    if (P.unknown && !S.revealed) return t + " The equivalence point is hidden in unknown mode.";
    vq = veq();
    t += " Equivalence point: " + vq.toFixed(2) + " mL at pH " + phAt(vq).toFixed(2) + ".";
    if (sc.weak) {
      pK = -Math.log(sc.K) / Math.LN10;
      t += sc.acidAnalyte ? " At half-equivalence the pH equals pKa (" + pK.toFixed(2) + ")." : " At half-equivalence the pOH equals pKb (" + pK.toFixed(2) + ").";
    }
    return t;
  }

  function updateReadouts() {
    var ph = phAt(S.Vb), col = indColor(ph), vq, st, msg = "", c;
    setText("rv1", S.Vb.toFixed(2) + " mL"); setText("rv2", ph.toFixed(2));
    setText("rv3", (P.va + S.Vb).toFixed(1) + " mL"); setText("rv4", col.name);
    setText("rv5", (P.cb * S.Vb).toFixed(2) + " mmol");

    if (P.unknown && !S.revealed) {
      st = "Hidden (unknown)";
    } else {
      vq = veq();
      st = Math.abs(S.Vb - vq) <= 0.05 ? "At equivalence" : S.Vb < vq ? "Before equivalence" : "After equivalence";
      if (vq > VMAX) msg = "This titration needs about " + vq.toFixed(0) + " mL of titrant, but the burette holds 50 mL. Use a stronger burette solution or a smaller flask volume.";
    }
    setText("rv6", st);
    if (!msg && S.Vb >= VMAX) msg = "The burette is empty. Press Start over to refill it.";
    setStatus(msg);

    setText("ind-check", indicatorText());
    c = captionText();
    if (c !== S.cap) { S.cap = c; setText("graph-cap", c); }
  }

  // ---------------------------------------------------------------- drawing: shared
  function fitCanvas(c) {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    var w = Math.round(c.clientWidth * dpr), h = Math.round(c.clientHeight * dpr);
    if (w && h && (c.width !== w || c.height !== h)) { c.width = w; c.height = h; }
  }
  function rrect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }
  function liquidH(vt) { return 8 + Math.min(1, vt / 100) * 45; }
  function flaskPath() {
    ctx.beginPath();
    ctx.moveTo(FL.nl, FL.ny0); ctx.lineTo(FL.nl, FL.ny1); ctx.lineTo(FL.bl, FL.base);
    ctx.lineTo(FL.br, FL.base); ctx.lineTo(FL.nr, FL.ny1); ctx.lineTo(FL.nr, FL.ny0);
  }

  // ---------------------------------------------------------------- drawing: apparatus
  function draw() {
    var W = cv.clientWidth, H = cv.clientHeight;
    if (!W || !H) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = "#161616"; ctx.fillRect(0, 0, W, H);
    var sc = Math.min(W / WORLD_W, H / WORLD_H);
    ctx.setTransform(dpr * sc, 0, 0, dpr * sc, dpr * (W - WORLD_W * sc) / 2, dpr * (H - WORLD_H * sc) / 2);
    ctx.lineCap = "round"; ctx.lineJoin = "round";

    var S0 = SCEN[P.sc], ph = phAt(S.Vb), col = indColor(ph), ys = B.y0 + S.Vb * B.ppm;
    var ly = FL.base - liquidH(P.va + S.Vb), m, y, i, d, txt;

    // stand
    ctx.fillStyle = "#3a3a3a";
    ctx.fillRect(20, 305, 360, 8); ctx.fillRect(66, 28, 7, 280); ctx.fillRect(66, 86, 75, 5);

    // burette: titrant, tube, graduations, tap and tip
    ctx.fillStyle = "rgba(150,190,255,0.5)";
    ctx.fillRect(B.xl + 1, ys, B.xr - B.xl - 2, B.bottom - ys);
    if (S.Vb < VMAX) ctx.fillRect(B.cx - 2, B.tipTop, 4, B.tipBottom - B.tipTop);
    ctx.strokeStyle = "#cfcfcf"; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(B.xl, B.top); ctx.lineTo(B.xl, B.bottom); ctx.moveTo(B.xr, B.top); ctx.lineTo(B.xr, B.bottom); ctx.stroke();
    ctx.strokeRect(B.cx - 3, B.tipTop, 6, B.tipBottom - B.tipTop);
    ctx.fillStyle = "#8a8a8a"; ctx.fillRect(B.cx - 18, B.bottom, 36, 6);
    ctx.fillStyle = "#e14a4a"; ctx.fillRect(B.cx - 28, B.bottom + 1, 10, 4);
    ctx.strokeStyle = "#9a9a9a"; ctx.fillStyle = "#9a9a9a"; ctx.lineWidth = 1; ctx.font = "10px 'DM Sans', Arial, sans-serif"; ctx.textAlign = "left";
    for (m = 0; m <= 50; m += 5) {
      y = B.y0 + m * B.ppm;
      ctx.beginPath(); ctx.moveTo(B.xr, y); ctx.lineTo(B.xr + (m % 10 === 0 ? 9 : 5), y); ctx.stroke();
      if (m % 10 === 0) ctx.fillText(String(m), B.xr + 13, y + 3.5);
    }

    // flask liquid (coloured by the indicator), then the glass
    ctx.save(); flaskPath(); ctx.closePath(); ctx.clip();
    ctx.fillStyle = "rgba(" + col.rgb[0] + "," + col.rgb[1] + "," + col.rgb[2] + ",0.78)";
    ctx.fillRect(FL.bl - 5, ly, FL.br - FL.bl + 10, FL.base - ly + 2);
    ctx.restore();
    flaskPath(); ctx.strokeStyle = "#cfcfcf"; ctx.lineWidth = 2.5; ctx.stroke();

    // falling drops
    ctx.fillStyle = "rgba(150,190,255,0.95)";
    for (i = 0; i < S.drops.length; i++) { ctx.beginPath(); ctx.arc(B.cx, S.drops[i].y, 2.6, 0, 6.2832); ctx.fill(); }

    // pH probe and meter
    ctx.strokeStyle = "#8a8a8a"; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(262, 132); ctx.lineTo(262, 170); ctx.lineTo(186, 246); ctx.lineTo(186, 288); ctx.stroke();
    ctx.fillStyle = "#555"; ctx.fillRect(183, 282, 6, 10);
    rrect(245, 50, 140, 82, 8); ctx.fillStyle = "#222"; ctx.fill(); ctx.strokeStyle = "#555"; ctx.lineWidth = 2; ctx.stroke();
    ctx.fillStyle = "#9a9a9a"; ctx.font = "11px 'DM Sans', Arial, sans-serif"; ctx.fillText("pH meter", 257, 69);
    ctx.fillStyle = "#7cfc9a"; ctx.font = "700 34px 'DM Sans', Arial, sans-serif"; ctx.fillText(ph.toFixed(2), 257, 112);

    // labels
    ctx.font = "12px 'DM Sans', Arial, sans-serif"; ctx.fillStyle = "#cfcfcf";
    ctx.fillText("Burette: " + S0.titrant + " " + P.cb.toFixed(3) + " M", 20, 328);
    txt = "Flask: " + S0.analyte + (P.unknown && !S.revealed ? " (unknown)" : " " + CA().toFixed(3) + " M") + ", " + P.va.toFixed(0) + " mL";
    ctx.fillText(txt, 20, 344);
  }

  // ---------------------------------------------------------------- drawing: curve
  function drawGraph() {
    var W = gc.clientWidth, H = gc.clientHeight;
    if (!W || !H) return;
    gx.setTransform(dpr, 0, 0, dpr, 0, 0); gx.clearRect(0, 0, W, H);
    var pad = { l: 46, r: 14, t: 14, b: 42 }, pw = W - pad.l - pad.r, ph = H - pad.t - pad.b;
    if (pw < 30 || ph < 30) return;

    var hidden = P.unknown && !S.revealed;
    var vq = hidden ? null : veq();
    var xmax = vq === null ? VMAX : Math.min(VMAX, Math.max(10, niceCeil(vq * 1.6)));
    if (S.Vb > xmax * 0.98) xmax = Math.min(VMAX, niceCeil(S.Vb * 1.1));   // keep the latest point on the plot
    var X = function (v) { return pad.l + v / xmax * pw; }, Y = function (v) { return pad.t + ph - v / 14 * ph; };
    var sx = niceStep(xmax), t, i, x, ind = IND[P.ind];

    gx.font = "11px 'DM Sans', Arial, sans-serif"; gx.lineWidth = 1; gx.strokeStyle = "#ece8e6"; gx.fillStyle = "#777"; gx.textAlign = "center";
    for (t = 0; t <= xmax + 1e-9; t += sx) {
      gx.beginPath(); gx.moveTo(X(t), pad.t); gx.lineTo(X(t), pad.t + ph); gx.stroke();
      gx.fillText(tick(t), X(t), pad.t + ph + 15);
    }
    gx.textAlign = "right";
    for (t = 0; t <= 14; t += 2) {
      gx.beginPath(); gx.moveTo(pad.l, Y(t)); gx.lineTo(pad.l + pw, Y(t)); gx.stroke();
      gx.fillText(String(t), pad.l - 7, Y(t) + 4);
    }

    if (ind.pK) {                                              // band where the indicator changes colour
      gx.fillStyle = "rgba(" + ind.base[0] + "," + ind.base[1] + "," + ind.base[2] + ",0.20)";
      gx.fillRect(pad.l, Y(ind.hi), pw, Y(ind.lo) - Y(ind.hi));
      gx.fillStyle = "#777"; gx.textAlign = "left"; gx.fillText(ind.name, pad.l + 6, Y(ind.hi) + 12);
    }

    gx.strokeStyle = "#999"; gx.lineWidth = 1.5;
    gx.beginPath(); gx.moveTo(pad.l, pad.t); gx.lineTo(pad.l, pad.t + ph); gx.lineTo(pad.l + pw, pad.t + ph); gx.stroke();
    gx.fillStyle = "#555"; gx.textAlign = "center";
    gx.fillText("Volume of titrant added (mL)", pad.l + pw / 2, H - 6);
    gx.save(); gx.translate(13, pad.t + ph / 2); gx.rotate(-Math.PI / 2); gx.fillText("pH", 0, 0); gx.restore();

    gx.save(); gx.beginPath(); gx.rect(pad.l - 4, pad.t - 4, pw + 8, ph + 8); gx.clip();
    if ($("c-curve").checked && !hidden) {                     // the full theoretical curve, for comparison
      gx.setLineDash([5, 4]); gx.strokeStyle = "#b5b0ad"; gx.lineWidth = 1.5; gx.beginPath();
      for (i = 0; i <= 240; i++) { x = xmax * i / 240; if (i) gx.lineTo(X(x), Y(phAt(x))); else gx.moveTo(X(x), Y(phAt(x))); }
      gx.stroke(); gx.setLineDash([]);
    }
    if ($("c-eq").checked && vq !== null && vq <= xmax) {      // equivalence point
      gx.setLineDash([3, 4]); gx.strokeStyle = "#3d8b3d"; gx.lineWidth = 1.5;
      gx.beginPath(); gx.moveTo(X(vq), pad.t); gx.lineTo(X(vq), pad.t + ph); gx.stroke(); gx.setLineDash([]);
      gx.fillStyle = "#3d8b3d"; gx.beginPath(); gx.arc(X(vq), Y(phAt(vq)), 4.5, 0, 6.2832); gx.fill();
    }
    gx.strokeStyle = "#b22222"; gx.lineWidth = 2.5; gx.beginPath();            // the learner's own points
    for (i = 0; i < S.pts.length; i++) { if (i) gx.lineTo(X(S.pts[i].v), Y(S.pts[i].ph)); else gx.moveTo(X(S.pts[i].v), Y(S.pts[i].ph)); }
    gx.stroke();
    gx.fillStyle = "#b22222";
    for (i = 0; i < S.pts.length; i++) { gx.beginPath(); gx.arc(X(S.pts[i].v), Y(S.pts[i].ph), 2.6, 0, 6.2832); gx.fill(); }
    gx.strokeStyle = "#fff"; gx.lineWidth = 2; gx.beginPath(); gx.arc(X(S.Vb), Y(phAt(S.Vb)), 6, 0, 6.2832); gx.fill(); gx.stroke();
    gx.restore();

    if (vq !== null && $("c-eq").checked && vq <= xmax) {
      gx.fillStyle = "#3d8b3d"; gx.textAlign = "left"; gx.fillText("Equivalence", Math.min(X(vq) + 6, pad.l + pw - 70), pad.t + ph - 8);
    }
  }

  // ---------------------------------------------------------------- main loop
  function frame(ts) {
    if (!S.last) S.last = ts;
    var dt = Math.min(0.05, (ts - S.last) / 1000), i, d, surf, j;
    S.last = ts;

    if (S.run && dt > 0) {
      addVolume(parseFloat($("sel-rate").value) * dt, false);
      if (!S.run) recordPoint(true);                           // stopped (burette empty): keep the last volume
    }

    if (S.dropAcc >= 1 && S.drops.length < 8) { S.drops.push({ y: B.tipBottom + 3, v: 40 }); S.dropAcc -= 1; }
    surf = FL.base - liquidH(P.va + S.Vb);
    j = 0;
    for (i = 0; i < S.drops.length; i++) {
      d = S.drops[i]; d.v += 600 * dt; d.y += d.v * dt;
      if (d.y < surf) S.drops[j++] = d;
    }
    S.drops.length = j;

    draw();
    S.statT += dt;
    if (S.statT > 0.1) { S.statT = 0; updateReadouts(); drawGraph(); }
    requestAnimationFrame(frame);
  }

  // ---------------------------------------------------------------- wiring
  function syncUI() {
    $("sel-scen").value = P.sc; setText("scen-desc", SCEN[P.sc].desc);
    $("c-ca").value = P.ca; setText("o-ca", P.unknown ? "?" : P.ca.toFixed(3) + " M");
    $("c-va").value = P.va; setText("o-va", P.va.toFixed(0) + " mL");
    $("c-cb").value = P.cb; setText("o-cb", P.cb.toFixed(3) + " M");
    $("sel-ind").value = P.ind;
  }

  function bind() {
    $("sel-scen").addEventListener("change", function (e) { P.sc = e.target.value; setText("scen-desc", SCEN[P.sc].desc); restart(); });
    $("c-ca").addEventListener("input", function (e) { P.ca = parseFloat(e.target.value); setText("o-ca", P.ca.toFixed(3) + " M"); restart(); });
    $("c-va").addEventListener("input", function (e) { P.va = parseFloat(e.target.value); setText("o-va", P.va.toFixed(0) + " mL"); restart(); });
    $("c-cb").addEventListener("input", function (e) { P.cb = parseFloat(e.target.value); setText("o-cb", P.cb.toFixed(3) + " M"); restart(); });
    $("sel-ind").addEventListener("change", function (e) { P.ind = e.target.value; updateReadouts(); drawGraph(); });
    $("c-curve").addEventListener("change", drawGraph);
    $("c-eq").addEventListener("change", drawGraph);

    $("c-unknown").addEventListener("change", function (e) {
      P.unknown = e.target.checked;
      $("grp-unk").hidden = !P.unknown;
      $("c-ca").disabled = P.unknown;
      setText("o-ca", P.unknown ? "?" : P.ca.toFixed(3) + " M");
      if (P.unknown) newUnknown(); else { S.revealed = false; restart(); }
    });
    $("btn-newunk").addEventListener("click", newUnknown);
    $("btn-check").addEventListener("click", checkAnswer);
    $("btn-endpoint").addEventListener("click", function () {
      S.endpoint = S.Vb;
      setText("endpoint-note", "Endpoint recorded: " + S.Vb.toFixed(2) + " mL of " + SCEN[P.sc].titrant + " (" + P.cb.toFixed(3) + " M) added to " + P.va.toFixed(0) + " mL in the flask.");
    });

    $("btn-1").addEventListener("click", function () { addVolume(1, true); });
    $("btn-01").addEventListener("click", function () { addVolume(0.1, true); });
    $("btn-drop").addEventListener("click", function () { addVolume(DROP, true); });
    $("btn-run").addEventListener("click", function () {
      if (S.run) { setRun(false); recordPoint(true); }
      else if (S.Vb < VMAX) setRun(true);
    });
    $("btn-undo").addEventListener("click", undo);
    $("btn-restart").addEventListener("click", restart);

    var onResize = function () { fitCanvas(cv); fitCanvas(gc); drawGraph(); };
    if (window.ResizeObserver) { new ResizeObserver(onResize).observe(cv); new ResizeObserver(onResize).observe(gc); }
    else window.addEventListener("resize", onResize);
    onResize();
  }

  function init() {
    syncUI();
    restart();                                                 // creates the first point before anything draws
    bind();
    requestAnimationFrame(frame);
  }
  init();
})();

/**
 * Cell Diffusion and Osmosis – OOPA Virtual Labs / Biology
 *
 * Two experiments share one page.
 *
 * DIFFUSION  – a tank divided by a membrane. Each particle moves in straight runs with
 *   random changes of direction (speed ~ sqrt of absolute temperature). When a particle
 *   reaches the membrane it crosses with probability  openness x sizeFactor,  otherwise it
 *   bounces back. Net movement from the crowded side to the sparse side is therefore an
 *   outcome of the random motion, not something programmed in.
 *
 * OSMOSIS    – one cell in a solution. The cell holds a fixed amount of solute, so its
 *   inside concentration is  c_in = 300 / V  (V = volume relative to normal). Water flows
 *   at a rate proportional to the difference in concentration:
 *        dV/dt = k * aquaporins * (c_in - c_out - turgor) / 300
 *   Animal cell: turgor = 0, and it bursts at V >= 1.6.
 *   Plant cell : the wall pushes back, turgor = 2000 * max(0, V - 1), so it cannot burst.
 *   The dots are an illustration: inside dots keep a fixed count (so they crowd together
 *   as the cell shrinks), outside dots follow the chosen concentration.
 *
 * Units for osmosis: concentrations in mOsm/L, volume relative to normal (1 = 100 %).
 */
(function () {
  "use strict";

  // ---------------------------------------------------------------- constants
  var WORLD_W = 480, WORLD_H = 300;                         // drawing space, scaled to the canvas

  var TANK = { x0: 20, x1: 460, y0: 30, y1: 270 }, XM = 240; // diffusion tank and membrane position
  var SLOT = 20, D_SPEED = 60;                              // membrane pore slot height; speed at 20 C
  var SOLUTES = {
    oxygen:  { r: 3,   f: 1,   col: "#7fd1a8", label: "Oxygen (small)",   note: "Small enough to pass through the pores." },
    glucose: { r: 4.5, f: 0.5, col: "#f0b34a", label: "Glucose (medium)", note: "Medium size: passes through only half as easily as oxygen." },
    starch:  { r: 7,   f: 0,   col: "#c07be0", label: "Starch (large)",   note: "Too large to pass through the pores, however open the membrane is." }
  };

  var BK = { x0: 10, x1: 470, y0: 10, y1: 290 };            // osmosis beaker
  var CELL = { cx: 240, cy: 150, R0: 80, PH0: 70, WALL: 8 };// animal radius, plant protoplast half-size, wall thickness
  var C_IN0 = 300, N_IN = 40, LYSE_V = 1.6, MIN_V = 0.3;
  var PLANT_E = 2000, K_BASE = 0.08;                        // wall stiffness (mOsm per unit volume); water flow rate
  var O_SPEED = 45, OPR = 3.2, MAX_OUT = 700;               // dot speed, dot radius, cap on outside dots

  var LABELS = {
    diffusion: ["Left half", "Right half", "Net movement", "Crossings → per second", "Crossings ← per second", "State"],
    osmosis:   ["Inside the cell", "Outside", "Outside solution is", "Cell volume", "Water movement", "Cell state"]
  };
  var EXP_DESC = {
    diffusion: "Diffusion: particles spread from where they are crowded to where they are scarce, until they are evenly spread. The membrane decides which particles can cross.",
    osmosis: "Osmosis: water crosses the cell membrane toward the side with more dissolved solute. Change the solution around the cell and watch how the cell responds."
  };
  var CAPS = {
    diffusion: "Particles on each side over time. The dashed line is an even split. The lines meet and then wobble around it: particles keep crossing both ways.",
    osmosis: "Cell volume over time. The dashed green line is the volume the cell is heading for. The red dotted line is the size at which an animal cell bursts."
  };

  var $ = function (id) { return document.getElementById(id); };
  var cv = $("bio"), ctx = cv.getContext("2d");
  var gc = $("graph"), gx = gc.getContext("2d");
  var dpr = 1;

  var P = { solute: "oxygen", nl: 100, nr: 0, temp: 20, perm: 50, type: "animal", cout: 100, aqp: 1 };
  var S = { mode: "diffusion", paused: false, t: 0, nextSample: 0, hist: { t: [], a: [] }, last: 0, statT: 0,
            msg: null, water: [], spawnIn: 0, spawnOut: 0 };
  var D = null, O = null;

  // ---------------------------------------------------------------- helpers
  function setText(id, t) { $(id).textContent = t; }
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function rnd(a, b) { return a + Math.random() * (b - a); }
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
  function setStatus(msg) { if (msg !== S.msg) { S.msg = msg; setText("bio-status", msg); } }
  function mkParticle(x, y) { var a = rnd(0, 6.2832); return { x: x, y: y, ux: Math.cos(a), uy: Math.sin(a) }; }

  function resetClock() {
    S.t = 0; S.nextSample = 0; S.hist = { t: [], a: [] };
    S.water = []; S.spawnIn = 0; S.spawnOut = 0;
  }

  // ================================================================ DIFFUSION
  function dNew(left) {
    var r = SOLUTES[P.solute].r;
    return mkParticle(left ? rnd(TANK.x0 + r, XM - r) : rnd(XM + r, TANK.x1 - r), rnd(TANK.y0 + r, TANK.y1 - r));
  }
  function dInit() {
    var parts = [], i;
    for (i = 0; i < P.nl; i++) parts.push(dNew(true));
    for (i = 0; i < P.nr; i++) parts.push(dNew(false));
    D = { parts: parts, N: parts.length, lr: 0, rl: 0, win: 0, rateLR: 0, rateRL: 0 };
    resetClock();
  }
  function dCountLeft() {
    var n = 0, i;
    for (i = 0; i < D.parts.length; i++) if (D.parts[i].x < XM) n++;
    return n;
  }
  function dStep(dt) {
    var sol = SOLUTES[P.solute], r = sol.r;
    var v = D_SPEED * Math.sqrt((P.temp + 273.15) / 293.15);
    var pCross = (P.perm / 100) * sol.f, pTurn = Math.min(1, 2 * dt);
    var i, q, nx, ny, a;
    for (i = 0; i < D.parts.length; i++) {
      q = D.parts[i];
      if (Math.random() < pTurn) { a = rnd(0, 6.2832); q.ux = Math.cos(a); q.uy = Math.sin(a); }
      nx = q.x + q.ux * v * dt; ny = q.y + q.uy * v * dt;
      if (ny < TANK.y0 + r) { ny = 2 * (TANK.y0 + r) - ny; q.uy = Math.abs(q.uy); }
      else if (ny > TANK.y1 - r) { ny = 2 * (TANK.y1 - r) - ny; q.uy = -Math.abs(q.uy); }
      if (nx < TANK.x0 + r) { nx = 2 * (TANK.x0 + r) - nx; q.ux = Math.abs(q.ux); }
      else if (nx > TANK.x1 - r) { nx = 2 * (TANK.x1 - r) - nx; q.ux = -Math.abs(q.ux); }
      if ((q.x < XM) !== (nx < XM)) {                       // reached the membrane
        if (Math.random() < pCross) { if (q.x < XM) D.lr++; else D.rl++; }
        else { nx = 2 * XM - nx; q.ux = -q.ux; }
      }
      q.x = nx; q.y = ny;
    }
    D.win += dt;
    if (D.win >= 0.5) {                                     // smoothed crossings per second, each way
      D.rateLR = D.rateLR * 0.6 + (D.lr / D.win) * 0.4;
      D.rateRL = D.rateRL * 0.6 + (D.rl / D.win) * 0.4;
      D.lr = 0; D.rl = 0; D.win = 0;
    }
  }

  // ================================================================ OSMOSIS
  function cellArea() { return P.type === "plant" ? 4 * CELL.PH0 * CELL.PH0 : Math.PI * CELL.R0 * CELL.R0; }

  function insideForbidden(x, y, pad) {                     // is a point inside the protoplast (plus pad)?
    var dx = x - CELL.cx, dy = y - CELL.cy, s;
    if (P.type === "plant") { s = CELL.PH0 * Math.sqrt(O.V) + pad; return Math.abs(dx) < s && Math.abs(dy) < s; }
    s = CELL.R0 * Math.sqrt(O.V) + pad; return dx * dx + dy * dy < s * s;
  }
  function randInCell(V) {
    var h, R, x = 0, y = 0, k;
    if (P.type === "plant") {
      h = CELL.PH0 * Math.sqrt(V) - OPR;
      return { x: CELL.cx + rnd(-h, h), y: CELL.cy + rnd(-h, h) };
    }
    R = CELL.R0 * Math.sqrt(V) - OPR;
    for (k = 0; k < 30; k++) { x = rnd(-R, R); y = rnd(-R, R); if (x * x + y * y <= R * R) break; }
    if (x * x + y * y > R * R) { x = 0; y = 0; }
    return { x: CELL.cx + x, y: CELL.cy + y };
  }
  function randOutside() {
    var k, x = BK.x0 + OPR, y = BK.y0 + OPR;
    for (k = 0; k < 30; k++) {
      x = rnd(BK.x0 + OPR, BK.x1 - OPR); y = rnd(BK.y0 + OPR, BK.y1 - OPR);
      if (O.burst || !insideForbidden(x, y, OPR)) break;
    }
    return mkParticle(x, y);
  }
  function outTarget() {                                    // same dot density as inside when outside = 300 mOsm/L
    var aOut = (BK.x1 - BK.x0) * (BK.y1 - BK.y0) - cellArea();
    return Math.min(MAX_OUT, Math.round(N_IN / cellArea() * aOut * P.cout / C_IN0));
  }
  function syncOut() {
    if (O.burst) return;
    var want = outTarget();
    while (O.out.length < want) O.out.push(randOutside());
    if (O.out.length > want) O.out.length = want;
  }
  function oInit() {
    var i, pt;
    O = { V: 1, burst: false, rate: 0, inn: [], out: [] };
    for (i = 0; i < N_IN; i++) { pt = randInCell(1); O.inn.push(mkParticle(pt.x, pt.y)); }
    syncOut();
    resetClock();
  }

  function vEq() {                                          // volume the cell is heading for (null = bursts)
    var v, lo, hi, mid, i;
    if (P.type === "animal") {
      if (P.cout <= 0) return null;
      v = C_IN0 / P.cout;
      return v >= LYSE_V ? null : Math.max(MIN_V, v);
    }
    lo = MIN_V; hi = 3;
    for (i = 0; i < 60; i++) {
      mid = (lo + hi) / 2;
      if (C_IN0 / mid - P.cout - PLANT_E * Math.max(0, mid - 1) > 0) lo = mid; else hi = mid;
    }
    return (lo + hi) / 2;
  }

  function oStep(h) {
    var i, q, dx, dy, d, nx, ny, dot, lim, s, w, j, cin, turgor, dV, net;

    if (!O.burst) {
      cin = C_IN0 / O.V;
      turgor = P.type === "plant" ? PLANT_E * Math.max(0, O.V - 1) : 0;
      dV = K_BASE * P.aqp * (cin - P.cout - turgor) / C_IN0 * h;
      O.V = clamp(O.V + dV, MIN_V, 3);
      O.rate = dV / h;
      if (P.type === "animal" && O.V >= LYSE_V) {           // the cell bursts: its contents spill out
        O.burst = true; O.rate = 0;
        O.out = O.out.concat(O.inn); O.inn = []; S.water = [];
      }
    }

    if (!O.burst) {                                         // water molecules crossing the membrane (illustration)
      net = clamp(Math.abs(O.rate) * 500, 0, 40);
      S.spawnIn += (5 + (O.rate > 0 ? net : 0)) * h;
      S.spawnOut += (5 + (O.rate < 0 ? net : 0)) * h;
      while (S.spawnIn >= 1) { S.spawnIn -= 1; if (S.water.length < 150) S.water.push({ a: rnd(0, 6.2832), s: 0, dir: 1 }); }
      while (S.spawnOut >= 1) { S.spawnOut -= 1; if (S.water.length < 150) S.water.push({ a: rnd(0, 6.2832), s: 0, dir: -1 }); }
    }
    j = 0;
    for (i = 0; i < S.water.length; i++) { w = S.water[i]; w.s += h / 0.7; if (w.s < 1) S.water[j++] = w; }
    S.water.length = j;

    // dots inside the cell
    for (i = 0; i < O.inn.length; i++) {
      q = O.inn[i];
      if (Math.random() < Math.min(1, 2 * h)) { d = rnd(0, 6.2832); q.ux = Math.cos(d); q.uy = Math.sin(d); }
      q.x += q.ux * O_SPEED * h; q.y += q.uy * O_SPEED * h;
      if (P.type === "plant") {
        lim = CELL.PH0 * Math.sqrt(O.V) - OPR;
        if (q.x - CELL.cx > lim) { q.x = CELL.cx + lim; q.ux = -Math.abs(q.ux); }
        else if (q.x - CELL.cx < -lim) { q.x = CELL.cx - lim; q.ux = Math.abs(q.ux); }
        if (q.y - CELL.cy > lim) { q.y = CELL.cy + lim; q.uy = -Math.abs(q.uy); }
        else if (q.y - CELL.cy < -lim) { q.y = CELL.cy - lim; q.uy = Math.abs(q.uy); }
      } else {
        dx = q.x - CELL.cx; dy = q.y - CELL.cy; d = Math.sqrt(dx * dx + dy * dy);
        lim = CELL.R0 * Math.sqrt(O.V) - OPR;
        if (d > lim && d > 0) {
          nx = dx / d; ny = dy / d;
          q.x = CELL.cx + nx * lim; q.y = CELL.cy + ny * lim;
          dot = q.ux * nx + q.uy * ny;
          if (dot > 0) { q.ux -= 2 * dot * nx; q.uy -= 2 * dot * ny; }
        }
      }
    }

    // dots outside (and, after a burst, the spilled contents)
    for (i = 0; i < O.out.length; i++) {
      q = O.out[i];
      if (Math.random() < Math.min(1, 2 * h)) { d = rnd(0, 6.2832); q.ux = Math.cos(d); q.uy = Math.sin(d); }
      q.x += q.ux * O_SPEED * h; q.y += q.uy * O_SPEED * h;
      if (q.x < BK.x0 + OPR) { q.x = 2 * (BK.x0 + OPR) - q.x; q.ux = Math.abs(q.ux); }
      else if (q.x > BK.x1 - OPR) { q.x = 2 * (BK.x1 - OPR) - q.x; q.ux = -Math.abs(q.ux); }
      if (q.y < BK.y0 + OPR) { q.y = 2 * (BK.y0 + OPR) - q.y; q.uy = Math.abs(q.uy); }
      else if (q.y > BK.y1 - OPR) { q.y = 2 * (BK.y1 - OPR) - q.y; q.uy = -Math.abs(q.uy); }
      if (!O.burst && insideForbidden(q.x, q.y, OPR)) {     // keep outside dots out of the cell
        dx = q.x - CELL.cx; dy = q.y - CELL.cy;
        if (P.type === "plant") {
          s = CELL.PH0 * Math.sqrt(O.V) + OPR;
          if (Math.abs(dx) >= Math.abs(dy)) { q.x = CELL.cx + (dx >= 0 ? s : -s); q.ux = dx >= 0 ? Math.abs(q.ux) : -Math.abs(q.ux); }
          else { q.y = CELL.cy + (dy >= 0 ? s : -s); q.uy = dy >= 0 ? Math.abs(q.uy) : -Math.abs(q.uy); }
        } else {
          d = Math.sqrt(dx * dx + dy * dy);
          if (d < 1e-6) { dx = 1; dy = 0; d = 1; }
          nx = dx / d; ny = dy / d; s = CELL.R0 * Math.sqrt(O.V) + OPR;
          q.x = CELL.cx + nx * s; q.y = CELL.cy + ny * s;
          dot = q.ux * nx + q.uy * ny;
          if (dot < 0) { q.ux -= 2 * dot * nx; q.uy -= 2 * dot * ny; }
        }
      }
    }
  }

  // ---------------------------------------------------------------- history, readouts
  function thin(_, i) { return i % 2 === 0; }
  function sampleHist() {
    var h = S.hist;
    h.t.push(S.t);
    h.a.push(S.mode === "diffusion" ? dCountLeft() : O.V * 100);
    if (h.t.length > 3000) { h.t = h.t.filter(thin); h.a = h.a.filter(thin); }
  }

  function updateReadouts() {
    var L, R, net, p, bal, st, msg = "", V, cin, ton;
    if (S.mode === "diffusion") {
      L = dCountLeft(); R = D.N - L; net = D.rateLR - D.rateRL;
      p = (P.perm / 100) * SOLUTES[P.solute].f;
      bal = Math.abs(L - R) <= Math.max(3, 0.06 * D.N);
      if (D.N === 0) { st = "No particles"; }
      else if (p === 0) {
        st = "Blocked";
        msg = P.solute === "starch" ? "Starch is too large to pass through the membrane." : "The membrane is closed, so nothing can cross.";
      } else if (bal) {
        st = "Dynamic equilibrium";
        msg = "Particles are still crossing both ways, but there is no net movement.";
      } else { st = "Moving toward equilibrium"; }
      setText("rv1", String(L)); setText("rv2", String(R));
      setText("rv3", net > 0.4 ? "Left → right" : net < -0.4 ? "Right → left" : "None");
      setText("rv4", D.rateLR.toFixed(1)); setText("rv5", D.rateRL.toFixed(1));
      setText("rv6", st);
    } else {
      V = O.V; cin = C_IN0 / V;
      ton = P.cout < C_IN0 - 10 ? "Hypotonic" : P.cout > C_IN0 + 10 ? "Hypertonic" : "Isotonic";
      if (P.type === "animal") {
        st = O.burst ? "Burst (lysed)" : V > 1.15 ? "Swollen" : V < 0.85 ? "Shrunken (crenated)" : "Normal";
        if (O.burst) msg = "The cell burst: too much water flowed in.";
        else if (V < 0.85) msg = "Water left the cell, so it shrank and its surface crinkled.";
      } else {
        st = V > 1.03 ? "Turgid (firm)" : V > 0.95 ? "Flaccid (limp)" : "Plasmolysed";
        if (V <= 0.95) msg = "The cell membrane has pulled away from the cell wall.";
        else if (V > 1.03) msg = "The cell wall stops the cell swelling further, so it stays firm.";
      }
      setText("rv1", O.burst ? "–" : Math.round(cin) + " mOsm/L");
      setText("rv2", P.cout + " mOsm/L");
      setText("rv3", ton);
      setText("rv4", O.burst ? "Burst" : Math.round(V * 100) + "% of normal");
      setText("rv5", O.burst ? "–" : O.rate > 0.003 ? "Into the cell" : O.rate < -0.003 ? "Out of the cell" : "Balanced");
      setText("rv6", st);
    }
    setStatus(msg);
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

  // ---------------------------------------------------------------- drawing: diffusion
  function drawDiffusion() {
    var sol = SOLUTES[P.solute], i, q, k, y, gap = 16 * (P.perm / 100), solid = (SLOT - gap) / 2, w = TANK.x1 - TANK.x0, h = TANK.y1 - TANK.y0;
    ctx.fillStyle = "#1b2230"; ctx.fillRect(TANK.x0, TANK.y0, w, h);

    ctx.fillStyle = sol.col;
    for (i = 0; i < D.parts.length; i++) {
      q = D.parts[i];
      ctx.beginPath(); ctx.arc(q.x, q.y, sol.r, 0, 6.2832); ctx.fill();
    }

    ctx.fillStyle = "#d9d9d9";                              // membrane: pore size follows the openness slider
    for (k = 0; k < h / SLOT; k++) {
      y = TANK.y0 + k * SLOT;
      ctx.fillRect(XM - 3, y, 6, solid);
      ctx.fillRect(XM - 3, y + SLOT - solid, 6, solid);
    }

    ctx.strokeStyle = "#cfcfcf"; ctx.lineWidth = 3; ctx.strokeRect(TANK.x0, TANK.y0, w, h);

    ctx.font = "13px 'DM Sans', Arial, sans-serif"; ctx.fillStyle = "#9a9a9a"; ctx.textAlign = "center";
    ctx.fillText("Left", (TANK.x0 + XM) / 2, TANK.y0 - 10);
    ctx.fillText("Right", (XM + TANK.x1) / 2, TANK.y0 - 10);
    ctx.textAlign = "left"; ctx.fillStyle = sol.col;
    ctx.beginPath(); ctx.arc(TANK.x0 + 5, 288, 4, 0, 6.2832); ctx.fill();
    ctx.fillStyle = "#cfcfcf"; ctx.fillText(sol.label, TANK.x0 + 16, 292);
  }

  // ---------------------------------------------------------------- drawing: osmosis
  function drawCell() {
    var cx = CELL.cx, cy = CELL.cy, V = O.V, i, th, R, rr, amp, hh, hw, vac;
    if (P.type === "animal") {
      if (O.burst) {                                        // broken ring of membrane fragments
        ctx.strokeStyle = "rgba(232,160,160,0.7)"; ctx.lineWidth = 3;
        for (i = 0; i < 6; i++) { ctx.beginPath(); ctx.arc(cx, cy, CELL.R0 * 1.45, i * 1.0472 + 0.1, i * 1.0472 + 0.75); ctx.stroke(); }
        return;
      }
      R = CELL.R0 * Math.sqrt(V);
      amp = clamp((0.85 - V) / 0.4, 0, 1) * 0.10 * R;       // crinkled outline when the cell has shrunk
      ctx.beginPath();
      for (i = 0; i <= 120; i++) {
        th = i / 120 * 6.2832; rr = R + amp * Math.sin(14 * th);
        if (i) ctx.lineTo(cx + Math.cos(th) * rr, cy + Math.sin(th) * rr); else ctx.moveTo(cx + Math.cos(th) * rr, cy + Math.sin(th) * rr);
      }
      ctx.closePath(); ctx.fillStyle = "rgba(240,150,150,0.22)"; ctx.fill();
      ctx.strokeStyle = "#e8a0a0"; ctx.lineWidth = 3; ctx.stroke();
      ctx.fillStyle = "rgba(180,90,140,0.55)"; ctx.beginPath(); ctx.arc(cx, cy, 13 * Math.sqrt(V), 0, 6.2832); ctx.fill();
    } else {
      hh = CELL.PH0 * Math.sqrt(V);                         // protoplast half-size
      hw = CELL.PH0 * Math.max(1, Math.sqrt(V));            // wall inner half-size (it stretches a little when turgid)
      ctx.lineJoin = "round"; ctx.strokeStyle = "#5d9b4a"; ctx.lineWidth = CELL.WALL;
      rrect(cx - hw - CELL.WALL / 2, cy - hw - CELL.WALL / 2, 2 * hw + CELL.WALL, 2 * hw + CELL.WALL, 10); ctx.stroke();
      rrect(cx - hh, cy - hh, 2 * hh, 2 * hh, 8);
      ctx.fillStyle = "rgba(130,200,120,0.22)"; ctx.fill();
      ctx.strokeStyle = "#9ad18b"; ctx.lineWidth = 2.5; ctx.stroke();
      vac = hh * 0.55;
      rrect(cx - vac, cy - vac, 2 * vac, 2 * vac, 10); ctx.fillStyle = "rgba(120,170,230,0.22)"; ctx.fill();
      ctx.fillStyle = "rgba(180,90,140,0.55)"; ctx.beginPath(); ctx.arc(cx - hh * 0.72, cy - hh * 0.72, 8, 0, 6.2832); ctx.fill();
    }
  }
  function drawWater() {
    if (O.burst) return;
    var i, w, bd, d, c, sn, h = CELL.PH0 * Math.sqrt(O.V), R = CELL.R0 * Math.sqrt(O.V);
    ctx.fillStyle = "#6ec3ff";
    for (i = 0; i < S.water.length; i++) {
      w = S.water[i]; c = Math.cos(w.a); sn = Math.sin(w.a);
      bd = P.type === "plant" ? h / Math.max(Math.abs(c), Math.abs(sn), 1e-6) : R;   // distance from centre to the membrane
      d = w.dir > 0 ? bd + 22 * (1 - 2 * w.s) : bd - 22 * (1 - 2 * w.s);             // inward: outside -> inside
      ctx.beginPath(); ctx.arc(CELL.cx + c * d, CELL.cy + sn * d, 2.6, 0, 6.2832); ctx.fill();
    }
  }
  function drawOsmosis() {
    var i, q;
    ctx.fillStyle = "rgba(70,130,200,0.16)"; ctx.fillRect(BK.x0, BK.y0, BK.x1 - BK.x0, BK.y1 - BK.y0);
    ctx.strokeStyle = "#cfcfcf"; ctx.lineWidth = 3; ctx.strokeRect(BK.x0, BK.y0, BK.x1 - BK.x0, BK.y1 - BK.y0);

    ctx.fillStyle = "rgba(242,242,242,0.85)";
    for (i = 0; i < O.out.length; i++) { q = O.out[i]; ctx.beginPath(); ctx.arc(q.x, q.y, 2.4, 0, 6.2832); ctx.fill(); }
    drawCell();
    ctx.fillStyle = "rgba(255,230,160,0.95)";               // the cell's own solute, a warmer colour
    for (i = 0; i < O.inn.length; i++) { q = O.inn[i]; ctx.beginPath(); ctx.arc(q.x, q.y, 2.4, 0, 6.2832); ctx.fill(); }
    drawWater();

    ctx.font = "13px 'DM Sans', Arial, sans-serif"; ctx.textAlign = "left"; ctx.fillStyle = "#cfd8e3";
    ctx.fillText("Outside: " + P.cout + " mOsm/L", BK.x0 + 10, BK.y0 + 22);
    ctx.fillText("Inside: " + (O.burst ? "–" : Math.round(C_IN0 / O.V) + " mOsm/L"), BK.x0 + 10, BK.y0 + 40);
    ctx.fillStyle = "#6ec3ff"; ctx.fillText("● water", BK.x1 - 70, BK.y1 - 12);
  }

  function draw() {
    var W = cv.clientWidth, H = cv.clientHeight;
    if (!W || !H) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = "#161616"; ctx.fillRect(0, 0, W, H);
    var sc = Math.min(W / WORLD_W, H / WORLD_H);
    ctx.setTransform(dpr * sc, 0, 0, dpr * sc, dpr * (W - WORLD_W * sc) / 2, dpr * (H - WORLD_H * sc) / 2);
    ctx.lineCap = "round";
    if (S.mode === "diffusion") drawDiffusion(); else drawOsmosis();
  }

  // ---------------------------------------------------------------- drawing: graph
  function drawGraph() {
    var W = gc.clientWidth, H = gc.clientHeight;
    if (!W || !H) return;
    gx.setTransform(dpr, 0, 0, dpr, 0, 0); gx.clearRect(0, 0, W, H);
    var pad = { l: 52, r: 14, t: 14, b: 40 }, pw = W - pad.l - pad.r, ph = H - pad.t - pad.b;
    if (pw < 30 || ph < 30) return;

    var hs = S.hist, n = hs.t.length, tmax = Math.max(30, niceCeil(Math.max(S.t, 1)));
    var diff = S.mode === "diffusion", ymax, ylab, ve, t;
    if ((diff && !D) || (!diff && !O)) return;
    if (diff) { ymax = niceCeil(Math.max(10, P.nl, P.nr) * 1.1); ylab = "Particles in each half"; }
    else { ymax = 200; ylab = "Cell volume (% of normal)"; }
    var X = function (v) { return pad.l + v / tmax * pw; }, Y = function (v) { return pad.t + ph - v / ymax * ph; };
    var sx = niceStep(tmax), sy = niceStep(ymax);

    gx.font = "11px 'DM Sans', Arial, sans-serif"; gx.lineWidth = 1; gx.strokeStyle = "#ece8e6"; gx.fillStyle = "#777"; gx.textAlign = "center";
    for (t = 0; t <= tmax + 1e-9; t += sx) {
      gx.beginPath(); gx.moveTo(X(t), pad.t); gx.lineTo(X(t), pad.t + ph); gx.stroke();
      gx.fillText(tick(t), X(t), pad.t + ph + 15);
    }
    gx.textAlign = "right";
    for (t = 0; t <= ymax + 1e-9; t += sy) {
      gx.beginPath(); gx.moveTo(pad.l, Y(t)); gx.lineTo(pad.l + pw, Y(t)); gx.stroke();
      gx.fillText(tick(t), pad.l - 7, Y(t) + 4);
    }
    gx.strokeStyle = "#999"; gx.lineWidth = 1.5;
    gx.beginPath(); gx.moveTo(pad.l, pad.t); gx.lineTo(pad.l, pad.t + ph); gx.lineTo(pad.l + pw, pad.t + ph); gx.stroke();
    gx.fillStyle = "#555"; gx.textAlign = "center";
    gx.fillText("Time (s)", pad.l + pw / 2, H - 6);
    gx.save(); gx.translate(13, pad.t + ph / 2); gx.rotate(-Math.PI / 2); gx.fillText(ylab, 0, 0); gx.restore();

    var line = function (arr, col, wd) {
      var k;
      if (n < 2) return;
      gx.strokeStyle = col; gx.lineWidth = wd; gx.beginPath();
      for (k = 0; k < n; k++) { if (k) gx.lineTo(X(hs.t[k]), Y(arr[k])); else gx.moveTo(X(hs.t[k]), Y(arr[k])); }
      gx.stroke();
    };
    var hline = function (v, col, dash, label) {
      gx.setLineDash(dash); gx.strokeStyle = col; gx.lineWidth = 1.5;
      gx.beginPath(); gx.moveTo(pad.l, Y(v)); gx.lineTo(pad.l + pw, Y(v)); gx.stroke(); gx.setLineDash([]);
      if (label) { gx.fillStyle = col; gx.textAlign = "right"; gx.fillText(label, pad.l + pw - 4, Y(v) - 5); }
    };

    gx.save(); gx.beginPath(); gx.rect(pad.l, pad.t, pw, ph); gx.clip();
    if (diff) {
      var right = [], k;
      for (k = 0; k < n; k++) right.push(D.N - hs.a[k]);
      if (D.N > 0) hline(D.N / 2, "#aaa", [5, 4], "");
      line(hs.a, "#b22222", 2.5); line(right, "#4a78b5", 2.5);
    } else {
      hline(100, "#aaa", [5, 4], "Normal");
      if (P.type === "animal") hline(LYSE_V * 100, "#e14a4a", [2, 3], "Bursts");
      ve = vEq();
      if (ve !== null) hline(ve * 100, "#3d8b3d", [7, 4], "Heading for " + Math.round(ve * 100) + "%");
      line(hs.a, "#b22222", 2.5);
    }
    gx.restore();

    if (diff) {                                             // legend
      gx.textAlign = "left"; gx.fillStyle = "#b22222"; gx.fillRect(pad.l + 10, pad.t + 8, 12, 4); gx.fillText("Left", pad.l + 27, pad.t + 13);
      gx.fillStyle = "#4a78b5"; gx.fillRect(pad.l + 70, pad.t + 8, 12, 4); gx.fillText("Right", pad.l + 87, pad.t + 13);
    } else if (ve === null) {
      gx.textAlign = "right"; gx.fillStyle = "#e14a4a"; gx.fillText("This cell will burst", pad.l + pw - 6, pad.t + ph - 8);
    }
  }

  // ---------------------------------------------------------------- main loop
  function step(h) {
    if (S.mode === "diffusion") dStep(h); else oStep(h);
    S.t += h;
    if (S.t >= S.nextSample) { S.nextSample = S.t + (S.mode === "diffusion" ? 0.25 : 0.2); sampleHist(); }
  }

  function frame(ts) {
    if (!S.last) S.last = ts;
    var dt = Math.min(0.05, (ts - S.last) / 1000), sim, n, h, i;
    S.last = ts;
    if (S.mode === "osmosis") syncOut();
    if (!S.paused) {
      sim = dt * parseFloat($("timescale").value);
      if (sim > 0) {
        n = Math.max(1, Math.ceil(sim / (1 / 90))); h = sim / n;
        for (i = 0; i < n; i++) step(h);
      }
    }
    draw();
    S.statT += dt;
    if (S.statT > 0.1) { S.statT = 0; updateReadouts(); drawGraph(); }
    requestAnimationFrame(frame);
  }

  // ---------------------------------------------------------------- wiring
  function restart() {
    if (S.mode === "diffusion") dInit(); else oInit();
    sampleHist(); S.nextSample = S.t + 0.2;
    S.msg = null;
    updateReadouts(); drawGraph();
  }
  function setMode(m) {
    S.mode = m;
    $("grp-diff").hidden = m !== "diffusion";
    $("grp-osm").hidden = m !== "osmosis";
    LABELS[m].forEach(function (t, i) { setText("rl" + (i + 1), t); });
    setText("exp-desc", EXP_DESC[m]); setText("graph-cap", CAPS[m]);
    restart();
  }
  function syncUI() {
    $("c-nl").value = P.nl; setText("o-nl", String(P.nl));
    $("c-nr").value = P.nr; setText("o-nr", String(P.nr));
    $("c-temp").value = P.temp; setText("o-temp", P.temp + " °C");
    $("c-perm").value = P.perm; setText("o-perm", P.perm + "%");
    $("c-out").value = P.cout; setText("o-out", P.cout + " mOsm/L");
    $("c-aqp").value = P.aqp; setText("o-aqp", P.aqp.toFixed(1) + "×");
    $("sel-solute").value = P.solute; setText("sol-note", SOLUTES[P.solute].note);
  }

  function bind() {
    Array.prototype.forEach.call(document.querySelectorAll('input[name="exp"]'), function (r) {
      r.addEventListener("change", function () { if (r.checked) setMode(r.value); });
    });
    Array.prototype.forEach.call(document.querySelectorAll('input[name="ctype"]'), function (r) {
      r.addEventListener("change", function () { if (r.checked) { P.type = r.value; restart(); } });
    });
    $("sel-solute").addEventListener("change", function (e) {
      P.solute = e.target.value; setText("sol-note", SOLUTES[P.solute].note); restart();
    });
    $("c-nl").addEventListener("input", function (e) { P.nl = parseInt(e.target.value, 10); setText("o-nl", String(P.nl)); restart(); });
    $("c-nr").addEventListener("input", function (e) { P.nr = parseInt(e.target.value, 10); setText("o-nr", String(P.nr)); restart(); });
    $("c-temp").addEventListener("input", function (e) { P.temp = parseFloat(e.target.value); setText("o-temp", P.temp + " °C"); });
    $("c-perm").addEventListener("input", function (e) { P.perm = parseFloat(e.target.value); setText("o-perm", P.perm + "%"); });
    $("c-out").addEventListener("input", function (e) { P.cout = parseFloat(e.target.value); setText("o-out", P.cout + " mOsm/L"); });
    $("c-aqp").addEventListener("input", function (e) { P.aqp = parseFloat(e.target.value); setText("o-aqp", P.aqp.toFixed(1) + "×"); });
    Array.prototype.forEach.call(document.querySelectorAll("[data-out]"), function (b) {
      b.addEventListener("click", function () {
        P.cout = parseFloat(b.getAttribute("data-out"));
        $("c-out").value = P.cout; setText("o-out", P.cout + " mOsm/L");
      });
    });
    $("btn-pause").addEventListener("click", function () {
      S.paused = !S.paused;
      this.setAttribute("aria-pressed", S.paused ? "true" : "false");
      this.textContent = S.paused ? "Resume" : "Pause";
    });
    $("btn-reset").addEventListener("click", restart);

    var onResize = function () { fitCanvas(cv); fitCanvas(gc); drawGraph(); };
    if (window.ResizeObserver) { new ResizeObserver(onResize).observe(cv); new ResizeObserver(onResize).observe(gc); }
    else window.addEventListener("resize", onResize);
    onResize();
  }

  function init() {
    syncUI();
    setMode("diffusion");                                   // creates the first experiment ...
    bind();                                                 // ... before bind() triggers any drawing
    requestAnimationFrame(frame);
  }
  init();
})();

/**
 * Gas Laws – OOPA Virtual Labs / Chemistry
 *
 * One ideal gas, PV = nRT, with P in kPa, V in litres, T in kelvin, n in moles and
 * R = 8.314 J/(mol K)  (kPa x L = J, so the units agree).
 *
 * The pressure shown is always calculated from the law. The moving dots are an
 * illustration of the particles: their speed follows v_rms ~ sqrt(T), their number
 * follows n, and the container height follows V. They do not collide with each other
 * (an ideal gas), and they are not what produces the pressure reading.
 *
 * Laws: each one holds two quantities fixed (captured when the law is chosen) and lets
 * the learner change one. The fourth quantity follows from PV = nRT.
 */
(function () {
  "use strict";

  var R = 8.314;
  var VMIN = 2, VMAX = 30, TMIN = 100, TMAX = 800, NMIN = 0.1, NMAX = 3;
  var WORLD_W = 260;                       // chamber width in world units
  var UPL = 11.25;                         // world units of chamber height per litre
  var PR = 5;                              // particle radius (world units)
  var PER_MOL = 40;                        // particles drawn per mole
  var VK = 120 / Math.sqrt(300);           // v_rms = VK * sqrt(T)   (world units per second)
  var G_LO = 1, G_HI = 10000;              // gauge range in kPa (log scale)
  var DEFAULTS = { n: 1, T: 300, V: 10 };
  var MAX_ROWS = 12;

  var AXL = { V: "Volume (L)", P: "Pressure (kPa)", T: "Temperature (K)", n: "Amount of gas (mol)" };

  var LAWS = {
    free: {
      free: ["V", "T", "n"], dep: null, x: "V", y: "P",
      hold: "Nothing is held constant",
      desc: "Change the volume, temperature and amount of gas together. The pressure always follows PV = nRT.",
      cLabel: "P × V ÷ (n × T)", cUnit: "J/(mol·K)",
      cFn: function (s) { return s.P * s.V / (s.n * s.T); },
      note: "In every row this should equal the gas constant R, 8.314 J/(mol·K).",
      cap: "Pressure against volume for each recorded point. Choose a law to see its prediction."
    },
    boyle: {
      free: ["V"], dep: null, x: "V", y: "P",
      hold: "Held constant: temperature, amount of gas",
      desc: "Boyle’s law: at constant temperature and amount of gas, pressure is inversely proportional to volume. Move the piston and P × V stays the same.",
      cLabel: "P × V", cUnit: "kPa·L",
      cFn: function (s) { return s.P * s.V; },
      note: "This column should be the same in every row. That constant is Boyle’s law.",
      cap: "Pressure against volume is a curve, because P is inversely proportional to V."
    },
    charles: {
      free: ["T"], dep: "V", x: "T", y: "V",
      hold: "Held constant: pressure, amount of gas",
      desc: "Charles’s law: at constant pressure and amount of gas, volume is directly proportional to temperature in kelvin. Heat the gas and the piston rises. V ÷ T stays the same.",
      cLabel: "V ÷ T", cUnit: "L/K",
      cFn: function (s) { return s.V / s.T; },
      note: "This column should be the same in every row. That constant is Charles’s law.",
      cap: "Volume against temperature is a straight line through the origin. The dashed part lies beyond the piston’s limits and runs back toward absolute zero."
    },
    gaylussac: {
      free: ["T"], dep: null, x: "T", y: "P",
      hold: "Held constant: volume, amount of gas",
      desc: "Gay-Lussac’s law: at constant volume and amount of gas, pressure is directly proportional to temperature in kelvin. The piston is locked, and P ÷ T stays the same.",
      cLabel: "P ÷ T", cUnit: "kPa/K",
      cFn: function (s) { return s.P / s.T; },
      note: "This column should be the same in every row. That constant is Gay-Lussac’s law.",
      cap: "Pressure against temperature is a straight line through the origin."
    },
    avogadro: {
      free: ["n"], dep: "V", x: "n", y: "V",
      hold: "Held constant: pressure, temperature",
      desc: "Avogadro’s law: at constant pressure and temperature, volume is directly proportional to the amount of gas. Add gas and the piston rises. V ÷ n stays the same.",
      cLabel: "V ÷ n", cUnit: "L/mol",
      cFn: function (s) { return s.V / s.n; },
      note: "This column should be the same in every row. That constant is Avogadro’s law.",
      cap: "Volume against amount of gas is a straight line through the origin."
    }
  };

  var FMT = {
    V: function (v) { return v.toFixed(1) + " L"; },
    T: function (v) { return Math.round(v) + " K"; },
    n: function (v) { return v.toFixed(2) + " mol"; }
  };

  var $ = function (id) { return document.getElementById(id); };
  var cv = $("chamber"), ctx = cv.getContext("2d");
  var gc = $("graph"), gx = gc.getContext("2d");
  var dpr = 1;

  var S = {
    law: "boyle", n: DEFAULTS.n, T: DEFAULTS.T, V: DEFAULTS.V, P: 0,
    base: null,                              // snapshot taken when a law is chosen
    Vd: DEFAULTS.V, Pd: 0, Tp: DEFAULTS.T,   // eased volume / pressure for drawing; T the particles represent
    parts: [], hits: 0, hitWin: 0, hitShow: 0,
    paused: false, data: [], last: 0, statT: 0
  };

  // ---------------------------------------------------------------- helpers
  function setText(id, t) { $(id).textContent = t; }
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function sig(v, d) { return String(+v.toPrecision(d)); }
  function fmtP(p) { return p >= 1000 ? p.toFixed(0) : p >= 10 ? p.toFixed(1) : p.toFixed(2); }
  function tick(t) { return String(+t.toPrecision(6)); }
  function gauss() { return Math.sqrt(-2 * Math.log(1 - Math.random())) * Math.cos(2 * Math.PI * Math.random()); }
  function niceStep(span) {
    var raw = span / 6, p = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10)), f = raw / p;
    return (f < 1.5 ? 1 : f < 3.5 ? 2 : f < 7.5 ? 5 : 10) * p;
  }
  function niceCeil(v) {
    var p = Math.pow(10, Math.floor(Math.log(v) / Math.LN10)), f = v / p, steps = [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10];
    for (var i = 0; i < steps.length; i++) if (f <= steps[i] + 1e-9) return steps[i] * p;
    return 10 * p;
  }

  function recompute() { S.P = R * S.n * S.T / S.V; }
  function snapshot() { S.base = { n: S.n, T: S.T, V: S.V, P: S.P }; }
  function setMsg(t) { setText("gl-status", t || ""); }

  // ---------------------------------------------------------------- controls and laws
  function onControl(key, val) {
    var b = S.base, msg = "", v;
    if (S.law === "free") {
      S[key] = val;
    } else if (S.law === "boyle") {
      if (key === "V") S.V = val;
    } else if (S.law === "gaylussac") {
      if (key === "T") S.T = val;
    } else if (S.law === "charles") {
      if (key === "T") {                                   // constant pressure: V = nRT / P
        v = S.n * R * val / b.P;
        if (v < VMIN) { v = VMIN; val = v * b.P / (S.n * R); msg = "The piston is at its lowest position."; }
        else if (v > VMAX) { v = VMAX; val = v * b.P / (S.n * R); msg = "The piston is at its highest position."; }
        S.T = val; S.V = v;
      }
    } else if (S.law === "avogadro") {
      if (key === "n") {                                   // constant pressure and temperature: V = nRT / P
        v = val * R * S.T / b.P;
        if (v < VMIN) { v = VMIN; val = v * b.P / (R * S.T); msg = "The piston is at its lowest position."; }
        else if (v > VMAX) { v = VMAX; val = v * b.P / (R * S.T); msg = "The piston is at its highest position."; }
        S.n = val; S.V = v;
      }
    }
    recompute(); setMsg(msg); syncControls();
  }

  function syncControls() {
    var L = LAWS[S.law];
    ["V", "T", "n"].forEach(function (k) {
      var el = $("c-" + k), isFree = L.free.indexOf(k) >= 0, h = $("h-" + k);
      el.value = S[k]; el.disabled = !isFree;
      setText("o-" + k, FMT[k](S[k]));
      if (isFree) { h.textContent = "You control this"; h.className = "hint free"; }
      else if (L.dep === k) { h.textContent = "Set by the law"; h.className = "hint"; }
      else { h.textContent = "Held constant"; h.className = "hint"; }
    });
  }

  function setLaw(name) {
    S.law = name; snapshot(); S.data = [];
    var L = LAWS[name];
    setText("law-desc", L.desc); setText("hold-note", L.hold); setText("graph-cap", L.cap);
    setText("law-const-label", L.cLabel); setText("data-const-head", L.cLabel + " (" + L.cUnit + ")");
    setText("table-note", L.note);
    setMsg(""); syncControls(); renderTable(); updateReadouts(); drawGraph();
  }

  function resetAll() {
    S.n = DEFAULTS.n; S.T = DEFAULTS.T; S.V = DEFAULTS.V; recompute();
    S.Vd = S.V; S.Pd = S.P;
    setLaw(S.law);                                         // re-snapshot, clear data, refresh texts
  }

  // ---------------------------------------------------------------- data table
  function record() {
    if (S.data.length >= MAX_ROWS) S.data.shift();
    S.data.push({ V: S.V, P: S.P, T: S.T, n: S.n });
    renderTable(); drawGraph();
  }
  function addCell(tr, text, cls) {
    var td = document.createElement("td"); td.textContent = text; if (cls) td.className = cls; tr.appendChild(td); return td;
  }
  function renderTable() {
    var tb = $("data-body"), L = LAWS[S.law], tr, td;
    while (tb.firstChild) tb.removeChild(tb.firstChild);
    if (!S.data.length) {
      tr = document.createElement("tr"); td = addCell(tr, "No data yet. Press Record data point.", "empty"); td.colSpan = 5; tb.appendChild(tr); return;
    }
    S.data.forEach(function (r) {
      tr = document.createElement("tr");
      addCell(tr, r.V.toFixed(2)); addCell(tr, fmtP(r.P)); addCell(tr, r.T.toFixed(0)); addCell(tr, r.n.toFixed(2));
      addCell(tr, sig(L.cFn(r), 4));
      tb.appendChild(tr);
    });
  }

  // ---------------------------------------------------------------- readouts
  function updateReadouts() {
    var L = LAWS[S.law];
    setText("s-P", fmtP(S.P) + " kPa"); setText("s-Patm", (S.P / 101.325).toFixed(2) + " atm");
    setText("s-V", S.V.toFixed(1) + " L");
    setText("s-T", Math.round(S.T) + " K (" + Math.round(S.T - 273.15) + " °C)");
    setText("s-n", S.n.toFixed(2) + " mol"); setText("s-N", S.parts.length + " particles drawn");
    setText("s-hits", String(Math.round(S.hitShow)));
    setText("law-const", sig(L.cFn(S), 4) + " " + L.cUnit);
  }

  // ---------------------------------------------------------------- particles (illustration)
  function newParticle(hh) {
    var sigma = VK * Math.sqrt(S.Tp) / Math.SQRT2;
    return { x: PR + Math.random() * (WORLD_W - 2 * PR), y: PR + Math.random() * Math.max(1, hh - 2 * PR),
             vx: gauss() * sigma, vy: gauss() * sigma };
  }
  function syncParticles() {
    var want = Math.max(4, Math.round(S.n * PER_MOL)), hh = S.Vd * UPL, k;
    while (S.parts.length < want) S.parts.push(newParticle(hh));
    if (S.parts.length > want) S.parts.length = want;
    if (Math.abs(S.T - S.Tp) > 1e-9) {                      // temperature changed: rescale every speed
      k = Math.sqrt(S.T / S.Tp);
      S.parts.forEach(function (p) { p.vx *= k; p.vy *= k; });
      S.Tp = S.T;
    }
  }
  function stepParticles(dt) {
    var hw = WORLD_W, hh = S.Vd * UPL, i, p, ny;
    for (i = 0; i < S.parts.length; i++) {
      p = S.parts[i];
      p.x += p.vx * dt; p.y += p.vy * dt;
      if (p.x < PR) { p.x = 2 * PR - p.x; p.vx = Math.abs(p.vx); }
      else if (p.x > hw - PR) { p.x = 2 * (hw - PR) - p.x; p.vx = -Math.abs(p.vx); }
      if (p.y < PR) { p.y = 2 * PR - p.y; p.vy = Math.abs(p.vy); }
      else if (p.y > hh - PR) {                             // the piston
        ny = 2 * (hh - PR) - p.y;
        p.y = ny >= PR ? ny : hh - PR;                      // piston dropped past it: sit just under the piston
        p.vy = -Math.abs(p.vy); S.hits++;
      }
    }
  }

  // ---------------------------------------------------------------- canvas sizing
  function fitCanvas(c) {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    var w = Math.round(c.clientWidth * dpr), h = Math.round(c.clientHeight * dpr);
    if (w && h && (c.width !== w || c.height !== h)) { c.width = w; c.height = h; }
  }

  // ---------------------------------------------------------------- chamber drawing
  function drawChamber() {
    var W = cv.clientWidth, H = cv.clientHeight;
    if (!W || !H) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = "#161616"; ctx.fillRect(0, 0, W, H);

    var m = 14, heaterH = 34, top = 34;
    var floorY = H - heaterH - m, maxH = floorY - top;
    var sc = Math.min((W * 0.40) / WORLD_W, maxH / (VMAX * UPL));
    if (!(sc > 0)) return;
    var cw = WORLD_W * sc, left = m + 40, right = left + cw;
    var pistonY = floorY - S.Vd * UPL * sc, wallTop = floorY - VMAX * UPL * sc;
    var tN = clamp((S.T - TMIN) / (TMAX - TMIN), 0, 1);
    var hr = Math.round(lerp(70, 235, tN)), hg = Math.round(lerp(130, 70, tN)), hb = Math.round(lerp(215, 40, tN));
    var heat = "rgb(" + hr + "," + hg + "," + hb + ")";
    var i, y, a;

    ctx.font = "11px 'DM Sans', Arial, sans-serif";

    // gas region and the heater's glow
    ctx.fillStyle = "#1b2230"; ctx.fillRect(left, pistonY, cw, floorY - pistonY);
    var glowTop = Math.max(pistonY, floorY - 80), gr0 = ctx.createLinearGradient(0, floorY, 0, floorY - 80);
    gr0.addColorStop(0, "rgba(" + hr + "," + hg + "," + hb + "," + (0.10 + 0.40 * tN).toFixed(2) + ")");
    gr0.addColorStop(1, "rgba(" + hr + "," + hg + "," + hb + ",0)");
    ctx.fillStyle = gr0; ctx.fillRect(left, glowTop, cw, floorY - glowTop);

    // volume ruler
    ctx.strokeStyle = "#777"; ctx.fillStyle = "#8a8a8a"; ctx.lineWidth = 1; ctx.textAlign = "right";
    for (i = 0; i <= VMAX; i += 5) {
      y = floorY - i * UPL * sc;
      ctx.beginPath(); ctx.moveTo(left - 8, y); ctx.lineTo(left, y); ctx.stroke();
      ctx.fillText(String(i), left - 11, y + 4);
    }
    ctx.textAlign = "left"; ctx.fillText("L", m - 2, wallTop - 8);

    // particles
    var vr = VK * Math.sqrt(S.T), pr = Math.max(2.2, PR * sc * 0.7), sp, tt;
    for (i = 0; i < S.parts.length; i++) {
      var p = S.parts[i];
      sp = Math.sqrt(p.vx * p.vx + p.vy * p.vy) / vr; tt = clamp((sp - 0.3) / 1.6, 0, 1);
      ctx.fillStyle = "rgb(" + Math.round(lerp(90, 235, tt)) + "," + Math.round(lerp(150, 70, tt)) + "," + Math.round(lerp(235, 60, tt)) + ")";
      ctx.beginPath(); ctx.arc(left + p.x * sc, floorY - p.y * sc, pr, 0, 6.2832); ctx.fill();
    }

    // walls and floor
    ctx.strokeStyle = "#cfcfcf"; ctx.lineWidth = 3; ctx.lineCap = "round";
    ctx.beginPath(); ctx.moveTo(left, wallTop); ctx.lineTo(left, floorY); ctx.lineTo(right, floorY); ctx.lineTo(right, wallTop); ctx.stroke();

    // piston, rod and handle
    ctx.fillStyle = "#7d7d7d"; ctx.fillRect(left + cw / 2 - 3, 12, 6, Math.max(0, pistonY - 12));
    ctx.fillStyle = "#aaa"; ctx.fillRect(left + cw / 2 - 15, 5, 30, 8);
    ctx.fillStyle = "#a8a8a8"; ctx.fillRect(left + 2, pistonY - 9, cw - 4, 9);
    if (S.law === "charles" || S.law === "avogadro") {      // weights: constant external pressure
      ctx.fillStyle = "#5b5b5b";
      ctx.fillRect(left + 8, pistonY - 9 - 13, 34 * Math.min(1, sc + 0.3), 13);
      ctx.fillRect(right - 8 - 34 * Math.min(1, sc + 0.3), pistonY - 9 - 13, 34 * Math.min(1, sc + 0.3), 13);
    } else if (S.law === "gaylussac") {                     // pins: volume locked
      ctx.fillStyle = "#e14a4a";
      ctx.fillRect(left - 7, pistonY - 6, 9, 5); ctx.fillRect(right - 2, pistonY - 6, 9, 5);
    }

    // heater
    ctx.fillStyle = "#262626"; ctx.fillRect(left - 6, floorY + 2, cw + 12, heaterH);
    ctx.strokeStyle = heat; ctx.lineWidth = 3; ctx.lineJoin = "round"; ctx.beginPath();
    var zig = 12, x0 = left + 6, x1 = right - 6, mid = floorY + 2 + heaterH / 2;
    ctx.moveTo(x0, mid);
    for (a = x0, i = 0; a < x1; a += (x1 - x0) / zig, i++) ctx.lineTo(a, mid + (i % 2 ? 7 : -7));
    ctx.stroke();

    // pressure gauge (log scale)
    var space = W - right, gcx = right + space / 2 + 4, gR = clamp(Math.min(space / 2 - 22, H * 0.30, 110), 34, 110), gcy = H * 0.40;
    var a0 = 0.75 * Math.PI, a1 = 2.25 * Math.PI;
    var frac = clamp((Math.log(Math.max(S.Pd, G_LO)) / Math.LN10 - Math.log(G_LO) / Math.LN10) / (Math.log(G_HI) / Math.LN10 - Math.log(G_LO) / Math.LN10), 0, 1);
    ctx.fillStyle = "#222"; ctx.beginPath(); ctx.arc(gcx, gcy, gR, 0, 6.2832); ctx.fill();
    ctx.strokeStyle = "#444"; ctx.lineWidth = 2; ctx.stroke();
    ctx.lineWidth = Math.max(3, gR * 0.09); ctx.lineCap = "butt";
    ctx.strokeStyle = "#3a3a3a"; ctx.beginPath(); ctx.arc(gcx, gcy, gR * 0.80, a0, a1); ctx.stroke();
    ctx.strokeStyle = "#b22222"; ctx.beginPath(); ctx.arc(gcx, gcy, gR * 0.80, a0, a0 + frac * (a1 - a0)); ctx.stroke();
    var labels = ["1", "10", "100", "1k", "10k"];
    ctx.fillStyle = "#9a9a9a"; ctx.textAlign = "center"; ctx.font = "10px 'DM Sans', Arial, sans-serif";
    for (i = 0; i < 5; i++) {
      a = a0 + (i / 4) * (a1 - a0);
      ctx.fillText(labels[i], gcx + Math.cos(a) * gR * 0.58, gcy + Math.sin(a) * gR * 0.58 + 3);
    }
    a = a0 + frac * (a1 - a0);
    ctx.strokeStyle = "#f0b34a"; ctx.lineWidth = 2.5; ctx.lineCap = "round";
    ctx.beginPath(); ctx.moveTo(gcx, gcy); ctx.lineTo(gcx + Math.cos(a) * gR * 0.74, gcy + Math.sin(a) * gR * 0.74); ctx.stroke();
    ctx.fillStyle = "#f0b34a"; ctx.beginPath(); ctx.arc(gcx, gcy, 4, 0, 6.2832); ctx.fill();
    ctx.fillStyle = "#fff"; ctx.font = "700 15px 'DM Sans', Arial, sans-serif";
    ctx.fillText(fmtP(S.P) + " kPa", gcx, gcy + gR + 20);
    ctx.fillStyle = "#9a9a9a"; ctx.font = "11px 'DM Sans', Arial, sans-serif";
    ctx.fillText("PRESSURE", gcx, gcy + gR + 36);
  }

  // ---------------------------------------------------------------- graph
  function graphSpec() {
    var b = S.base, sp = { x: LAWS[S.law].x, y: LAWS[S.law].y, curve: null, dom: null }, k, c, i, m;
    if (S.law === "boyle") {
      k = b.n * R * b.T;
      sp.xmax = 32; sp.ymax = niceCeil(k / VMIN * 1.05);
      sp.curve = function (x) { return k / x; }; sp.dom = [VMIN, VMAX];
    } else if (S.law === "charles") {
      c = b.n * R / b.P;
      sp.xmax = 850; sp.ymax = 32;
      sp.curve = function (x) { return c * x; }; sp.dom = [Math.max(TMIN, VMIN / c), Math.min(TMAX, VMAX / c)];
    } else if (S.law === "gaylussac") {
      c = b.n * R / b.V;
      sp.xmax = 850; sp.ymax = niceCeil(c * 850 * 1.02);
      sp.curve = function (x) { return c * x; }; sp.dom = [TMIN, TMAX];
    } else if (S.law === "avogadro") {
      c = R * b.T / b.P;
      sp.xmax = 3.2; sp.ymax = 32;
      sp.curve = function (x) { return c * x; }; sp.dom = [Math.max(NMIN, VMIN / c), Math.min(NMAX, VMAX / c)];
    } else {
      m = S.P;
      for (i = 0; i < S.data.length; i++) if (S.data[i].P > m) m = S.data[i].P;
      sp.xmax = 32; sp.ymax = niceCeil(m * 1.2);
    }
    return sp;
  }

  function drawGraph() {
    var W = gc.clientWidth, H = gc.clientHeight;
    if (!W || !H) return;
    gx.setTransform(dpr, 0, 0, dpr, 0, 0); gx.clearRect(0, 0, W, H);
    var sp = graphSpec(), pad = { l: 56, r: 16, t: 14, b: 42 }, pw = W - pad.l - pad.r, ph = H - pad.t - pad.b;
    if (pw < 30 || ph < 30) return;
    var X = function (v) { return pad.l + v / sp.xmax * pw; }, Y = function (v) { return pad.t + ph - v / sp.ymax * ph; };
    var sx = niceStep(sp.xmax), sy = niceStep(sp.ymax), t, i, x;

    gx.font = "11px 'DM Sans', Arial, sans-serif"; gx.lineWidth = 1; gx.strokeStyle = "#ece8e6"; gx.fillStyle = "#777";
    gx.textAlign = "center";
    for (t = 0; t <= sp.xmax + 1e-9; t += sx) {
      gx.beginPath(); gx.moveTo(X(t), pad.t); gx.lineTo(X(t), pad.t + ph); gx.stroke();
      gx.fillText(tick(t), X(t), pad.t + ph + 15);
    }
    gx.textAlign = "right";
    for (t = 0; t <= sp.ymax + 1e-9; t += sy) {
      gx.beginPath(); gx.moveTo(pad.l, Y(t)); gx.lineTo(pad.l + pw, Y(t)); gx.stroke();
      gx.fillText(tick(t), pad.l - 7, Y(t) + 4);
    }
    gx.strokeStyle = "#999"; gx.lineWidth = 1.5;
    gx.beginPath(); gx.moveTo(pad.l, pad.t); gx.lineTo(pad.l, pad.t + ph); gx.lineTo(pad.l + pw, pad.t + ph); gx.stroke();
    gx.fillStyle = "#555"; gx.textAlign = "center";
    gx.fillText(AXL[sp.x], pad.l + pw / 2, H - 6);
    gx.save(); gx.translate(13, pad.t + ph / 2); gx.rotate(-Math.PI / 2); gx.fillText(AXL[sp.y], 0, 0); gx.restore();

    gx.save(); gx.beginPath(); gx.rect(pad.l, pad.t, pw, ph); gx.clip();
    if (sp.curve) {
      gx.setLineDash([5, 4]); gx.strokeStyle = "#b5b0ad"; gx.lineWidth = 1.5; gx.beginPath();
      for (i = 0; i <= 160; i++) { x = sp.xmax * (0.004 + 0.996 * i / 160); i ? gx.lineTo(X(x), Y(sp.curve(x))) : gx.moveTo(X(x), Y(sp.curve(x))); }
      gx.stroke(); gx.setLineDash([]);
      if (sp.dom[1] > sp.dom[0]) {
        gx.strokeStyle = "#b22222"; gx.lineWidth = 2.5; gx.beginPath();
        for (i = 0; i <= 100; i++) { x = sp.dom[0] + (sp.dom[1] - sp.dom[0]) * i / 100; i ? gx.lineTo(X(x), Y(sp.curve(x))) : gx.moveTo(X(x), Y(sp.curve(x))); }
        gx.stroke();
      }
    }
    gx.restore();

    gx.lineWidth = 2; gx.strokeStyle = "#161616"; gx.fillStyle = "#fff";
    S.data.forEach(function (r) { gx.beginPath(); gx.arc(X(r[sp.x]), Y(r[sp.y]), 4.5, 0, 6.2832); gx.fill(); gx.stroke(); });
    gx.fillStyle = "#b22222"; gx.strokeStyle = "#fff"; gx.lineWidth = 2;
    gx.beginPath(); gx.arc(X(S[sp.x]), Y(S[sp.y]), 6.5, 0, 6.2832); gx.fill(); gx.stroke();
  }

  // ---------------------------------------------------------------- main loop
  function frame(ts) {
    if (!S.last) S.last = ts;
    var dt = Math.min(0.05, (ts - S.last) / 1000), k = Math.min(1, dt * 10); S.last = ts;
    S.Vd += (S.V - S.Vd) * k; S.Pd += (S.P - S.Pd) * k;
    syncParticles();
    if (!S.paused) {
      stepParticles(dt);
      S.hitWin += dt;
      if (S.hitWin >= 0.5) { S.hitShow = S.hitShow * 0.6 + (S.hits / S.hitWin) * 0.4; S.hits = 0; S.hitWin = 0; }
    }
    drawChamber();
    S.statT += dt;
    if (S.statT > 0.1) { S.statT = 0; updateReadouts(); drawGraph(); }
    requestAnimationFrame(frame);
  }

  // ---------------------------------------------------------------- wiring
  function bind() {
    ["V", "T", "n"].forEach(function (k) {
      $("c-" + k).addEventListener("input", function (e) { onControl(k, parseFloat(e.target.value)); });
    });
    Array.prototype.forEach.call(document.querySelectorAll('input[name="law"]'), function (r) {
      r.addEventListener("change", function () { if (r.checked) setLaw(r.value); });
    });
    $("btn-record").addEventListener("click", record);
    $("btn-clear").addEventListener("click", function () { S.data = []; renderTable(); drawGraph(); });
    $("btn-reset").addEventListener("click", resetAll);
    $("btn-pause").addEventListener("click", function () {
      S.paused = !S.paused;
      this.setAttribute("aria-pressed", S.paused ? "true" : "false");
      this.textContent = S.paused ? "Resume motion" : "Pause motion";
    });
    var onResize = function () { fitCanvas(cv); fitCanvas(gc); drawGraph(); };
    if (window.ResizeObserver) { new ResizeObserver(onResize).observe(cv); new ResizeObserver(onResize).observe(gc); }
    else window.addEventListener("resize", onResize);
    onResize();
  }

  function init() {
    recompute(); S.Vd = S.V; S.Pd = S.P; S.Tp = S.T;
    snapshot();                                            // bind() draws the graph, which needs the baseline
    bind();
    setLaw(S.law);
    requestAnimationFrame(frame);
  }
  init();
})();

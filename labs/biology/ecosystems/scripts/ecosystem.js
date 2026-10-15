/**
 * Ecosystems UI (OOPA Virtual Labs / Biology). Model lives in ecosystem-model.js.
 * Fixed model step of 0.02 years; the simulation clock advances SIM_RATE years per real second
 * (times the Time setting), independent of frame rate. The food web is drawn in a fixed
 * 800 x 500 world and scaled to the canvas.
 */
(function () {
  "use strict";

  var M = window.EcoModel;
  var DT = 0.02, SIM_RATE = 5, SAMPLE = 0.5, WINDOW = 100, MAXN = 1500;
  var COL = { P: "#5fc48d", H: "#f4a259", C: "#e0483e", D: "#a0775a", N: "#5aa9e6", SUN: "#ffe066", OUT: "#8899aa" };
  var WW = 800, WH = 500;
  var NODES = { sun: { x: 90, y: 70 }, N: { x: 90, y: 370 }, P: { x: 260, y: 230 }, H: { x: 470, y: 230 }, C: { x: 680, y: 230 }, D: { x: 470, y: 410 } };
  var EVENT_NAMES = { fire: "Wildfire", drought: "Drought", fertilizer: "Fertilizer", hunt: "Hunt", invade: "Herbivores added" };

  var $ = function (id) { return document.getElementById(id); };
  var cv = $("sim"), ctx = cv.getContext("2d"), ch = $("chart"), cx = ch.getContext("2d");
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var PRESETS = {
    balanced: { light: 1,   d: 0.5,  aH: 4.45, aC: 4.1, inflow: 0, leach: 0 },
    rich:     { light: 1.4, d: 0.5,  aH: 4.45, aC: 4.1, inflow: 0, leach: 0 },
    slow:     { light: 1,   d: 0.15, aH: 4.45, aC: 4.1, inflow: 0, leach: 0 },
    leaky:    { light: 1,   d: 0.5,  aH: 4.45, aC: 4.1, inflow: 0, leach: 0.1 }
  };
  var KEYS = ["light", "d", "aH", "aC", "inflow", "leach"];
  var FMT = {
    light:  function (v) { return "×" + v.toFixed(2); },
    d:      function (v) { return v.toFixed(2) + " /yr"; },
    aH:     function (v) { return v.toFixed(2); },
    aC:     function (v) { return v.toFixed(1); },
    inflow: function (v) { return v.toFixed(0) + " /yr"; },
    leach:  function (v) { return v.toFixed(2) + " /yr"; }
  };

  var S = { p: { light: 1, d: 0.5, aH: 4.45, aC: 4.1, inflow: 0, leach: 0 }, s: null, hist: [], events: [],
            nextSample: SAMPLE, acc: 0, last: 0, running: !reduce, notified: false };

  // ---------- model glue ----------
  function record() { var s = S.s; S.hist.push([s.t, s.N, s.P, s.H, s.C, s.D]); if (S.hist.length > MAXN) S.hist.splice(0, S.hist.length - MAXN); }
  function reset() {
    S.s = M.init(); S.hist = []; S.events = []; S.nextSample = SAMPLE; S.acc = 0; record();
  }
  function advance() {
    M.step(S.p, S.s, DT);
    if (S.s.t >= S.nextSample - 1e-9) { S.nextSample += SAMPLE; record(); }
  }

  // ---------- food web drawing ----------
  function wid(f) { return 1 + 9 * Math.sqrt(Math.min(1, f / 250)); }
  function rad(v) { return v > 0 ? 16 + 40 * Math.sqrt(Math.min(1, v / 500)) : 12; }

  function arrow(g, a, b, ra, rb, w, col, value, fs) {
    var dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy), ux = dx / len, uy = dy / len;
    var x0 = a.x + ux * (ra + 4), y0 = a.y + uy * (ra + 4), hl = 8 + w * 1.3;
    var x1 = b.x - ux * (rb + 6), y1 = b.y - uy * (rb + 6);
    if ((x1 - x0) * ux + (y1 - y0) * uy < hl + 4) return;
    var bx = x1 - ux * hl, by = y1 - uy * hl, half = hl * 0.55 + w * 0.4;
    g.globalAlpha = 0.8; g.strokeStyle = col; g.fillStyle = col; g.lineWidth = w; g.lineCap = "butt";
    g.beginPath(); g.moveTo(x0, y0); g.lineTo(bx, by); g.stroke();
    g.beginPath(); g.moveTo(x1, y1); g.lineTo(bx - uy * half, by + ux * half); g.lineTo(bx + uy * half, by - ux * half); g.closePath(); g.fill();
    g.globalAlpha = 1;
    if (value >= 0.5) {
      var off = w / 2 + fs * 0.8;
      g.fillStyle = "#cfcfcf"; g.font = (fs * 0.85) + "px 'DM Sans', Arial, sans-serif"; g.textAlign = "center"; g.textBaseline = "middle";
      g.fillText(String(Math.round(value)), (x0 + x1) / 2 - uy * off, (y0 + y1) / 2 + ux * off);
    }
  }

  function node(g, key, v, name, col, fs) {
    var n = NODES[key], r = rad(v), i, a;
    if (v > 0) {
      g.globalAlpha = 0.88; g.fillStyle = col; g.beginPath(); g.arc(n.x, n.y, r, 0, 6.2832); g.fill(); g.globalAlpha = 1;
      g.strokeStyle = "rgba(255,255,255,0.55)"; g.lineWidth = 1.5; g.stroke();
    } else {
      g.strokeStyle = "#777"; g.lineWidth = 1.5; g.setLineDash([4, 3]); g.beginPath(); g.arc(n.x, n.y, r, 0, 6.2832); g.stroke(); g.setLineDash([]);
    }
    g.textAlign = "center"; g.textBaseline = "middle";
    g.fillStyle = "#eeeeee"; g.font = "bold " + fs + "px 'DM Sans', Arial, sans-serif"; g.fillText(name, n.x, n.y + r + fs * 0.95);
    g.fillStyle = "#aaaaaa"; g.font = (fs * 0.9) + "px 'DM Sans', Arial, sans-serif";
    g.fillText(v > 0 ? String(Math.round(v)) : "extinct", n.x, n.y + r + fs * 2.05);
  }

  function drawWeb() {
    var w = cv.width; if (!w) return;
    var k = w / WW, g = ctx, s = S.s, p = S.p, r = M.flows(p, s), fs = Math.max(11, Math.min(26, 10000 / cv.clientWidth)), i, n, a;
    g.setTransform(k, 0, 0, k, 0, 0);
    g.fillStyle = "#1a211e"; g.fillRect(0, 0, WW, WH);

    // arrows first, then circles on top
    var sunW = 2 + 8 * (p.light / 1.5) * (s.drought > 0 ? 0.4 : 1);
    arrow(g, NODES.sun, NODES.P, 26, rad(s.P), sunW, COL.SUN, 0, fs);
    arrow(g, NODES.N, NODES.P, rad(s.N), rad(s.P), wid(r.G), COL.N, r.G, fs);
    arrow(g, NODES.P, NODES.H, rad(s.P), rad(s.H), wid(r.Gr), COL.H, r.Gr, fs);
    arrow(g, NODES.H, NODES.C, rad(s.H), rad(s.C), wid(r.Pr), COL.C, r.Pr, fs);
    arrow(g, NODES.P, NODES.D, rad(s.P), rad(s.D), wid(r.toD_P), COL.D, r.toD_P, fs);
    arrow(g, NODES.H, NODES.D, rad(s.H), rad(s.D), wid(r.toD_H), COL.D, r.toD_H, fs);
    arrow(g, NODES.C, NODES.D, rad(s.C), rad(s.D), wid(r.toD_C), COL.D, r.toD_C, fs);
    arrow(g, NODES.D, NODES.N, rad(s.D), rad(s.N), wid(r.dec), COL.N, r.dec, fs);
    if (p.inflow > 0) arrow(g, { x: 20, y: 470 }, NODES.N, 0, rad(s.N), wid(r.inflow), COL.N, r.inflow, fs);
    if (p.leach > 0) arrow(g, NODES.N, { x: 200, y: 480 }, rad(s.N), 0, wid(r.leach), COL.OUT, r.leach, fs);

    // sun with rays
    n = NODES.sun; g.fillStyle = COL.SUN; g.strokeStyle = COL.SUN; g.lineWidth = 2;
    g.beginPath(); g.arc(n.x, n.y, 16, 0, 6.2832); g.fill();
    for (i = 0; i < 8; i++) { a = i * Math.PI / 4; g.beginPath(); g.moveTo(n.x + Math.cos(a) * 21, n.y + Math.sin(a) * 21); g.lineTo(n.x + Math.cos(a) * 28, n.y + Math.sin(a) * 28); g.stroke(); }
    g.fillStyle = "#eeeeee"; g.font = "bold " + fs + "px 'DM Sans', Arial, sans-serif"; g.textAlign = "center"; g.textBaseline = "middle";
    g.fillText("Sunlight", n.x, n.y + 28 + fs * 0.95);

    node(g, "P", s.P, "Plants", COL.P, fs);
    node(g, "H", s.H, "Herbivores", COL.H, fs);
    node(g, "C", s.C, "Carnivores", COL.C, fs);
    node(g, "D", s.D, "Dead matter", COL.D, fs);
    node(g, "N", s.N, "Nutrients", COL.N, fs);

    if (s.drought > 0) {
      g.fillStyle = COL.H; g.font = "bold " + fs + "px 'DM Sans', Arial, sans-serif"; g.textAlign = "right"; g.textBaseline = "top";
      g.fillText("Drought: " + Math.ceil(s.drought) + " years left", WW - 14, 12);
    }
  }

  // ---------- chart ----------
  function nice(v) {
    var e = Math.pow(10, Math.floor(Math.log(v) / Math.LN10)), f = v / e;
    return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * e;
  }

  function drawChart() {
    var w = ch.width, h = ch.height; if (!w) return;
    var dpr = w / ch.clientWidth, pad = { l: 44 * dpr, r: 12 * dpr, t: 14 * dpr, b: 34 * dpr };
    var pw = w - pad.l - pad.r, ph = h - pad.t - pad.b;
    var series = $("chart-mode").value === "matter"
      ? [{ k: 1, col: COL.N, name: "Nutrients" }, { k: 5, col: COL.D, name: "Dead matter" }]
      : [{ k: 2, col: COL.P, name: "Plants" }, { k: 3, col: COL.H, name: "Herbivores" }, { k: 4, col: COL.C, name: "Carnivores" }];
    var x1 = Math.max(WINDOW, S.s.t), x0 = x1 - WINDOW, hh = S.hist, i, j, v, ymax = 10, step, gx, gy, d, X, Y, started, lx;
    cx.setTransform(1, 0, 0, 1, 0, 0); cx.fillStyle = "#161616"; cx.fillRect(0, 0, w, h);
    for (i = 0; i < hh.length; i++) if (hh[i][0] >= x0) for (j = 0; j < series.length; j++) ymax = Math.max(ymax, hh[i][series[j].k]);
    ymax = Math.max(10, nice(ymax * 1.08));
    cx.font = (11 * dpr) + "px 'DM Sans', Arial, sans-serif"; cx.lineWidth = dpr;
    cx.strokeStyle = "#2c2c2c"; cx.fillStyle = "#999"; cx.textAlign = "right"; cx.textBaseline = "alphabetic";
    step = nice(ymax / 4);
    for (v = 0; v <= ymax + 1e-9; v += step) {
      gy = pad.t + ph - v / ymax * ph; cx.beginPath(); cx.moveTo(pad.l, gy); cx.lineTo(pad.l + pw, gy); cx.stroke();
      cx.fillText(String(Math.round(v)), pad.l - 6 * dpr, gy + 4 * dpr);
    }
    cx.textAlign = "center"; step = nice(WINDOW / 6);
    for (v = Math.ceil(x0 / step) * step; v <= x1 + 1e-9; v += step) {
      gx = pad.l + (v - x0) / WINDOW * pw; cx.fillText(String(Math.round(v)), gx, pad.t + ph + 16 * dpr);
    }
    cx.fillText("Years", pad.l + pw / 2, h - 4 * dpr);
    cx.save(); cx.translate(12 * dpr, pad.t + ph / 2); cx.rotate(-Math.PI / 2); cx.fillText("Matter units", 0, 0); cx.restore();

    cx.save(); cx.beginPath(); cx.rect(pad.l, pad.t, pw, ph); cx.clip();
    // event markers
    cx.setLineDash([4 * dpr, 4 * dpr]); cx.textAlign = "left"; cx.font = (10 * dpr) + "px 'DM Sans', Arial, sans-serif";
    for (i = 0; i < S.events.length; i++) {
      if (S.events[i].t < x0 || S.events[i].t > x1) continue;
      lx = pad.l + (S.events[i].t - x0) / WINDOW * pw;
      cx.strokeStyle = "rgba(255,255,255,0.35)"; cx.beginPath(); cx.moveTo(lx, pad.t); cx.lineTo(lx, pad.t + ph); cx.stroke();
      cx.fillStyle = "#bbb"; cx.fillText(EVENT_NAMES[S.events[i].k], lx + 3 * dpr, pad.t + ph - 5 * dpr);
    }
    cx.setLineDash([]);
    for (j = 0; j < series.length; j++) {
      cx.strokeStyle = series[j].col; cx.lineWidth = 2.2 * dpr; cx.lineJoin = "round"; cx.beginPath(); started = false;
      for (i = 0; i < hh.length; i++) {
        d = hh[i]; if (d[0] < x0 - SAMPLE) continue;
        X = pad.l + (d[0] - x0) / WINDOW * pw; Y = pad.t + ph - d[series[j].k] / ymax * ph;
        if (started) cx.lineTo(X, Y); else cx.moveTo(X, Y);
        started = true;
      }
      cx.stroke();
    }
    cx.restore();
    cx.font = (12 * dpr) + "px 'DM Sans', Arial, sans-serif"; cx.textAlign = "left"; lx = pad.l + 10 * dpr;
    for (j = 0; j < series.length; j++) {
      cx.fillStyle = series[j].col; cx.fillRect(lx, pad.t + 8 * dpr, 14 * dpr, 3 * dpr); cx.fillText(series[j].name, lx + 20 * dpr, pad.t + 13 * dpr);
      lx += (series[j].name.length * 7 + 44) * dpr;
    }
  }

  // ---------- readouts & UI ----------
  function fmt(v) { return v < 10 && v > 0 ? v.toFixed(1) : String(Math.round(v)); }
  function pct(x, base) { return base > 0 ? Math.round(x / base * 100) + "% of level below" : ""; }
  function updateStats() {
    var s = S.s, r = M.flows(S.p, s);
    $("s-t").textContent = s.t.toFixed(0); $("s-g").textContent = fmt(r.G);
    $("s-p").textContent = fmt(s.P); $("s-h").textContent = fmt(s.H); $("s-c").textContent = fmt(s.C);
    $("s-n").textContent = fmt(s.N); $("s-d").textContent = fmt(s.D); $("s-tot").textContent = fmt(M.total(s));
    $("status").textContent = M.status(S.p, s);

    $("pb-p").style.width = (r.G > 0 ? 100 : 0) + "%";
    $("pb-h").style.width = (r.G > 0 ? Math.min(100, r.prodH / r.G * 100) : 0) + "%";
    $("pb-c").style.width = (r.G > 0 ? Math.min(100, r.prodC / r.G * 100) : 0) + "%";
    $("pv-p").textContent = fmt(r.G) + " per year";
    $("pv-h").textContent = fmt(r.prodH) + " per year" + (r.prodH > 0 ? ", " + pct(r.prodH, r.G) : "");
    $("pv-c").textContent = fmt(r.prodC) + " per year" + (r.prodC > 0 ? ", " + pct(r.prodC, r.prodH) : "");
  }
  function syncUI() { KEYS.forEach(function (k) { $("c-" + k).value = S.p[k]; $("o-" + k).textContent = FMT[k](S.p[k]); }); }
  function setRunning(on) { S.running = on; $("btn-play").textContent = on ? "Pause" : "Play"; $("btn-play").setAttribute("aria-pressed", String(on)); }
  function refresh() { updateStats(); drawWeb(); drawChart(); }
  function tip() { if (!S.notified && window.Jenny) { S.notified = true; Jenny.notifyNewTip("ecosystem"); } }

  function bind() {
    KEYS.forEach(function (k) {
      $("c-" + k).addEventListener("input", function (ev) {
        var v = parseFloat(ev.target.value);
        S.p[k] = v; $("o-" + k).textContent = FMT[k](v); refresh(); tip();
      });
    });
    $("btn-play").addEventListener("click", function () { setRunning(!S.running); });
    $("btn-step").addEventListener("click", function () { var i; setRunning(false); for (i = 0; i < 50; i++) advance(); refresh(); });
    $("btn-reset").addEventListener("click", function () { reset(); refresh(); });
    $("chart-mode").addEventListener("change", drawChart);
    Array.prototype.forEach.call(document.querySelectorAll("[data-preset]"), function (b) {
      b.addEventListener("click", function () {
        var q = PRESETS[b.getAttribute("data-preset")];
        KEYS.forEach(function (k) { S.p[k] = q[k]; });
        syncUI(); reset(); refresh();
      });
    });
    Array.prototype.forEach.call(document.querySelectorAll("[data-event]"), function (b) {
      b.addEventListener("click", function () {
        var kind = b.getAttribute("data-event");
        M.applyEvent(S.s, kind); S.events.push({ t: S.s.t, k: kind }); refresh();
      });
    });
    var onResize = function () { fit(cv, WW / WH); fit(ch, 16 / 5); drawWeb(); drawChart(); };
    if (window.ResizeObserver) { new ResizeObserver(onResize).observe(cv); new ResizeObserver(onResize).observe(ch); }
    else window.addEventListener("resize", onResize);
    onResize();
  }
  function fit(c, ratio) {
    var dpr = Math.min(window.devicePixelRatio || 1, 2), w = Math.round(c.clientWidth * dpr);
    if (w && c.width !== w) { c.width = w; c.height = Math.round(w / ratio); }
  }

  var statTimer = 0;
  function frame(ts) {
    if (!S.last) S.last = ts;
    var dt = Math.min(0.05, (ts - S.last) / 1000); S.last = ts;
    if (S.running) {
      S.acc += dt * SIM_RATE * parseFloat($("timescale").value);
      while (S.acc >= DT) { advance(); S.acc -= DT; }
      drawWeb();
    }
    statTimer += dt;
    if (statTimer > 0.2) { statTimer = 0; updateStats(); drawChart(); }
    requestAnimationFrame(frame);
  }

  KEYS.forEach(function (k) { S.p[k] = PRESETS.balanced[k]; });
  reset(); syncUI(); bind(); setRunning(S.running); refresh();
  requestAnimationFrame(frame);
})();

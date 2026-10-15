/**
 * Predator-Prey UI (OOPA Virtual Labs / Biology). Model lives in predator-prey-model.js.
 * Fixed physics step of 0.01 years; the simulation clock advances SIM_RATE years per
 * real second (times the Time setting), independent of frame rate.
 */
(function () {
  "use strict";

  var M = window.PredPreyModel;
  var DT = 0.01, SIM_RATE = 2, SAMPLE = 0.1, WINDOW = 60, MAXN = 4000;
  var PREY = "#5fc48d", PRED = "#e0483e";

  var $ = function (id) { return document.getElementById(id); };
  var cv = $("sim"), ctx = cv.getContext("2d"), pv = $("phase"), px = pv.getContext("2d");
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var PRESETS = {
    cycles:   { r: 0.6, a: 0.02, b: 0.5, m: 0.4, K: 500, x0: 60,  y0: 20, ext: true },
    stable:   { r: 0.6, a: 0.02, b: 0.5, m: 0.4, K: 150, x0: 60,  y0: 20, ext: true },
    collapse: { r: 0.8, a: 0.03, b: 0.5, m: 0.3, K: 500, x0: 120, y0: 6,  ext: true }
  };
  var KEYS = ["r", "a", "b", "m", "K", "x0", "y0"];
  var S = { p: { r: 0.6, a: 0.02, b: 0.5, m: 0.4, K: 500, ext: true }, x0: 60, y0: 20,
            s: { x: 0, y: 0, t: 0 }, hist: [], acc: 0, last: 0, nextSample: 0, running: !reduce, peaks: [], notified: false };

  // ---------- model glue ----------
  function reset() {
    S.s = { x: S.x0, y: S.y0, t: 0 };
    S.hist = [[0, S.x0, S.y0]]; S.nextSample = SAMPLE; S.peaks = [];
  }
  function advance() {
    M.step(S.p, S.s, DT);
    if (S.s.t >= S.nextSample - 1e-9) { S.nextSample += SAMPLE; record(); }
  }
  function record() {
    var h = S.hist, n = h.length, s = S.s;
    h.push([s.t, s.x, s.y]);
    if (n >= 2 && h[n][1] < h[n - 1][1] && h[n - 1][1] >= h[n - 2][1] && h[n - 1][1] > 1) S.peaks.push(h[n - 1][0]);
    if (h.length > MAXN) h.splice(0, h.length - MAXN);
    if (S.peaks.length > 6) S.peaks.shift();
  }
  function period() { var k = S.peaks.length; return k >= 2 ? S.peaks[k - 1] - S.peaks[k - 2] : null; }

  // ---------- drawing helpers ----------
  function fit(c, ratio) {
    var dpr = Math.min(window.devicePixelRatio || 1, 2), w = Math.round(c.clientWidth * dpr);
    if (w && c.width !== w) { c.width = w; c.height = Math.round(w / ratio); }
  }
  function nice(v) {
    var e = Math.pow(10, Math.floor(Math.log(v) / Math.LN10)), f = v / e;
    return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * e;
  }
  function axes(c, g, w, h, pad, xmax, ymax, xlab, ylab, xmin) {
    var dpr = w / c.clientWidth, i, v, gx, gy, pw = w - pad.l - pad.r, ph = h - pad.t - pad.b, step = nice(ymax / 4);
    g.font = (11 * dpr) + "px 'DM Sans', Arial, sans-serif"; g.lineWidth = dpr;
    g.strokeStyle = "#2c2c2c"; g.fillStyle = "#999"; g.textAlign = "right";
    for (v = 0; v <= ymax + 1e-9; v += step) {
      gy = pad.t + ph - v / ymax * ph; g.beginPath(); g.moveTo(pad.l, gy); g.lineTo(pad.l + pw, gy); g.stroke();
      g.fillText(String(Math.round(v)), pad.l - 6 * dpr, gy + 4 * dpr);
    }
    g.textAlign = "center"; step = nice((xmax - xmin) / 5);
    for (v = Math.ceil(xmin / step) * step; v <= xmax + 1e-9; v += step) {
      gx = pad.l + (v - xmin) / (xmax - xmin) * pw; g.fillText(String(Math.round(v)), gx, pad.t + ph + 16 * dpr);
    }
    g.fillText(xlab, pad.l + pw / 2, h - 4 * dpr);
    g.save(); g.translate(12 * dpr, pad.t + ph / 2); g.rotate(-Math.PI / 2); g.fillText(ylab, 0, 0); g.restore();
    return { pw: pw, ph: ph, dpr: dpr };
  }

  function drawSeries() {
    var w = cv.width, h = cv.height; if (!w) return;
    var dpr = w / cv.clientWidth, pad = { l: 40 * dpr, r: 12 * dpr, t: 14 * dpr, b: 34 * dpr };
    var t = S.s.t, x1 = Math.max(WINDOW, t), x0 = x1 - WINDOW, hh = S.hist, i, ymax = 10, d;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = "#161616"; ctx.fillRect(0, 0, w, h);
    for (i = 0; i < hh.length; i++) if (hh[i][0] >= x0) ymax = Math.max(ymax, hh[i][1], hh[i][2]);
    ymax = nice(ymax * 1.08); if (ymax < 10) ymax = 10;
    var a = axes(cv, ctx, w, h, pad, x1, ymax, "Years", "Animals", x0);
    function line(col, k) {
      ctx.strokeStyle = col; ctx.lineWidth = 2.2 * dpr; ctx.lineJoin = "round"; ctx.beginPath();
      var started = false;
      for (var j = 0; j < hh.length; j++) {
        d = hh[j]; if (d[0] < x0 - SAMPLE) continue;
        var X = pad.l + (d[0] - x0) / WINDOW * a.pw, Y = pad.t + a.ph - d[k] / ymax * a.ph;
        started ? ctx.lineTo(X, Y) : ctx.moveTo(X, Y); started = true;
      }
      ctx.stroke();
    }
    ctx.save(); ctx.beginPath(); ctx.rect(pad.l, pad.t, a.pw, a.ph); ctx.clip();
    line(PREY, 1); line(PRED, 2); ctx.restore();
    ctx.font = (12 * dpr) + "px 'DM Sans', Arial, sans-serif"; ctx.textAlign = "left";
    ctx.fillStyle = PREY; ctx.fillRect(pad.l + 10 * dpr, pad.t + 8 * dpr, 14 * dpr, 3 * dpr); ctx.fillText("Prey", pad.l + 30 * dpr, pad.t + 13 * dpr);
    ctx.fillStyle = PRED; ctx.fillRect(pad.l + 80 * dpr, pad.t + 8 * dpr, 14 * dpr, 3 * dpr); ctx.fillText("Predators", pad.l + 100 * dpr, pad.t + 13 * dpr);
  }

  function drawPhase() {
    var w = pv.width, h = pv.height; if (!w) return;
    var dpr = w / pv.clientWidth, pad = { l: 40 * dpr, r: 14 * dpr, t: 12 * dpr, b: 34 * dpr };
    var eq = M.equilibrium(S.p), hh = S.hist, i, xm = Math.max(S.x0, eq ? eq.x * 1.6 : 0, 20), ym = Math.max(S.y0, eq ? eq.y * 1.6 : 0, 10);
    px.setTransform(1, 0, 0, 1, 0, 0); px.fillStyle = "#161616"; px.fillRect(0, 0, w, h);
    for (i = 0; i < hh.length; i++) { xm = Math.max(xm, hh[i][1]); ym = Math.max(ym, hh[i][2]); }
    xm = nice(xm * 1.08); ym = nice(ym * 1.08);
    var a = axes(pv, px, w, h, pad, xm, ym, "Prey", "Predators", 0);
    var X = function (v) { return pad.l + v / xm * a.pw; }, Y = function (v) { return pad.t + a.ph - v / ym * a.ph; };
    px.save(); px.beginPath(); px.rect(pad.l, pad.t, a.pw, a.ph); px.clip();
    px.strokeStyle = "#8a8a8a"; px.lineWidth = 1.5 * dpr; px.setLineDash([6 * dpr, 4 * dpr]); px.beginPath();
    if (S.p.K >= M.K_OFF) { px.moveTo(pad.l, Y(S.p.r / S.p.a)); px.lineTo(pad.l + a.pw, Y(S.p.r / S.p.a)); }
    else { px.moveTo(X(0), Y(S.p.r / S.p.a)); px.lineTo(X(S.p.K), Y(0)); }       // prey stops changing
    if (eq) { px.moveTo(X(eq.x), pad.t); px.lineTo(X(eq.x), pad.t + a.ph); }        // predators stop changing
    px.stroke(); px.setLineDash([]);
    px.strokeStyle = PRED; px.lineWidth = 2 * dpr; px.lineJoin = "round"; px.beginPath();
    for (i = 0; i < hh.length; i++) i ? px.lineTo(X(hh[i][1]), Y(hh[i][2])) : px.moveTo(X(hh[i][1]), Y(hh[i][2]));
    px.stroke();
    if (eq) { px.fillStyle = "#fff"; px.beginPath(); px.arc(X(eq.x), Y(eq.y), 5 * dpr, 0, 6.2832); px.fill(); }
    px.fillStyle = PREY; px.beginPath(); px.arc(X(S.s.x), Y(S.s.y), 5 * dpr, 0, 6.2832); px.fill();
    px.restore();
  }

  // ---------- readouts & UI ----------
  function fmt(v) { return v >= 1e4 ? v.toExponential(1) : v.toFixed(v < 100 ? 1 : 0); }
  function updateStats() {
    var eq = M.equilibrium(S.p), per = period();
    $("s-x").textContent = fmt(S.s.x); $("s-y").textContent = fmt(S.s.y); $("s-t").textContent = S.s.t.toFixed(1);
    $("s-per").textContent = per ? per.toFixed(1) + " yr" : "–";
    $("s-ex").textContent = eq ? fmt(eq.x) : "none"; $("s-ey").textContent = eq ? fmt(eq.y) : "none";
    $("status").textContent = M.status(S.p, S.s);
  }
  var FMT = {
    r: function (v) { return v.toFixed(2) + " /yr"; }, a: function (v) { return v.toFixed(3); },
    b: function (v) { return v.toFixed(2); }, m: function (v) { return v.toFixed(2) + " /yr"; },
    K: function (v) { return v >= M.K_OFF ? "no limit" : String(v); },
    x0: String, y0: String
  };
  function syncUI() {
    KEYS.forEach(function (k) { var v = (k === "x0" || k === "y0") ? S[k] : S.p[k]; $("c-" + k).value = v; $("o-" + k).textContent = FMT[k](Number(v)); });
    $("c-ext").checked = S.p.ext;
  }
  function setRunning(on) { S.running = on; $("btn-play").textContent = on ? "Pause" : "Play"; $("btn-play").setAttribute("aria-pressed", String(on)); }
  function refresh() { updateStats(); drawSeries(); drawPhase(); }
  function tip() { if (!S.notified && window.Jenny) { S.notified = true; Jenny.notifyNewTip("predator-prey"); } }

  function bind() {
    KEYS.forEach(function (k) {
      $("c-" + k).addEventListener("input", function (ev) {
        var v = parseFloat(ev.target.value);
        if (k === "x0" || k === "y0") { S[k] = v; reset(); } else S.p[k] = v;
        $("o-" + k).textContent = FMT[k](v); refresh();
        if (k !== "x0" && k !== "y0") tip();
      });
    });
    $("c-ext").addEventListener("change", function (ev) { S.p.ext = ev.target.checked; });
    $("btn-play").addEventListener("click", function () { setRunning(!S.running); });
    $("btn-step").addEventListener("click", function () { setRunning(false); for (var i = 0; i < 50; i++) advance(); refresh(); });
    $("btn-reset").addEventListener("click", function () { reset(); refresh(); });
    Array.prototype.forEach.call(document.querySelectorAll("[data-preset]"), function (b) {
      b.addEventListener("click", function () {
        var q = PRESETS[b.getAttribute("data-preset")];
        ["r", "a", "b", "m", "K", "ext"].forEach(function (k) { S.p[k] = q[k]; });
        S.x0 = q.x0; S.y0 = q.y0; syncUI(); reset(); refresh();
      });
    });
    var onResize = function () { fit(cv, 8 / 5); fit(pv, 4 / 3); drawSeries(); drawPhase(); };
    if (window.ResizeObserver) { new ResizeObserver(onResize).observe(cv); new ResizeObserver(onResize).observe(pv); }
    else window.addEventListener("resize", onResize);
    onResize();
  }

  var statTimer = 0;
  function frame(ts) {
    if (!S.last) S.last = ts;
    var dt = Math.min(0.05, (ts - S.last) / 1000); S.last = ts;
    if (S.running) {
      S.acc += dt * SIM_RATE * parseFloat($("timescale").value);
      while (S.acc >= DT) { advance(); S.acc -= DT; }
      drawSeries(); drawPhase();
    }
    statTimer += dt;
    if (statTimer > 0.2) { statTimer = 0; updateStats(); }
    requestAnimationFrame(frame);
  }

  window.PredPreyLab = { S: S, reset: reset, advance: advance };
  Object.assign(S.p, PRESETS.cycles); S.x0 = PRESETS.cycles.x0; S.y0 = PRESETS.cycles.y0;
  syncUI(); bind(); setRunning(S.running); reset(); refresh();
  requestAnimationFrame(frame);
})();

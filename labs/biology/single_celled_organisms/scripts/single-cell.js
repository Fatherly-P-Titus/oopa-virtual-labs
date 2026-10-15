/**
 * Single-Celled Organisms UI (OOPA Virtual Labs / Biology). Model lives in cell-model.js.
 * Fixed model step of 1/30 s; the simulation clock advances SIM_RATE seconds per real second
 * (times the Time setting), independent of frame rate. The dish canvas is drawn in model units.
 */
(function () {
  "use strict";

  var M = window.CellModel;
  var DT = 1 / 30, SIM_RATE = 2, SAMPLE = 0.5, WINDOW = 120, MAXN = 2000;
  var CELLS = "#5fc48d", FOODC = "#e9c46a";

  var $ = function (id) { return document.getElementById(id); };
  var cv = $("sim"), ctx = cv.getContext("2d"), ch = $("chart"), cx = ch.getContext("2d");
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var PRESETS = {
    balanced: { foodRate: 6,   speed: 40, metab: 0.4, sense: 60, divide: 60, maxAge: 240, n0: 12 },
    feast:    { foodRate: 14,  speed: 40, metab: 0.4, sense: 60, divide: 60, maxAge: 240, n0: 12 },
    scarce:   { foodRate: 1.5, speed: 40, metab: 0.6, sense: 60, divide: 60, maxAge: 240, n0: 12 },
    blind:    { foodRate: 6,   speed: 40, metab: 0.4, sense: 0,  divide: 60, maxAge: 240, n0: 12 }
  };
  var KEYS = ["foodRate", "speed", "metab", "sense", "divide", "maxAge", "n0"];
  var FMT = {
    foodRate: function (v) { return v.toFixed(1) + " /s"; },
    speed:    function (v) { return String(v) + " /s"; },
    metab:    function (v) { return v.toFixed(2) + " /s"; },
    sense:    function (v) { return v === 0 ? "none" : String(v); },
    divide:   function (v) { return String(v); },
    maxAge:   function (v) { return v >= M.AGE_OFF ? "no limit" : v + " s"; },
    n0:       function (v) { return String(v); }
  };

  var S = { p: { foodRate: 6, speed: 40, metab: 0.4, sense: 60, divide: 60, maxAge: 240 }, n0: 12,
            s: null, hist: [], nextSample: SAMPLE, acc: 0, last: 0, running: !reduce, sel: 0, selGone: "", notified: false };

  // ---------- model glue ----------
  function reset() {
    S.s = M.init(S.p, S.n0, 80, Math.floor(Math.random() * 4294967296));
    S.hist = [[0, S.s.cells.length, S.s.food.length]];
    S.nextSample = SAMPLE; S.acc = 0; S.sel = 0; S.selGone = "";
  }
  function advance() {
    M.step(S.p, S.s, DT);
    if (S.s.t >= S.nextSample - 1e-9) {
      S.nextSample += SAMPLE;
      S.hist.push([S.s.t, S.s.cells.length, S.s.food.length]);
      if (S.hist.length > MAXN) S.hist.splice(0, S.hist.length - MAXN);
    }
  }
  function findCell(id) {
    var c = S.s.cells, i;
    for (i = 0; i < c.length; i++) if (c[i].id === id) return c[i];
    return null;
  }
  function select(id) { S.sel = id; S.selGone = ""; S.s.watch = id; S.s.watchFate = ""; updateSel(); drawDish(); }

  // ---------- drawing ----------
  function fit(c, ratio) {
    var dpr = Math.min(window.devicePixelRatio || 1, 2), w = Math.round(c.clientWidth * dpr);
    if (w && c.width !== w) { c.width = w; c.height = Math.round(w / ratio); }
  }
  function mix(a, b, u) { return Math.round(a + (b - a) * u); }

  function drawDish() {
    var w = cv.width; if (!w) return;
    var k = w / M.W, s = S.s, p = S.p, i, c, e, u, q, r, t = s.t, back, L, wob, bx, by, rgb;
    ctx.setTransform(k, 0, 0, k, 0, 0);
    ctx.fillStyle = "#1a211e"; ctx.fillRect(0, 0, M.W, M.H);
    ctx.strokeStyle = "#2b3a33"; ctx.lineWidth = 2; ctx.strokeRect(1, 1, M.W - 2, M.H - 2);

    ctx.fillStyle = FOODC; ctx.beginPath();
    for (i = 0; i < s.food.length; i++) { ctx.moveTo(s.food[i].x + M.FR, s.food[i].y); ctx.arc(s.food[i].x, s.food[i].y, M.FR, 0, 6.2832); }
    ctx.fill();

    for (i = 0; i < s.cells.length; i++) {
      c = s.cells[i]; r = c.r;
      q = Math.min(1, c.E / p.divide);
      // tail
      back = c.th + Math.PI; L = r * 1.9; wob = Math.sin(t * 9 + c.id) * r * 0.5;
      bx = c.x + Math.cos(back) * r; by = c.y + Math.sin(back) * r;
      ctx.strokeStyle = "rgba(168,230,195,0.55)"; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(bx, by);
      ctx.quadraticCurveTo(bx + Math.cos(back) * L * 0.5 - Math.sin(back) * wob, by + Math.sin(back) * L * 0.5 + Math.cos(back) * wob,
                           bx + Math.cos(back) * L, by + Math.sin(back) * L);
      ctx.stroke();
      // body: brown when hungry, green when well fed
      ctx.fillStyle = "rgba(" + mix(140, 95, q) + "," + mix(90, 196, q) + "," + mix(70, 141, q) + ",0.82)";
      ctx.beginPath(); ctx.arc(c.x, c.y, r, 0, 6.2832); ctx.fill();
      ctx.strokeStyle = c.E >= 0.9 * p.divide ? "#ffffff" : "rgba(168,230,195,0.8)";
      ctx.lineWidth = c.E >= 0.9 * p.divide ? 2 : 1.2; ctx.stroke();
      ctx.fillStyle = "rgba(20,40,30,0.65)"; ctx.beginPath(); ctx.arc(c.x + Math.cos(c.th) * r * 0.2, c.y + Math.sin(c.th) * r * 0.2, r * 0.32, 0, 6.2832); ctx.fill();
      if (c.fed > 0) { ctx.strokeStyle = "rgba(233,196,106," + (c.fed / 0.6).toFixed(2) + ")"; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(c.x, c.y, r + 2.5, 0, 6.2832); ctx.stroke(); }
    }

    // birth and death rings
    for (i = 0; i < s.fx.length; i++) {
      e = s.fx[i]; u = (t - e.t) / M.FX_LIFE; if (u < 0 || u > 1) continue;
      rgb = e.k === "starved" ? "224,72,62" : e.k === "age" ? "170,170,170" : "255,255,255";
      ctx.strokeStyle = "rgba(" + rgb + "," + (1 - u).toFixed(2) + ")";
      ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(e.x, e.y, 8 + 18 * u, 0, 6.2832); ctx.stroke();
    }

    // followed cell: marker and sensing range
    c = S.sel ? findCell(S.sel) : null;
    if (c) {
      if (p.sense > 0) { ctx.strokeStyle = "rgba(255,255,255,0.25)"; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(c.x, c.y, p.sense, 0, 6.2832); ctx.stroke(); }
      ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 1.5; ctx.setLineDash([4, 3]);
      ctx.beginPath(); ctx.arc(c.x, c.y, c.r + 6, 0, 6.2832); ctx.stroke(); ctx.setLineDash([]);
    }
  }

  function nice(v) {
    var e = Math.pow(10, Math.floor(Math.log(v) / Math.LN10)), f = v / e;
    return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * e;
  }

  function drawChart() {
    var w = ch.width, h = ch.height; if (!w) return;
    var dpr = w / ch.clientWidth, pad = { l: 40 * dpr, r: 12 * dpr, t: 14 * dpr, b: 34 * dpr };
    var pw = w - pad.l - pad.r, ph = h - pad.t - pad.b;
    var x1 = Math.max(WINDOW, S.s.t), x0 = x1 - WINDOW, hh = S.hist, i, v, ymax = 10, step, gx, gy, d;
    cx.setTransform(1, 0, 0, 1, 0, 0); cx.fillStyle = "#161616"; cx.fillRect(0, 0, w, h);
    for (i = 0; i < hh.length; i++) if (hh[i][0] >= x0) ymax = Math.max(ymax, hh[i][1], hh[i][2]);
    ymax = Math.max(10, nice(ymax * 1.08));
    cx.font = (11 * dpr) + "px 'DM Sans', Arial, sans-serif"; cx.lineWidth = dpr;
    cx.strokeStyle = "#2c2c2c"; cx.fillStyle = "#999"; cx.textAlign = "right";
    step = nice(ymax / 4);
    for (v = 0; v <= ymax + 1e-9; v += step) {
      gy = pad.t + ph - v / ymax * ph; cx.beginPath(); cx.moveTo(pad.l, gy); cx.lineTo(pad.l + pw, gy); cx.stroke();
      cx.fillText(String(Math.round(v)), pad.l - 6 * dpr, gy + 4 * dpr);
    }
    cx.textAlign = "center"; step = nice(WINDOW / 6);
    for (v = Math.ceil(x0 / step) * step; v <= x1 + 1e-9; v += step) {
      gx = pad.l + (v - x0) / WINDOW * pw; cx.fillText(String(Math.round(v)), gx, pad.t + ph + 16 * dpr);
    }
    cx.fillText("Seconds", pad.l + pw / 2, h - 4 * dpr);
    cx.save(); cx.translate(12 * dpr, pad.t + ph / 2); cx.rotate(-Math.PI / 2); cx.fillText("Count", 0, 0); cx.restore();

    function line(col, k) {
      var started = false, j, X, Y;
      cx.strokeStyle = col; cx.lineWidth = 2.2 * dpr; cx.lineJoin = "round"; cx.beginPath();
      for (j = 0; j < hh.length; j++) {
        d = hh[j]; if (d[0] < x0 - SAMPLE) continue;
        X = pad.l + (d[0] - x0) / WINDOW * pw; Y = pad.t + ph - d[k] / ymax * ph;
        if (started) cx.lineTo(X, Y); else cx.moveTo(X, Y);
        started = true;
      }
      cx.stroke();
    }
    cx.save(); cx.beginPath(); cx.rect(pad.l, pad.t, pw, ph); cx.clip();
    line(FOODC, 2); line(CELLS, 1); cx.restore();
    cx.font = (12 * dpr) + "px 'DM Sans', Arial, sans-serif"; cx.textAlign = "left";
    cx.fillStyle = CELLS; cx.fillRect(pad.l + 10 * dpr, pad.t + 8 * dpr, 14 * dpr, 3 * dpr); cx.fillText("Cells", pad.l + 30 * dpr, pad.t + 13 * dpr);
    cx.fillStyle = FOODC; cx.fillRect(pad.l + 80 * dpr, pad.t + 8 * dpr, 14 * dpr, 3 * dpr); cx.fillText("Food", pad.l + 100 * dpr, pad.t + 13 * dpr);
  }

  // ---------- readouts & UI ----------
  function updateStats() {
    var m = M.summary(S.p, S.s);
    $("s-n").textContent = m.n; $("s-f").textContent = m.food; $("s-t").textContent = S.s.t.toFixed(0);
    $("s-fed").textContent = m.n ? Math.round(m.fed * 100) + "%" : "–";
    $("s-b").textContent = S.s.births; $("s-st").textContent = S.s.starved; $("s-ag").textContent = S.s.aged;
    $("s-up").textContent = M.upkeep(S.p, 1).toFixed(2) + " /s";
    $("status").textContent = M.status(S.p, S.s);
  }
  function updateSel() {
    var c = S.sel ? findCell(S.sel) : null, show = !!c;
    $("sel-stats").hidden = !show; $("sel-e").hidden = !show; $("sel-e-label").hidden = !show;
    $("sel-msg").hidden = show;
    if (c) {
      $("sel-id").textContent = "#" + c.id; $("sel-stage").textContent = M.phase(c, S.p);
      $("sel-age").textContent = c.age.toFixed(0) + " s"; $("sel-size").textContent = (c.r * 2).toFixed(1);
      $("sel-e").value = Math.min(1, c.E / S.p.divide);
      return;
    }
    if (S.sel && !S.selGone) {
      S.selGone = S.s.watchFate === "starved" ? "starved" : S.s.watchFate === "age" ? "age" : "gone";
    }
    $("sel-msg").textContent =
      !S.sel ? "Click a cell in the dish to follow it." :
      S.selGone === "starved" ? "Cell #" + S.sel + " starved. Click another cell to follow it." :
      S.selGone === "age" ? "Cell #" + S.sel + " died of old age. Click another cell to follow it." :
      "Cell #" + S.sel + " is no longer in the dish. Click another cell to follow it.";
  }
  function syncUI() {
    KEYS.forEach(function (k) {
      var v = k === "n0" ? S.n0 : S.p[k];
      $("c-" + k).value = v; $("o-" + k).textContent = FMT[k](Number(v));
    });
  }
  function setRunning(on) { S.running = on; $("btn-play").textContent = on ? "Pause" : "Play"; $("btn-play").setAttribute("aria-pressed", String(on)); }
  function refresh() { updateStats(); updateSel(); drawDish(); drawChart(); }
  function tip() { if (!S.notified && window.Jenny) { S.notified = true; Jenny.notifyNewTip("single-cell"); } }

  function pick(ev) {
    var rect = cv.getBoundingClientRect(), wx = (ev.clientX - rect.left) / rect.width * M.W, wy = (ev.clientY - rect.top) / rect.height * M.H;
    var cells = S.s.cells, best = null, bd = Infinity, i, c, d, lim;
    for (i = 0; i < cells.length; i++) {
      c = cells[i]; d = Math.hypot(c.x - wx, c.y - wy); lim = Math.max(16, c.r + 8);
      if (d < lim && d < bd) { bd = d; best = c; }
    }
    if (best) select(best.id); else { S.sel = 0; S.selGone = ""; S.s.watch = 0; updateSel(); drawDish(); }
  }

  function bind() {
    KEYS.forEach(function (k) {
      $("c-" + k).addEventListener("input", function (ev) {
        var v = parseFloat(ev.target.value);
        if (k === "n0") { S.n0 = v; reset(); } else { S.p[k] = v; tip(); }
        $("o-" + k).textContent = FMT[k](v); refresh();
      });
    });
    $("btn-play").addEventListener("click", function () { setRunning(!S.running); });
    $("btn-step").addEventListener("click", function () { var i; setRunning(false); for (i = 0; i < 15; i++) advance(); refresh(); });
    $("btn-reset").addEventListener("click", function () { reset(); refresh(); });
    $("btn-follow").addEventListener("click", function () {
      var cells = S.s.cells; if (!cells.length) return;
      select(cells[Math.floor(Math.random() * cells.length)].id);
    });
    cv.addEventListener("click", pick);
    Array.prototype.forEach.call(document.querySelectorAll("[data-preset]"), function (b) {
      b.addEventListener("click", function () {
        var q = PRESETS[b.getAttribute("data-preset")];
        KEYS.forEach(function (k) { if (k === "n0") S.n0 = q.n0; else S.p[k] = q[k]; });
        syncUI(); reset(); refresh();
      });
    });
    var onResize = function () { fit(cv, M.W / M.H); fit(ch, 16 / 5); drawDish(); drawChart(); };
    if (window.ResizeObserver) { new ResizeObserver(onResize).observe(cv); new ResizeObserver(onResize).observe(ch); }
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
    }
    drawDish();
    statTimer += dt;
    if (statTimer > 0.2) { statTimer = 0; updateStats(); updateSel(); drawChart(); }
    requestAnimationFrame(frame);
  }

  Object.keys(PRESETS.balanced).forEach(function (k) { if (k === "n0") S.n0 = PRESETS.balanced.n0; else S.p[k] = PRESETS.balanced[k]; });
  reset(); syncUI(); bind(); setRunning(S.running); refresh();
  requestAnimationFrame(frame);
})();

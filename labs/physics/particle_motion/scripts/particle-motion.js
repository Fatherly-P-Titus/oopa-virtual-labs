/**
 * Particle Motion – 2D hard-disc gas simulation (OOPA Virtual Labs / Physics)
 *
 * World is a fixed 800 x 500 box (pixels = length units, mass = 1 for all discs);
 * it is scaled to whatever size the canvas has, so the physics never depends on
 * screen size. Physics runs on a fixed 1/120 s step, independent of frame rate.
 */
(function () {
  "use strict";

  var W = 800, H = 500, DT = 1 / 120, SPEED_K = 30;   // vrms = SPEED_K * sqrt(T)
  var NBINS = 24;

  var $ = function (id) { return document.getElementById(id); };
  var cv = $("sim"), ctx = cv.getContext("2d");
  var hv = $("hist"), hx = hv.getContext("2d");
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var PRESETS = {
    gas:    { n: 80,  T: 40, g: 0,   r: 6, e: 1,    collide: true },
    hot:    { n: 80,  T: 90, g: 0,   r: 6, e: 1,    collide: true },
    settle: { n: 120, T: 30, g: 400, r: 6, e: 0.82, collide: true }
  };

  var S = {
    p: [], n: 80, T: 40, g: 0, r: 6, e: 1, collide: true, trails: false,
    running: !reduce, scale: 1, acc: 0, last: 0, simT: 0,
    hits: 0, wallHits: 0, wallImp: 0,
    mark: { t: 0, hits: 0, imp: 0 }, nudged: false
  };

  // ---------- helpers ----------
  function gauss() {
    var u = 1 - Math.random(), v = Math.random();
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  }
  function vTarget() { return SPEED_K * Math.sqrt(S.T); }
  function rms() {
    var s = 0, p = S.p, i;
    for (i = 0; i < p.length; i++) s += p[i].vx * p[i].vx + p[i].vy * p[i].vy;
    return p.length ? Math.sqrt(s / p.length) : 0;
  }
  function rescaleTo(target) {
    var c = rms(), k, p = S.p, i;
    if (c < 1e-9) { for (i = 0; i < p.length; i++) { p[i].vx = gauss(); p[i].vy = gauss(); } c = rms(); }
    k = c > 0 ? target / c : 0;
    for (i = 0; i < p.length; i++) { p[i].vx *= k; p[i].vy *= k; }
  }
  function spawn() {
    var r = S.r, tries = 0, x, y, ok, j, s = vTarget() / Math.SQRT2;
    do {
      x = r + Math.random() * (W - 2 * r);
      y = r + Math.random() * (H - 2 * r);
      ok = true;
      for (j = 0; j < S.p.length && ok; j++) {
        var dx = S.p[j].x - x, dy = S.p[j].y - y;
        if (dx * dx + dy * dy < 4 * r * r) ok = false;
      }
    } while (!ok && ++tries < 60);
    S.p.push({ x: x, y: y, vx: gauss() * s, vy: gauss() * s });
  }
  function zeroMomentum() {
    var p = S.p, mx = 0, my = 0, i;
    if (!p.length) return;
    for (i = 0; i < p.length; i++) { mx += p[i].vx; my += p[i].vy; }
    mx /= p.length; my /= p.length;
    for (i = 0; i < p.length; i++) { p[i].vx -= mx; p[i].vy -= my; }
  }

  function reset() {
    S.p = [];
    for (var i = 0; i < S.n; i++) spawn();
    zeroMomentum();
    rescaleTo(vTarget());                 // exact starting temperature
    S.hits = S.wallHits = S.wallImp = 0; S.simT = 0;
    S.mark = { t: 0, hits: 0, imp: 0 };
    clearStage();
  }

  function setCount(n) {
    S.n = n;
    while (S.p.length < n) spawn();
    if (S.p.length > n) S.p.length = n;
  }

  // ---------- physics ----------
  function step(dt) {
    var p = S.p, n = p.length, r = S.r, g = S.g, e = S.e, i, j, a, b;

    var vw;
    for (i = 0; i < n; i++) {
      a = p[i];
      // exact free flight in a uniform field (y points down, so +g pulls toward the floor)
      a.x += a.vx * dt;
      a.y += a.vy * dt + 0.5 * g * dt * dt;
      a.vy += g * dt;
      if (a.x < r)          { a.x = r;     if (a.vx < 0) { S.wallImp += -(1 + e) * a.vx; S.wallHits++; a.vx = -a.vx * e; } }
      else if (a.x > W - r) { a.x = W - r; if (a.vx > 0) { S.wallImp +=  (1 + e) * a.vx; S.wallHits++; a.vx = -a.vx * e; } }
      // Floor / ceiling: place the particle on the wall and take its speed there from energy
      // conservation (v_wall^2 = v^2 + 2g(y_wall - y)), so an elastic bounce loses no energy.
      if (a.y > H - r) {
        vw = Math.sqrt(Math.max(0, a.vy * a.vy + 2 * g * ((H - r) - a.y)));
        a.y = H - r;
        if (a.vy > 0) { S.wallImp += (1 + e) * vw; S.wallHits++; a.vy = -vw * e; }
      } else if (a.y < r) {
        vw = Math.sqrt(Math.max(0, a.vy * a.vy + 2 * g * (r - a.y)));
        a.y = r;
        if (a.vy < 0) { S.wallImp += (1 + e) * vw; S.wallHits++; a.vy = vw * e; }
      }
    }

    if (!S.collide) return;
    var m = 2 * r, m2 = m * m, dx, dy, d2, d, nx, ny, vn, jn, ov;
    for (i = 0; i < n - 1; i++) {
      a = p[i];
      for (j = i + 1; j < n; j++) {
        b = p[j];
        dx = b.x - a.x; dy = b.y - a.y;
        if (dx > m || dx < -m || dy > m || dy < -m) continue;
        d2 = dx * dx + dy * dy;
        if (d2 >= m2) continue;
        if (d2 < 1e-12) { dx = 1e-3; dy = 0; d2 = 1e-6; }   // exactly stacked: nudge apart
        d = Math.sqrt(d2); nx = dx / d; ny = dy / d;
        vn = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (vn < 0) {                       // approaching: equal-mass impulse along the normal
          jn = -(1 + e) * vn / 2;
          a.vx -= jn * nx; a.vy -= jn * ny;
          b.vx += jn * nx; b.vy += jn * ny;
          S.hits++;
        }
        ov = (m - d) / 2;                   // push overlapping discs apart
        a.x -= nx * ov; a.y -= ny * ov; b.x += nx * ov; b.y += ny * ov;
      }
    }
  }

  function energy() {
    var p = S.p, ke = 0, pe = 0, i;
    for (i = 0; i < p.length; i++) {
      ke += 0.5 * (p[i].vx * p[i].vx + p[i].vy * p[i].vy);
      pe += S.g * (H - p[i].y);
    }
    return { ke: ke, pe: pe, total: ke + pe };
  }

  // ---------- drawing ----------
  function fit(c, ratio) {
    var dpr = Math.min(window.devicePixelRatio || 1, 2), w = Math.round(c.clientWidth * dpr);
    if (w && (c.width !== w)) { c.width = w; c.height = Math.round(w / ratio); }
  }
  function clearStage() { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = "#161616"; ctx.fillRect(0, 0, cv.width, cv.height); }

  function draw() {
    S.scale = cv.width / W;
    ctx.setTransform(S.scale, 0, 0, S.scale, 0, 0);
    ctx.fillStyle = S.trails ? "rgba(22,22,22,0.16)" : "#161616";
    ctx.fillRect(0, 0, W, H);
    var p = S.p, ref = 2 * Math.max(vTarget(), 1), i, a, t, rr, gg, bb;
    for (i = 0; i < p.length; i++) {
      a = p[i];
      t = Math.min(1, Math.sqrt(a.vx * a.vx + a.vy * a.vy) / ref);   // slow = steel blue, fast = red
      rr = Math.round(120 + 105 * t); gg = Math.round(150 - 107 * t); bb = Math.round(200 - 157 * t);
      ctx.fillStyle = "rgb(" + rr + "," + gg + "," + bb + ")";
      ctx.beginPath(); ctx.arc(a.x, a.y, S.r, 0, 6.2832); ctx.fill();
    }
  }

  function drawHist() {
    var w = hv.width, h = hv.height, p = S.p, n = p.length;
    if (!w) return;
    var dpr = w / hv.clientWidth, pad = { l: 34 * dpr, r: 8 * dpr, t: 8 * dpr, b: 26 * dpr };
    var pw = w - pad.l - pad.r, ph = h - pad.t - pad.b, i, k;
    hx.setTransform(1, 0, 0, 1, 0, 0); hx.clearRect(0, 0, w, h);
    if (!n) return;
    var vr = rms(), vmax = Math.max(3 * vr, 1), bw = vmax / NBINS, counts = [], peak = 1;
    for (i = 0; i < NBINS; i++) counts.push(0);
    for (i = 0; i < n; i++) { k = Math.floor(Math.sqrt(p[i].vx * p[i].vx + p[i].vy * p[i].vy) / bw); if (k < NBINS) counts[k]++; }
    var s2 = vr * vr / 2, curve = [];
    for (i = 0; i < NBINS; i++) {
      var v = (i + 0.5) * bw;
      curve.push(n * bw * (v / s2) * Math.exp(-v * v / (2 * s2)));
      peak = Math.max(peak, counts[i], curve[i]);
    }
    peak *= 1.1;
    hx.font = (11 * dpr) + "px 'DM Sans', Arial, sans-serif"; hx.fillStyle = "#777"; hx.strokeStyle = "#ddd"; hx.lineWidth = dpr;
    hx.beginPath(); hx.moveTo(pad.l, pad.t); hx.lineTo(pad.l, pad.t + ph); hx.lineTo(pad.l + pw, pad.t + ph); hx.stroke();
    hx.textAlign = "right"; hx.fillText(String(Math.round(peak)), pad.l - 5 * dpr, pad.t + 9 * dpr);
    hx.fillText("0", pad.l - 5 * dpr, pad.t + ph);
    hx.textAlign = "left"; hx.fillText("0", pad.l, h - 8 * dpr);
    hx.textAlign = "right"; hx.fillText(Math.round(vmax) + " px/s  (speed)", pad.l + pw, h - 8 * dpr);
    hx.fillStyle = "rgba(178,34,34,0.85)";
    var bwp = pw / NBINS;
    for (i = 0; i < NBINS; i++) { var bh = counts[i] / peak * ph; hx.fillRect(pad.l + i * bwp + 1, pad.t + ph - bh, bwp - 2, bh); }
    hx.strokeStyle = "#111"; hx.lineWidth = 2 * dpr; hx.setLineDash([6 * dpr, 4 * dpr]); hx.beginPath();
    for (i = 0; i < NBINS; i++) { var cx = pad.l + (i + 0.5) * bwp, cy = pad.t + ph - curve[i] / peak * ph; i ? hx.lineTo(cx, cy) : hx.moveTo(cx, cy); }
    hx.stroke(); hx.setLineDash([]);
  }

  // ---------- readouts ----------
  function fmt(v) {
    if (v >= 1e6) return (v / 1e6).toFixed(2) + "M";
    if (v >= 1e3) return (v / 1e3).toFixed(1) + "k";
    return v.toFixed(v < 10 ? 1 : 0);
  }
  function updateStats() {
    var p = S.p, n = p.length, sp = 0, i, en = energy(), dt = S.simT - S.mark.t;
    for (i = 0; i < n; i++) sp += Math.sqrt(p[i].vx * p[i].vx + p[i].vy * p[i].vy);
    $("s-avg").textContent = n ? fmt(sp / n) : "–";
    $("s-rms").textContent = n ? fmt(rms()) : "–";
    $("s-ke").textContent = fmt(en.ke);
    $("s-te").textContent = fmt(en.total);
    if (dt > 0.2) {
      $("s-col").textContent = fmt((S.hits - S.mark.hits) / dt);
      $("s-p").textContent = fmt((S.wallImp - S.mark.imp) / dt / (2 * (W + H)));   // momentum / s / wall length
      S.mark = { t: S.simT, hits: S.hits, imp: S.wallImp };
    }
  }

  // ---------- main loop ----------
  var statTimer = 0;
  function frame(ts) {
    if (!S.last) S.last = ts;
    var dt = Math.min(0.05, (ts - S.last) / 1000); S.last = ts;
    if (S.running) {
      S.acc += dt * parseFloat($("timescale").value);
      while (S.acc >= DT) { step(DT); S.acc -= DT; S.simT += DT; }
    }
    draw();
    statTimer += dt;
    if (statTimer > 0.25) { statTimer = 0; updateStats(); drawHist(); }
    requestAnimationFrame(frame);
  }

  // ---------- UI ----------
  var FMT = {
    n: function (v) { return String(v); }, T: function (v) { return String(v); },
    g: function (v) { return v === 0 ? "off" : String(v); }, r: function (v) { return v + " px"; },
    e: function (v) { return Number(v).toFixed(2); }
  };
  function syncUI() {
    ["n", "T", "g", "r", "e"].forEach(function (k) { $("c-" + k).value = S[k]; $("o-" + k).textContent = FMT[k](S[k]); });
    $("c-collide").checked = S.collide; $("c-trails").checked = S.trails;
  }
  function setRunning(on) {
    S.running = on; $("btn-play").textContent = on ? "Pause" : "Play"; $("btn-play").setAttribute("aria-pressed", String(on));
  }
  var notified = false;
  function tip() { if (!notified && window.Jenny) { notified = true; Jenny.notifyNewTip("particle-motion"); } }

  function bind() {
    ["n", "T", "g", "r", "e"].forEach(function (k) {
      $("c-" + k).addEventListener("input", function (ev) {
        var v = parseFloat(ev.target.value); S[k] = v; $("o-" + k).textContent = FMT[k](v);
        if (k === "n") setCount(v);
        else if (k === "T") rescaleTo(vTarget());
        if (k === "T" || k === "g") tip();
      });
    });
    $("c-collide").addEventListener("change", function (ev) { S.collide = ev.target.checked; });
    $("c-trails").addEventListener("change", function (ev) { S.trails = ev.target.checked; if (!S.trails) clearStage(); });
    $("btn-play").addEventListener("click", function () { setRunning(!S.running); });
    $("btn-step").addEventListener("click", function () { setRunning(false); for (var i = 0; i < 4; i++) { step(DT); S.simT += DT; } updateStats(); drawHist(); });
    $("btn-reset").addEventListener("click", function () { reset(); updateStats(); drawHist(); });
    Array.prototype.forEach.call(document.querySelectorAll("[data-preset]"), function (b) {
      b.addEventListener("click", function () { Object.assign(S, PRESETS[b.getAttribute("data-preset")]); syncUI(); reset(); updateStats(); drawHist(); });
    });
    var onResize = function () { fit(cv, 8 / 5); fit(hv, 3.4); clearStage(); drawHist(); };
    if (window.ResizeObserver) { new ResizeObserver(onResize).observe(cv); new ResizeObserver(onResize).observe(hv); }
    else window.addEventListener("resize", onResize);
    onResize();
  }

  function init() {
    Object.assign(S, PRESETS.gas);
    syncUI(); bind(); setRunning(S.running); reset(); updateStats(); drawHist();
    requestAnimationFrame(frame);
  }

  window.ParticleLab = { S: S, step: step, reset: reset, energy: energy, rms: rms, vTarget: vTarget, W: W, H: H, DT: DT };
  init();
})();

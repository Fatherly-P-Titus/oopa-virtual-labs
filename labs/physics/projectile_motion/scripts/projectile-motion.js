/**
 * Projectile Motion – OOPA Virtual Labs / Physics
 *
 * Physics (SI units, y up, x toward the target):
 *   a = ( -(c/m)|v_rel| v_rel.x ,  -g - (c/m)|v_rel| v_rel.y ),  v_rel = v - wind
 *   integrated with RK4 on a fixed 1/240 s step (independent of frame rate).
 *   Ground impacts are located by linear interpolation inside the step, so landing
 *   position and time are accurate to well under a millimetre.
 *   At impact: vy -> -e*vy, vx -> (1 - mu)*vx. Below a small bounce speed the
 *   projectile rolls, decelerating at mu*g, until it stops.
 * The "ideal" path is the textbook vacuum parabola from the same launch conditions.
 */
(function () {
  "use strict";

  var DT = 1 / 240, TMAX = 180, REST_V = 0.4, STOP_V = 0.02;
  var DEF = { v0: 25, angle: 45, h0: 0, g: 9.81, m: 1, c: 0, wind: 0, e: 0, mu: 1 };

  // ------------------------------------------------------------------ physics
  var ax = 0, ay = 0;
  function accel(P, vx, vy) {
    var rx = vx - P.wind, k = (P.c / P.m) * Math.sqrt(rx * rx + vy * vy);
    ax = -k * rx; ay = -P.g - k * vy;
  }

  function ideal(P) {
    var r = P.angle * Math.PI / 180, vx = P.v0 * Math.cos(r), vy = P.v0 * Math.sin(r);
    var T = (vy + Math.sqrt(vy * vy + 2 * P.g * P.h0)) / P.g;
    return { vx: vx, vy: vy, T: T, R: vx * T, H: P.h0 + (vy > 0 ? vy * vy / (2 * P.g) : 0) };
  }

  function newState(P) {
    var id = ideal(P);
    var s = { x: 0, y: P.h0, vx: id.vx, vy: id.vy, t: 0, maxY: P.h0, minX: 0, maxX: 0,
              landings: [], resting: false, done: false, reason: "" };
    if (P.h0 === 0 && id.vy <= 1e-9) s.resting = true;      // launched along the ground: rolls
    return s;
  }

  function rk4(P, s, dt) {
    var x = s.x, y = s.y, vx = s.vx, vy = s.vy, h = dt / 2;
    accel(P, vx, vy); var a1x = ax, a1y = ay;
    var v2x = vx + h * a1x, v2y = vy + h * a1y;
    accel(P, v2x, v2y); var a2x = ax, a2y = ay;
    var v3x = vx + h * a2x, v3y = vy + h * a2y;
    accel(P, v3x, v3y); var a3x = ax, a3y = ay;
    var v4x = vx + dt * a3x, v4y = vy + dt * a3y;
    accel(P, v4x, v4y); var a4x = ax, a4y = ay;
    s.x = x + dt / 6 * (vx + 2 * v2x + 2 * v3x + v4x);
    s.y = y + dt / 6 * (vy + 2 * v2y + 2 * v3y + v4y);
    s.vx = vx + dt / 6 * (a1x + 2 * a2x + 2 * a3x + a4x);
    s.vy = vy + dt / 6 * (a1y + 2 * a2y + 2 * a3y + a4y);
  }

  function advance(P, s, dt) {
    if (s.done) return;
    if (s.resting) {                                         // rolling on the ground
      var sgn = s.vx >= 0 ? 1 : -1, sp = Math.abs(s.vx), ns = Math.max(0, sp - P.mu * P.g * dt);
      s.x += sgn * (sp + ns) / 2 * dt; s.vx = sgn * ns; s.t += dt;
      if (ns < STOP_V) { s.vx = 0; s.done = true; s.reason = "rest"; }
    } else {
      var px = s.x, py = s.y, pvx = s.vx, pvy = s.vy;
      rk4(P, s, dt); s.t += dt;
      if (s.y < 0 && s.vy < 0) {                             // crossed the ground inside this step
        var al = py / (py - s.y); al = al < 0 ? 0 : al > 1 ? 1 : al;
        s.x = px + (s.x - px) * al; s.vx = pvx + (s.vx - pvx) * al; s.vy = pvy + (s.vy - pvy) * al;
        s.y = 0; s.t += (al - 1) * dt;
        s.landings.push({ x: s.x, t: s.t, speed: Math.sqrt(s.vx * s.vx + s.vy * s.vy) });
        s.vy = -P.e * s.vy; s.vx *= (1 - P.mu);
        if (s.vy < REST_V) {
          s.vy = 0; s.resting = true;
          if (Math.abs(s.vx) < STOP_V) { s.vx = 0; s.done = true; s.reason = "rest"; }
        }
      }
      if (!s.landings.length && s.y > s.maxY) s.maxY = s.y;  // "maximum height" = first flight
    }
    if (s.x > s.maxX) s.maxX = s.x;
    if (s.x < s.minX) s.minX = s.x;
    if (!s.done && s.t >= TMAX) { s.done = true; s.reason = "limit"; }
  }

  function energy(P, s) {
    var ke = 0.5 * P.m * (s.vx * s.vx + s.vy * s.vy), pe = P.m * P.g * s.y;
    return { ke: ke, pe: pe, total: ke + pe };
  }

  function simulate(p, maxT) {                               // headless run (used by tests)
    var Q = Object.assign({}, DEF, p), s = newState(Q), lim = maxT || TMAX;
    while (!s.done && s.t < lim) advance(Q, s, DT);
    return s;
  }

  // ------------------------------------------------------------------ UI
  var root = typeof window !== "undefined" ? window : globalThis;
  if (typeof document === "undefined" || !document.getElementById("sim")) {
    root.ProjectileLab = { DEF: DEF, DT: DT, ideal: ideal, newState: newState, advance: advance, energy: energy, simulate: simulate };
    return;
  }

  var $ = function (id) { return document.getElementById(id); };
  var cv = $("sim"), ctx = cv.getContext("2d"), ev = $("energy"), ex = ev.getContext("2d");

  var PRESETS = {
    max:    { v0: 30, angle: 45, h0: 0,  g: 9.81, m: 1, c: 0,    wind: 0, e: 0,   mu: 1 },
    moon:   { v0: 30, angle: 45, h0: 0,  g: 1.62, m: 1, c: 0,    wind: 0, e: 0,   mu: 1 },
    cliff:  { v0: 20, angle: 30, h0: 50, g: 9.81, m: 1, c: 0,    wind: 0, e: 0,   mu: 1 },
    drag:   { v0: 50, angle: 45, h0: 0,  g: 9.81, m: 1, c: 0.03, wind: 0, e: 0,   mu: 1 },
    bounce: { v0: 15, angle: 60, h0: 0,  g: 9.81, m: 1, c: 0,    wind: 0, e: 0.7, mu: 0.2 }
  };
  var P = Object.assign({}, DEF, PRESETS.max);
  var S = { mode: "ready", running: false, sim: null, acc: 0, last: 0, view: null, hist: { t: [], ke: [], pe: [] }, nextSample: 0, show: { ideal: true, arrow: true, trail: true }, trail: [], statT: 0 };

  var FMT = {
    v0: function (v) { return v + " m/s"; }, angle: function (v) { return v + "°"; }, h0: function (v) { return v + " m"; },
    g: function (v) { return Number(v).toFixed(2) + " m/s²"; }, c: function (v) { return v === 0 ? "none" : Number(v).toFixed(3) + " kg/m"; },
    wind: function (v) { return v === 0 ? "calm" : (v > 0 ? "+" : "") + v + " m/s"; }, m: function (v) { return Number(v).toFixed(1) + " kg"; },
    e: function (v) { return Number(v).toFixed(2); }, mu: function (v) { return Number(v).toFixed(2); }
  };
  var KEYS = ["v0", "angle", "h0", "g", "c", "wind", "m", "e", "mu"];

  function num(v, d) { return (Math.abs(v) < 0.005 ? 0 : v).toFixed(d === undefined ? 1 : d); }
  function setText(id, t) { $(id).textContent = t; }

  // ---- state transitions
  function status(t) { setText("status", t); cv.setAttribute("aria-label", "Projectile launch view. " + t); }
  function resetToReady(msg) {
    S.mode = "ready"; S.running = false; S.sim = newState(P); S.view = null; S.acc = 0;
    S.hist = { t: [], ke: [], pe: [] }; S.nextSample = 0; S.trail = [{ x: 0, y: P.h0 }];
    $("btn-go").textContent = "Launch";
    status(msg || "Ready. Set the launch conditions and press Launch.");
    sample(); updateReadouts();
  }
  function launch() {
    if (S.mode === "done") resetToReady();
    if (S.mode === "ready") { S.mode = "flying"; S.running = true; status("In flight…"); }
    else S.running = !S.running;
    $("btn-go").textContent = S.running ? "Pause" : "Resume";
  }
  function stepOnce() {
    if (S.mode === "done") return;
    if (S.mode === "ready") { S.mode = "flying"; status("Stepping…"); }
    S.running = false; $("btn-go").textContent = "Resume";
    for (var i = 0; i < 4; i++) tick();
    updateReadouts();
  }
  function finish() {
    S.mode = "done"; S.running = false; $("btn-go").textContent = "Launch again";
    var s = S.sim, l = s.landings[0], id = ideal(P), txt = "";
    if (l) txt = "First landing at x = " + num(l.x, 2) + " m after " + num(l.t, 2) + " s (ideal: " + num(id.R, 2) + " m). ";
    txt += s.reason === "limit" ? "Stopped at the 3-minute limit." : (s.landings.length ? "Came to rest at x = " + num(s.x, 2) + " m." : "Rolled to rest at x = " + num(s.x, 2) + " m.");
    status(txt);
  }

  // ---- stepping and sampling
  function sample() {
    var e = energy(P, S.sim); S.hist.t.push(S.sim.t); S.hist.ke.push(e.ke); S.hist.pe.push(e.pe);
    if (S.hist.t.length > 4000) { S.hist.t = S.hist.t.filter(thin); S.hist.ke = S.hist.ke.filter(thin); S.hist.pe = S.hist.pe.filter(thin); }
  }
  function thin(_, i) { return i % 2 === 0; }
  function tick() {
    var s = S.sim;
    advance(P, s, DT);
    if (s.t >= S.nextSample) { S.nextSample = s.t + 0.02; sample(); if (!s.resting) S.trail.push({ x: s.x, y: s.y }); }
    if (s.done) finish();
  }

  // ---- readouts
  function updateReadouts() {
    var s = S.sim, id = ideal(P), l = s.landings[0], sp = Math.sqrt(s.vx * s.vx + s.vy * s.vy);
    setText("s-t", s.t.toFixed(2) + " s"); setText("s-x", num(s.x, 1) + " m"); setText("s-y", num(s.y, 1) + " m");
    setText("s-vx", num(s.vx, 1) + " m/s"); setText("s-vy", num(s.vy, 1) + " m/s"); setText("s-sp", num(sp, 1) + " m/s");
    setText("c-r-sim", l ? num(l.x, 2) + " m" : "–"); setText("c-r-id", num(id.R, 2) + " m");
    setText("c-t-sim", l ? num(l.t, 2) + " s" : "–"); setText("c-t-id", num(id.T, 2) + " s");
    setText("c-h-sim", S.mode === "ready" ? "–" : num(s.maxY, 2) + " m"); setText("c-h-id", num(id.H, 2) + " m");
  }

  // ---- drawing helpers
  function niceStep(span) {
    var raw = span / 7, p = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10)), f = raw / p;
    return (f < 1.5 ? 1 : f < 3.5 ? 2 : f < 7.5 ? 5 : 10) * p;
  }
  // Match the canvas bitmap to its on-screen size (CSS controls the shape, so nothing is ever stretched)
  function fit(c) {
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    var w = Math.round(c.clientWidth * dpr), h = Math.round(c.clientHeight * dpr);
    if (w && h && (c.width !== w || c.height !== h)) { c.width = w; c.height = h; }
    return dpr;
  }
  function updateView() {
    var id = ideal(P), s = S.sim;
    var v = { xmin: Math.min(0, s.minX), xmax: Math.max(id.R, s.maxX, 10) * 1.06, ymax: Math.max(id.H, s.maxY, P.h0, 5) * 1.15 };
    if (S.view && S.mode !== "ready") {                         // while flying the view only ever zooms out
      v = { xmin: Math.min(v.xmin, S.view.xmin), xmax: Math.max(v.xmax, S.view.xmax), ymax: Math.max(v.ymax, S.view.ymax) };
    }
    S.view = v;
  }

  function draw() {
    var u = cv.width / 820, W = cv.width, H = cv.height;
    var pl = 58 * u, pr = 18 * u, pt = 18 * u, pb = 36 * u;
    updateView();
    var V = S.view, scale = Math.min((W - pl - pr) / (V.xmax - V.xmin), (H - pt - pb) / V.ymax);
    var ox = pl - V.xmin * scale, oy = H - pb;
    var X = function (x) { return ox + x * scale; }, Y = function (y) { return oy - y * scale; };

    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = "#161616"; ctx.fillRect(0, 0, W, H);
    ctx.font = (11 * u) + "px 'DM Sans', Arial, sans-serif";

    // grid + axis labels
    var sx = niceStep(V.xmax - V.xmin), sy = niceStep(V.ymax), t;
    ctx.lineWidth = u; ctx.strokeStyle = "#262626"; ctx.fillStyle = "#8a8a8a"; ctx.textAlign = "center";
    for (t = Math.ceil(V.xmin / sx) * sx; t <= V.xmax + 1e-9; t += sx) {
      ctx.beginPath(); ctx.moveTo(X(t), pt); ctx.lineTo(X(t), oy); ctx.stroke();
      ctx.fillText(+t.toFixed(6) + "", X(t), oy + 16 * u);
    }
    ctx.textAlign = "right";
    for (t = 0; t <= V.ymax + 1e-9; t += sy) {
      ctx.beginPath(); ctx.moveTo(pl, Y(t)); ctx.lineTo(W - pr, Y(t)); ctx.stroke();
      ctx.fillText(+t.toFixed(6) + "", pl - 8 * u, Y(t) + 4 * u);
    }
    ctx.textAlign = "left"; ctx.fillText("m", W - pr - 14 * u, oy + 30 * u);
    ctx.fillStyle = "#1f1f1f"; ctx.fillRect(0, oy, W, H - oy);                  // below ground
    ctx.strokeStyle = "#6b6b6b"; ctx.lineWidth = 2 * u; ctx.beginPath(); ctx.moveTo(0, oy); ctx.lineTo(W, oy); ctx.stroke();

    // launch tower
    if (P.h0 > 0) { ctx.fillStyle = "#3a3a3a"; ctx.fillRect(X(0) - 9 * u, Y(P.h0), 9 * u, P.h0 * scale); }

    // ideal path
    if (S.show.ideal) {
      var id = ideal(P), n = 140, i, tt;
      ctx.strokeStyle = "#8a8a8a"; ctx.lineWidth = 1.5 * u; ctx.setLineDash([6 * u, 5 * u]); ctx.beginPath();
      for (i = 0; i <= n; i++) { tt = id.T * i / n; var px = id.vx * tt, py = P.h0 + id.vy * tt - 0.5 * P.g * tt * tt; i ? ctx.lineTo(X(px), Y(Math.max(0, py))) : ctx.moveTo(X(px), Y(py)); }
      ctx.stroke(); ctx.setLineDash([]);
    }

    // trail
    var tr = S.trail;
    if (S.show.trail && tr.length > 1) {
      ctx.strokeStyle = "#e14a4a"; ctx.lineWidth = 2.5 * u; ctx.lineJoin = "round"; ctx.beginPath();
      for (var k = 0; k < tr.length; k++) k ? ctx.lineTo(X(tr[k].x), Y(tr[k].y)) : ctx.moveTo(X(tr[k].x), Y(tr[k].y));
      ctx.lineTo(X(S.sim.x), Y(S.sim.y)); ctx.stroke();
    }

    // landing markers
    ctx.textAlign = "center"; ctx.fillStyle = "#f0b34a"; ctx.strokeStyle = "#f0b34a"; ctx.lineWidth = 2 * u;
    S.sim.landings.slice(0, 8).forEach(function (l, j) {
      ctx.beginPath(); ctx.moveTo(X(l.x), oy - 7 * u); ctx.lineTo(X(l.x), oy + 7 * u); ctx.stroke();
      if (j < 3) ctx.fillText(num(l.x, 1) + " m", X(l.x), oy - 12 * u - (j % 2) * 13 * u);
    });

    // projectile and velocity arrow
    var s = S.sim, cx = X(s.x), cy = Y(s.y);
    if (S.show.arrow && !s.resting) {
      var sp = Math.sqrt(s.vx * s.vx + s.vy * s.vy), len = Math.min(90 * u, sp * 2 * u);
      if (len > 6 * u) {
        var dx = s.vx / sp * len, dy = -s.vy / sp * len, ang = Math.atan2(dy, dx);
        ctx.strokeStyle = "#7fd1a8"; ctx.fillStyle = "#7fd1a8"; ctx.lineWidth = 2 * u;
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + dx, cy + dy); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(cx + dx, cy + dy);
        ctx.lineTo(cx + dx - 9 * u * Math.cos(ang - 0.45), cy + dy - 9 * u * Math.sin(ang - 0.45));
        ctx.lineTo(cx + dx - 9 * u * Math.cos(ang + 0.45), cy + dy - 9 * u * Math.sin(ang + 0.45)); ctx.closePath(); ctx.fill();
      }
    }
    ctx.fillStyle = "#b22222"; ctx.strokeStyle = "#fff"; ctx.lineWidth = 2 * u;
    ctx.beginPath(); ctx.arc(cx, cy, 6.5 * u, 0, 6.2832); ctx.fill(); ctx.stroke();
  }

  function drawEnergy() {
    var dpr = fit(ev); var w = ev.width, h = ev.height, hs = S.hist;
    if (!w) return;
    var pad = { l: 46 * dpr, r: 10 * dpr, t: 10 * dpr, b: 26 * dpr }, pw = w - pad.l - pad.r, ph = h - pad.t - pad.b, i;
    ex.setTransform(1, 0, 0, 1, 0, 0); ex.clearRect(0, 0, w, h);
    var n = hs.t.length, tmax = Math.max(1, n ? hs.t[n - 1] : 1), emax = 1, tot = [];
    for (i = 0; i < n; i++) { tot.push(hs.ke[i] + hs.pe[i]); emax = Math.max(emax, tot[i]); }
    emax *= 1.08;
    ex.font = (11 * dpr) + "px 'DM Sans', Arial, sans-serif"; ex.fillStyle = "#777"; ex.strokeStyle = "#ddd"; ex.lineWidth = dpr;
    ex.beginPath(); ex.moveTo(pad.l, pad.t); ex.lineTo(pad.l, pad.t + ph); ex.lineTo(pad.l + pw, pad.t + ph); ex.stroke();
    ex.textAlign = "right"; ex.fillText(emax >= 1000 ? (emax / 1000).toFixed(1) + " kJ" : Math.round(emax) + " J", pad.l - 5 * dpr, pad.t + 9 * dpr); ex.fillText("0", pad.l - 5 * dpr, pad.t + ph);
    ex.textAlign = "left"; ex.fillText("0", pad.l, h - 8 * dpr); ex.textAlign = "right"; ex.fillText(tmax.toFixed(1) + " s", pad.l + pw, h - 8 * dpr);
    if (n < 2) return;
    var line = function (arr, col, wd, dash) {
      ex.strokeStyle = col; ex.lineWidth = wd * dpr; ex.setLineDash(dash || []); ex.beginPath();
      for (var j = 0; j < n; j++) { var px = pad.l + hs.t[j] / tmax * pw, py = pad.t + ph - arr[j] / emax * ph; j ? ex.lineTo(px, py) : ex.moveTo(px, py); }
      ex.stroke(); ex.setLineDash([]);
    };
    line(hs.pe, "#4a78b5", 2); line(hs.ke, "#b22222", 2); line(tot, "#111", 2, [6 * dpr, 4 * dpr]);
  }

  // ---- main loop
  function frame(ts) {
    if (!S.last) S.last = ts;
    var dt = Math.min(0.05, (ts - S.last) / 1000); S.last = ts;
    if (S.running) {
      S.acc += dt * parseFloat($("timescale").value);
      var guard = 0;
      while (S.acc >= DT && S.running && guard++ < 2000) { tick(); S.acc -= DT; }
    }
    draw();
    S.statT += dt;
    if (S.statT > 0.1) { S.statT = 0; updateReadouts(); drawEnergy(); }
    requestAnimationFrame(frame);
  }

  // ---- controls
  function planetFor(g) {
    var opts = $("sel-planet").options;
    for (var i = 0; i < opts.length; i++) if (opts[i].value !== "custom" && Math.abs(parseFloat(opts[i].value) - g) < 0.005) return opts[i].value;
    return "custom";
  }
  function syncUI() {
    KEYS.forEach(function (k) { $("c-" + k).value = P[k]; setText("o-" + k, FMT[k](P[k])); });
    $("sel-planet").value = planetFor(P.g);
    $("c-ideal").checked = S.show.ideal; $("c-arrow").checked = S.show.arrow; $("c-trail").checked = S.show.trail;
  }
  function bind() {
    KEYS.forEach(function (k) {
      $("c-" + k).addEventListener("input", function (e) {
        P[k] = parseFloat(e.target.value); setText("o-" + k, FMT[k](P[k]));
        if (k === "g") $("sel-planet").value = planetFor(P.g);
        if (k === "v0" || k === "angle" || k === "h0") resetToReady();     // launch conditions: start over
        else if (S.mode === "ready") { S.sim = newState(P); updateReadouts(); }
      });
    });
    $("sel-planet").addEventListener("change", function (e) {
      if (e.target.value === "custom") return;
      P.g = parseFloat(e.target.value); $("c-g").value = P.g; setText("o-g", FMT.g(P.g));
      if (S.mode === "ready") { S.sim = newState(P); updateReadouts(); }
    });
    $("c-ideal").addEventListener("change", function (e) { S.show.ideal = e.target.checked; });
    $("c-arrow").addEventListener("change", function (e) { S.show.arrow = e.target.checked; });
    $("c-trail").addEventListener("change", function (e) { S.show.trail = e.target.checked; });
    $("btn-go").addEventListener("click", launch);
    $("btn-step").addEventListener("click", stepOnce);
    $("btn-reset").addEventListener("click", function () { resetToReady(); });
    Array.prototype.forEach.call(document.querySelectorAll("[data-preset]"), function (b) {
      b.addEventListener("click", function () { Object.assign(P, PRESETS[b.getAttribute("data-preset")]); syncUI(); resetToReady(); });
    });
    document.addEventListener("keydown", function (e) {
      var t = e.target && e.target.tagName;
      if (t === "INPUT" || t === "SELECT" || t === "BUTTON" || t === "TEXTAREA" || e.ctrlKey || e.metaKey || e.altKey) return;
      if (e.key === " ") { e.preventDefault(); launch(); }
      else if (e.key === "s" || e.key === "S") stepOnce();
      else if (e.key === "r" || e.key === "R") resetToReady();
    });
    var onResize = function () { fit(cv); drawEnergy(); };
    if (window.ResizeObserver) { new ResizeObserver(onResize).observe(cv); new ResizeObserver(onResize).observe(ev); }
    else window.addEventListener("resize", onResize);
    onResize();
  }

  function init() {
    syncUI(); bind(); resetToReady();
    requestAnimationFrame(frame);
  }

  root.ProjectileLab = { P: P, S: S, DEF: DEF, DT: DT, ideal: ideal, newState: newState, advance: advance, energy: energy, simulate: simulate };
  init();
})();

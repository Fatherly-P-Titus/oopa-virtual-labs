/**
 * Spring–Mass–Damper UI – animation + strip chart.
 */
(function () {
  "use strict";

  var model = new SMDModel({ m: 1, k: 40, c: 2, x0: 0.25, v0: 0, F0: 0, omega: 5 });
  var running = true;
  var lastFrame = 0;
  var reducedMotion = false;
  try {
    reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  } catch (e) { /* ignore */ }
  if (reducedMotion) running = false;

  var canvas = document.getElementById("smd-canvas");
  var ctx = canvas.getContext("2d");
  var plot = document.getElementById("plot-canvas");
  var pctx = plot.getContext("2d");
  var hintEl = document.getElementById("hint-bar");

  var DT = 1 / 120; // physics step
  var TIME_SCALE = 1;

  function setHint(t) { if (hintEl) hintEl.textContent = t; }
  function setText(id, t) {
    var el = document.getElementById(id);
    if (el) el.textContent = t;
  }
  function fmt(n, d) {
    if (n == null || !isFinite(n)) return "–";
    return Number(n).toFixed(d == null ? 2 : d);
  }

  function resize() {
    var dpr = window.devicePixelRatio || 1;
    function fit(c, h) {
      var rect = c.getBoundingClientRect();
      c.width = Math.max(320, Math.floor(rect.width * dpr));
      c.height = Math.floor(h * dpr);
      c.getContext("2d").setTransform(dpr, 0, 0, dpr, 0, 0);
    }
    fit(canvas, 200);
    fit(plot, 200);
  }

  function drawAnim() {
    var w = canvas.clientWidth || 640;
    var h = 200;
    ctx.clearRect(0, 0, w, h);

    var wallX = 40;
    var eqY = h * 0.55;
    var scale = 120; // px per metre
    var massX = wallX + 100 + model.x * scale;
    massX = Math.max(wallX + 50, Math.min(w - 60, massX));

    // Wall
    ctx.fillStyle = "#1b1b1b";
    ctx.fillRect(wallX - 8, 30, 8, h - 60);
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 2;
    for (var i = 0; i < 8; i++) {
      ctx.beginPath();
      ctx.moveTo(wallX - 8, 35 + i * 18);
      ctx.lineTo(wallX - 20, 45 + i * 18);
      ctx.stroke();
    }

    // Spring (zigzag)
    var sx0 = wallX;
    var sx1 = massX - 28;
    var coils = 10;
    ctx.strokeStyle = "#555";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(sx0, eqY);
    var span = sx1 - sx0;
    for (var c = 0; c < coils; c++) {
      var x1 = sx0 + ((c + 0.25) / coils) * span;
      var x2 = sx0 + ((c + 0.75) / coils) * span;
      var yOff = (c % 2 === 0 ? -14 : 14);
      ctx.lineTo(x1, eqY + yOff);
      ctx.lineTo(x2, eqY - yOff);
    }
    ctx.lineTo(sx1, eqY);
    ctx.stroke();

    // Damper (dashpot under spring)
    var dy = eqY + 28;
    ctx.strokeStyle = "#1565c0";
    ctx.lineWidth = 2;
    ctx.strokeRect(wallX + 10, dy - 8, 36, 16);
    ctx.beginPath();
    ctx.moveTo(wallX + 28, dy);
    ctx.lineTo(massX - 28, dy);
    ctx.stroke();
    ctx.fillStyle = "#1565c0";
    ctx.fillRect(massX - 36, dy - 6, 10, 12);

    // Mass
    ctx.fillStyle = "#b22222";
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 2;
    ctx.fillRect(massX - 28, eqY - 24, 56, 48);
    ctx.strokeRect(massX - 28, eqY - 24, 56, 48);
    ctx.fillStyle = "#fff";
    ctx.font = "700 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("m", massX, eqY);

    // Equilibrium line
    ctx.strokeStyle = "rgba(0,0,0,0.15)";
    ctx.setLineDash([4, 4]);
    ctx.beginPath();
    ctx.moveTo(wallX + 100, 20);
    ctx.lineTo(wallX + 100, h - 20);
    ctx.stroke();
    ctx.setLineDash([]);

    // Displacement readout
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("x = " + fmt(model.x, 3) + " m", 16, 22);
    ctx.fillText("t = " + fmt(model.t, 2) + " s", 16, 40);
  }

  function drawPlot() {
    var w = plot.clientWidth || 640;
    var h = 200;
    pctx.clearRect(0, 0, w, h);

    var hist = model.history;
    if (hist.length < 2) return;

    var tMax = hist[hist.length - 1].t;
    var tMin = Math.max(0, tMax - 8);
    var xMax = 0.05;
    hist.forEach(function (p) {
      if (p.t >= tMin) xMax = Math.max(xMax, Math.abs(p.x));
    });
    xMax *= 1.15;

    function tx(t) { return ((t - tMin) / (tMax - tMin + 1e-9)) * (w - 40) + 30; }
    function ty(x) { return h / 2 - (x / xMax) * (h / 2 - 20); }

    // Axes
    pctx.strokeStyle = "#ddd";
    pctx.lineWidth = 1;
    pctx.beginPath();
    pctx.moveTo(30, h / 2);
    pctx.lineTo(w - 10, h / 2);
    pctx.stroke();

    pctx.strokeStyle = "#b22222";
    pctx.lineWidth = 2;
    pctx.beginPath();
    var started = false;
    hist.forEach(function (p) {
      if (p.t < tMin) return;
      var x = tx(p.t), y = ty(p.x);
      if (!started) { pctx.moveTo(x, y); started = true; }
      else pctx.lineTo(x, y);
    });
    pctx.stroke();

    pctx.fillStyle = "#666";
    pctx.font = "600 10px DM Sans, Arial, sans-serif";
    pctx.textAlign = "left";
    pctx.fillText("x(t)", 8, 16);
    pctx.textAlign = "right";
    pctx.fillText(fmt(xMax, 2) + " m", w - 12, 16);
  }

  function updateReadouts() {
    var wn = model.wn();
    var z = model.zeta();
    setText("s-wn", fmt(wn, 2) + " rad/s");
    setText("s-fn", fmt(wn / (2 * Math.PI), 2) + " Hz");
    setText("s-zeta", fmt(z, 3));
    setText("s-regime", model.regime());
    setText("s-x", fmt(model.x, 3) + " m");
    setText("s-v", fmt(model.v, 3) + " m/s");
    if (model.F0 > 0) {
      setText("s-amp", fmt(model.steadyAmplitude(), 3) + " m");
    } else {
      setText("s-amp", "–");
    }
  }

  function tick(now) {
    if (!lastFrame) lastFrame = now;
    var elapsed = (now - lastFrame) / 1000;
    lastFrame = now;

    if (running) {
      var steps = Math.min(8, Math.floor((elapsed * TIME_SCALE) / DT) + 1);
      for (var i = 0; i < steps; i++) model.step(DT);
    }
    drawAnim();
    drawPlot();
    updateReadouts();
    requestAnimationFrame(tick);
  }

  function syncSliders() {
    setSlider("c-m", model.m, " kg");
    setSlider("c-k", model.k, " N/m");
    setSlider("c-c", model.c, " N·s/m");
    setSlider("c-F0", model.F0, " N");
    setSlider("c-omega", model.omega, " rad/s");
  }

  function setSlider(id, val, unit) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out) out.textContent = (id === "c-m" || id === "c-k" || id === "c-c" || id === "c-F0" || id === "c-omega"
      ? Number(val).toFixed(id === "c-m" ? 2 : 1) : val) + (unit || "");
  }

  function applyParams() {
    // Live params; don't reset position mid-run unless user hits Reset
    syncSliders();
  }

  function bind() {
    function bindRange(id, key) {
      var el = document.getElementById(id);
      if (!el) return;
      el.addEventListener("input", function () {
        var v = parseFloat(el.value);
        if (!isFinite(v)) return;
        model[key] = v;
        setSlider(id, v, id === "c-m" ? " kg" : id === "c-k" ? " N/m" : id === "c-c" ? " N·s/m" : id === "c-F0" ? " N" : " rad/s");
      });
    }
    bindRange("c-m", "m");
    bindRange("c-k", "k");
    bindRange("c-c", "c");
    bindRange("c-F0", "F0");
    bindRange("c-omega", "omega");

    document.getElementById("btn-play").addEventListener("click", function () {
      running = !running;
      this.textContent = running ? "Pause" : "Play";
    });
    document.getElementById("btn-reset").addEventListener("click", function () {
      model.reset(0.25, 0);
      drawAnim();
      drawPlot();
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        if (p === "under") {
          model.m = 1; model.k = 40; model.c = 2; model.F0 = 0;
          model.reset(0.3, 0);
          setHint("Underdamped free vibration — oscillates while decaying.");
        } else if (p === "critical") {
          model.m = 1; model.k = 40; model.c = 2 * Math.sqrt(40); model.F0 = 0;
          model.reset(0.3, 0);
          setHint("Critically damped — fastest return without oscillating.");
        } else if (p === "over") {
          model.m = 1; model.k = 40; model.c = 20; model.F0 = 0;
          model.reset(0.3, 0);
          setHint("Overdamped — slow return, no oscillation.");
        } else if (p === "forced") {
          model.m = 1; model.k = 40; model.c = 1.5; model.F0 = 8; model.omega = model.wn();
          model.reset(0, 0);
          setHint("Forced at ω ≈ ωn — resonance builds a large amplitude.");
        } else if (p === "offres") {
          model.m = 1; model.k = 40; model.c = 1.5; model.F0 = 8; model.omega = 2;
          model.reset(0, 0);
          setHint("Forced well below resonance — smaller steady amplitude.");
        }
        syncSliders();
        running = true;
        document.getElementById("btn-play").textContent = "Pause";
      });
    });

    window.addEventListener("resize", function () { resize(); drawAnim(); drawPlot(); });
  }

  function init() {
    bind();
    resize();
    model.reset(0.25, 0);
    syncSliders();
    setHint("Underdamped free vibration by default. Try the presets for critical, overdamped and forced response.");
    requestAnimationFrame(tick);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

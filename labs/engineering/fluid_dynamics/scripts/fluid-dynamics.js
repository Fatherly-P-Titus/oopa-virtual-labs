/**
 * Fluid Dynamics UI – venturi / pipe Bernoulli demo.
 */
(function () {
  "use strict";

  var model = new FluidModel();
  var canvas = document.getElementById("fluid-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");
  var particles = [];
  var lastT = 0;
  var running = true;

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
    var rect = canvas.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(320, Math.floor(rect.width * dpr));
    canvas.height = Math.floor(420 * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  // Pipe geometry in canvas coords
  function pipeLayout(w, h) {
    var left = 50, right = w - 50;
    var midY = h * 0.42;
    var scale = 900; // px per metre for diameter
    var r1 = (model.D1 / 2) * scale;
    var r2 = (model.D2 / 2) * scale;
    r1 = Math.max(18, Math.min(70, r1));
    r2 = Math.max(8, Math.min(50, r2));
    var x1 = left + (right - left) * 0.22;
    var x2 = left + (right - left) * 0.55;
    var x3 = left + (right - left) * 0.85;
    return { left: left, right: right, midY: midY, r1: r1, r2: r2, x1: x1, x2: x2, x3: x3 };
  }

  function radiusAt(x, lay) {
    // piecewise: wide - taper - throat - taper - wide
    if (x <= lay.x1) return lay.r1;
    if (x >= lay.x3) return lay.r1;
    if (x >= lay.x2 - 20 && x <= lay.x2 + 20) return lay.r2;
    if (x < lay.x2) {
      var t = (x - lay.x1) / (lay.x2 - 20 - lay.x1);
      return lay.r1 + (lay.r2 - lay.r1) * Math.max(0, Math.min(1, t));
    }
    var t2 = (x - (lay.x2 + 20)) / (lay.x3 - lay.x2 - 20);
    return lay.r2 + (lay.r1 - lay.r2) * Math.max(0, Math.min(1, t2));
  }

  function draw() {
    var w = canvas.clientWidth || 640;
    var h = 420;
    ctx.clearRect(0, 0, w, h);
    var res = model.solve();
    var lay = pipeLayout(w, h);

    // Pipe outline
    ctx.fillStyle = "#bbdefb";
    ctx.strokeStyle = "#1565c0";
    ctx.lineWidth = 2;
    ctx.beginPath();
    // top wall
    for (var x = lay.left; x <= lay.right; x += 2) {
      var r = radiusAt(x, lay);
      if (x === lay.left) ctx.moveTo(x, lay.midY - r);
      else ctx.lineTo(x, lay.midY - r);
    }
    // bottom wall reverse
    for (var x = lay.right; x >= lay.left; x -= 2) {
      var r = radiusAt(x, lay);
      ctx.lineTo(x, lay.midY + r);
    }
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    // Station markers
    function station(x, r, label, p, v) {
      ctx.strokeStyle = "#b22222";
      ctx.lineWidth = 1.5;
      ctx.setLineDash([3, 3]);
      ctx.beginPath();
      ctx.moveTo(x, lay.midY - r - 30);
      ctx.lineTo(x, lay.midY + r + 10);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = "#1b1b1b";
      ctx.font = "700 12px DM Sans, Arial, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(label, x, lay.midY - r - 38);
      ctx.font = "600 11px DM Sans, Arial, sans-serif";
      ctx.fillStyle = "#1565c0";
      ctx.fillText("v=" + fmt(v, 2) + " m/s", x, lay.midY + r + 28);
      ctx.fillStyle = "#b22222";
      ctx.fillText("p=" + fmt(p / 1000, 1) + " kPa", x, lay.midY + r + 44);
    }
    station(lay.x1, lay.r1, "① Inlet", res.p1, res.v1);
    station(lay.x2, lay.r2, "② Throat", res.p2, res.v2);

    // Diameter labels
    ctx.fillStyle = "#666";
    ctx.font = "600 10px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("D₁=" + fmt(model.D1 * 1000, 0) + " mm", lay.x1, lay.midY + lay.r1 + 60);
    ctx.fillText("D₂=" + fmt(model.D2 * 1000, 0) + " mm", lay.x2, lay.midY + lay.r2 + 60);

    // Particles
    particles.forEach(function (p) {
      var r = radiusAt(p.x, lay);
      var yy = lay.midY + p.frac * r * 0.7;
      ctx.beginPath();
      ctx.arc(p.x, yy, 2.5, 0, Math.PI * 2);
      ctx.fillStyle = "rgba(21,101,192,0.7)";
      ctx.fill();
    });

    // Flow arrow
    ctx.fillStyle = "#1565c0";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Q = " + fmt(res.Q * 1000, 2) + " L/s  →", lay.left, 28);

    updateReadouts(res);
  }

  function updateReadouts(res) {
    setText("s-v1", fmt(res.v1, 2) + " m/s");
    setText("s-v2", fmt(res.v2, 2) + " m/s");
    setText("s-p1", fmt(res.p1 / 1000, 1) + " kPa");
    setText("s-p2", fmt(res.p2 / 1000, 1) + " kPa");
    setText("s-Q", fmt(res.Q * 1000, 2) + " L/s");
    setText("s-hL", fmt(res.hL * 1000, 2) + " mm");
    setText("s-H1", fmt(res.H1, 3) + " m");
    setText("s-H2", fmt(res.H2, 3) + " m");
    var ratio = res.v1 > 1e-9 ? res.v2 / res.v1 : 0;
    setText("s-ratio", fmt(ratio, 2));
  }

  function spawnParticle(lay) {
    particles.push({
      x: lay.left + 4,
      frac: (Math.random() - 0.5) * 1.6
    });
  }

  function tick(t) {
    if (!lastT) lastT = t;
    var dt = Math.min(0.05, (t - lastT) / 1000);
    lastT = t;
    if (running) {
      var w = canvas.clientWidth || 640;
      var h = 420;
      var lay = pipeLayout(w, h);
      var res = model.solve();
      // speed scale for animation
      var baseSpeed = 80 + res.v1 * 40;
      for (var i = particles.length - 1; i >= 0; i--) {
        var p = particles[i];
        var r = radiusAt(p.x, lay);
        var localV = res.v1 * (lay.r1 / Math.max(r, 1));
        p.x += baseSpeed * (localV / Math.max(res.v1, 0.1)) * dt;
        if (p.x > lay.right - 4) particles.splice(i, 1);
      }
      if (particles.length < 40 && Math.random() < 0.4) spawnParticle(lay);
    }
    draw();
    requestAnimationFrame(tick);
  }

  function syncSliders() {
    setSlider("c-D1", model.D1 * 1000, function (v) { return fmt(v, 0) + " mm"; });
    setSlider("c-D2", model.D2 * 1000, function (v) { return fmt(v, 0) + " mm"; });
    setSlider("c-Q", model.Q * 1000, function (v) { return fmt(v, 1) + " L/s"; });
    setSlider("c-p1", model.p1 / 1000, function (v) { return fmt(v, 0) + " kPa"; });
    setSlider("c-f", model.f, function (v) { return fmt(v, 3); });
    setSlider("c-z2", model.z2, function (v) { return fmt(v, 2) + " m"; });
  }

  function setSlider(id, val, fmtFn) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out && fmtFn) out.textContent = fmtFn(val);
  }

  function bind() {
    document.getElementById("c-D1").addEventListener("input", function () {
      model.D1 = parseFloat(this.value) / 1000;
      setSlider("c-D1", this.value, function (v) { return fmt(v, 0) + " mm"; });
    });
    document.getElementById("c-D2").addEventListener("input", function () {
      model.D2 = parseFloat(this.value) / 1000;
      setSlider("c-D2", this.value, function (v) { return fmt(v, 0) + " mm"; });
    });
    document.getElementById("c-Q").addEventListener("input", function () {
      model.Q = parseFloat(this.value) / 1000;
      setSlider("c-Q", this.value, function (v) { return fmt(v, 1) + " L/s"; });
    });
    document.getElementById("c-p1").addEventListener("input", function () {
      model.p1 = parseFloat(this.value) * 1000;
      setSlider("c-p1", this.value, function (v) { return fmt(v, 0) + " kPa"; });
    });
    document.getElementById("c-f").addEventListener("input", function () {
      model.f = parseFloat(this.value);
      setSlider("c-f", this.value, function (v) { return fmt(v, 3); });
    });
    document.getElementById("c-z2").addEventListener("input", function () {
      model.z2 = parseFloat(this.value);
      setSlider("c-z2", this.value, function (v) { return fmt(v, 2) + " m"; });
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        if (p === "venturi") {
          model.D1 = 0.08; model.D2 = 0.04; model.Q = 0.006; model.p1 = 150e3; model.f = 0; model.z2 = 0;
          setHint("Classic venturi: speed rises at the throat, pressure falls.");
        } else if (p === "wide") {
          model.D1 = 0.1; model.D2 = 0.08; model.Q = 0.004; model.p1 = 120e3; model.f = 0; model.z2 = 0;
          setHint("Mild constriction — smaller speed and pressure change.");
        } else if (p === "friction") {
          model.D1 = 0.08; model.D2 = 0.04; model.Q = 0.006; model.p1 = 150e3; model.f = 0.03; model.z2 = 0;
          setHint("With friction factor f > 0, total head drops between stations.");
        } else if (p === "elevate") {
          model.D1 = 0.08; model.D2 = 0.04; model.Q = 0.005; model.p1 = 180e3; model.f = 0; model.z2 = 1.5;
          setHint("Throat elevated: gravitational head trades with pressure.");
        }
        syncSliders();
      });
    });

    window.addEventListener("resize", function () { resize(); draw(); });
  }

  function init() {
    bind();
    resize();
    syncSliders();
    setHint("Venturi / pipe flow. Continuity links areas and speeds; Bernoulli links pressure, speed and height.");
    requestAnimationFrame(tick);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

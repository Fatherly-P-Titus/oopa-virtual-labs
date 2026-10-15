/**
 * Stress & Strain UI – axial bar + σ–ε plot.
 */
(function () {
  "use strict";

  var model = new StressStrainModel();
  var barCanvas = document.getElementById("bar-canvas");
  var curveCanvas = document.getElementById("curve-canvas");
  var bctx = barCanvas.getContext("2d");
  var cctx = curveCanvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");
  var statusEl = document.getElementById("status-line");

  function setHint(t) { if (hintEl) hintEl.textContent = t; }
  function setStatus(t, cls) {
    if (!statusEl) return;
    statusEl.textContent = t || "";
    statusEl.className = "status-line" + (cls ? " " + cls : "");
  }
  function setText(id, t) {
    var el = document.getElementById(id);
    if (el) el.textContent = t;
  }
  function fmt(n, d) {
    if (n == null || !isFinite(n)) return "–";
    return Number(n).toFixed(d == null ? 2 : d);
  }
  function fmtSci(n) {
    if (!isFinite(n)) return "–";
    var a = Math.abs(n);
    if (a >= 1e9) return (n / 1e9).toFixed(2) + " GPa";
    if (a >= 1e6) return (n / 1e6).toFixed(1) + " MPa";
    if (a >= 1e3) return (n / 1e3).toFixed(1) + " kPa";
    return n.toFixed(1) + " Pa";
  }

  function resize() {
    var dpr = window.devicePixelRatio || 1;
    function fit(c, h) {
      var rect = c.getBoundingClientRect();
      c.width = Math.max(320, Math.floor(rect.width * dpr));
      c.height = Math.floor(h * dpr);
      c.getContext("2d").setTransform(dpr, 0, 0, dpr, 0, 0);
    }
    fit(barCanvas, 220);
    fit(curveCanvas, 200);
  }

  function drawBar(res) {
    var w = barCanvas.clientWidth || 640;
    var h = 220;
    bctx.clearRect(0, 0, w, h);

    var L0 = 280;
    // exaggeration for visibility
    var maxVis = 80;
    var scale = Math.min(maxVis / Math.max(Math.abs(res.delta) * 200, 1e-6), 40);
    var stretch = Math.min(maxVis, Math.max(-40, res.delta * 200 * scale / 40));
    // simpler: visual elongation proportional but capped
    var visDelta = Math.sign(res.delta) * Math.min(50, Math.abs(res.delta) / 0.001 * 8);
    if (!isFinite(visDelta)) visDelta = 0;

    var x0 = 80;
    var y0 = h * 0.45;
    var barH = 28 + model.d * 400; // thickness hint from diameter
    barH = Math.max(18, Math.min(48, barH));
    var barW = L0 + visDelta;

    // Fixed support left
    bctx.fillStyle = "#1b1b1b";
    bctx.fillRect(x0 - 14, y0 - 40, 10, 80);
    bctx.strokeStyle = "#1b1b1b";
    bctx.lineWidth = 2;
    for (var i = 0; i < 6; i++) {
      bctx.beginPath();
      bctx.moveTo(x0 - 14, y0 - 35 + i * 14);
      bctx.lineTo(x0 - 26, y0 - 28 + i * 14);
      bctx.stroke();
    }

    // Undeformed outline
    bctx.strokeStyle = "rgba(0,0,0,0.2)";
    bctx.setLineDash([4, 4]);
    bctx.strokeRect(x0, y0 - barH / 2, L0, barH);
    bctx.setLineDash([]);

    // Deformed bar
    bctx.fillStyle = res.yielded ? "#ef9a9a" : res.color;
    bctx.strokeStyle = "#1b1b1b";
    bctx.lineWidth = 2;
    bctx.fillRect(x0, y0 - barH / 2, barW, barH);
    bctx.strokeRect(x0, y0 - barH / 2, barW, barH);

    // Force arrow at free end
    var fx = x0 + barW + 8;
    bctx.strokeStyle = "#b22222";
    bctx.fillStyle = "#b22222";
    bctx.lineWidth = 3;
    bctx.beginPath();
    bctx.moveTo(fx, y0);
    bctx.lineTo(fx + 50, y0);
    bctx.stroke();
    bctx.beginPath();
    bctx.moveTo(fx + 50, y0);
    bctx.lineTo(fx + 40, y0 - 7);
    bctx.lineTo(fx + 40, y0 + 7);
    bctx.closePath();
    bctx.fill();
    bctx.font = "600 12px DM Sans, Arial, sans-serif";
    bctx.textAlign = "left";
    bctx.fillText("F = " + fmt(model.F / 1000, 1) + " kN", fx + 8, y0 - 14);

    // Labels
    bctx.fillStyle = "#1b1b1b";
    bctx.font = "600 11px DM Sans, Arial, sans-serif";
    bctx.textAlign = "center";
    bctx.fillText("L = " + fmt(model.L, 2) + " m", x0 + L0 / 2, y0 + barH / 2 + 22);
    bctx.fillText("δ = " + (Math.abs(res.delta) < 1e-6 ? fmt(res.delta * 1e6, 1) + " µm" : fmt(res.delta * 1000, 2) + " mm"), x0 + barW / 2, y0 - barH / 2 - 12);
    bctx.textAlign = "left";
    bctx.fillText(res.materialName, 16, 24);
    bctx.fillText("d = " + fmt(model.d * 1000, 1) + " mm", 16, 42);
  }

  function drawCurve(res) {
    var w = curveCanvas.clientWidth || 640;
    var h = 200;
    cctx.clearRect(0, 0, w, h);

    var padL = 50, padR = 20, padT = 20, padB = 36;
    var plotW = w - padL - padR;
    var plotH = h - padT - padB;

    var mat = model.mat();
    var epsMax = Math.max(mat.sy / mat.E * 1.4, Math.abs(res.eps) * 1.3, 1e-4);
    var sigMax = Math.max(mat.sy * 1.15, Math.abs(res.sigma) * 1.2);

    function xOf(eps) { return padL + (eps / epsMax) * plotW; }
    function yOf(sig) { return padT + plotH - (sig / sigMax) * plotH; }

    // Axes
    cctx.strokeStyle = "#ccc";
    cctx.lineWidth = 1;
    cctx.beginPath();
    cctx.moveTo(padL, padT);
    cctx.lineTo(padL, padT + plotH);
    cctx.lineTo(padL + plotW, padT + plotH);
    cctx.stroke();

    // Elastic line to yield
    var epsY = mat.sy / mat.E;
    cctx.strokeStyle = "#1565c0";
    cctx.lineWidth = 2;
    cctx.beginPath();
    cctx.moveTo(xOf(0), yOf(0));
    cctx.lineTo(xOf(Math.min(epsY, epsMax)), yOf(Math.min(mat.sy, sigMax)));
    cctx.stroke();

    // Yield plateau hint
    if (epsY < epsMax) {
      cctx.strokeStyle = "rgba(198,40,40,0.5)";
      cctx.setLineDash([4, 3]);
      cctx.beginPath();
      cctx.moveTo(xOf(epsY), yOf(mat.sy));
      cctx.lineTo(xOf(epsMax), yOf(mat.sy));
      cctx.stroke();
      cctx.setLineDash([]);
    }

    // Operating point
    var px = xOf(Math.min(Math.abs(res.eps), epsMax));
    var py = yOf(Math.min(Math.abs(res.sigma), sigMax));
    cctx.fillStyle = res.yielded ? "#c62828" : "#b22222";
    cctx.beginPath();
    cctx.arc(px, py, 6, 0, Math.PI * 2);
    cctx.fill();

    // Labels
    cctx.fillStyle = "#666";
    cctx.font = "600 10px DM Sans, Arial, sans-serif";
    cctx.textAlign = "center";
    cctx.fillText("ε", padL + plotW / 2, h - 8);
    cctx.save();
    cctx.translate(14, padT + plotH / 2);
    cctx.rotate(-Math.PI / 2);
    cctx.fillText("σ", 0, 0);
    cctx.restore();
    cctx.textAlign = "left";
    cctx.fillText("E = " + fmtSci(mat.E), padL + 8, padT + 14);
    cctx.fillText("σy = " + fmtSci(mat.sy), padL + 8, padT + 28);
  }

  function update() {
    var res = model.solve();
    drawBar(res);
    drawCurve(res);

    setText("s-sigma", fmtSci(res.sigma));
    setText("s-eps", (res.eps * 100).toFixed(3) + " %");
    setText("s-delta", Math.abs(res.delta) < 1e-6 ? fmt(res.delta * 1e6, 2) + " µm" : fmt(res.delta * 1000, 3) + " mm");
    setText("s-A", fmt(res.A * 1e6, 2) + " mm²");
    setText("s-E", fmtSci(res.E));
    setText("s-sy", fmtSci(res.sy));
    setText("s-n", fmt(res.n, 2));

    var nRow = document.getElementById("row-n");
    if (nRow) {
      nRow.className = res.yielded ? "warn" : res.n < 1.5 ? "hl" : "";
    }

    if (res.yielded) {
      setStatus("Working stress ≥ yield — bar has yielded in this ideal model (n < 1).", "err");
    } else if (res.n < 1.5) {
      setStatus("Low safety factor (n = " + fmt(res.n, 2) + "). Typical design targets are higher.", "err");
    } else {
      setStatus("Within elastic range. Safety factor n = " + fmt(res.n, 2) + ".", "ok");
    }
  }

  function syncSliders() {
    setSlider("c-F", model.F / 1000, function (v) { return fmt(v, 1) + " kN"; });
    setSlider("c-L", model.L, function (v) { return fmt(v, 2) + " m"; });
    setSlider("c-d", model.d * 1000, function (v) { return fmt(v, 1) + " mm"; });
    document.querySelectorAll(".mat-row button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-mat") === model.material);
    });
  }

  function setSlider(id, val, fmtFn) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out && fmtFn) out.textContent = fmtFn(val);
  }

  function bind() {
    document.getElementById("c-F").addEventListener("input", function () {
      model.F = parseFloat(this.value) * 1000;
      setSlider("c-F", this.value, function (v) { return fmt(v, 1) + " kN"; });
      update();
    });
    document.getElementById("c-L").addEventListener("input", function () {
      model.L = parseFloat(this.value);
      setSlider("c-L", this.value, function (v) { return fmt(v, 2) + " m"; });
      update();
    });
    document.getElementById("c-d").addEventListener("input", function () {
      model.d = parseFloat(this.value) / 1000;
      setSlider("c-d", this.value, function (v) { return fmt(v, 1) + " mm"; });
      update();
    });
    document.querySelectorAll(".mat-row button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.material = btn.getAttribute("data-mat");
        syncSliders();
        update();
        setHint("Material: " + model.mat().name + ". E and σy update the curve and safety factor.");
      });
    });
    window.addEventListener("resize", function () { resize(); update(); });
  }

  function init() {
    bind();
    resize();
    syncSliders();
    update();
    setHint("Axial bar in tension. Change force, length, diameter or material and watch stress, strain and safety factor.");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

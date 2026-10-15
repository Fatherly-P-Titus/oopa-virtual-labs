/**
 * Reaction Rates UI – [A](t) chart, order, Arrhenius.
 */
(function () {
  "use strict";

  var model = new ReactionRatesModel();
  var canvas = document.getElementById("rate-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");
  var tMax = 60; // s display window

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
    canvas.height = Math.floor(400 * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    draw();
  }

  function autoTMax() {
    var hl = model.halfLife();
    if (!isFinite(hl) || hl <= 0) return 60;
    // show ~4 half-lives
    return Math.max(10, Math.min(300, hl * 4));
  }

  function draw() {
    var w = canvas.clientWidth || 640;
    var h = 400;
    ctx.clearRect(0, 0, w, h);

    tMax = autoTMax();
    var series = model.series(tMax, 250);
    var padL = 55, padR = 20, padT = 30, padB = 40;
    var plotW = w - padL - padR;
    var plotH = h - padT - padB;

    var Amax = Math.max(model.A0 * 1.05, 0.1);

    function xOf(t) { return padL + (t / tMax) * plotW; }
    function yOf(A) { return padT + plotH - (A / Amax) * plotH; }

    // Grid
    ctx.strokeStyle = "#eee";
    ctx.lineWidth = 1;
    for (var i = 0; i <= 4; i++) {
      var yy = padT + (i / 4) * plotH;
      ctx.beginPath();
      ctx.moveTo(padL, yy);
      ctx.lineTo(padL + plotW, yy);
      ctx.stroke();
    }

    // Axes
    ctx.strokeStyle = "#ccc";
    ctx.beginPath();
    ctx.moveTo(padL, padT);
    ctx.lineTo(padL, padT + plotH);
    ctx.lineTo(padL + plotW, padT + plotH);
    ctx.stroke();

    // Half-life marker
    var hl = model.halfLife();
    if (isFinite(hl) && hl > 0 && hl < tMax) {
      ctx.strokeStyle = "rgba(178,34,34,0.35)";
      ctx.setLineDash([4, 4]);
      ctx.beginPath();
      ctx.moveTo(xOf(hl), padT);
      ctx.lineTo(xOf(hl), padT + plotH);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = "#b22222";
      ctx.font = "600 10px DM Sans, Arial, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("t½", xOf(hl), padT + 12);
    }

    // Curve
    ctx.strokeStyle = "#b22222";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    series.forEach(function (p, i) {
      var x = xOf(p.t), y = yOf(p.A);
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

    // Start point
    ctx.fillStyle = "#b22222";
    ctx.beginPath();
    ctx.arc(xOf(0), yOf(model.A0), 5, 0, Math.PI * 2);
    ctx.fill();

    // Labels
    ctx.fillStyle = "#666";
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("t (s)", padL + plotW / 2, h - 10);
    ctx.save();
    ctx.translate(16, padT + plotH / 2);
    ctx.rotate(-Math.PI / 2);
    ctx.fillText("[A] (mol/L)", 0, 0);
    ctx.restore();

    ctx.textAlign = "right";
    ctx.fillText(fmt(Amax, 2), padL - 6, padT + 4);
    ctx.fillText("0", padL - 6, padT + plotH + 4);
    ctx.textAlign = "center";
    ctx.fillText("0", padL, padT + plotH + 16);
    ctx.fillText(fmt(tMax, 0), padL + plotW, padT + plotH + 16);

    // Order badge
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    var orderNames = { 0: "Zero-order", 1: "First-order", 2: "Second-order" };
    ctx.fillText(orderNames[model.order] || "", padL, 18);

    updateReadouts();
  }

  function kUnits() {
    if (model.order === 0) return "mol·L⁻¹·s⁻¹";
    if (model.order === 1) return "s⁻¹";
    return "L·mol⁻¹·s⁻¹";
  }

  function updateReadouts() {
    var k = model.effectiveK();
    var hl = model.halfLife();
    setText("s-k", fmt(k, 4) + " " + kUnits());
    setText("s-hl", isFinite(hl) ? fmt(hl, 2) + " s" : "–");
    setText("s-A0", fmt(model.A0, 2) + " mol/L");
    setText("s-order", String(model.order));
    setText("s-rate0", fmt(model.rate(0), 4) + " mol·L⁻¹·s⁻¹");
    if (model.useArrhenius) {
      setText("s-T", fmt(model.T, 0) + " K");
      setText("s-Ea", fmt(model.Ea / 1000, 1) + " kJ/mol");
    }
  }

  function syncSliders() {
    setSlider("c-A0", model.A0, function (v) { return fmt(v, 2) + " M"; });
    setSlider("c-k", model.k, function (v) { return fmt(v, 3); });
    setSlider("c-T", model.T, function (v) { return fmt(v, 0) + " K"; });
    setSlider("c-Ea", model.Ea / 1000, function (v) { return fmt(v, 0) + " kJ/mol"; });
    document.querySelectorAll(".order-row button").forEach(function (btn) {
      btn.classList.toggle("active", Number(btn.getAttribute("data-order")) === model.order);
    });
    var arr = document.getElementById("c-arrhenius");
    if (arr) arr.checked = model.useArrhenius;
    document.getElementById("arrhenius-controls").style.display =
      model.useArrhenius ? "block" : "none";
  }

  function setSlider(id, val, fmtFn) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out && fmtFn) out.textContent = fmtFn(val);
  }

  function bind() {
    document.querySelectorAll(".order-row button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.order = Number(btn.getAttribute("data-order"));
        // sensible default k per order
        if (model.order === 0) model.k = 0.02;
        if (model.order === 1) model.k = 0.05;
        if (model.order === 2) model.k = 0.1;
        if (model.useArrhenius) model.calibrateArrhenius(298);
        syncSliders();
        draw();
        setHint("Order " + model.order + ". Watch how the [A] vs t curve shape changes.");
      });
    });

    document.getElementById("c-A0").addEventListener("input", function () {
      model.A0 = parseFloat(this.value);
      setSlider("c-A0", this.value, function (v) { return fmt(v, 2) + " M"; });
      draw();
    });
    document.getElementById("c-k").addEventListener("input", function () {
      model.k = parseFloat(this.value);
      if (model.useArrhenius) model.calibrateArrhenius(model.T);
      setSlider("c-k", this.value, function (v) { return fmt(v, 3); });
      draw();
    });
    document.getElementById("c-T").addEventListener("input", function () {
      model.T = parseFloat(this.value);
      setSlider("c-T", this.value, function (v) { return fmt(v, 0) + " K"; });
      draw();
    });
    document.getElementById("c-Ea").addEventListener("input", function () {
      model.Ea = parseFloat(this.value) * 1000;
      setSlider("c-Ea", this.value, function (v) { return fmt(v, 0) + " kJ/mol"; });
      draw();
    });

    document.getElementById("c-arrhenius").addEventListener("change", function () {
      model.useArrhenius = this.checked;
      if (model.useArrhenius) model.calibrateArrhenius(model.T);
      syncSliders();
      draw();
      setHint(model.useArrhenius
        ? "Arrhenius on: change T or Ea and watch k and the curve respond."
        : "Fixed k mode. Toggle Arrhenius to explore temperature dependence.");
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        model.useArrhenius = false;
        if (p === "first") {
          model.order = 1; model.A0 = 1; model.k = 0.05;
          setHint("First-order: exponential decay. Half-life is constant.");
        } else if (p === "second") {
          model.order = 2; model.A0 = 1; model.k = 0.15;
          setHint("Second-order: falls faster at first, then slows. t½ depends on [A]₀.");
        } else if (p === "zero") {
          model.order = 0; model.A0 = 1; model.k = 0.025;
          setHint("Zero-order: linear drop until reactant is gone.");
        } else if (p === "hot") {
          model.order = 1; model.A0 = 1; model.k = 0.05; model.T = 298; model.Ea = 50e3;
          model.calibrateArrhenius(298);
          model.T = 350;
          setHint("Arrhenius at elevated T — k rises and the reaction runs faster.");
        }
        syncSliders();
        draw();
      });
    });

    window.addEventListener("resize", resize);
  }

  function init() {
    bind();
    resize();
    syncSliders();
    setHint("First-order decay by default. Switch order and watch the curve shape and half-life change.");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

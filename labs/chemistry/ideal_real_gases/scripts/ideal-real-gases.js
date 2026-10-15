/**
 * Ideal vs Real Gases UI – PV isotherms + Z(V).
 */
(function () {
  "use strict";

  var model = new IRGModel();
  var pvCanvas = document.getElementById("pv-canvas");
  var zCanvas = document.getElementById("z-canvas");
  var pvCtx = pvCanvas.getContext("2d");
  var zCtx = zCanvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");

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
    fit(pvCanvas, 260);
    fit(zCanvas, 180);
    draw();
  }

  function draw() {
    var series = model.isotherm(null, Math.max(40, model.V * 2.5), 220);
    drawPV(series);
    drawZ(series);
    updateReadouts(model.solve());
  }

  function drawPV(series) {
    var w = pvCanvas.clientWidth || 640;
    var h = 260;
    var ctx = pvCtx;
    ctx.clearRect(0, 0, w, h);

    var padL = 55, padR = 20, padT = 28, padB = 36;
    var plotW = w - padL - padR;
    var plotH = h - padT - padB;

    var Vmin = series[0].V;
    var Vmax = series[series.length - 1].V;
    var Pmax = 0.5;
    series.forEach(function (p) {
      if (isFinite(p.Pideal)) Pmax = Math.max(Pmax, p.Pideal);
      if (isFinite(p.Pvdw) && p.Pvdw > 0 && p.Pvdw < 500) Pmax = Math.max(Pmax, p.Pvdw);
    });
    // Include operating point
    var op = model.solve();
    if (isFinite(op.Pideal)) Pmax = Math.max(Pmax, op.Pideal);
    if (isFinite(op.Pvdw) && op.Pvdw > 0) Pmax = Math.max(Pmax, op.Pvdw);
    Pmax *= 1.1;

    function xOf(V) { return padL + ((V - Vmin) / (Vmax - Vmin)) * plotW; }
    function yOf(P) { return padT + plotH - (Math.max(0, P) / Pmax) * plotH; }

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

    // Ideal isotherm
    ctx.strokeStyle = "#1565c0";
    ctx.lineWidth = 2;
    ctx.beginPath();
    var started = false;
    series.forEach(function (p) {
      if (!isFinite(p.Pideal)) return;
      var x = xOf(p.V), y = yOf(p.Pideal);
      if (!started) { ctx.moveTo(x, y); started = true; }
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

    // van der Waals isotherm
    ctx.strokeStyle = "#b22222";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    started = false;
    series.forEach(function (p) {
      if (!isFinite(p.Pvdw) || p.Pvdw < 0 || p.Pvdw > Pmax * 1.5) {
        started = false;
        return;
      }
      var x = xOf(p.V), y = yOf(p.Pvdw);
      if (!started) { ctx.moveTo(x, y); started = true; }
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

    // Operating point
    if (isFinite(op.Pvdw) && op.V >= Vmin && op.V <= Vmax) {
      ctx.fillStyle = "#b22222";
      ctx.beginPath();
      ctx.arc(xOf(op.V), yOf(op.Pvdw), 5, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#1565c0";
      ctx.beginPath();
      ctx.arc(xOf(op.V), yOf(op.Pideal), 4, 0, Math.PI * 2);
      ctx.fill();
    }

    // Critical volume marker
    var crit = op.critical;
    if (crit.Vc > Vmin && crit.Vc < Vmax) {
      ctx.strokeStyle = "rgba(0,0,0,0.2)";
      ctx.setLineDash([4, 3]);
      ctx.beginPath();
      ctx.moveTo(xOf(crit.Vc), padT);
      ctx.lineTo(xOf(crit.Vc), padT + plotH);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = "#888";
      ctx.font = "600 9px DM Sans, Arial, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("Vc", xOf(crit.Vc), padT + 12);
    }

    // Labels
    ctx.fillStyle = "#666";
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("V (L)", padL + plotW / 2, h - 8);
    ctx.save();
    ctx.translate(14, padT + plotH / 2);
    ctx.rotate(-Math.PI / 2);
    ctx.fillText("P (bar)", 0, 0);
    ctx.restore();

    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Isotherm  T = " + fmt(model.T, 0) + " K", padL, 16);
  }

  function drawZ(series) {
    var w = zCanvas.clientWidth || 640;
    var h = 180;
    var ctx = zCtx;
    ctx.clearRect(0, 0, w, h);

    var padL = 55, padR = 20, padT = 20, padB = 32;
    var plotW = w - padL - padR;
    var plotH = h - padT - padB;

    var Vmin = series[0].V;
    var Vmax = series[series.length - 1].V;
    var Zmin = 0.4, Zmax = 1.6;
    series.forEach(function (p) {
      if (isFinite(p.Z)) {
        Zmin = Math.min(Zmin, p.Z);
        Zmax = Math.max(Zmax, p.Z);
      }
    });
    Zmin = Math.min(Zmin, 0.5);
    Zmax = Math.max(Zmax, 1.3);
    var span = Zmax - Zmin || 1;

    function xOf(V) { return padL + ((V - Vmin) / (Vmax - Vmin)) * plotW; }
    function yOf(Z) { return padT + plotH - ((Z - Zmin) / span) * plotH; }

    // Z = 1 line
    ctx.strokeStyle = "#2e7d32";
    ctx.lineWidth = 1.5;
    ctx.setLineDash([4, 3]);
    ctx.beginPath();
    ctx.moveTo(padL, yOf(1));
    ctx.lineTo(padL + plotW, yOf(1));
    ctx.stroke();
    ctx.setLineDash([]);

    // Axes
    ctx.strokeStyle = "#ccc";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(padL, padT);
    ctx.lineTo(padL, padT + plotH);
    ctx.lineTo(padL + plotW, padT + plotH);
    ctx.stroke();

    // Z curve
    ctx.strokeStyle = "#b22222";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    var started = false;
    series.forEach(function (p) {
      if (!isFinite(p.Z) || p.Z < 0.05 || p.Z > 5) {
        started = false;
        return;
      }
      var x = xOf(p.V), y = yOf(p.Z);
      if (!started) { ctx.moveTo(x, y); started = true; }
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

    // Operating Z
    var op = model.solve();
    if (isFinite(op.Z) && op.V >= Vmin && op.V <= Vmax) {
      ctx.fillStyle = "#b22222";
      ctx.beginPath();
      ctx.arc(xOf(op.V), yOf(op.Z), 5, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.fillStyle = "#666";
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("V (L)", padL + plotW / 2, h - 6);
    ctx.save();
    ctx.translate(14, padT + plotH / 2);
    ctx.rotate(-Math.PI / 2);
    ctx.fillText("Z = PV/nRT", 0, 0);
    ctx.restore();

    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Compressibility factor", padL, 14);
  }

  function updateReadouts(res) {
    setText("s-Pideal", fmt(res.Pideal, 3) + " bar");
    setText("s-Pvdw", fmt(res.Pvdw, 3) + " bar");
    setText("s-Z", fmt(res.Z, 4));
    setText("s-dP", fmt(res.deltaP, 3) + " bar");
    setText("s-Tc", fmt(res.critical.Tc, 1) + " K");
    setText("s-Pc", fmt(res.critical.Pc, 2) + " bar");
    setText("s-Vc", fmt(res.critical.Vc, 3) + " L");
    setText("s-Tr", fmt(res.reducedT, 3));
    setText("s-a", fmt(res.a, 3));
    setText("s-b", fmt(res.b, 4));
    setText("s-gas", res.gasName);
  }

  function syncSliders() {
    setSlider("c-T", model.T, function (v) { return fmt(v, 0) + " K"; });
    setSlider("c-V", model.V, function (v) { return fmt(v, 2) + " L"; });
    setSlider("c-n", model.n, function (v) { return fmt(v, 2) + " mol"; });
    setSlider("c-a", model.a, function (v) { return fmt(v, 3); });
    setSlider("c-b", model.b, function (v) { return fmt(v, 4); });
    document.querySelectorAll(".gas-row button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-gas") === model.gas);
    });
  }

  function setSlider(id, val, fmtFn) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out && fmtFn) out.textContent = fmtFn(val);
  }

  function bind() {
    document.querySelectorAll(".gas-row button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.setGas(btn.getAttribute("data-gas"));
        syncSliders();
        draw();
        setHint(model.gas + " selected. Compare the red van der Waals isotherm with the blue ideal curve.");
      });
    });

    document.getElementById("c-T").addEventListener("input", function () {
      model.T = parseFloat(this.value);
      setSlider("c-T", this.value, function (v) { return fmt(v, 0) + " K"; });
      draw();
    });
    document.getElementById("c-V").addEventListener("input", function () {
      model.V = parseFloat(this.value);
      setSlider("c-V", this.value, function (v) { return fmt(v, 2) + " L"; });
      draw();
    });
    document.getElementById("c-n").addEventListener("input", function () {
      model.n = parseFloat(this.value);
      setSlider("c-n", this.value, function (v) { return fmt(v, 2) + " mol"; });
      draw();
    });
    document.getElementById("c-a").addEventListener("input", function () {
      model.a = parseFloat(this.value);
      model.gas = "custom";
      setSlider("c-a", this.value, function (v) { return fmt(v, 3); });
      document.querySelectorAll(".gas-row button").forEach(function (b) { b.classList.remove("active"); });
      draw();
    });
    document.getElementById("c-b").addEventListener("input", function () {
      model.b = parseFloat(this.value);
      model.gas = "custom";
      setSlider("c-b", this.value, function (v) { return fmt(v, 4); });
      document.querySelectorAll(".gas-row button").forEach(function (b) { b.classList.remove("active"); });
      draw();
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        if (p === "co2-room") {
          model.setGas("CO2"); model.T = 300; model.V = 5; model.n = 1;
          setHint("CO₂ near room temperature — modest deviation from ideal.");
        } else if (p === "co2-cold") {
          model.setGas("CO2"); model.T = 280; model.V = 0.8; model.n = 1;
          setHint("CO₂ at lower T and small V — strong attraction (a) lowers pressure vs ideal.");
        } else if (p === "he") {
          model.setGas("He"); model.T = 300; model.V = 5; model.n = 1;
          setHint("Helium: small a and b — almost ideal at these conditions.");
        } else if (p === "h2o") {
          model.setGas("H2O"); model.T = 500; model.V = 2; model.n = 1;
          setHint("Water vapour: large a — significant non-ideality even well above boiling point.");
        } else if (p === "crit") {
          model.setGas("CO2");
          var c = model.critical();
          model.T = c.Tc; model.V = c.Vc; model.n = 1;
          setHint("At the critical point the isotherm has a horizontal inflection (van der Waals).");
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
    setHint("Blue = ideal gas isotherm. Red = van der Waals. Z = 1 means ideal behaviour.");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

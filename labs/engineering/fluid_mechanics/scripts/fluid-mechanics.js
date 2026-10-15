/**
 * Fluid Mechanics UI – hydrostatic, manometer, buoyancy.
 */
(function () {
  "use strict";

  var M = window.FMModel;
  var mode = "hydro"; // hydro | mano | buoy
  var state = {
    fluid: "water",
    h: 2.0,       // m depth
    dh: 0.3,      // m manometer difference
    rhoObj: 600,  // kg/m³ object
    A: 0.5,       // m² base
    H: 0.8        // m object height
  };

  var canvas = document.getElementById("fm-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");

  function fluid() { return M.FLUIDS[state.fluid] || M.FLUIDS.water; }

  function result() {
    var f = fluid();
    if (mode === "hydro") return M.hydrostatic(f.rho, state.h);
    if (mode === "mano") return M.manometer(f.rho, state.dh);
    return M.buoyancy(f.rho, state.rhoObj, state.A, state.H);
  }

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
    draw();
  }

  function draw() {
    var w = canvas.clientWidth || 640;
    var h = 420;
    ctx.clearRect(0, 0, w, h);
    var res = result();
    if (mode === "hydro") drawHydro(w, h, res);
    else if (mode === "mano") drawMano(w, h, res);
    else drawBuoy(w, h, res);
    updateReadouts(res);
  }

  function drawHydro(w, h, res) {
    var f = fluid();
    var tankX = w * 0.25, tankW = w * 0.35;
    var top = 50, bot = h - 50;
    var tankH = bot - top;
    var maxH = 5; // visual scale max depth
    var waterH = Math.min(tankH * 0.9, (state.h / maxH) * tankH);
    var waterTop = bot - waterH;

    // Tank
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(tankX, top);
    ctx.lineTo(tankX, bot);
    ctx.lineTo(tankX + tankW, bot);
    ctx.lineTo(tankX + tankW, top);
    ctx.stroke();

    // Fluid
    ctx.fillStyle = f.color;
    ctx.globalAlpha = 0.55;
    ctx.fillRect(tankX + 2, waterTop, tankW - 4, waterH);
    ctx.globalAlpha = 1;

    // Depth marker
    var probeY = waterTop + waterH * 0.6;
    ctx.strokeStyle = "#b22222";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(tankX + tankW + 10, waterTop);
    ctx.lineTo(tankX + tankW + 30, waterTop);
    ctx.moveTo(tankX + tankW + 10, probeY);
    ctx.lineTo(tankX + tankW + 30, probeY);
    ctx.moveTo(tankX + tankW + 20, waterTop);
    ctx.lineTo(tankX + tankW + 20, probeY);
    ctx.stroke();
    ctx.fillStyle = "#b22222";
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("h = " + fmt(state.h, 2) + " m", tankX + tankW + 36, (waterTop + probeY) / 2 + 4);

    // Pressure readout at depth
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Hydrostatic pressure", 24, 28);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillText("p = ρgh = " + fmt(res.pGauge / 1000, 2) + " kPa (gauge)", 24, 50);

    // Free surface label
    ctx.fillStyle = "#1565c0";
    ctx.fillText("Free surface", tankX + tankW / 2, waterTop - 10);
  }

  function drawMano(w, h, res) {
    var f = fluid();
    var cx = w * 0.4;
    var baseY = h - 60;
    var colH = 220;
    var tubeW = 28;
    var mid = state.dh / 2;
    // left column lower by dh/2, right higher
    var scale = 180 / Math.max(0.5, Math.abs(state.dh) + 0.2);
    var leftTop = baseY - 100 - mid * scale;
    var rightTop = baseY - 100 + mid * scale;
    if (state.dh < 0) {
      leftTop = baseY - 100 + Math.abs(mid) * scale;
      rightTop = baseY - 100 - Math.abs(mid) * scale;
    }

    // U-tube
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 3;
    var leftX = cx - 50, rightX = cx + 50;
    // left vertical
    ctx.beginPath();
    ctx.moveTo(leftX, 80);
    ctx.lineTo(leftX, baseY);
    ctx.lineTo(rightX, baseY);
    ctx.lineTo(rightX, 80);
    ctx.stroke();

    // Fluid in U
    ctx.fillStyle = f.color;
    ctx.globalAlpha = 0.6;
    ctx.fillRect(leftX - tubeW / 2, leftTop, tubeW, baseY - leftTop);
    ctx.fillRect(rightX - tubeW / 2, rightTop, tubeW, baseY - rightTop);
    ctx.fillRect(leftX - tubeW / 2, baseY - 8, rightX - leftX + tubeW, 10);
    ctx.globalAlpha = 1;

    // Delta h markers
    ctx.strokeStyle = "#b22222";
    ctx.lineWidth = 1.5;
    ctx.setLineDash([4, 3]);
    ctx.beginPath();
    ctx.moveTo(leftX + tubeW / 2 + 4, leftTop);
    ctx.lineTo(rightX + 40, leftTop);
    ctx.moveTo(rightX + tubeW / 2 + 4, rightTop);
    ctx.lineTo(rightX + 40, rightTop);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.beginPath();
    ctx.moveTo(rightX + 36, leftTop);
    ctx.lineTo(rightX + 36, rightTop);
    ctx.stroke();
    ctx.fillStyle = "#b22222";
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Δh = " + fmt(state.dh * 100, 1) + " cm", rightX + 44, (leftTop + rightTop) / 2 + 4);

    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("U-tube manometer", 24, 28);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillText("Δp = ρgΔh = " + fmt(res.dp / 1000, 2) + " kPa", 24, 50);
  }

  function drawBuoy(w, h, res) {
    var f = fluid();
    var tankX = w * 0.2, tankW = w * 0.45;
    var bot = h - 50, top = 40;
    var waterLevel = bot - 200;

    // Tank
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(tankX, top);
    ctx.lineTo(tankX, bot);
    ctx.lineTo(tankX + tankW, bot);
    ctx.lineTo(tankX + tankW, top);
    ctx.stroke();

    // Water
    ctx.fillStyle = f.color;
    ctx.globalAlpha = 0.45;
    ctx.fillRect(tankX + 2, waterLevel, tankW - 4, bot - waterLevel - 2);
    ctx.globalAlpha = 1;

    // Block
    var scale = 120; // px per metre height
    var blockH = state.H * scale;
    var blockW = Math.sqrt(state.A) * scale * 1.2;
    blockW = Math.max(40, Math.min(tankW * 0.5, blockW));
    var draftPx = res.draft * scale;
    var blockBottom = waterLevel + draftPx;
    if (!res.floats) {
      // sit on bottom partially - fully submerged floating mid
      blockBottom = waterLevel + blockH * 0.5 + 20;
    }
    var blockTop = blockBottom - blockH;
    var blockX = tankX + (tankW - blockW) / 2;

    ctx.fillStyle = res.floats ? "#8d6e63" : "#5d4037";
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 2;
    ctx.fillRect(blockX, blockTop, blockW, blockH);
    ctx.strokeRect(blockX, blockTop, blockW, blockH);

    // Force arrows
    var mx = blockX + blockW / 2;
    // Weight down
    ctx.strokeStyle = "#b22222";
    ctx.fillStyle = "#b22222";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(mx - 20, blockTop + blockH / 2);
    ctx.lineTo(mx - 20, blockTop + blockH / 2 + 40);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(mx - 20, blockTop + blockH / 2 + 40);
    ctx.lineTo(mx - 26, blockTop + blockH / 2 + 32);
    ctx.lineTo(mx - 14, blockTop + blockH / 2 + 32);
    ctx.closePath();
    ctx.fill();
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("W", mx - 20, blockTop + blockH / 2 + 54);

    // Buoyancy up
    ctx.strokeStyle = "#1565c0";
    ctx.fillStyle = "#1565c0";
    ctx.beginPath();
    ctx.moveTo(mx + 20, blockTop + blockH / 2);
    ctx.lineTo(mx + 20, blockTop + blockH / 2 - 40);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(mx + 20, blockTop + blockH / 2 - 40);
    ctx.lineTo(mx + 14, blockTop + blockH / 2 - 32);
    ctx.lineTo(mx + 26, blockTop + blockH / 2 - 32);
    ctx.closePath();
    ctx.fill();
    ctx.fillText("F_B", mx + 20, blockTop + blockH / 2 - 48);

    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(res.floats ? "Floating" : "Sinking (fully submerged)", 24, 28);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillText("Draft = " + fmt(res.draft * 100, 1) + " cm", 24, 50);
  }

  function updateReadouts(res) {
    if (mode === "hydro") {
      setText("s-p", fmt(res.pGauge / 1000, 2) + " kPa");
      setText("s-pabs", fmt(res.pAbs / 1000, 1) + " kPa");
      setText("s-rho", fmt(res.rho, 0) + " kg/m³");
      setText("s-h", fmt(res.h, 2) + " m");
    } else if (mode === "mano") {
      setText("s-dp", fmt(res.dp / 1000, 2) + " kPa");
      setText("s-dh", fmt(res.dh * 100, 1) + " cm");
      setText("s-rho", fmt(res.rho, 0) + " kg/m³");
    } else {
      setText("s-W", fmt(res.W, 1) + " N");
      setText("s-FB", fmt(res.FB, 1) + " N");
      setText("s-draft", fmt(res.draft * 100, 1) + " cm");
      setText("s-net", fmt(res.netForce, 1) + " N");
      setText("s-status", res.floats ? "Floats" : "Sinks");
    }
  }

  function setMode(name) {
    mode = name;
    document.body.classList.remove("m-hydro", "m-mano", "m-buoy");
    document.body.classList.add("m-" + name);
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-mode") === name);
    });
    var hints = {
      hydro: "Pressure increases linearly with depth. p = ρgh (gauge).",
      mano: "A U-tube manometer reads pressure difference from the height difference of the liquid columns.",
      buoy: "An object floats when buoyant force equals weight. Draft adjusts until F_B = W if density is lower than the fluid."
    };
    setHint(hints[name] || "");
    // show/hide result rows
    document.querySelectorAll("[data-for]").forEach(function (el) {
      el.style.display = el.getAttribute("data-for") === name ? "" : "none";
    });
    var rowRho = document.getElementById("row-rho");
    if (rowRho) rowRho.style.display = name === "buoy" ? "none" : "";
    syncSliders();
    draw();
  }

  function syncSliders() {
    setSlider("c-h", state.h, function (v) { return fmt(v, 2) + " m"; });
    setSlider("c-dh", state.dh * 100, function (v) { return fmt(v, 1) + " cm"; });
    setSlider("c-rhoObj", state.rhoObj, function (v) { return fmt(v, 0) + " kg/m³"; });
    setSlider("c-H", state.H * 100, function (v) { return fmt(v, 0) + " cm"; });
    setSlider("c-A", state.A, function (v) { return fmt(v, 2) + " m²"; });
    document.querySelectorAll(".fluid-row button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-fluid") === state.fluid);
    });
  }

  function setSlider(id, val, fmtFn) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out && fmtFn) out.textContent = fmtFn(val);
  }

  function bind() {
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        setMode(btn.getAttribute("data-mode"));
      });
    });
    document.querySelectorAll(".fluid-row button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        state.fluid = btn.getAttribute("data-fluid");
        syncSliders();
        draw();
      });
    });

    document.getElementById("c-h").addEventListener("input", function () {
      state.h = parseFloat(this.value);
      setSlider("c-h", this.value, function (v) { return fmt(v, 2) + " m"; });
      draw();
    });
    document.getElementById("c-dh").addEventListener("input", function () {
      state.dh = parseFloat(this.value) / 100;
      setSlider("c-dh", this.value, function (v) { return fmt(v, 1) + " cm"; });
      draw();
    });
    document.getElementById("c-rhoObj").addEventListener("input", function () {
      state.rhoObj = parseFloat(this.value);
      setSlider("c-rhoObj", this.value, function (v) { return fmt(v, 0) + " kg/m³"; });
      draw();
    });
    document.getElementById("c-H").addEventListener("input", function () {
      state.H = parseFloat(this.value) / 100;
      setSlider("c-H", this.value, function (v) { return fmt(v, 0) + " cm"; });
      draw();
    });
    document.getElementById("c-A").addEventListener("input", function () {
      state.A = parseFloat(this.value);
      setSlider("c-A", this.value, function (v) { return fmt(v, 2) + " m²"; });
      draw();
    });

    window.addEventListener("resize", resize);
  }

  function init() {
    bind();
    document.body.classList.add("m-hydro");
    resize();
    setMode("hydro");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

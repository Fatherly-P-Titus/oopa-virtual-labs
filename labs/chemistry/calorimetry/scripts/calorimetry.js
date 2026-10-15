/**
 * Calorimetry UI – coffee-cup / bomb, thermometer, energy results.
 */
(function () {
  "use strict";

  var model = new CalorimetryModel();
  var canvas = document.getElementById("cal-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");
  var statusEl = document.getElementById("status-line");
  var animT = null; // animated temperature toward Tf
  var animTarget = 25;
  var animCurrent = 25;

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

  function resize() {
    var rect = canvas.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(320, Math.floor(rect.width * dpr));
    canvas.height = Math.floor(420 * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function result() { return model.solve(); }

  function tempColor(T) {
    // 15 blue → 40 neutral → 80 red
    var t = Math.max(0, Math.min(1, (T - 15) / 65));
    var r = Math.round(40 + 180 * t);
    var g = Math.round(100 + 40 * (1 - Math.abs(t - 0.4)));
    var b = Math.round(200 - 160 * t);
    return "rgb(" + r + "," + g + "," + b + ")";
  }

  function draw() {
    var w = canvas.clientWidth || 640;
    var h = 420;
    ctx.clearRect(0, 0, w, h);
    var res = result();
    animTarget = res.Tf;
    if (animCurrent == null) animCurrent = res.Ti != null ? res.Ti : res.Tf;

    if (model.mode === "bomb") drawBomb(w, h, res);
    else drawCoffeeCup(w, h, res);

    drawThermometer(w, h, animCurrent);
    updateReadouts(res);
  }

  function drawCoffeeCup(w, h, res) {
    var cx = w * 0.32;
    var cupW = 130;
    var cupH = 180;
    var cupY = 100;

    // Outer cup
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(cx - cupW / 2, cupY);
    ctx.lineTo(cx - cupW / 2 - 8, cupY + cupH);
    ctx.lineTo(cx + cupW / 2 + 8, cupY + cupH);
    ctx.lineTo(cx + cupW / 2, cupY);
    ctx.stroke();

    // Inner cup (insulation gap)
    ctx.beginPath();
    ctx.moveTo(cx - cupW / 2 + 10, cupY + 12);
    ctx.lineTo(cx - cupW / 2 + 4, cupY + cupH - 10);
    ctx.lineTo(cx + cupW / 2 - 4, cupY + cupH - 10);
    ctx.lineTo(cx + cupW / 2 - 10, cupY + 12);
    ctx.stroke();

    // Liquid
    var liqTop = cupY + 50;
    ctx.fillStyle = tempColor(animCurrent);
    ctx.globalAlpha = 0.55;
    ctx.beginPath();
    ctx.moveTo(cx - cupW / 2 + 12, liqTop);
    ctx.lineTo(cx - cupW / 2 + 6, cupY + cupH - 12);
    ctx.lineTo(cx + cupW / 2 - 6, cupY + cupH - 12);
    ctx.lineTo(cx + cupW / 2 - 12, liqTop);
    ctx.closePath();
    ctx.fill();
    ctx.globalAlpha = 1;

    // Metal sample in metal mode
    if (model.mode === "metal") {
      var met = CalorimetryModel.METALS[model.metal] || CalorimetryModel.METALS.Cu;
      ctx.fillStyle = met.color;
      ctx.strokeStyle = "#1b1b1b";
      ctx.lineWidth = 1.5;
      ctx.fillRect(cx - 18, liqTop + 40, 36, 28);
      ctx.strokeRect(cx - 18, liqTop + 40, 36, 28);
      ctx.fillStyle = "#1b1b1b";
      ctx.font = "600 10px DM Sans, Arial, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(met.name, cx, liqTop + 58);
    }

    // Lid
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(cx - cupW / 2 - 6, cupY);
    ctx.lineTo(cx + cupW / 2 + 6, cupY);
    ctx.stroke();

    // Title
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    var titles = {
      metal: "Coffee-cup · specific heat",
      solution: "Coffee-cup · enthalpy of solution",
      neut: "Coffee-cup · neutralisation"
    };
    ctx.fillText(titles[model.mode] || "Coffee-cup calorimeter", 20, 28);

    // Energy flow annotation
    var dT = res.Tf - (res.Ti != null ? res.Ti : model.Twater);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = dT >= 0 ? "#c62828" : "#1565c0";
    ctx.fillText(dT >= 0 ? "Exothermic warming" : "Endothermic cooling", 20, 50);
  }

  function drawBomb(w, h, res) {
    var cx = w * 0.32;
    var by = 80;
    // Bomb body
    ctx.fillStyle = "#546e7a";
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 3;
    roundRect(cx - 55, by, 110, 160, 12);
    ctx.fill();
    ctx.stroke();
    // Cap
    ctx.fillStyle = "#37474f";
    roundRect(cx - 40, by - 20, 80, 28, 6);
    ctx.fill();
    ctx.stroke();
    // Water bath outline
    ctx.strokeStyle = "#1565c0";
    ctx.lineWidth = 2;
    ctx.strokeRect(cx - 90, by - 40, 180, 230);
    ctx.fillStyle = "rgba(21,101,192,0.12)";
    ctx.fillRect(cx - 90, by - 40, 180, 230);

    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Bomb calorimeter · combustion", 20, 28);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#555";
    ctx.fillText("C_cal + water bath", 20, 50);

    // Sample indicator
    ctx.fillStyle = "#ffc107";
    ctx.beginPath();
    ctx.arc(cx, by + 80, 10, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#1b1b1b";
    ctx.stroke();
  }

  function roundRect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function drawThermometer(w, h, T) {
    var tx = w * 0.72;
    var ty = 60;
    var th = 280;
    var minT = 10, maxT = 90;
    var frac = Math.max(0, Math.min(1, (T - minT) / (maxT - minT)));

    // Stem
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 2;
    ctx.strokeRect(tx - 8, ty, 16, th);
    // Bulb
    ctx.beginPath();
    ctx.arc(tx, ty + th + 14, 16, 0, Math.PI * 2);
    ctx.fillStyle = tempColor(T);
    ctx.fill();
    ctx.stroke();
    // Mercury column
    var colH = frac * (th - 8);
    ctx.fillStyle = tempColor(T);
    ctx.fillRect(tx - 5, ty + th - colH, 10, colH);
    // Scale
    ctx.fillStyle = "#666";
    ctx.font = "600 10px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    for (var t = 20; t <= 80; t += 20) {
      var y = ty + th - ((t - minT) / (maxT - minT)) * (th - 8);
      ctx.beginPath();
      ctx.moveTo(tx + 10, y);
      ctx.lineTo(tx + 18, y);
      ctx.strokeStyle = "#999";
      ctx.lineWidth = 1;
      ctx.stroke();
      ctx.fillText(t + "°", tx + 22, y + 3);
    }
    // Readout
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 22px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(fmt(T, 2) + " °C", tx, ty - 16);
  }

  function updateReadouts(res) {
    setText("s-Tf", fmt(res.Tf, 2) + " °C");
    // Mode-specific
    document.querySelectorAll("[data-for]").forEach(function (el) {
      var modes = el.getAttribute("data-for").split(",");
      el.style.display = modes.indexOf(model.mode) >= 0 ? "" : "none";
    });

    if (res.mode === "metal") {
      setText("s-qMetal", fmt(res.qMetal, 1) + " J");
      setText("s-qWater", fmt(res.qWater, 1) + " J");
      setText("s-c", fmt(res.cMetal, 3) + " J·g⁻¹·°C⁻¹");
      setText("s-cRec", fmt(res.cRecovered, 3) + " J·g⁻¹·°C⁻¹");
      setStatus("Energy conserved: heat lost by metal = heat gained by water (+ calorimeter).", "ok");
    } else if (res.mode === "solution") {
      setText("s-dT", fmt(res.Tf - res.Ti, 2) + " °C");
      setText("s-qRxn", fmt(res.qRxn / 1000, 2) + " kJ");
      setText("s-dH", fmt(res.dH, 2) + " kJ/mol");
      setText("s-dHexp", fmt(res.dHexp, 2) + " kJ/mol");
      var exo = res.dH < 0;
      setStatus(exo ? "Exothermic dissolution — solution warms." : "Endothermic dissolution — solution cools.", "ok");
    } else if (res.mode === "neut") {
      setText("s-dT", fmt(res.Tf - res.Ti, 2) + " °C");
      setText("s-nLim", fmt(res.nLim, 4) + " mol");
      setText("s-qRxn", fmt(res.qRxn / 1000, 2) + " kJ");
      setText("s-dH", fmt(res.dH, 2) + " kJ/mol");
      setText("s-dHexp", fmt(res.dHexp, 2) + " kJ/mol");
      setStatus("Strong acid + strong base. ΔH per mole of water formed.", "ok");
    } else {
      setText("s-dT", fmt(res.Tf - res.Ti, 2) + " °C");
      setText("s-qRxn", fmt(res.qRxn / 1000, 2) + " kJ");
      setText("s-dU", fmt(res.dU, 1) + " kJ/mol");
      setText("s-dUexp", fmt(res.dUexp, 1) + " kJ/mol");
      setText("s-dH", fmt(res.dH, 1) + " kJ/mol");
      setText("s-Ctot", fmt(res.Ctot, 0) + " J/°C");
      setStatus("Bomb at constant volume. ΔU from q_v; ΔH ≈ ΔU + Δn_g RT.", "ok");
    }

    var eq = document.getElementById("eq-box");
    if (eq) {
      if (model.mode === "metal") {
        eq.textContent = "m_m c_m (T_f − T_m) + (m_w c_w + C_cal)(T_f − T_w) = 0";
      } else if (model.mode === "solution") {
        eq.textContent = "n ΔH_soln + (m c_w + C_cal)(T_f − T_i) = 0  →  ΔH_soln = −q_cal / n";
      } else if (model.mode === "neut") {
        eq.textContent = "n_lim ΔH_neut + (m c_w + C_cal)(T_f − T_i) = 0  →  ΔH_neut = −q_cal / n_lim";
      } else {
        eq.textContent = "q_rxn = n ΔU = −(C_bomb + m_w c_w)ΔT    ΔH ≈ ΔU + Δn_g RT";
      }
    }
  }

  function setMode(name) {
    model.mode = name;
    document.body.classList.remove("m-metal", "m-solution", "m-neut", "m-bomb");
    document.body.classList.add("m-" + name);
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-mode") === name);
    });
    var hints = {
      metal: "Hot metal into cool water. Final temperature gives the metal’s specific heat from the energy balance.",
      solution: "Salt dissolves in water. Exothermic salts warm the cup; endothermic salts cool it.",
      neut: "Strong acid meets strong base. Heat released is referenced per mole of water formed.",
      bomb: "Combustion in a constant-volume bomb. The bomb + water bath absorb the heat release."
    };
    setHint(hints[name] || "");
    var res = result();
    animCurrent = res.Ti != null ? res.Ti : (name === "metal" ? model.Twater : 25);
    animTarget = res.Tf;
    syncSliders();
    draw();
  }

  function syncSliders() {
    function S(id, val, fn) {
      var el = document.getElementById(id);
      if (el) el.value = val;
      var out = document.getElementById("o-" + id.slice(2));
      if (out && fn) out.textContent = fn(val);
    }
    S("c-mMetal", model.mMetal, function (v) { return fmt(v, 0) + " g"; });
    S("c-Tmetal", model.Tmetal, function (v) { return fmt(v, 0) + " °C"; });
    S("c-mWater", model.mWater, function (v) { return fmt(v, 0) + " g"; });
    S("c-Twater", model.Twater, function (v) { return fmt(v, 0) + " °C"; });
    S("c-cMetal", model.cMetal, function (v) { return fmt(v, 3); });
    S("c-Ccal", model.Ccal, function (v) { return fmt(v, 0) + " J/°C"; });
    S("c-nSalt", model.nSalt, function (v) { return fmt(v, 3) + " mol"; });
    S("c-dHsoln", model.dHsoln, function (v) { return fmt(v, 1) + " kJ/mol"; });
    S("c-mSolvent", model.mSolvent, function (v) { return fmt(v, 0) + " g"; });
    S("c-Tsoln", model.Tsoln, function (v) { return fmt(v, 0) + " °C"; });
    S("c-Cacid", model.Cacid, function (v) { return fmt(v, 2) + " M"; });
    S("c-Cbase", model.Cbase, function (v) { return fmt(v, 2) + " M"; });
    S("c-Vacid", model.Vacid, function (v) { return fmt(v, 0) + " mL"; });
    S("c-Vbase", model.Vbase, function (v) { return fmt(v, 0) + " mL"; });
    S("c-Tneut", model.Tneut, function (v) { return fmt(v, 0) + " °C"; });
    S("c-dHneut", model.dHneut, function (v) { return fmt(v, 1) + " kJ/mol"; });
    S("c-mSample", model.mSample, function (v) { return fmt(v, 2) + " g"; });
    S("c-molarMass", model.molarMass, function (v) { return fmt(v, 0) + " g/mol"; });
    S("c-Cbomb", model.Cbomb, function (v) { return fmt(v, 0) + " J/°C"; });
    S("c-mBombWater", model.mBombWater, function (v) { return fmt(v, 0) + " g"; });
    S("c-dUcomb", model.dUcomb, function (v) { return fmt(v, 0) + " kJ/mol"; });
    S("c-dNg", model.dNg, function (v) { return fmt(v, 1); });

    document.querySelectorAll(".pick-row[data-pick=metal] button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-metal") === model.metal);
    });
    document.querySelectorAll(".pick-row[data-pick=salt] button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-salt") === model.salt);
    });
  }

  function bindRange(id, key, scale) {
    var el = document.getElementById(id);
    if (!el) return;
    el.addEventListener("input", function () {
      var v = parseFloat(el.value);
      model[key] = scale ? v * scale : v;
      syncSliders();
      var res = result();
      animTarget = res.Tf;
      draw();
    });
  }

  function bind() {
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        setMode(btn.getAttribute("data-mode"));
      });
    });
    document.querySelectorAll(".pick-row[data-pick=metal] button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.setMetal(btn.getAttribute("data-metal"));
        syncSliders();
        draw();
      });
    });
    document.querySelectorAll(".pick-row[data-pick=salt] button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.setSalt(btn.getAttribute("data-salt"));
        syncSliders();
        draw();
      });
    });

    bindRange("c-mMetal", "mMetal");
    bindRange("c-Tmetal", "Tmetal");
    bindRange("c-mWater", "mWater");
    bindRange("c-Twater", "Twater");
    bindRange("c-cMetal", "cMetal");
    bindRange("c-Ccal", "Ccal");
    bindRange("c-nSalt", "nSalt");
    bindRange("c-dHsoln", "dHsoln");
    bindRange("c-mSolvent", "mSolvent");
    bindRange("c-Tsoln", "Tsoln");
    bindRange("c-Cacid", "Cacid");
    bindRange("c-Cbase", "Cbase");
    bindRange("c-Vacid", "Vacid");
    bindRange("c-Vbase", "Vbase");
    bindRange("c-Tneut", "Tneut");
    bindRange("c-dHneut", "dHneut");
    bindRange("c-mSample", "mSample");
    bindRange("c-molarMass", "molarMass");
    bindRange("c-Cbomb", "Cbomb");
    bindRange("c-mBombWater", "mBombWater");
    bindRange("c-dUcomb", "dUcomb");
    bindRange("c-dNg", "dNg");

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        if (p === "cu") {
          model.mode = "metal"; model.setMetal("Cu");
          model.mMetal = 50; model.Tmetal = 100; model.mWater = 100; model.Twater = 25; model.Ccal = 0;
          setHint("Copper slug at 100 °C into 25 °C water — classic specific-heat determination.");
        } else if (p === "al") {
          model.mode = "metal"; model.setMetal("Al");
          model.mMetal = 40; model.Tmetal = 100; model.mWater = 100; model.Twater = 22; model.Ccal = 20;
          setHint("Aluminium with a small calorimeter constant C_cal.");
        } else if (p === "naoh") {
          model.mode = "solution"; model.setSalt("NaOH");
          model.nSalt = 0.05; model.mSolvent = 100; model.Tsoln = 25; model.Ccal = 0;
          setHint("NaOH dissolves exothermically — watch the temperature rise.");
        } else if (p === "nh4") {
          model.mode = "solution"; model.setSalt("NH4NO3");
          model.nSalt = 0.05; model.mSolvent = 100; model.Tsoln = 25; model.Ccal = 0;
          setHint("Ammonium nitrate dissolves endothermically — the cup cools (cold pack).");
        } else if (p === "neut") {
          model.mode = "neut";
          model.Cacid = 1; model.Cbase = 1; model.Vacid = 50; model.Vbase = 50;
          model.Tneut = 25; model.dHneut = -55.8; model.Ccal = 0;
          setHint("50 mL of 1 M HCl + 50 mL of 1 M NaOH.");
        } else if (p === "bomb") {
          model.mode = "bomb";
          model.mSample = 1; model.molarMass = 180; model.dUcomb = -2803;
          model.Cbomb = 2500; model.mBombWater = 2000; model.Tbomb = 25; model.dNg = 0;
          setHint("Combustion of ~1 g organic sample in a bomb calorimeter.");
        }
        document.body.classList.remove("m-metal", "m-solution", "m-neut", "m-bomb");
        document.body.classList.add("m-" + model.mode);
        document.querySelectorAll(".mode-tabs button").forEach(function (b) {
          b.classList.toggle("active", b.getAttribute("data-mode") === model.mode);
        });
        var res = result();
        animCurrent = res.Ti != null ? res.Ti : model.Twater;
        animTarget = res.Tf;
        syncSliders();
        draw();
      });
    });

    window.addEventListener("resize", function () { resize(); draw(); });
  }

  function tick() {
    if (animCurrent != null && animTarget != null) {
      animCurrent += (animTarget - animCurrent) * 0.08;
      if (Math.abs(animTarget - animCurrent) < 0.01) animCurrent = animTarget;
    }
    draw();
    requestAnimationFrame(tick);
  }

  function init() {
    bind();
    resize();
    document.body.classList.add("m-metal");
    setMode("metal");
    requestAnimationFrame(tick);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

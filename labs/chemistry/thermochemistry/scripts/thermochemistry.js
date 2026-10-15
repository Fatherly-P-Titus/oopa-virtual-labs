/**
 * Thermochemistry UI – formation, Hess cycles, bond estimates.
 */
(function () {
  "use strict";

  var model = new ThermoModel();
  var canvas = document.getElementById("thermo-canvas");
  var ctx = canvas.getContext("2d");
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
    return Number(n).toFixed(d == null ? 1 : d);
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
    var res = model.solve();
    if (model.mode === "formation") drawFormation(w, h, res);
    else if (model.mode === "hess") drawHess(w, h, res);
    else drawBond(w, h, res);
    updatePanel(res);
  }

  function arrow(x1, y1, x2, y2, color) {
    ctx.strokeStyle = color || "#1b1b1b";
    ctx.fillStyle = color || "#1b1b1b";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x2, y2);
    ctx.stroke();
    var ang = Math.atan2(y2 - y1, x2 - x1);
    ctx.beginPath();
    ctx.moveTo(x2, y2);
    ctx.lineTo(x2 - 10 * Math.cos(ang - 0.4), y2 - 10 * Math.sin(ang - 0.4));
    ctx.lineTo(x2 - 10 * Math.cos(ang + 0.4), y2 - 10 * Math.sin(ang + 0.4));
    ctx.closePath();
    ctx.fill();
  }

  function drawFormation(w, h, res) {
    // Energy level diagram: reactants → products
    var dH = res.dH;
    var midX = w * 0.5;
    var baseY = h * 0.55;
    var scale = Math.min(80, Math.abs(dH) > 1 ? 120 / Math.abs(dH) * 50 : 40);
    var reactY = baseY;
    var prodY = baseY + (dH > 0 ? -Math.min(100, Math.abs(dH) * scale / 50) : Math.min(100, Math.abs(dH) * scale / 50));
    // For exo dH<0, products lower
    if (dH < 0) {
      prodY = baseY + Math.min(110, Math.abs(dH) * 0.15);
      reactY = baseY - 20;
    } else {
      reactY = baseY + 20;
      prodY = baseY - Math.min(110, Math.abs(dH) * 0.15);
    }

    // Reactant bar
    ctx.fillStyle = "#1565c0";
    ctx.fillRect(midX - 140, reactY - 6, 100, 12);
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("Reactants", midX - 90, reactY - 14);

    // Product bar
    ctx.fillStyle = "#c62828";
    ctx.fillRect(midX + 40, prodY - 6, 100, 12);
    ctx.fillText("Products", midX + 90, prodY - 14);

    // Arrow
    arrow(midX - 30, reactY, midX + 30, prodY, dH < 0 ? "#2e7d32" : "#c62828");

    // ΔH label
    ctx.font = "700 16px DM Sans, Arial, sans-serif";
    ctx.fillStyle = dH < 0 ? "#2e7d32" : "#c62828";
    ctx.fillText("ΔH° = " + fmt(dH, 1) + " kJ/mol", midX, Math.min(reactY, prodY) - 36);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#666";
    ctx.fillText(dH < 0 ? "Exothermic" : "Endothermic", midX, Math.min(reactY, prodY) - 18);

    // Equation
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(res.name, 20, 28);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#555";
    var eq = formatTerms(res.terms);
    ctx.fillText(eq, 20, 50);

    // Formula reminder
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#888";
    ctx.fillText("ΔH°_rxn = Σ ν ΔH_f°(products) − Σ ν ΔH_f°(reactants)", 20, h - 20);
  }

  function formatTerms(terms) {
    var left = [], right = [];
    terms.forEach(function (t) {
      var s = (Math.abs(t.coef) === 1 ? "" : String(t.coef)) + t.species;
      if (t.coef < 0) left.push((Math.abs(t.coef) === 1 ? "" : String(Math.abs(t.coef))) + t.species);
      else right.push((t.coef === 1 ? "" : String(t.coef)) + t.species);
    });
    return left.join(" + ") + " → " + right.join(" + ");
  }

  function drawHess(w, h, res) {
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(res.name, 20, 28);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#555";
    ctx.fillText("Target: " + res.targetName, 20, 50);

    // Cycle as stacked steps
    var y0 = 80;
    var boxW = Math.min(420, w - 80);
    var x0 = (w - boxW) / 2;

    res.applied.forEach(function (step, i) {
      var y = y0 + i * 70;
      ctx.fillStyle = step.mult === 0 ? "#eee" : (step.reversed ? "#fff3e0" : "#e8f5e9");
      ctx.strokeStyle = "#1b1b1b";
      ctx.lineWidth = 1.5;
      roundRect(x0, y, boxW, 56, 8);
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = "#1b1b1b";
      ctx.font = "600 12px DM Sans, Arial, sans-serif";
      ctx.textAlign = "left";
      var prefix = step.mult === 0 ? "(off) " : (step.reversed ? "reverse ×" + Math.abs(step.mult) + ": " : (Math.abs(step.mult) !== 1 ? "×" + step.mult + ": " : ""));
      ctx.fillText(prefix + step.label, x0 + 12, y + 22);
      ctx.font = "700 13px DM Sans, Arial, sans-serif";
      ctx.fillStyle = step.contrib < 0 ? "#2e7d32" : (step.contrib > 0 ? "#c62828" : "#888");
      ctx.textAlign = "right";
      ctx.fillText((step.contrib >= 0 ? "+" : "") + fmt(step.contrib, 1) + " kJ", x0 + boxW - 12, y + 22);
      ctx.font = "600 11px DM Sans, Arial, sans-serif";
      ctx.fillStyle = "#888";
      ctx.fillText("step ΔH = " + fmt(step.dH, 1) + " kJ", x0 + boxW - 12, y + 42);
    });

    // Total
    var ty = y0 + res.applied.length * 70 + 10;
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 16px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("Σ ΔH = " + fmt(res.totalDH, 1) + " kJ", w / 2, ty);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = res.match ? "#2e7d32" : "#c62828";
    ctx.fillText(res.match ? "Stoichiometry matches target" : "Stoichiometry does NOT match target — adjust multipliers", w / 2, ty + 22);
  }

  function drawBond(w, h, res) {
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(res.name, 20, 28);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#555";
    ctx.fillText("ΔH ≈ Σ bonds broken − Σ bonds formed", 20, 50);

    var mid = w / 2;
    // Broken column
    ctx.fillStyle = "#c62828";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("Broken (+)", mid - 120, 90);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#1b1b1b";
    res.broken.forEach(function (b, i) {
      ctx.fillText(b.n + " × " + b.bond + " = " + fmt(b.total, 0) + " kJ", mid - 120, 115 + i * 20);
    });
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#c62828";
    ctx.fillText("Σ = " + fmt(res.sumBroken, 0) + " kJ", mid - 120, 115 + res.broken.length * 20 + 10);

    // Formed column
    ctx.fillStyle = "#2e7d32";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.fillText("Formed (−)", mid + 120, 90);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#1b1b1b";
    res.formed.forEach(function (b, i) {
      ctx.fillText(b.n + " × " + b.bond + " = " + fmt(b.total, 0) + " kJ", mid + 120, 115 + i * 20);
    });
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#2e7d32";
    ctx.fillText("Σ = " + fmt(res.sumFormed, 0) + " kJ", mid + 120, 115 + res.formed.length * 20 + 10);

    // Result
    var dH = res.dH;
    ctx.font = "700 20px DM Sans, Arial, sans-serif";
    ctx.fillStyle = dH < 0 ? "#2e7d32" : "#c62828";
    ctx.fillText("ΔH ≈ " + fmt(dH, 0) + " kJ/mol", mid, h - 50);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#888";
    ctx.fillText("Bond method is approximate (average bond enthalpies)", mid, h - 28);
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

  function updatePanel(res) {
    document.querySelectorAll("[data-for]").forEach(function (el) {
      var modes = el.getAttribute("data-for").split(",");
      el.style.display = modes.indexOf(model.mode) >= 0 ? "" : "none";
    });

    if (res.mode === "formation") {
      setText("s-dH", fmt(res.dH, 1) + " kJ/mol");
      setText("s-type", res.dH < 0 ? "Exothermic" : "Endothermic");
      var body = document.getElementById("form-body");
      if (body) {
        body.innerHTML = res.lines.map(function (l) {
          return "<tr><td>" + (l.coef > 0 ? "+" : "") + l.coef + " " + l.species +
            "</td><td>" + fmt(l.hf, 1) + "</td><td>" + fmt(l.contrib, 1) + "</td></tr>";
        }).join("");
      }
      setStatus(res.ok ? "ΔH° from standard enthalpies of formation." : "Missing ΔH_f for: " + res.missing.join(", "), res.ok ? "ok" : "err");
    } else if (res.mode === "hess") {
      setText("s-dH", fmt(res.totalDH, 1) + " kJ");
      setText("s-match", res.match ? "Yes" : "No");
      if (res.refDH != null) setText("s-ref", fmt(res.refDH, 1) + " kJ");
      else setText("s-ref", "–");
      buildHessSteps(res);
      setStatus(res.match
        ? "Cycle closed — total ΔH is the target enthalpy change."
        : "Adjust step multipliers (scale / reverse) until net stoichiometry matches the target.",
        res.match ? "ok" : "err");
    } else {
      setText("s-dH", fmt(res.dH, 0) + " kJ/mol");
      setText("s-broken", fmt(res.sumBroken, 0) + " kJ");
      setText("s-formed", fmt(res.sumFormed, 0) + " kJ");
      setStatus("Bond-enthalpy estimate. Compare with formation-based values when available.", "ok");
    }
  }

  function buildHessSteps(res) {
    var box = document.getElementById("hess-steps");
    if (!box) return;
    box.innerHTML = "";
    res.steps.forEach(function (step) {
      var m = model.multipliers[step.id] != null ? model.multipliers[step.id] : 1;
      var card = document.createElement("div");
      card.className = "step-card";
      card.innerHTML =
        "<div class='label'>" + step.label + "  (ΔH = " + fmt(step.dH, 1) + " kJ)</div>" +
        "<div class='row'>" +
        "<button type='button' class='mini' data-act='rev' data-id='" + step.id + "'>Reverse</button>" +
        "<button type='button' class='mini' data-act='off' data-id='" + step.id + "'>Off</button>" +
        "<label>× <input type='number' step='0.5' value='" + m + "' data-id='" + step.id + "'></label>" +
        "<span class='contrib'>" + fmt(m * step.dH, 1) + " kJ</span>" +
        "</div>";
      box.appendChild(card);
    });

    box.querySelectorAll("input[type=number]").forEach(function (inp) {
      inp.addEventListener("change", function () {
        model.multipliers[inp.getAttribute("data-id")] = parseFloat(inp.value) || 0;
        draw();
      });
    });
    box.querySelectorAll("button[data-act]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var id = btn.getAttribute("data-id");
        var act = btn.getAttribute("data-act");
        var cur = model.multipliers[id] != null ? model.multipliers[id] : 1;
        if (act === "rev") model.multipliers[id] = cur === 0 ? -1 : -cur;
        if (act === "off") model.multipliers[id] = 0;
        draw();
      });
    });
  }

  function setMode(name) {
    model.mode = name;
    document.body.classList.remove("m-formation", "m-hess", "m-bond");
    document.body.classList.add("m-" + name);
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-mode") === name);
    });
    var hints = {
      formation: "ΔH° from tabulated enthalpies of formation. Choose a target reaction.",
      hess: "Combine thermochemical equations: scale, reverse, add. Match the target stoichiometry.",
      bond: "Estimate ΔH from average bond enthalpies: broken minus formed."
    };
    setHint(hints[name] || "");
    if (name === "hess" && !Object.keys(model.multipliers).length) model.setCycle(model.cycleId);
    draw();
  }

  function bind() {
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        setMode(btn.getAttribute("data-mode"));
      });
    });

    document.querySelectorAll(".pick-row[data-pick=target] button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.targetId = btn.getAttribute("data-target");
        document.querySelectorAll(".pick-row[data-pick=target] button").forEach(function (b) {
          b.classList.toggle("active", b === btn);
        });
        draw();
      });
    });

    document.querySelectorAll(".pick-row[data-pick=cycle] button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.setCycle(btn.getAttribute("data-cycle"));
        document.querySelectorAll(".pick-row[data-pick=cycle] button").forEach(function (b) {
          b.classList.toggle("active", b === btn);
        });
        draw();
      });
    });

    document.querySelectorAll(".pick-row[data-pick=bond] button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.bondRxnId = btn.getAttribute("data-bond");
        document.querySelectorAll(".pick-row[data-pick=bond] button").forEach(function (b) {
          b.classList.toggle("active", b === btn);
        });
        draw();
      });
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        if (p === "ch4") {
          model.mode = "formation"; model.targetId = "comb_ch4";
          setHint("Combustion of methane from formation enthalpies.");
        } else if (p === "co-path") {
          model.mode = "hess"; model.setCycle("co_path");
          setHint("Classic C → CO → CO₂ Hess path. Both steps ×1 should match CO₂ formation.");
        } else if (p === "methane-hess") {
          model.mode = "hess"; model.setCycle("methane");
          // Correct combination: s1 + 2*s2 - s3
          model.multipliers = { s1: 1, s2: 2, s3: -1 };
          setHint("Formation of CH₄: combustion of C + 2× formation of water − combustion of CH₄.");
        } else if (p === "bonds") {
          model.mode = "bond"; model.bondRxnId = "n2_h2";
          setHint("Haber reaction via bond enthalpies — compare with formation value (−45.9 kJ/mol NH₃).");
        }
        document.body.classList.remove("m-formation", "m-hess", "m-bond");
        document.body.classList.add("m-" + model.mode);
        document.querySelectorAll(".mode-tabs button").forEach(function (b) {
          b.classList.toggle("active", b.getAttribute("data-mode") === model.mode);
        });
        // sync pick rows
        document.querySelectorAll(".pick-row[data-pick=target] button").forEach(function (b) {
          b.classList.toggle("active", b.getAttribute("data-target") === model.targetId);
        });
        document.querySelectorAll(".pick-row[data-pick=cycle] button").forEach(function (b) {
          b.classList.toggle("active", b.getAttribute("data-cycle") === model.cycleId);
        });
        document.querySelectorAll(".pick-row[data-pick=bond] button").forEach(function (b) {
          b.classList.toggle("active", b.getAttribute("data-bond") === model.bondRxnId);
        });
        draw();
      });
    });

    window.addEventListener("resize", resize);
  }

  function init() {
    bind();
    document.body.classList.add("m-formation");
    resize();
    setMode("formation");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

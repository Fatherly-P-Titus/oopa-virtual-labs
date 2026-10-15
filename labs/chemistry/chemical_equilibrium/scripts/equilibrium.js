/**
 * Chemical Equilibrium UI – bar chart, ICE table, Le Chatelier controls.
 */
(function () {
  "use strict";

  var model = new EquilibriumModel();
  var canvas = document.getElementById("eq-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");
  var statusEl = document.getElementById("status-line");
  var COLORS = ["#b22222", "#1565c0", "#2e7d32", "#6a1b9a", "#ef6c00"];

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
    if (Math.abs(n) < 1e-4 && n !== 0) return n.toExponential(2);
    return Number(n).toFixed(d == null ? 3 : d);
  }

  function resize() {
    var rect = canvas.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(320, Math.floor(rect.width * dpr));
    canvas.height = Math.floor(360 * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    draw();
  }

  function labelOf(s, rxn) {
    if (rxn.labels && rxn.labels[s]) return rxn.labels[s];
    return s;
  }

  function draw() {
    var w = canvas.clientWidth || 640;
    var h = 360;
    ctx.clearRect(0, 0, w, h);
    var res = model.solve();
    if (!res.ok) {
      setStatus(res.message, "err");
      return;
    }
    setStatus(res.message, "ok");

    var rxn = res.rxn;
    var species = rxn.species;
    var padL = 50, padR = 20, padT = 50, padB = 50;
    var plotW = w - padL - padR;
    var plotH = h - padT - padB;

    var maxC = 0.1;
    species.forEach(function (s) {
      maxC = Math.max(maxC, res.initialConc[s] || 0, res.conc[s] || 0);
    });
    maxC *= 1.15;

    var groupW = plotW / species.length;
    var barW = groupW * 0.28;

    species.forEach(function (s, i) {
      var cx = padL + (i + 0.5) * groupW;
      var c0 = res.initialConc[s] || 0;
      var ce = res.conc[s] || 0;
      var h0 = (c0 / maxC) * plotH;
      var he = (ce / maxC) * plotH;

      // Initial (light)
      ctx.fillStyle = "rgba(0,0,0,0.12)";
      ctx.fillRect(cx - barW - 4, padT + plotH - h0, barW, h0);
      // Equilibrium
      ctx.fillStyle = COLORS[i % COLORS.length];
      ctx.fillRect(cx + 4, padT + plotH - he, barW, he);

      ctx.fillStyle = "#1b1b1b";
      ctx.font = "700 12px DM Sans, Arial, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(labelOf(s, rxn), cx, padT + plotH + 18);
      ctx.font = "600 10px DM Sans, Arial, sans-serif";
      ctx.fillStyle = "#666";
      ctx.fillText(fmt(ce, 3), cx, padT + plotH - he - 6);
    });

    // Baseline
    ctx.strokeStyle = "#ccc";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(padL, padT + plotH);
    ctx.lineTo(padL + plotW, padT + plotH);
    ctx.stroke();

    // Legend
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "rgba(0,0,0,0.35)";
    ctx.fillRect(padL, 14, 12, 12);
    ctx.fillStyle = "#666";
    ctx.textAlign = "left";
    ctx.fillText("Initial", padL + 18, 24);
    ctx.fillStyle = COLORS[0];
    ctx.fillRect(padL + 80, 14, 12, 12);
    ctx.fillStyle = "#666";
    ctx.fillText("Equilibrium", padL + 98, 24);

    // Title
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "right";
    ctx.fillText(rxn.name, w - padR, 24);

    updateICE(res);
    updateReadouts(res);
  }

  function updateICE(res) {
    var head = document.getElementById("ice-head");
    var body = document.getElementById("ice-body");
    if (!head || !body) return;
    var rxn = res.rxn;
    var species = rxn.species;

    head.innerHTML = "<th></th>" + species.map(function (s) {
      return "<th>" + labelOf(s, rxn) + "</th>";
    }).join("");

    function row(label, vals) {
      return "<tr><td style='text-align:left;font-weight:600;color:#666'>" + label + "</td>" +
        vals.map(function (v) { return "<td>" + v + "</td>"; }).join("") + "</tr>";
    }

    var init = species.map(function (s) { return fmt(res.initialConc[s], 3); });
    var change = species.map(function (s) {
      var d = (res.conc[s] || 0) - (res.initialConc[s] || 0);
      var sign = d >= 0 ? "+" : "";
      return sign + fmt(d, 3);
    });
    var eq = species.map(function (s) { return fmt(res.conc[s], 3); });

    body.innerHTML = row("I", init) + row("C", change) + row("E", eq);
  }

  function updateReadouts(res) {
    setText("s-Kc", fmt(res.Kc, 3));
    setText("s-Q", fmt(res.Q, 3));
    setText("s-xi", fmt(res.xi, 4));
    setText("s-V", fmt(res.V, 2) + " L");
    setText("s-expr", res.rxn.KcExpr);
  }

  function buildSpeciesControls() {
    var box = document.getElementById("species-ctls");
    if (!box) return;
    box.innerHTML = "";
    var rxn = model.rxn();
    rxn.species.forEach(function (s) {
      var wrap = document.createElement("div");
      wrap.className = "ctl";
      var lab = document.createElement("label");
      lab.htmlFor = "c-" + s;
      lab.textContent = "n₀(" + labelOf(s, rxn) + ") mol";
      var out = document.createElement("output");
      out.id = "o-" + s;
      out.textContent = fmt(model.initial[s] || 0, 2);
      var inp = document.createElement("input");
      inp.type = "range";
      inp.id = "c-" + s;
      inp.min = "0";
      inp.max = "5";
      inp.step = "0.05";
      inp.value = model.initial[s] != null ? model.initial[s] : 0;
      inp.addEventListener("input", function () {
        model.initial[s] = parseFloat(inp.value);
        out.textContent = fmt(inp.value, 2);
        draw();
      });
      wrap.appendChild(lab);
      wrap.appendChild(out);
      wrap.appendChild(inp);
      box.appendChild(wrap);
    });
  }

  function setReaction(id) {
    model.reaction = id;
    var rxn = model.rxn();
    // sensible defaults
    if (id === "isom") {
      model.initial = { A: 1, B: 0, C: 0, N2: 0, H2: 0, NH3: 0 };
      model.Kc = 4; model.V = 1;
    } else if (id === "addition") {
      model.initial = { A: 1, B: 1, C: 0, N2: 0, H2: 0, NH3: 0 };
      model.Kc = 10; model.V = 1;
    } else if (id === "dimer") {
      model.initial = { A: 1, B: 0, C: 0, N2: 0, H2: 0, NH3: 0 };
      model.Kc = 5; model.V = 1;
    } else {
      model.initial = { A: 0, B: 0, C: 0, N2: 1, H2: 3, NH3: 0 };
      model.Kc = 0.5; model.V = 1;
    }
    document.querySelectorAll(".rxn-row button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-rxn") === id);
    });
    syncSliders();
    buildSpeciesControls();
    draw();
    setHint(rxn.name + " — Kc = " + rxn.KcExpr + ". Change amounts, Kc or volume to shift the position.");
  }

  function syncSliders() {
    setSlider("c-Kc", model.Kc, function (v) { return fmt(v, 2); });
    setSlider("c-V", model.V, function (v) { return fmt(v, 2) + " L"; });
  }

  function setSlider(id, val, fmtFn) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out && fmtFn) out.textContent = fmtFn(val);
  }

  function bind() {
    document.querySelectorAll(".rxn-row button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        setReaction(btn.getAttribute("data-rxn"));
      });
    });
    document.getElementById("c-Kc").addEventListener("input", function () {
      model.Kc = parseFloat(this.value);
      setSlider("c-Kc", this.value, function (v) { return fmt(v, 2); });
      draw();
    });
    document.getElementById("c-V").addEventListener("input", function () {
      model.V = parseFloat(this.value);
      setSlider("c-V", this.value, function (v) { return fmt(v, 2) + " L"; });
      draw();
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        if (p === "forward") {
          model.Kc = Math.min(100, model.Kc * 3);
          setHint("Larger Kc favours products (e.g. lower T for an exothermic reaction).");
        } else if (p === "reverse") {
          model.Kc = Math.max(0.01, model.Kc / 3);
          setHint("Smaller Kc favours reactants (e.g. higher T for an exothermic reaction).");
        } else if (p === "compress") {
          model.V = Math.max(0.2, model.V / 2);
          setHint("Smaller volume raises all concentrations. For Haber, equilibrium shifts toward fewer gas moles (NH₃).");
        } else if (p === "dilute") {
          model.V = Math.min(5, model.V * 2);
          setHint("Larger volume dilutes everything. Reactions that produce more particles are favoured.");
        } else if (p === "add-product") {
          var rxn = model.rxn();
          var last = rxn.species[rxn.species.length - 1];
          model.initial[last] = (model.initial[last] || 0) + 0.5;
          setHint("Extra product — system shifts left to consume some of it (Le Chatelier).");
        }
        syncSliders();
        buildSpeciesControls();
        draw();
      });
    });

    window.addEventListener("resize", resize);
  }

  function init() {
    bind();
    resize();
    setReaction("isom");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

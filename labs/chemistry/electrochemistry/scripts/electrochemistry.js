/**
 * Electrochemistry UI – galvanic cell diagram, Nernst, ΔG.
 */
(function () {
  "use strict";

  var model = new ElectrochemistryModel();
  var canvas = document.getElementById("cell-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");
  var statusEl = document.getElementById("status-line");
  var eFlowPhase = 0;

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
    if (n === 0) return "0";
    var a = Math.abs(n);
    if (a >= 1e6 || a < 1e-3) return n.toExponential(2);
    return n.toFixed(2);
  }

  function resize() {
    var rect = canvas.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(320, Math.floor(rect.width * dpr));
    canvas.height = Math.floor(440 * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    draw();
  }

  function draw() {
    var w = canvas.clientWidth || 700;
    var h = 440;
    ctx.clearRect(0, 0, w, h);
    var res = model.solve();

    // Layout: left beaker, salt bridge, right beaker, wire on top with voltmeter
    var leftX = w * 0.12;
    var rightX = w * 0.58;
    var beakerW = w * 0.28;
    var beakerH = 200;
    var beakerY = 140;

    drawBeaker(leftX, beakerY, beakerW, beakerH, res.left, model.cLeft, res.anodeSide === "left", res);
    drawBeaker(rightX, beakerY, beakerW, beakerH, res.right, model.cRight, res.anodeSide === "right", res);

    // Salt bridge
    var sbX1 = leftX + beakerW - 4;
    var sbX2 = rightX + 4;
    var sbY = beakerY + 40;
    ctx.strokeStyle = "#6d4c41";
    ctx.lineWidth = 14;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(sbX1, sbY);
    ctx.bezierCurveTo(sbX1 + 30, sbY - 50, sbX2 - 30, sbY - 50, sbX2, sbY);
    ctx.stroke();
    ctx.fillStyle = "#5d4037";
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("salt bridge", (sbX1 + sbX2) / 2, sbY - 58);

    // Wire + voltmeter
    var wireY = 70;
    var eL = leftX + beakerW / 2;
    var eR = rightX + beakerW / 2;
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(eL, beakerY);
    ctx.lineTo(eL, wireY);
    ctx.lineTo(eR, wireY);
    ctx.lineTo(eR, beakerY);
    ctx.stroke();

    // Voltmeter box
    var vmX = (eL + eR) / 2;
    ctx.fillStyle = "#fff";
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 2;
    roundRect(vmX - 48, wireY - 28, 96, 36, 6);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = res.spontaneous ? "#2e7d32" : "#c62828";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(fmt(res.E, 3) + " V", vmX, wireY - 10);

    // Electron flow animation (anode → cathode externally)
    var anodeX = res.anodeSide === "left" ? eL : eR;
    var cathodeX = res.cathodeSide === "left" ? eL : eR;
    if (res.spontaneous) {
      drawElectronFlow(anodeX, cathodeX, wireY, beakerY);
    }

    // Labels
    ctx.fillStyle = "#c62828";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    var anX = res.anodeSide === "left" ? leftX + beakerW / 2 : rightX + beakerW / 2;
    var caX = res.cathodeSide === "left" ? leftX + beakerW / 2 : rightX + beakerW / 2;
    ctx.fillText("ANODE (−) oxidation", anX, beakerY + beakerH + 28);
    ctx.fillStyle = "#1565c0";
    ctx.fillText("CATHODE (+) reduction", caX, beakerY + beakerH + 28);

    // Title
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(res.anode.metal + " | " + res.anode.ion + " || " + res.cathode.ion + " | " + res.cathode.metal, 20, 28);

    updatePanel(res);
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

  function drawBeaker(x, y, w, h, half, conc, isAnode, res) {
    // Glass
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x, y + h);
    ctx.lineTo(x + w, y + h);
    ctx.lineTo(x + w, y);
    ctx.stroke();

    // Solution
    var solH = h * 0.62;
    ctx.fillStyle = isAnode ? "rgba(198,40,40,0.18)" : "rgba(21,101,192,0.18)";
    ctx.fillRect(x + 3, y + h - solH, w - 6, solH - 2);

    // Electrode strip
    var ex = x + w / 2 - 10;
    var ey = y + 10;
    var eh = h - 30;
    ctx.fillStyle = half.color;
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 1.5;
    ctx.fillRect(ex, ey, 20, eh);
    ctx.strokeRect(ex, ey, 20, eh);

    // Bubbles for gas electrodes
    if (half.gas) {
      ctx.fillStyle = "rgba(255,255,255,0.7)";
      for (var i = 0; i < 5; i++) {
        ctx.beginPath();
        ctx.arc(ex + 10 + (i % 2) * 8 - 4, y + h - 30 - i * 18, 3, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Labels
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(half.metal, x + w / 2, y + h - solH - 12);
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#555";
    ctx.fillText(half.ion + "  " + fmt(conc, 2) + " M", x + w / 2, y + h - 12);
    ctx.fillText("E° = " + fmt(half.E0, 2) + " V", x + w / 2, y - 8);
  }

  function drawElectronFlow(anodeX, cathodeX, wireY, beakerY) {
    // Dashed electron path along wire with moving dots
    var t = eFlowPhase;
    var points = [];
    // up from anode
    for (var i = 0; i <= 8; i++) {
      points.push({ x: anodeX, y: beakerY - (beakerY - wireY) * (i / 8) });
    }
    // across
    var dir = cathodeX > anodeX ? 1 : -1;
    var span = Math.abs(cathodeX - anodeX);
    for (var j = 1; j <= 12; j++) {
      points.push({ x: anodeX + dir * span * (j / 12), y: wireY });
    }
    // down to cathode
    for (var k = 1; k <= 8; k++) {
      points.push({ x: cathodeX, y: wireY + (beakerY - wireY) * (k / 8) });
    }

    ctx.fillStyle = "#ffc107";
    var n = points.length;
    for (var p = 0; p < 5; p++) {
      var idx = Math.floor((t * 0.4 + p * n / 5) % n);
      var pt = points[idx];
      if (!pt) continue;
      ctx.beginPath();
      ctx.arc(pt.x, pt.y, 3.5, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = "#666";
    ctx.font = "600 10px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("e⁻", (anodeX + cathodeX) / 2, wireY - 36);
  }

  function updatePanel(res) {
    setText("s-E0", fmt(res.E0, 3) + " V");
    setText("s-E", fmt(res.E, 3) + " V");
    setText("s-n", String(res.n));
    setText("s-Q", fmtSci(res.Q));
    setText("s-dG", fmt(res.dG / 1000, 1) + " kJ/mol");
    setText("s-dG0", fmt(res.dG0 / 1000, 1) + " kJ/mol");
    setText("s-K", fmtSci(res.K));
    setText("s-anode", res.anode.name);
    setText("s-cathode", res.cathode.name);

    var eq = document.getElementById("eq-box");
    if (eq) {
      eq.innerHTML =
        "<div class='half'>Oxidation (anode): " + res.oxidation + "</div>" +
        "<div class='half'>Reduction (cathode): " + res.reduction + "</div>" +
        "<div class='rxn'>Cell: " + res.reaction + "</div>";
    }

    if (res.spontaneous) {
      setStatus("Spontaneous galvanic cell — E > 0, ΔG < 0. Electrons flow anode → cathode in the wire.", "ok");
    } else {
      setStatus("Non-spontaneous as drawn (E ≤ 0). Swap electrodes or change concentrations.", "err");
    }

    // Highlight potential table
    document.querySelectorAll(".potential-table tr[data-key]").forEach(function (tr) {
      var k = tr.getAttribute("data-key");
      tr.classList.toggle("active", k === res.anodeKey || k === res.cathodeKey);
    });
  }

  function fillSelects() {
    var keys = Object.keys(ElectrochemistryModel.HALF_CELLS);
    ["sel-left", "sel-right"].forEach(function (id) {
      var sel = document.getElementById(id);
      if (!sel) return;
      sel.innerHTML = "";
      keys.forEach(function (k) {
        var h = ElectrochemistryModel.HALF_CELLS[k];
        var opt = document.createElement("option");
        opt.value = k;
        opt.textContent = h.name + "  (" + (h.E0 >= 0 ? "+" : "") + h.E0.toFixed(2) + " V)";
        sel.appendChild(opt);
      });
    });
    document.getElementById("sel-left").value = model.left;
    document.getElementById("sel-right").value = model.right;
  }

  function fillPotentialTable() {
    var body = document.getElementById("pot-body");
    if (!body) return;
    var keys = Object.keys(ElectrochemistryModel.HALF_CELLS);
    keys.sort(function (a, b) {
      return ElectrochemistryModel.HALF_CELLS[b].E0 - ElectrochemistryModel.HALF_CELLS[a].E0;
    });
    body.innerHTML = keys.map(function (k) {
      var h = ElectrochemistryModel.HALF_CELLS[k];
      return "<tr data-key='" + k + "'><td>" + h.name + "</td><td>" +
        (h.E0 >= 0 ? "+" : "") + h.E0.toFixed(2) + "</td><td>" + h.n + "</td></tr>";
    }).join("");
  }

  function syncSliders() {
    setSlider("c-left", model.cLeft, function (v) { return fmt(v, 2) + " M"; });
    setSlider("c-right", model.cRight, function (v) { return fmt(v, 2) + " M"; });
  }

  function setSlider(id, val, fmtFn) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out && fmtFn) out.textContent = fmtFn(val);
  }

  function bind() {
    document.getElementById("sel-left").addEventListener("change", function () {
      model.left = this.value;
      draw();
    });
    document.getElementById("sel-right").addEventListener("change", function () {
      model.right = this.value;
      draw();
    });
    document.getElementById("c-left").addEventListener("input", function () {
      model.cLeft = parseFloat(this.value);
      setSlider("c-left", this.value, function (v) { return fmt(v, 2) + " M"; });
      draw();
    });
    document.getElementById("c-right").addEventListener("input", function () {
      model.cRight = parseFloat(this.value);
      setSlider("c-right", this.value, function (v) { return fmt(v, 2) + " M"; });
      draw();
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        if (p === "daniell") {
          model.left = "Zn"; model.right = "Cu"; model.cLeft = 1; model.cRight = 1;
          setHint("Daniell cell: Zn anode, Cu cathode. Classic E° ≈ 1.10 V.");
        } else if (p === "concent") {
          model.left = "Cu"; model.right = "Cu"; model.cLeft = 0.01; model.cRight = 1;
          setHint("Concentration cell: same metal, different [Cu²⁺]. Electrons flow to the dilute side’s companion… higher [ion] is cathode.");
        } else if (p === "agzn") {
          model.left = "Zn"; model.right = "Ag"; model.cLeft = 1; model.cRight = 1;
          setHint("Zn–Ag cell: larger E° than Daniell; n balanced via LCM of electron counts.");
        } else if (p === "she") {
          model.left = "Zn"; model.right = "H"; model.cLeft = 1; model.cRight = 1;
          setHint("Zn vs SHE: the standard potential of Zn is the cell potential when the other half is the hydrogen electrode.");
        } else if (p === "swap") {
          var t = model.left; model.left = model.right; model.right = t;
          var c = model.cLeft; model.cLeft = model.cRight; model.cRight = c;
          setHint("Electrodes swapped — anode and cathode roles follow the potentials, not the beaker side.");
        }
        fillSelects();
        syncSliders();
        draw();
      });
    });

    window.addEventListener("resize", resize);
  }

  function tick() {
    eFlowPhase += 1;
    draw();
    requestAnimationFrame(tick);
  }

  function init() {
    fillSelects();
    fillPotentialTable();
    bind();
    resize();
    syncSliders();
    setHint("Daniell cell by default. Change electrodes or concentrations — E follows the Nernst equation.");
    requestAnimationFrame(tick);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

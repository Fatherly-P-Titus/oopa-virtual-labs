/**
 * Heat Transfer UI – multilayer wall + T(x).
 */
(function () {
  "use strict";

  var model = new HeatModel();
  var wallCanvas = document.getElementById("wall-canvas");
  var txCanvas = document.getElementById("tx-canvas");
  var wctx = wallCanvas.getContext("2d");
  var tctx = txCanvas.getContext("2d");
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
    fit(wallCanvas, 240);
    fit(txCanvas, 180);
  }

  function drawWall(res) {
    var w = wallCanvas.clientWidth || 640;
    var h = 240;
    wctx.clearRect(0, 0, w, h);

    var pad = 60;
    var wallH = 100;
    var y0 = (h - wallH) / 2;
    var totalL = res.layers.reduce(function (s, l) { return s + l.L; }, 0);
    var scale = (w - 2 * pad) / Math.max(totalL, 0.01);

    // Hot / cold fluid labels
    wctx.fillStyle = "#e53935";
    wctx.font = "700 12px DM Sans, Arial, sans-serif";
    wctx.textAlign = "center";
    wctx.fillText("HOT", pad / 2, y0 + wallH / 2 - 8);
    wctx.fillText(fmt(model.T_hot, 0) + "°C", pad / 2, y0 + wallH / 2 + 10);
    wctx.fillStyle = "#1565c0";
    wctx.fillText("COLD", w - pad / 2, y0 + wallH / 2 - 8);
    wctx.fillText(fmt(model.T_cold, 0) + "°C", w - pad / 2, y0 + wallH / 2 + 10);

    // Layers
    var x = pad;
    res.layers.forEach(function (layer) {
      var lw = layer.L * scale;
      wctx.fillStyle = layer.color;
      wctx.fillRect(x, y0, lw, wallH);
      wctx.strokeStyle = "#1b1b1b";
      wctx.lineWidth = 1.5;
      wctx.strokeRect(x, y0, lw, wallH);
      wctx.fillStyle = "#1b1b1b";
      wctx.font = "600 10px DM Sans, Arial, sans-serif";
      wctx.textAlign = "center";
      if (lw > 40) {
        wctx.fillText(layer.name, x + lw / 2, y0 + wallH / 2 - 6);
        wctx.fillText(fmt(layer.L * 1000, 0) + " mm", x + lw / 2, y0 + wallH / 2 + 10);
      }
      x += lw;
    });

    // Heat flux arrow
    wctx.strokeStyle = "#b22222";
    wctx.fillStyle = "#b22222";
    wctx.lineWidth = 2.5;
    var ay = y0 - 24;
    wctx.beginPath();
    wctx.moveTo(pad, ay);
    wctx.lineTo(w - pad, ay);
    wctx.stroke();
    wctx.beginPath();
    wctx.moveTo(w - pad, ay);
    wctx.lineTo(w - pad - 10, ay - 5);
    wctx.lineTo(w - pad - 10, ay + 5);
    wctx.closePath();
    wctx.fill();
    wctx.font = "700 11px DM Sans, Arial, sans-serif";
    wctx.textAlign = "center";
    wctx.fillText("q'' = " + fmt(res.q, 1) + " W/m²", w / 2, ay - 8);
  }

  function drawTx(res) {
    var w = txCanvas.clientWidth || 640;
    var h = 180;
    tctx.clearRect(0, 0, w, h);

    var padL = 50, padR = 20, padT = 16, padB = 28;
    var plotW = w - padL - padR;
    var plotH = h - padT - padB;

    var totalL = res.layers.reduce(function (s, l) { return s + l.L; }, 0);
    // Build x positions: fluid nodes optional
    // T array includes conv nodes when useConv
    var Tmin = Math.min.apply(null, res.T);
    var Tmax = Math.max.apply(null, res.T);
    var span = Math.max(Tmax - Tmin, 1);

    // Simple x mapping across solid layers only for clarity
    // Node temperatures at solid interfaces
    var solidStart = model.useConv ? 1 : 0;
    var solidEnd = model.useConv ? res.T.length - 2 : res.T.length - 1;
    var nodeX = [0];
    var acc = 0;
    res.layers.forEach(function (l) {
      acc += l.L;
      nodeX.push(acc);
    });

    function xOf(xi) { return padL + (xi / Math.max(totalL, 1e-9)) * plotW; }
    function yOf(T) { return padT + plotH - ((T - Tmin) / span) * plotH; }

    // Axes
    tctx.strokeStyle = "#ddd";
    tctx.lineWidth = 1;
    tctx.beginPath();
    tctx.moveTo(padL, padT);
    tctx.lineTo(padL, padT + plotH);
    tctx.lineTo(padL + plotW, padT + plotH);
    tctx.stroke();

    // Layer boundaries
    tctx.strokeStyle = "rgba(0,0,0,0.1)";
    var xa = padL;
    res.layers.forEach(function (l) {
      xa += (l.L / Math.max(totalL, 1e-9)) * plotW;
      tctx.beginPath();
      tctx.moveTo(xa, padT);
      tctx.lineTo(xa, padT + plotH);
      tctx.stroke();
    });

    // Temperature polyline through solid
    var temps = [];
    if (model.useConv) {
      // T[0]=fluid hot, T[1]=surface hot, ... T[n-2]=surface cold, T[n-1]=fluid cold
      temps.push({ x: 0, T: res.T[1] });
      for (var i = 0; i < res.layers.length; i++) {
        temps.push({ x: nodeX[i + 1], T: res.T[i + 2] });
      }
    } else {
      for (var j = 0; j < nodeX.length; j++) {
        temps.push({ x: nodeX[j], T: res.T[j] });
      }
    }

    tctx.strokeStyle = "#b22222";
    tctx.lineWidth = 2.5;
    tctx.beginPath();
    temps.forEach(function (p, idx) {
      var X = xOf(p.x), Y = yOf(p.T);
      if (idx === 0) tctx.moveTo(X, Y);
      else tctx.lineTo(X, Y);
    });
    tctx.stroke();

    temps.forEach(function (p) {
      tctx.beginPath();
      tctx.arc(xOf(p.x), yOf(p.T), 4, 0, Math.PI * 2);
      tctx.fillStyle = "#b22222";
      tctx.fill();
    });

    tctx.fillStyle = "#666";
    tctx.font = "600 10px DM Sans, Arial, sans-serif";
    tctx.textAlign = "center";
    tctx.fillText("x →", padL + plotW / 2, h - 6);
    tctx.save();
    tctx.translate(14, padT + plotH / 2);
    tctx.rotate(-Math.PI / 2);
    tctx.fillText("T (°C)", 0, 0);
    tctx.restore();
  }

  function updateLayerList() {
    var box = document.getElementById("layer-list");
    if (!box) return;
    box.innerHTML = "";
    var mats = Object.keys(HeatModel.MATERIALS);
    model.layers.forEach(function (layer, idx) {
      var mat = HeatModel.MATERIALS[layer.material] || HeatModel.MATERIALS.brick;
      var row = document.createElement("div");
      row.className = "row";
      var sw = document.createElement("span");
      sw.className = "swatch";
      sw.style.background = mat.color;
      row.appendChild(sw);

      var sel = document.createElement("select");
      mats.forEach(function (key) {
        var opt = document.createElement("option");
        opt.value = key;
        opt.textContent = HeatModel.MATERIALS[key].name;
        if (key === layer.material) opt.selected = true;
        sel.appendChild(opt);
      });
      sel.addEventListener("change", function () {
        model.layers[idx].material = sel.value;
        update();
      });
      row.appendChild(sel);

      var inp = document.createElement("input");
      inp.type = "number";
      inp.min = "1";
      inp.max = "500";
      inp.step = "1";
      inp.value = Math.round(layer.L * 1000);
      inp.style.width = "4.5em";
      inp.title = "Thickness mm";
      inp.addEventListener("change", function () {
        model.layers[idx].L = Math.max(0.001, parseFloat(inp.value) / 1000);
        update();
      });
      row.appendChild(inp);
      var unit = document.createElement("span");
      unit.textContent = "mm";
      unit.style.color = "#888";
      row.appendChild(unit);

      if (model.layers.length > 1) {
        var rm = document.createElement("button");
        rm.type = "button";
        rm.textContent = "×";
        rm.title = "Remove layer";
        rm.addEventListener("click", function () {
          model.layers.splice(idx, 1);
          update();
        });
        row.appendChild(rm);
      }
      box.appendChild(row);
    });
  }

  function update() {
    var res = model.solve();
    drawWall(res);
    drawTx(res);
    updateLayerList();

    setText("s-q", fmt(res.q, 1) + " W/m²");
    setText("s-R", fmt(res.Rtot, 3) + " m²K/W");
    setText("s-U", fmt(1 / Math.max(res.Rtot, 1e-12), 2) + " W/m²K");
    setText("s-Th", fmt(model.T_hot, 1) + " °C");
    setText("s-Tc", fmt(model.T_cold, 1) + " °C");
  }

  function syncSliders() {
    setSlider("c-Th", model.T_hot, function (v) { return fmt(v, 0) + " °C"; });
    setSlider("c-Tc", model.T_cold, function (v) { return fmt(v, 0) + " °C"; });
    setSlider("c-hh", model.h_hot, function (v) { return fmt(v, 0) + " W/m²K"; });
    setSlider("c-hc", model.h_cold, function (v) { return fmt(v, 0) + " W/m²K"; });
  }

  function setSlider(id, val, fmtFn) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out && fmtFn) out.textContent = fmtFn(val);
  }

  function bind() {
    document.getElementById("c-Th").addEventListener("input", function () {
      model.T_hot = parseFloat(this.value);
      setSlider("c-Th", this.value, function (v) { return fmt(v, 0) + " °C"; });
      update();
    });
    document.getElementById("c-Tc").addEventListener("input", function () {
      model.T_cold = parseFloat(this.value);
      setSlider("c-Tc", this.value, function (v) { return fmt(v, 0) + " °C"; });
      update();
    });
    document.getElementById("c-hh").addEventListener("input", function () {
      model.h_hot = parseFloat(this.value);
      setSlider("c-hh", this.value, function (v) { return fmt(v, 0) + " W/m²K"; });
      update();
    });
    document.getElementById("c-hc").addEventListener("input", function () {
      model.h_cold = parseFloat(this.value);
      setSlider("c-hc", this.value, function (v) { return fmt(v, 0) + " W/m²K"; });
      update();
    });

    document.getElementById("btn-add").addEventListener("click", function () {
      if (model.layers.length >= 5) return;
      model.layers.push({ material: "insulation", L: 0.04 });
      update();
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        if (p === "wall") {
          model.layers = [
            { material: "brick", L: 0.1 },
            { material: "insulation", L: 0.05 },
            { material: "wood", L: 0.02 }
          ];
          model.T_hot = 20; model.T_cold = -5;
          setHint("Typical insulated wall: brick + insulation + wood finish.");
        } else if (p === "single") {
          model.layers = [{ material: "concrete", L: 0.2 }];
          model.T_hot = 25; model.T_cold = 5;
          setHint("Single concrete slab — high heat flux without insulation.");
        } else if (p === "window") {
          model.layers = [{ material: "glass", L: 0.006 }];
          model.T_hot = 20; model.T_cold = -5;
          model.h_hot = 10; model.h_cold = 25;
          setHint("Thin glass: conduction resistance is small; convection often dominates.");
        } else if (p === "metal") {
          model.layers = [{ material: "steel", L: 0.01 }];
          model.T_hot = 80; model.T_cold = 20;
          setHint("Thin steel sheet — almost isothermal through the thickness; drop is mostly convective.");
        }
        syncSliders();
        update();
      });
    });

    window.addEventListener("resize", function () { resize(); update(); });
  }

  function init() {
    bind();
    resize();
    syncSliders();
    update();
    setHint("Steady 1D wall. Add layers, change materials and thicknesses, and watch heat flux and the temperature profile.");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

/**
 * Simple Machines UI – lever, incline, pulley, wheel & axle.
 */
(function () {
  "use strict";

  var M = window.SimpleMachinesModel;
  var machine = "lever"; // lever | incline | pulley | wheel
  var state = {
    loadW: 100,
    eta: 0.9,
    // lever
    leverClass: 1,
    dL: 1.0,
    dE: 2.0,
    // incline
    angle: 30,
    mu: 0,
    // pulley
    strands: 2,
    // wheel
    R: 0.4,
    r: 0.1
  };

  var canvas = document.getElementById("machine-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");

  function result() {
    if (machine === "lever") {
      return M.lever(state.loadW, state.dL, state.dE, state.eta, state.leverClass);
    }
    if (machine === "incline") {
      return M.incline(state.loadW, state.angle, state.mu, state.eta);
    }
    if (machine === "pulley") {
      return M.pulley(state.loadW, state.strands, state.eta);
    }
    return M.wheelAxle(state.loadW, state.R, state.r, state.eta);
  }

  function resize() {
    var rect = canvas.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(320, Math.floor(rect.width * dpr));
    canvas.height = Math.floor(420 * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    draw();
  }

  function setHint(t) {
    if (hintEl) hintEl.textContent = t;
  }

  function setText(id, t) {
    var el = document.getElementById(id);
    if (el) el.textContent = t;
  }

  function fmt(n, d) {
    if (n == null || !isFinite(n)) return "–";
    return Number(n).toFixed(d == null ? 2 : d);
  }

  // ---------- Draw ----------
  function draw() {
    var w = canvas.clientWidth || 640;
    var h = 420;
    ctx.clearRect(0, 0, w, h);
    var res = result();
    if (machine === "lever") drawLever(w, h, res);
    else if (machine === "incline") drawIncline(w, h, res);
    else if (machine === "pulley") drawPulley(w, h, res);
    else drawWheel(w, h, res);
    updateReadouts(res);
  }

  function drawLever(w, h, res) {
    var midY = h * 0.55;
    var left = 80, right = w - 80;
    var span = right - left;
    // Arms proportional to dE, dL depending on class
    var total = state.dE + state.dL;
    var fulcrumX;
    var loadX, effortX;

    if (state.leverClass === 1) {
      // F between E and L
      fulcrumX = left + (state.dE / total) * span;
      effortX = left;
      loadX = right;
    } else if (state.leverClass === 2) {
      // L between F and E  (effort at end, load middle-ish, fulcrum other end)
      fulcrumX = left;
      loadX = left + (state.dL / total) * span;
      effortX = right;
    } else {
      // class 3: E between F and L
      fulcrumX = left;
      effortX = left + (state.dE / total) * span;
      loadX = right;
    }

    // Beam
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 8;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(left, midY);
    ctx.lineTo(right, midY);
    ctx.stroke();

    // Fulcrum triangle
    ctx.fillStyle = "#1b1b1b";
    ctx.beginPath();
    ctx.moveTo(fulcrumX, midY + 4);
    ctx.lineTo(fulcrumX - 16, midY + 28);
    ctx.lineTo(fulcrumX + 16, midY + 28);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#666";
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("Fulcrum", fulcrumX, midY + 44);

    // Load arrow (down)
    drawForceArrow(loadX, midY - 8, 0, -50, "#b22222", "Load " + fmt(state.loadW, 0) + " N");
    // Effort arrow (direction depends – show up for lifting)
    drawForceArrow(effortX, midY + 8, 0, 50, "#1565c0", "Effort " + fmt(res.effortActual, 1) + " N");

    // Arm labels
    ctx.fillStyle = "#666";
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    var midEL = (effortX + fulcrumX) / 2;
    var midLL = (loadX + fulcrumX) / 2;
    ctx.fillText("dE " + fmt(state.dE, 2) + " m", midEL, midY - 18);
    ctx.fillText("dL " + fmt(state.dL, 2) + " m", midLL, midY - 18);

    // Class badge
    ctx.fillStyle = "#b22222";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Class " + state.leverClass + " lever", 24, 28);
  }

  function drawForceArrow(x, y, dx, dy, color, label) {
    // dy positive = draw downward from y
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.lineWidth = 2.5;
    var x2 = x + dx;
    var y2 = y + dy;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x2, y2);
    ctx.stroke();
    var ang = Math.atan2(dy, dx || 0.001);
    ctx.beginPath();
    ctx.moveTo(x2, y2);
    ctx.lineTo(x2 - 8 * Math.cos(ang - 0.4), y2 - 8 * Math.sin(ang - 0.4));
    ctx.lineTo(x2 - 8 * Math.cos(ang + 0.4), y2 - 8 * Math.sin(ang + 0.4));
    ctx.closePath();
    ctx.fill();
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(label, x, dy > 0 ? y2 + 16 : y2 - 8);
  }

  function drawIncline(w, h, res) {
    var baseY = h - 60;
    var originX = 60;
    var len = Math.min(w - 120, 360);
    var th = (state.angle * Math.PI) / 180;
    var run = len * Math.cos(th);
    var rise = len * Math.sin(th);

    // Ground
    ctx.strokeStyle = "#ccc";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(20, baseY);
    ctx.lineTo(w - 20, baseY);
    ctx.stroke();

    // Plane
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.moveTo(originX, baseY);
    ctx.lineTo(originX + run, baseY - rise);
    ctx.stroke();

    // Fill under plane
    ctx.fillStyle = "rgba(178,34,34,0.06)";
    ctx.beginPath();
    ctx.moveTo(originX, baseY);
    ctx.lineTo(originX + run, baseY - rise);
    ctx.lineTo(originX + run, baseY);
    ctx.closePath();
    ctx.fill();

    // Angle arc
    ctx.strokeStyle = "#b22222";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(originX, baseY, 36, -th, 0);
    ctx.stroke();
    ctx.fillStyle = "#b22222";
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(fmt(state.angle, 0) + "°", originX + 42, baseY - 8);

    // Block on plane (mid)
    var mx = originX + run * 0.55;
    var my = baseY - rise * 0.55;
    ctx.save();
    ctx.translate(mx, my);
    ctx.rotate(-th);
    ctx.fillStyle = "#b22222";
    ctx.fillRect(-18, -28, 36, 24);
    ctx.restore();

    // Weight arrow (vertical)
    drawForceArrow(mx, my - 30, 0, -40, "#b22222", "W " + fmt(state.loadW, 0) + " N");
    // Effort parallel to plane (up the slope)
    var ex = Math.cos(th) * 45;
    var ey = -Math.sin(th) * 45;
    ctx.strokeStyle = "#1565c0";
    ctx.fillStyle = "#1565c0";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(mx - Math.sin(th) * 20, my - Math.cos(th) * 20);
    var e0x = mx - Math.sin(th) * 20;
    var e0y = my - Math.cos(th) * 20;
    ctx.moveTo(e0x, e0y);
    ctx.lineTo(e0x + ex, e0y + ey);
    ctx.stroke();
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("E " + fmt(res.effortActual, 1) + " N", e0x + ex * 0.5, e0y + ey * 0.5 - 12);

    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Inclined plane", 24, 28);
  }

  function drawPulley(w, h, res) {
    var cx = w * 0.45;
    var topY = 70;
    var n = state.strands;

    // Ceiling
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(cx - 80, 40);
    ctx.lineTo(cx + 80, 40);
    ctx.stroke();
    for (var i = -70; i <= 70; i += 12) {
      ctx.beginPath();
      ctx.moveTo(cx + i, 40);
      ctx.lineTo(cx + i - 8, 28);
      ctx.stroke();
    }

    // Fixed pulley
    ctx.beginPath();
    ctx.arc(cx, topY, 22, 0, Math.PI * 2);
    ctx.fillStyle = "#fff";
    ctx.fill();
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 3;
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(cx, 40);
    ctx.lineTo(cx, topY - 22);
    ctx.stroke();

    // Rope strands (schematic)
    var loadY = 280;
    ctx.strokeStyle = "#555";
    ctx.lineWidth = 2;
    if (n === 1) {
      ctx.beginPath();
      ctx.moveTo(cx + 22, topY);
      ctx.quadraticCurveTo(cx + 60, topY + 40, cx + 50, 200);
      ctx.stroke();
      drawForceArrow(cx + 50, 200, 0, 40, "#1565c0", "E " + fmt(res.effortActual, 1));
      ctx.beginPath();
      ctx.moveTo(cx - 22, topY);
      ctx.lineTo(cx - 22, loadY);
      ctx.stroke();
    } else {
      // multiple vertical strands
      var spacing = 18;
      var startX = cx - ((n - 1) * spacing) / 2;
      for (var s = 0; s < n; s++) {
        var sx = startX + s * spacing;
        ctx.beginPath();
        ctx.moveTo(sx, topY + 22);
        ctx.lineTo(sx, loadY - 20);
        ctx.stroke();
      }
      // free end for effort
      ctx.beginPath();
      ctx.moveTo(startX + (n - 1) * spacing + 10, topY);
      ctx.lineTo(cx + 70, topY + 30);
      ctx.lineTo(cx + 70, 180);
      ctx.stroke();
      drawForceArrow(cx + 70, 180, 0, 40, "#1565c0", "E " + fmt(res.effortActual, 1));

      // movable pulley block
      if (n >= 2) {
        ctx.strokeStyle = "#1b1b1b";
        ctx.lineWidth = 3;
        ctx.strokeRect(startX - 12, loadY - 36, (n - 1) * spacing + 24, 20);
        ctx.beginPath();
        ctx.arc(cx, loadY - 26, 10, 0, Math.PI * 2);
        ctx.stroke();
      }
    }

    // Load
    ctx.fillStyle = "#b22222";
    ctx.fillRect(cx - 24, loadY, 48, 36);
    ctx.fillStyle = "#fff";
    ctx.font = "700 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(fmt(state.loadW, 0) + " N", cx, loadY + 22);

    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(n === 1 ? "Fixed pulley" : n === 2 ? "Movable pulley" : "Block & tackle (" + n + " strands)", 24, 28);
  }

  function drawWheel(w, h, res) {
    var cx = w * 0.45;
    var cy = h * 0.48;
    var maxR = Math.min(110, w * 0.22);
    var scale = maxR / Math.max(state.R, state.r * 1.5);
    var Rw = state.R * scale;
    var rw = state.r * scale;

    // Wheel
    ctx.beginPath();
    ctx.arc(cx, cy, Rw, 0, Math.PI * 2);
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 4;
    ctx.stroke();
    // Axle
    ctx.beginPath();
    ctx.arc(cx, cy, rw, 0, Math.PI * 2);
    ctx.fillStyle = "#eee";
    ctx.fill();
    ctx.stroke();

    // Spokes
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = "#999";
    for (var a = 0; a < 6; a++) {
      var ang = (a * Math.PI) / 3;
      ctx.beginPath();
      ctx.moveTo(cx + Math.cos(ang) * rw, cy + Math.sin(ang) * rw);
      ctx.lineTo(cx + Math.cos(ang) * Rw, cy + Math.sin(ang) * Rw);
      ctx.stroke();
    }

    // Effort at rim (tangent up)
    drawForceArrow(cx + Rw, cy, 0, -55, "#1565c0", "E " + fmt(res.effortActual, 1) + " N");
    // Load on axle (down)
    drawForceArrow(cx, cy + rw + 4, 0, 45, "#b22222", "Load " + fmt(state.loadW, 0) + " N");

    // Radius labels
    ctx.fillStyle = "#666";
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("R " + fmt(state.R, 2) + " m", cx + Rw + 8, cy - 8);
    ctx.fillText("r " + fmt(state.r, 2) + " m", cx + rw + 8, cy + 14);

    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Wheel and axle", 24, 28);
  }

  function updateReadouts(res) {
    setText("s-ma-ideal", fmt(res.maIdeal, 2));
    setText("s-ma-actual", fmt(res.maActual, 2));
    setText("s-effort-ideal", fmt(res.effortIdeal, 2) + " N");
    setText("s-effort-actual", fmt(res.effortActual, 2) + " N");
    setText("s-load", fmt(state.loadW, 0) + " N");
    setText("s-eta", fmt(state.eta * 100, 0) + "%");
  }

  // ---------- Controls ----------
  function setMachine(name) {
    machine = name;
    document.body.classList.remove("m-lever", "m-incline", "m-pulley", "m-wheel");
    document.body.classList.add("m-" + name);
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-machine") === name);
    });
    var hints = {
      lever: "Class 1: fulcrum between effort and load. Class 2: load between. Class 3: effort between.",
      incline: "Effort is parallel to the plane. Steeper angles need more effort; friction increases it further.",
      pulley: "Ideal MA equals the number of supporting rope strands. Fixed single ≈ 1; movable ≈ 2.",
      wheel: "Effort on the large radius, load on the axle. MA = R / r."
    };
    setHint(hints[name] || "");
    syncSliders();
    draw();
  }

  function syncSliders() {
    setSlider("c-load", state.loadW);
    setSlider("c-eta", state.eta * 100);
    setSlider("c-dL", state.dL);
    setSlider("c-dE", state.dE);
    setSlider("c-angle", state.angle);
    setSlider("c-mu", state.mu);
    setSlider("c-strands", state.strands);
    setSlider("c-R", state.R);
    setSlider("c-r", state.r);
    document.querySelectorAll(".class-row button").forEach(function (btn) {
      btn.classList.toggle("active", Number(btn.getAttribute("data-class")) === state.leverClass);
    });
  }

  function setSlider(id, val) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out) {
      if (id === "c-eta") out.textContent = Math.round(val) + "%";
      else if (id === "c-strands") out.textContent = String(Math.round(val));
      else if (id === "c-load") out.textContent = Math.round(val) + " N";
      else if (id === "c-angle") out.textContent = Math.round(val) + "°";
      else if (id === "c-mu") out.textContent = Number(val).toFixed(2);
      else out.textContent = Number(val).toFixed(2) + (id.indexOf("d") >= 0 || id === "c-R" || id === "c-r" ? " m" : "");
    }
  }

  function bind() {
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        setMachine(btn.getAttribute("data-machine"));
      });
    });
    document.querySelectorAll(".class-row button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        state.leverClass = Number(btn.getAttribute("data-class"));
        // Sensible default arms when switching class
        if (state.leverClass === 1) { state.dE = 2; state.dL = 1; }
        if (state.leverClass === 2) { state.dE = 2.5; state.dL = 1; }
        if (state.leverClass === 3) { state.dE = 0.8; state.dL = 2; }
        syncSliders();
        draw();
      });
    });

    function bindRange(id, key, scale) {
      var el = document.getElementById(id);
      if (!el) return;
      el.addEventListener("input", function () {
        var v = parseFloat(el.value);
        if (!isFinite(v)) return;
        state[key] = scale ? v * scale : v;
        setSlider(id, scale ? v : state[key]);
        draw();
      });
    }
    bindRange("c-load", "loadW");
    bindRange("c-eta", "eta", 0.01);
    bindRange("c-dL", "dL");
    bindRange("c-dE", "dE");
    bindRange("c-angle", "angle");
    bindRange("c-mu", "mu");
    bindRange("c-strands", "strands");
    bindRange("c-R", "R");
    bindRange("c-r", "r");

    window.addEventListener("resize", resize);
  }

  function init() {
    bind();
    document.body.classList.add("m-lever");
    resize();
    setMachine("lever");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

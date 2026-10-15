/**
 * Gear Trains UI – animated spur gears, ratio, torque.
 */
(function () {
  "use strict";

  var M = window.GearTrainsModel;
  var train = "simple"; // simple | idler | compound
  var state = {
    N1: 20, N2: 40, N3: 16, N4: 48,
    nIn: 60, // rpm
    tauIn: 5, // N·m
    eta: 0.95
  };

  var angles = [0, 0, 0, 0]; // radians
  var lastT = 0;
  var running = true;
  var canvas = document.getElementById("gear-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");

  function result() {
    if (train === "simple") {
      return M.simple(state.N1, state.N2, state.nIn, state.tauIn, state.eta);
    }
    if (train === "idler") {
      return M.idler(state.N1, state.N2, state.N3, state.nIn, state.tauIn, state.eta);
    }
    return M.compound(state.N1, state.N2, state.N3, state.N4, state.nIn, state.tauIn, state.eta);
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
  }

  // Pitch radius proportional to teeth (module = 1 visual unit)
  function pitchR(teeth, scale) {
    return (teeth / 2) * scale;
  }

  function drawGear(cx, cy, teeth, scale, angle, color) {
    var R = pitchR(teeth, scale);
    var tip = R + scale * 0.45;
    var root = R - scale * 0.55;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(angle);

    // Body
    ctx.beginPath();
    for (var i = 0; i < teeth; i++) {
      var a0 = (i / teeth) * Math.PI * 2;
      var a1 = ((i + 0.35) / teeth) * Math.PI * 2;
      var a2 = ((i + 0.5) / teeth) * Math.PI * 2;
      var a3 = ((i + 0.85) / teeth) * Math.PI * 2;
      if (i === 0) ctx.moveTo(Math.cos(a0) * root, Math.sin(a0) * root);
      ctx.lineTo(Math.cos(a0) * root, Math.sin(a0) * root);
      ctx.lineTo(Math.cos(a1) * tip, Math.sin(a1) * tip);
      ctx.lineTo(Math.cos(a2) * tip, Math.sin(a2) * tip);
      ctx.lineTo(Math.cos(a3) * root, Math.sin(a3) * root);
    }
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.fill();
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 1.5;
    ctx.stroke();

    // Hub
    ctx.beginPath();
    ctx.arc(0, 0, Math.max(6, scale * 2.5), 0, Math.PI * 2);
    ctx.fillStyle = "#333";
    ctx.fill();

    // Mark
    ctx.strokeStyle = "#fff";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(R * 0.7, 0);
    ctx.stroke();

    ctx.restore();

    // Teeth label
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(teeth + "T", cx, cy + R + 18);
  }

  function layout(res, w, h) {
    // Return centres and scale for gears
    var maxT = 0;
    res.gears.forEach(function (g) { maxT = Math.max(maxT, g.teeth); });
    var scale = Math.min(4.2, (h * 0.28) / (maxT / 2));
    var centres = [];

    if (res.type === "simple") {
      var r1 = pitchR(res.gears[0].teeth, scale);
      var r2 = pitchR(res.gears[1].teeth, scale);
      var gap = r1 + r2;
      var cx = w * 0.42;
      var cy = h * 0.48;
      centres = [
        { x: cx - gap * 0.5, y: cy },
        { x: cx + gap * 0.5, y: cy }
      ];
    } else if (res.type === "idler") {
      var ra = pitchR(res.gears[0].teeth, scale);
      var rb = pitchR(res.gears[1].teeth, scale);
      var rc = pitchR(res.gears[2].teeth, scale);
      var cy = h * 0.48;
      var x0 = w * 0.22;
      centres = [
        { x: x0, y: cy },
        { x: x0 + ra + rb, y: cy },
        { x: x0 + ra + 2 * rb + rc, y: cy }
      ];
    } else {
      // compound: G1-G2 mesh on left; G3-G4 on right; G2 and G3 share shaft (same centre)
      scale = Math.min(scale, 3.6);
      var r1 = pitchR(res.gears[0].teeth, scale);
      var r2 = pitchR(res.gears[1].teeth, scale);
      var r3 = pitchR(res.gears[2].teeth, scale);
      var r4 = pitchR(res.gears[3].teeth, scale);
      var cy = h * 0.48;
      var x1 = w * 0.28;
      var x2 = x1 + r1 + r2;
      var x4 = x2 + Math.max(r3, r2) + r4;
      centres = [
        { x: x1, y: cy },
        { x: x2, y: cy },
        { x: x2, y: cy }, // same shaft as g2 – drawn offset slightly in draw
        { x: x4, y: cy }
      ];
    }
    return { centres: centres, scale: scale };
  }

  function draw() {
    var w = canvas.clientWidth || 640;
    var h = 420;
    ctx.clearRect(0, 0, w, h);
    var res = result();
    var lay = layout(res, w, h);
    var speeds = M.gearSpeeds(res); // rpm
    var colors = ["#c62828", "#1565c0", "#2e7d32", "#6a1b9a"];

    // Shaft lines for compound
    if (res.type === "compound") {
      ctx.strokeStyle = "#999";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(lay.centres[1].x - 8, lay.centres[1].y);
      ctx.lineTo(lay.centres[1].x + 8, lay.centres[1].y);
      ctx.stroke();
    }

    res.gears.forEach(function (g, i) {
      var c = lay.centres[i];
      var sc = lay.scale;
      // For compound g3, draw slightly smaller offset if same centre – use actual teeth
      if (res.type === "compound" && i === 2) {
        // draw g3 concentric but we already share centre; visual: draw g2 larger, g3 as inner ring mark
        // Actually both mesh externally with partners – same axis means concentric gears of different size
        drawGear(c.x, c.y, g.teeth, sc, angles[i], colors[i]);
      } else {
        drawGear(c.x, c.y, g.teeth, sc, angles[i], colors[i]);
      }
      // Role label
      ctx.fillStyle = "#666";
      ctx.font = "600 10px DM Sans, Arial, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(g.role, c.x, c.y + pitchR(g.teeth, lay.scale) + 32);
    });

    // Input / output arrows
    if (lay.centres.length) {
      var cin = lay.centres[0];
      var cout = lay.centres[lay.centres.length - 1];
      ctx.fillStyle = "#b22222";
      ctx.font = "700 12px DM Sans, Arial, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("IN " + fmt(res.nIn, 0) + " rpm", cin.x, 36);
      ctx.fillText("OUT " + fmt(res.nOut, 1) + " rpm", cout.x, 36);
    }

    // Title
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 13px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    var titles = { simple: "Simple gear pair", idler: "Idler train", compound: "Compound train" };
    ctx.fillText(titles[train] || "Gear train", 20, 24);

    updateReadouts(res);
  }

  function updateReadouts(res) {
    setText("s-ratio", fmt(res.ratioMag, 3) + (res.ratio < 0 ? " (rev)" : " (same)"));
    setText("s-nin", fmt(res.nIn, 1) + " rpm");
    setText("s-nout", fmt(res.nOut, 2) + " rpm");
    setText("s-tin", fmt(res.tauIn, 2) + " N·m");
    setText("s-tout", fmt(res.tauOut, 2) + " N·m");
    setText("s-eta", fmt(res.eta * 100, 0) + "%");
    setText("s-dir", res.direction === "opposite" ? "Opposite" : "Same sense");
  }

  function tick(t) {
    if (!lastT) lastT = t;
    var dt = Math.min(0.05, (t - lastT) / 1000);
    lastT = t;
    if (running) {
      var res = result();
      var speeds = M.gearSpeeds(res); // rpm
      for (var i = 0; i < speeds.length; i++) {
        // rpm → rad/s
        var omega = (speeds[i] * Math.PI * 2) / 60;
        angles[i] += omega * dt;
      }
    }
    draw();
    requestAnimationFrame(tick);
  }

  function setTrain(name) {
    train = name;
    document.body.classList.remove("t-simple", "t-idler", "t-compound");
    document.body.classList.add("t-" + name);
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-train") === name);
    });
    var hints = {
      simple: "Two meshing gears. Ratio = N₁/N₂. Output turns the opposite way.",
      idler: "The middle gear is an idler: it changes direction twice so input and output turn the same way. Ratio uses first and last teeth only.",
      compound: "Two gears share a shaft. Overall ratio multiplies the two mesh ratios — useful for large reductions in a small space."
    };
    setHint(hints[name] || "");
    angles = [0, 0, 0, 0];
    syncSliders();
    draw();
  }

  function syncSliders() {
    ["c-N1", "c-iN1", "c-cN1"].forEach(function (id) { setSlider(id, state.N1); });
    ["c-N2", "c-iN2", "c-cN2"].forEach(function (id) { setSlider(id, state.N2); });
    ["c-N3", "c-iN3", "c-cN3"].forEach(function (id) { setSlider(id, state.N3); });
    setSlider("c-cN4", state.N4);
    setSlider("c-nin", state.nIn);
    setSlider("c-tin", state.tauIn);
    setSlider("c-eta", state.eta * 100);
  }

  function setSlider(id, val) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (!out) return;
    if (id === "c-eta") out.textContent = Math.round(val) + "%";
    else if (id === "c-nin") out.textContent = Math.round(val) + " rpm";
    else if (id === "c-tin") out.textContent = Number(val).toFixed(1) + " N·m";
    else out.textContent = String(Math.round(val));
  }

  function bind() {
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        setTrain(btn.getAttribute("data-train"));
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
    bindRange("c-N1", "N1");
    bindRange("c-N2", "N2");
    bindRange("c-iN1", "N1");
    bindRange("c-iN2", "N2");
    bindRange("c-iN3", "N3");
    bindRange("c-cN1", "N1");
    bindRange("c-cN2", "N2");
    bindRange("c-cN3", "N3");
    bindRange("c-cN4", "N4");
    bindRange("c-nin", "nIn");
    bindRange("c-tin", "tauIn");
    bindRange("c-eta", "eta", 0.01);

    var pauseBtn = document.getElementById("btn-pause");
    if (pauseBtn) {
      pauseBtn.addEventListener("click", function () {
        running = !running;
        pauseBtn.textContent = running ? "Pause" : "Play";
      });
    }

    window.addEventListener("resize", function () {
      resize();
      draw();
    });
  }

  function init() {
    bind();
    document.body.classList.add("t-simple");
    resize();
    setTrain("simple");
    requestAnimationFrame(tick);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

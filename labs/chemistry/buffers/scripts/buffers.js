/**
 * Buffers UI – pH scale, weak acid / buffer / strong.
 */
(function () {
  "use strict";

  var model = new BuffersModel();
  var canvas = document.getElementById("ph-canvas");
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
    if (Math.abs(n) > 0 && Math.abs(n) < 1e-3) return n.toExponential(2);
    return Number(n).toFixed(d == null ? 2 : d);
  }

  function resize() {
    var rect = canvas.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(320, Math.floor(rect.width * dpr));
    canvas.height = Math.floor(360 * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    draw();
  }

  function phColor(pH) {
    // rough visual scale acidic red → neutral green → basic blue
    if (pH < 7) {
      var t = Math.max(0, Math.min(1, pH / 7));
      return "rgb(" + Math.round(200 - 80 * t) + "," + Math.round(40 + 100 * t) + "," + Math.round(40 + 40 * t) + ")";
    }
    var u = Math.max(0, Math.min(1, (pH - 7) / 7));
    return "rgb(" + Math.round(40 + 40 * (1 - u)) + "," + Math.round(140 - 40 * u) + "," + Math.round(80 + 140 * u) + ")";
  }

  function draw() {
    var w = canvas.clientWidth || 640;
    var h = 360;
    ctx.clearRect(0, 0, w, h);
    var res = model.solve();

    // pH meter bezel
    var cx = w * 0.35;
    var cy = h * 0.42;
    var R = Math.min(100, w * 0.18);

    ctx.beginPath();
    ctx.arc(cx, cy, R + 8, 0, Math.PI * 2);
    ctx.fillStyle = "#eee";
    ctx.fill();
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 3;
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(cx, cy, R, 0, Math.PI * 2);
    ctx.fillStyle = phColor(res.pH);
    ctx.fill();

    ctx.fillStyle = "#fff";
    ctx.font = "700 36px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(fmt(res.pH, 2), cx, cy - 8);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillText("pH", cx, cy + 24);

    // Scale bar 0–14
    var bx = w * 0.62;
    var by = 40;
    var bh = h - 80;
    var bw = 28;
    for (var i = 0; i < 14; i++) {
      var y0 = by + (i / 14) * bh;
      var y1 = by + ((i + 1) / 14) * bh;
      var midPH = 14 - (i + 0.5);
      ctx.fillStyle = phColor(midPH);
      ctx.fillRect(bx, y0, bw, y1 - y0 + 1);
    }
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 1.5;
    ctx.strokeRect(bx, by, bw, bh);

    // Marker
    var my = by + ((14 - res.pH) / 14) * bh;
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(bx - 8, my);
    ctx.lineTo(bx + bw + 8, my);
    ctx.stroke();

    ctx.fillStyle = "#666";
    ctx.font = "600 10px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("14", bx + bw + 12, by + 4);
    ctx.fillText("7", bx + bw + 12, by + bh / 2 + 4);
    ctx.fillText("0", bx + bw + 12, by + bh);

    // Side labels
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 14px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(res.acidName, 24, 28);
    ctx.font = "600 12px DM Sans, Arial, sans-serif";
    ctx.fillStyle = "#666";
    ctx.fillText(res.formula + "   pKa = " + fmt(res.pKa, 2), 24, 48);

    if (model.mode === "buffer" && res.extra.broken) {
      setStatus("Buffer capacity exceeded — excess strong acid or base dominates.", "err");
    } else if (model.mode === "buffer") {
      setStatus("Buffer within capacity. pH ≈ pKa + log([A⁻]/[HA]).", "ok");
    } else if (model.mode === "weak") {
      setStatus("Weak acid: quadratic solution for [H⁺].", "ok");
    } else {
      setStatus("Strong " + model.strongType + ": full dissociation.", "ok");
    }

    updateReadouts(res);
  }

  function updateReadouts(res) {
    setText("s-pH", fmt(res.pH, 2));
    setText("s-H", res.H.toExponential(2) + " M");
    setText("s-pOH", fmt(res.pOH, 2));
    setText("s-pKa", fmt(res.pKa, 2));
    setText("s-Ka", res.Ka.toExponential(2));
    if (res.extra.HA != null) setText("s-HA", fmt(res.extra.HA, 4) + " M");
    if (res.extra.A != null) setText("s-A", fmt(res.extra.A, 4) + " M");
    if (res.extra.alpha != null) setText("s-alpha", fmt(res.extra.alpha * 100, 1) + "%");
  }

  function setMode(name) {
    model.mode = name;
    document.body.classList.remove("m-weak", "m-buffer", "m-strong");
    document.body.classList.add("m-" + name);
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-mode") === name);
    });
    var hints = {
      weak: "A weak acid HA only partially dissociates. Lower Ka → higher pH for the same concentration.",
      buffer: "A buffer resists pH change. Adjust [HA] and [A⁻], then add strong acid or base to test capacity.",
      strong: "Strong acids and bases dissociate fully. Compare pH with the weak-acid mode at the same concentration."
    };
    setHint(hints[name] || "");
    // show/hide result rows
    document.querySelectorAll("[data-for]").forEach(function (el) {
      var modes = el.getAttribute("data-for").split(",");
      el.style.display = modes.indexOf(name) >= 0 ? "" : "none";
    });
    syncSliders();
    draw();
  }

  function syncSliders() {
    setSlider("c-CHA", model.CHA, function (v) { return fmt(v, 3) + " M"; });
    setSlider("c-CA", model.CA, function (v) { return fmt(v, 3) + " M"; });
    setSlider("c-Cstrong", model.Cstrong, function (v) { return fmt(v, 3) + " M"; });
    setSlider("c-addAcid", model.addAcid, function (v) { return fmt(v, 3) + " M"; });
    setSlider("c-addBase", model.addBase, function (v) { return fmt(v, 3) + " M"; });
    setSlider("c-Ka", -Math.log10(model.Ka), function (v) { return "pKa " + fmt(v, 1); });
    document.querySelectorAll(".acid-row button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-acid") === model.acid);
    });
    document.querySelectorAll("[data-strong]").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-strong") === model.strongType);
    });
  }

  function setSlider(id, val, fmtFn) {
    var el = document.getElementById(id);
    if (!el) return;
    if (id === "c-Ka") el.value = -Math.log10(model.Ka);
    else el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out && fmtFn) out.textContent = fmtFn(id === "c-Ka" ? -Math.log10(model.Ka) : val);
  }

  function bind() {
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        setMode(btn.getAttribute("data-mode"));
      });
    });
    document.querySelectorAll(".acid-row button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.setAcid(btn.getAttribute("data-acid"));
        syncSliders();
        draw();
      });
    });
    document.querySelectorAll("[data-strong]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.strongType = btn.getAttribute("data-strong");
        syncSliders();
        draw();
      });
    });

    document.getElementById("c-CHA").addEventListener("input", function () {
      model.CHA = parseFloat(this.value);
      setSlider("c-CHA", this.value, function (v) { return fmt(v, 3) + " M"; });
      draw();
    });
    document.getElementById("c-CA").addEventListener("input", function () {
      model.CA = parseFloat(this.value);
      setSlider("c-CA", this.value, function (v) { return fmt(v, 3) + " M"; });
      draw();
    });
    document.getElementById("c-Cstrong").addEventListener("input", function () {
      model.Cstrong = parseFloat(this.value);
      setSlider("c-Cstrong", this.value, function (v) { return fmt(v, 3) + " M"; });
      draw();
    });
    document.getElementById("c-addAcid").addEventListener("input", function () {
      model.addAcid = parseFloat(this.value);
      setSlider("c-addAcid", this.value, function (v) { return fmt(v, 3) + " M"; });
      draw();
    });
    document.getElementById("c-addBase").addEventListener("input", function () {
      model.addBase = parseFloat(this.value);
      setSlider("c-addBase", this.value, function (v) { return fmt(v, 3) + " M"; });
      draw();
    });
    document.getElementById("c-Ka").addEventListener("input", function () {
      var pKa = parseFloat(this.value);
      model.Ka = Math.pow(10, -pKa);
      model.acid = "custom";
      syncSliders();
      draw();
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        if (p === "acetate") {
          model.mode = "buffer";
          model.setAcid("acetic");
          model.CHA = 0.1; model.CA = 0.1;
          model.addAcid = 0; model.addBase = 0;
          setHint("Equimolar acetic buffer — pH ≈ pKa ≈ 4.74.");
        } else if (p === "challenge") {
          model.mode = "buffer";
          model.setAcid("acetic");
          model.CHA = 0.1; model.CA = 0.1;
          model.addAcid = 0.05; model.addBase = 0;
          setHint("0.05 M strong acid added to the buffer — pH drops, but much less than without a buffer.");
        } else if (p === "break") {
          model.mode = "buffer";
          model.setAcid("acetic");
          model.CHA = 0.1; model.CA = 0.1;
          model.addAcid = 0.15; model.addBase = 0;
          setHint("Excess strong acid exceeds capacity — buffer is broken.");
        } else if (p === "weak") {
          model.mode = "weak";
          model.setAcid("acetic");
          model.CHA = 0.1;
          setHint("0.1 M acetic acid alone — compare pH with the buffer preset.");
        }
        document.body.classList.remove("m-weak", "m-buffer", "m-strong");
        document.body.classList.add("m-" + model.mode);
        document.querySelectorAll(".mode-tabs button").forEach(function (b) {
          b.classList.toggle("active", b.getAttribute("data-mode") === model.mode);
        });
        document.querySelectorAll("[data-for]").forEach(function (el) {
          var modes = el.getAttribute("data-for").split(",");
          el.style.display = modes.indexOf(model.mode) >= 0 ? "" : "none";
        });
        syncSliders();
        draw();
      });
    });

    window.addEventListener("resize", resize);
  }

  function init() {
    bind();
    document.body.classList.add("m-weak");
    resize();
    setMode("weak");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

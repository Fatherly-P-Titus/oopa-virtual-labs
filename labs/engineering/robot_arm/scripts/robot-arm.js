/**
 * Robot Arm UI – planar 2R FK/IK + workspace.
 */
(function () {
  "use strict";

  var model = new RobotArmModel();
  var target = null; // { x, y } in metres when IK mode
  var canvas = document.getElementById("arm-canvas");
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
    return Number(n).toFixed(d == null ? 2 : d);
  }

  function resize() {
    var rect = canvas.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(320, Math.floor(rect.width * dpr));
    canvas.height = Math.floor(440 * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    draw();
  }

  function worldToScreen(wx, wy, origin, scale) {
    return {
      x: origin.x + wx * scale,
      y: origin.y - wy * scale
    };
  }

  function screenToWorld(sx, sy, origin, scale) {
    return {
      x: (sx - origin.x) / scale,
      y: (origin.y - sy) / scale
    };
  }

  function draw() {
    var w = canvas.clientWidth || 640;
    var h = 440;
    ctx.clearRect(0, 0, w, h);

    var ws = model.workspace();
    var scale = Math.min(w, h) * 0.38 / Math.max(ws.rMax, 0.5);
    var origin = { x: w * 0.45, y: h * 0.55 };

    // Workspace rings
    ctx.strokeStyle = "rgba(178,34,34,0.15)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(origin.x, origin.y, ws.rMax * scale, 0, Math.PI * 2);
    ctx.stroke();
    if (ws.rMin > 0.01) {
      ctx.beginPath();
      ctx.arc(origin.x, origin.y, ws.rMin * scale, 0, Math.PI * 2);
      ctx.stroke();
    }
    // Fill workspace lightly
    ctx.fillStyle = "rgba(178,34,34,0.04)";
    ctx.beginPath();
    ctx.arc(origin.x, origin.y, ws.rMax * scale, 0, Math.PI * 2);
    if (ws.rMin > 0.01) {
      ctx.arc(origin.x, origin.y, ws.rMin * scale, 0, Math.PI * 2, true);
    }
    ctx.fill();

    // Axes
    ctx.strokeStyle = "#ddd";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(origin.x - ws.rMax * scale - 20, origin.y);
    ctx.lineTo(origin.x + ws.rMax * scale + 20, origin.y);
    ctx.moveTo(origin.x, origin.y - ws.rMax * scale - 20);
    ctx.lineTo(origin.x, origin.y + ws.rMax * scale + 20);
    ctx.stroke();

    var fk = model.forward();
    var base = worldToScreen(0, 0, origin, scale);
    var joint = worldToScreen(fk.joint.x, fk.joint.y, origin, scale);
    var end = worldToScreen(fk.end.x, fk.end.y, origin, scale);

    // Links
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 8;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(base.x, base.y);
    ctx.lineTo(joint.x, joint.y);
    ctx.stroke();
    ctx.strokeStyle = "#1565c0";
    ctx.beginPath();
    ctx.moveTo(joint.x, joint.y);
    ctx.lineTo(end.x, end.y);
    ctx.stroke();

    // Joints
    function dot(p, r, fill) {
      ctx.beginPath();
      ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
      ctx.fillStyle = fill;
      ctx.fill();
      ctx.strokeStyle = "#1b1b1b";
      ctx.lineWidth = 2;
      ctx.stroke();
    }
    dot(base, 10, "#333");
    dot(joint, 8, "#fff");
    dot(end, 7, "#b22222");

    // Target marker
    if (target) {
      var tp = worldToScreen(target.x, target.y, origin, scale);
      ctx.strokeStyle = "#2e7d32";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(tp.x - 8, tp.y);
      ctx.lineTo(tp.x + 8, tp.y);
      ctx.moveTo(tp.x, tp.y - 8);
      ctx.lineTo(tp.x, tp.y + 8);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(tp.x, tp.y, 10, 0, Math.PI * 2);
      ctx.stroke();
    }

    // Labels
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Base", base.x + 14, base.y - 10);
    ctx.fillText("Elbow", joint.x + 12, joint.y - 10);
    ctx.fillStyle = "#b22222";
    ctx.fillText("End", end.x + 12, end.y - 10);

    ctx.fillStyle = "#666";
    ctx.font = "600 10px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("workspace", origin.x, origin.y + ws.rMax * scale + 16);

    updateReadouts(fk);
  }

  function updateReadouts(fk) {
    setText("s-t1", fmt(model.theta1, 1) + "°");
    setText("s-t2", fmt(model.theta2, 1) + "°");
    setText("s-x", fmt(fk.end.x, 3) + " m");
    setText("s-y", fmt(fk.end.y, 3) + " m");
    var ws = model.workspace();
    setText("s-rmin", fmt(ws.rMin, 2) + " m");
    setText("s-rmax", fmt(ws.rMax, 2) + " m");
    var r = Math.sqrt(fk.end.x * fk.end.x + fk.end.y * fk.end.y);
    setText("s-r", fmt(r, 3) + " m");
  }

  function applyIK() {
    if (!target) return;
    var sol = model.inverse(target.x, target.y, model.elbowUp);
    if (sol.ok) {
      model.theta1 = sol.theta1;
      model.theta2 = sol.theta2;
      syncSliders();
      setStatus(sol.message + " θ₁=" + fmt(sol.theta1, 1) + "° θ₂=" + fmt(sol.theta2, 1) + "°", "ok");
    } else {
      setStatus(sol.message, "err");
    }
    draw();
  }

  function syncSliders() {
    setSlider("c-t1", model.theta1, function (v) { return fmt(v, 0) + "°"; });
    setSlider("c-t2", model.theta2, function (v) { return fmt(v, 0) + "°"; });
    setSlider("c-L1", model.L1, function (v) { return fmt(v, 2) + " m"; });
    setSlider("c-L2", model.L2, function (v) { return fmt(v, 2) + " m"; });
    document.querySelectorAll(".toggle-row button").forEach(function (btn) {
      var up = btn.getAttribute("data-elbow") === "up";
      btn.classList.toggle("active", up === model.elbowUp);
    });
  }

  function setSlider(id, val, fmtFn) {
    var el = document.getElementById(id);
    if (el) el.value = val;
    var out = document.getElementById("o-" + id.slice(2));
    if (out && fmtFn) out.textContent = fmtFn(val);
  }

  function canvasPos(evt) {
    var rect = canvas.getBoundingClientRect();
    var cx = evt.touches ? evt.touches[0].clientX : evt.clientX;
    var cy = evt.touches ? evt.touches[0].clientY : evt.clientY;
    return { x: cx - rect.left, y: cy - rect.top };
  }

  function onClick(evt) {
    evt.preventDefault();
    var p = canvasPos(evt);
    var w = canvas.clientWidth || 640;
    var h = 440;
    var ws = model.workspace();
    var scale = Math.min(w, h) * 0.38 / Math.max(ws.rMax, 0.5);
    var origin = { x: w * 0.45, y: h * 0.55 };
    var world = screenToWorld(p.x, p.y, origin, scale);
    target = { x: world.x, y: world.y };
    applyIK();
    setHint("Target set. IK " + (model.elbowUp ? "elbow-up" : "elbow-down") + " solution applied if reachable.");
  }

  function bind() {
    document.getElementById("c-t1").addEventListener("input", function () {
      model.theta1 = parseFloat(this.value);
      setSlider("c-t1", this.value, function (v) { return fmt(v, 0) + "°"; });
      target = null;
      setStatus("Forward kinematics.", "ok");
      draw();
    });
    document.getElementById("c-t2").addEventListener("input", function () {
      model.theta2 = parseFloat(this.value);
      setSlider("c-t2", this.value, function (v) { return fmt(v, 0) + "°"; });
      target = null;
      setStatus("Forward kinematics.", "ok");
      draw();
    });
    document.getElementById("c-L1").addEventListener("input", function () {
      model.L1 = parseFloat(this.value);
      setSlider("c-L1", this.value, function (v) { return fmt(v, 2) + " m"; });
      if (target) applyIK();
      else draw();
    });
    document.getElementById("c-L2").addEventListener("input", function () {
      model.L2 = parseFloat(this.value);
      setSlider("c-L2", this.value, function (v) { return fmt(v, 2) + " m"; });
      if (target) applyIK();
      else draw();
    });

    document.querySelectorAll(".toggle-row button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        model.elbowUp = btn.getAttribute("data-elbow") === "up";
        syncSliders();
        if (target) applyIK();
        else draw();
      });
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        target = null;
        if (p === "reach") { model.theta1 = 20; model.theta2 = 30; }
        else if (p === "fold") { model.theta1 = 90; model.theta2 = 150; }
        else if (p === "straight") { model.theta1 = 0; model.theta2 = 0; }
        else if (p === "up") { model.theta1 = 90; model.theta2 = -40; }
        syncSliders();
        setStatus("Preset pose (FK).", "ok");
        draw();
      });
    });

    canvas.addEventListener("mousedown", onClick);
    canvas.addEventListener("touchstart", onClick, { passive: false });
    window.addEventListener("resize", resize);
  }

  function init() {
    bind();
    resize();
    syncSliders();
    setStatus("Forward kinematics. Click the canvas to set an IK target.", "ok");
    setHint("Drag joint-angle sliders for forward kinematics. Click the workspace to solve inverse kinematics.");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

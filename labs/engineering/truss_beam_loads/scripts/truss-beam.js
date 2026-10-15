/**
 * Truss and Beam Loads – canvas UI.
 * Depends on TrussModel.
 */
(function () {
  "use strict";

  var GRID = 24;
  var JOINT_R = 7;
  var SCALE = 48; // px per model unit when drawing truss from model coords

  var model = new TrussModel();
  var mode = "truss"; // truss | beam
  var tool = "select";
  var selected = null; // { kind, id }
  var memberFrom = null; // joint id when placing member
  var trussResult = null;

  // Beam state (independent of truss model)
  var beam = {
    span: 10,
    cantilever: false,
    loads: [{ id: "bL0", x: 5, p: 10 }],
    result: null
  };

  var canvas = document.getElementById("struct-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");
  var statusEl = document.getElementById("status-line");

  // World → screen for truss (origin bottom-left-ish)
  var originX = 80;
  var originY = 380;

  function toScreen(mx, my) {
    return { x: originX + mx * SCALE, y: originY - my * SCALE };
  }

  function toModel(sx, sy) {
    return {
      x: (sx - originX) / SCALE,
      y: (originY - sy) / SCALE
    };
  }

  function snapModel(v) {
    var g = 0.5; // model grid
    return Math.round(v / g) * g;
  }

  function setHint(t) { if (hintEl) hintEl.textContent = t; }
  function setStatus(t, cls) {
    if (!statusEl) return;
    statusEl.textContent = t || "";
    statusEl.className = "status-line" + (cls ? " " + cls : "");
  }

  function resize() {
    var rect = canvas.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(320, Math.floor(rect.width * dpr));
    canvas.height = Math.floor(440 * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    originY = 380;
    draw();
  }

  // ---------- Draw ----------
  function draw() {
    var w = canvas.clientWidth || 640;
    ctx.clearRect(0, 0, w, 440);
    if (mode === "truss") drawTruss();
    else drawBeam();
  }

  function drawTruss() {
    // Members
    model.members.forEach(function (m) {
      var ja = joint(m.jointA), jb = joint(m.jointB);
      if (!ja || !jb) return;
      var a = toScreen(ja.x, ja.y), b = toScreen(jb.x, jb.y);
      var force = trussResult && trussResult.memberForces ? trussResult.memberForces[m.id] : null;
      var col = "#555";
      if (force != null) {
        if (force > 0.05) col = "#1565c0";
        else if (force < -0.05) col = "#c62828";
        else col = "#999";
      }
      ctx.strokeStyle = col;
      ctx.lineWidth = selected && selected.kind === "member" && selected.id === m.id ? 4 : 3;
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
      ctx.stroke();

      if (force != null && Math.abs(force) > 0.05) {
        var mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
        ctx.fillStyle = col;
        ctx.font = "600 11px DM Sans, Arial, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(fmt(force), mx, my - 8);
      }
    });

    // Supports
    model.supports.forEach(function (s) {
      var j = joint(s.jointId);
      if (!j) return;
      var p = toScreen(j.x, j.y);
      ctx.fillStyle = "#1b1b1b";
      ctx.strokeStyle = "#1b1b1b";
      ctx.lineWidth = 2;
      if (s.type === "pin") {
        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
        ctx.lineTo(p.x - 12, p.y + 18);
        ctx.lineTo(p.x + 12, p.y + 18);
        ctx.closePath();
        ctx.stroke();
        // hatch
        ctx.beginPath();
        for (var i = -12; i <= 12; i += 4) {
          ctx.moveTo(p.x + i, p.y + 18);
          ctx.lineTo(p.x + i - 4, p.y + 24);
        }
        ctx.stroke();
      } else {
        // roller: triangle + circle
        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
        ctx.lineTo(p.x - 10, p.y + 14);
        ctx.lineTo(p.x + 10, p.y + 14);
        ctx.closePath();
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(p.x, p.y + 18, 4, 0, Math.PI * 2);
        ctx.stroke();
      }
      // reaction labels
      if (trussResult && trussResult.reactions) {
        var rx = 0, ry = 0;
        trussResult.reactions.forEach(function (r) {
          if (r.supportId === s.id) { rx = r.rx; ry = r.ry; }
        });
        ctx.fillStyle = "#2e7d32";
        ctx.font = "600 10px DM Sans, Arial, sans-serif";
        ctx.textAlign = "center";
        var label = "";
        if (Math.abs(rx) > 0.05) label += "Hx " + fmt(rx) + " ";
        if (Math.abs(ry) > 0.05) label += "Hy " + fmt(ry);
        if (label) ctx.fillText(label.trim(), p.x, p.y + 36);
      }
    });

    // Loads
    model.loads.forEach(function (L) {
      var j = joint(L.jointId);
      if (!j) return;
      var p = toScreen(j.x, j.y);
      drawArrow(p.x, p.y, L.fx, L.fy);
      ctx.fillStyle = "#b22222";
      ctx.font = "600 11px DM Sans, Arial, sans-serif";
      ctx.textAlign = "left";
      var t = [];
      if (Math.abs(L.fx) > 0.01) t.push("Fx " + fmt(L.fx));
      if (Math.abs(L.fy) > 0.01) t.push("Fy " + fmt(L.fy));
      ctx.fillText(t.join(", "), p.x + 14, p.y - 14);
    });

    // Joints
    model.joints.forEach(function (j) {
      var p = toScreen(j.x, j.y);
      ctx.beginPath();
      ctx.arc(p.x, p.y, JOINT_R, 0, Math.PI * 2);
      ctx.fillStyle = selected && selected.kind === "joint" && selected.id === j.id ? "#b22222" : "#1b1b1b";
      ctx.fill();
      ctx.fillStyle = "#fff";
      ctx.beginPath();
      ctx.arc(p.x, p.y, 3, 0, Math.PI * 2);
      ctx.fill();
    });

    // Pending member
    if (memberFrom) {
      var jf = joint(memberFrom);
      if (jf) {
        var pf = toScreen(jf.x, jf.y);
        ctx.strokeStyle = "rgba(178,34,34,.5)";
        ctx.setLineDash([6, 4]);
        ctx.beginPath();
        ctx.arc(pf.x, pf.y, JOINT_R + 4, 0, Math.PI * 2);
        ctx.stroke();
        ctx.setLineDash([]);
      }
    }
  }

  function drawArrow(x, y, fx, fy) {
    // Screen: +fy model up → screen up is -y, so arrow direction:
    var len = Math.sqrt(fx * fx + fy * fy);
    if (len < 0.01) return;
    var scale = 28 / Math.max(len, 1);
    var sx = fx * scale;
    var sy = -fy * scale; // invert y for screen
    ctx.strokeStyle = "#b22222";
    ctx.fillStyle = "#b22222";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + sx, y + sy);
    ctx.stroke();
    // head
    var ang = Math.atan2(sy, sx);
    ctx.beginPath();
    ctx.moveTo(x + sx, y + sy);
    ctx.lineTo(x + sx - 8 * Math.cos(ang - 0.4), y + sy - 8 * Math.sin(ang - 0.4));
    ctx.lineTo(x + sx - 8 * Math.cos(ang + 0.4), y + sy - 8 * Math.sin(ang + 0.4));
    ctx.closePath();
    ctx.fill();
  }

  function drawBeam() {
    var span = beam.span;
    var marginL = 60, marginR = 40, topY = 120;
    var beamW = (canvas.clientWidth || 640) - marginL - marginR;
    var px = function (x) { return marginL + (x / span) * beamW; };

    // Beam line
    ctx.strokeStyle = "#1b1b1b";
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.moveTo(px(0), topY);
    ctx.lineTo(px(span), topY);
    ctx.stroke();

    // Supports
    ctx.lineWidth = 2;
    ctx.fillStyle = "#1b1b1b";
    // left
    ctx.beginPath();
    ctx.moveTo(px(0), topY);
    ctx.lineTo(px(0) - 14, topY + 22);
    ctx.lineTo(px(0) + 14, topY + 22);
    ctx.closePath();
    ctx.stroke();
    if (!beam.cantilever) {
      ctx.beginPath();
      ctx.moveTo(px(span), topY);
      ctx.lineTo(px(span) - 12, topY + 18);
      ctx.lineTo(px(span) + 12, topY + 18);
      ctx.closePath();
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(px(span), topY + 22, 4, 0, Math.PI * 2);
      ctx.stroke();
    } else {
      // fixed wall at left
      ctx.beginPath();
      for (var i = 0; i < 6; i++) {
        ctx.moveTo(px(0) - 4, topY - 20 + i * 10);
        ctx.lineTo(px(0) - 14, topY - 12 + i * 10);
      }
      ctx.stroke();
      ctx.strokeRect(px(0) - 4, topY - 24, 4, 48);
    }

    // Loads
    beam.loads.forEach(function (L) {
      var x = px(L.x);
      ctx.strokeStyle = "#b22222";
      ctx.fillStyle = "#b22222";
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.moveTo(x, topY - 50);
      ctx.lineTo(x, topY - 4);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(x, topY - 4);
      ctx.lineTo(x - 5, topY - 14);
      ctx.lineTo(x + 5, topY - 14);
      ctx.closePath();
      ctx.fill();
      ctx.font = "600 11px DM Sans, Arial, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(fmt(L.p) + " N", x, topY - 56);
    });

    // Reactions
    if (beam.result) {
      ctx.fillStyle = "#2e7d32";
      ctx.font = "600 11px DM Sans, Arial, sans-serif";
      ctx.textAlign = "center";
      if (beam.result.Ra) {
        ctx.fillText("Ra " + fmt(beam.result.Ra), px(0), topY + 48);
      }
      if (!beam.cantilever && beam.result.Rb) {
        ctx.fillText("Rb " + fmt(beam.result.Rb), px(span), topY + 48);
      }
      if (beam.cantilever && beam.result.Ma) {
        ctx.fillText("Ma " + fmt(beam.result.Ma), px(0) + 40, topY + 48);
      }
    }

    // Diagrams
    if (beam.result && beam.result.samples) {
      drawDiagram(beam.result.samples, "V", topY + 90, 50, px, "#1565c0", "Shear V");
      drawDiagram(beam.result.samples, "M", topY + 220, 50, px, "#6a1b9a", "Moment M");
    }
  }

  function drawDiagram(samples, key, baseY, amp, px, color, title) {
    var maxAbs = 0;
    samples.forEach(function (s) { maxAbs = Math.max(maxAbs, Math.abs(s[key])); });
    if (maxAbs < 1e-9) maxAbs = 1;
    ctx.strokeStyle = "#ccc";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(px(0), baseY);
    ctx.lineTo(px(beam.span), baseY);
    ctx.stroke();
    ctx.fillStyle = color;
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(title, px(0), baseY - amp - 6);

    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    samples.forEach(function (s, i) {
      var x = px(s.x);
      var y = baseY - (s[key] / maxAbs) * amp;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();
  }

  function joint(id) {
    for (var i = 0; i < model.joints.length; i++) {
      if (model.joints[i].id === id) return model.joints[i];
    }
    return null;
  }

  function fmt(n) {
    if (n == null || !isFinite(n)) return "–";
    var a = Math.abs(n);
    if (a >= 100) return n.toFixed(1);
    if (a >= 1) return n.toFixed(2);
    return n.toFixed(3);
  }

  // ---------- Analyse ----------
  function analyse() {
    if (mode === "truss") {
      trussResult = model.solveTruss();
      if (trussResult.ok) setStatus(trussResult.message, "ok");
      else setStatus(trussResult.message, "err");
      renderTrussReadouts();
    } else {
      beam.result = TrussModel.solveBeam(beam.span, beam.loads, beam.cantilever);
      setStatus(beam.result.message, "ok");
      renderBeamReadouts();
    }
    draw();
  }

  function renderTrussReadouts() {
    setText("s-joints", String(model.joints.length));
    setText("s-members", String(model.members.length));
    setText("s-supports", String(model.supports.length));
    var body = document.getElementById("force-body");
    if (!body) return;
    body.innerHTML = "";
    if (!trussResult || !trussResult.ok) return;
    model.members.forEach(function (m, i) {
      var f = trussResult.memberForces[m.id] || 0;
      var kind = f > 0.05 ? "T" : f < -0.05 ? "C" : "–";
      var cls = f > 0.05 ? "t" : f < -0.05 ? "c" : "";
      var tr = document.createElement("tr");
      tr.innerHTML = "<td>M" + (i + 1) + "</td><td class='num " + cls + "'>" + fmt(f) + "</td><td class='" + cls + "'>" + kind + "</td>";
      body.appendChild(tr);
    });
  }

  function renderBeamReadouts() {
    setText("s-span", fmt(beam.span));
    setText("s-loads", String(beam.loads.length));
    if (beam.result) {
      setText("s-ra", fmt(beam.result.Ra));
      setText("s-rb", beam.cantilever ? "–" : fmt(beam.result.Rb));
    }
  }

  function setText(id, t) {
    var el = document.getElementById(id);
    if (el) el.textContent = t;
  }

  // ---------- Hit test ----------
  function hitJoint(sx, sy) {
    for (var i = model.joints.length - 1; i >= 0; i--) {
      var j = model.joints[i];
      var p = toScreen(j.x, j.y);
      var dx = sx - p.x, dy = sy - p.y;
      if (dx * dx + dy * dy <= (JOINT_R + 6) * (JOINT_R + 6)) return j;
    }
    return null;
  }

  function hitMember(sx, sy) {
    for (var i = 0; i < model.members.length; i++) {
      var m = model.members[i];
      var ja = joint(m.jointA), jb = joint(m.jointB);
      if (!ja || !jb) continue;
      var a = toScreen(ja.x, ja.y), b = toScreen(jb.x, jb.y);
      if (distToSeg(sx, sy, a.x, a.y, b.x, b.y) < 8) return m;
    }
    return null;
  }

  function distToSeg(px, py, x1, y1, x2, y2) {
    var dx = x2 - x1, dy = y2 - y1;
    var l2 = dx * dx + dy * dy;
    if (l2 < 1e-6) return Math.hypot(px - x1, py - y1);
    var t = Math.max(0, Math.min(1, ((px - x1) * dx + (py - y1) * dy) / l2));
    return Math.hypot(px - (x1 + t * dx), py - (y1 + t * dy));
  }

  // ---------- Pointer ----------
  function canvasPos(evt) {
    var rect = canvas.getBoundingClientRect();
    var cx = evt.touches ? evt.touches[0].clientX : evt.clientX;
    var cy = evt.touches ? evt.touches[0].clientY : evt.clientY;
    return { x: cx - rect.left, y: cy - rect.top };
  }

  function onDown(evt) {
    evt.preventDefault();
    var p = canvasPos(evt);

    if (mode === "beam") {
      onBeamDown(p);
      return;
    }

    if (tool === "delete") {
      var hj = hitJoint(p.x, p.y);
      if (hj) { model.removeJoint(hj.id); analyse(); return; }
      var hm = hitMember(p.x, p.y);
      if (hm) { model.removeMember(hm.id); analyse(); return; }
      // loads / supports near joint
      return;
    }

    if (tool === "joint") {
      var m = toModel(p.x, p.y);
      model.addJoint(snapModel(m.x), snapModel(m.y));
      analyse();
      return;
    }

    if (tool === "member") {
      var j = hitJoint(p.x, p.y);
      if (!j) return;
      if (!memberFrom) {
        memberFrom = j.id;
        setHint("Click the second joint to place the member.");
        draw();
      } else {
        if (memberFrom !== j.id) {
          model.addMember(memberFrom, j.id);
          analyse();
        }
        memberFrom = null;
        setHint("Member tool: click two joints to connect them.");
      }
      return;
    }

    if (tool === "pin" || tool === "roller") {
      var js = hitJoint(p.x, p.y);
      if (js) {
        model.addSupport(js.id, tool === "roller" ? "roller" : "pin");
        analyse();
      }
      return;
    }

    if (tool === "load") {
      var jl = hitJoint(p.x, p.y);
      if (jl) {
        var fy = -10;
        var inp = document.getElementById("load-fy");
        if (inp && isFinite(parseFloat(inp.value))) fy = -Math.abs(parseFloat(inp.value));
        model.addLoad(jl.id, 0, fy);
        analyse();
      }
      return;
    }

    // select
    var hj2 = hitJoint(p.x, p.y);
    if (hj2) {
      selected = { kind: "joint", id: hj2.id };
      draw();
      return;
    }
    var hm2 = hitMember(p.x, p.y);
    if (hm2) {
      selected = { kind: "member", id: hm2.id };
      draw();
      return;
    }
    selected = null;
    draw();
  }

  function onBeamDown(p) {
    if (tool === "load") {
      var marginL = 60, marginR = 40;
      var beamW = (canvas.clientWidth || 640) - marginL - marginR;
      var x = ((p.x - marginL) / beamW) * beam.span;
      x = Math.max(0.1, Math.min(beam.span - 0.1, x));
      x = Math.round(x * 2) / 2;
      var pmag = 10;
      var inp = document.getElementById("load-fy");
      if (inp && isFinite(parseFloat(inp.value))) pmag = Math.abs(parseFloat(inp.value));
      beam.loads.push({ id: "bL" + Math.random().toString(36).slice(2, 6), x: x, p: pmag });
      analyse();
    } else if (tool === "delete") {
      // remove nearest load
      var marginL = 60, marginR = 40;
      var beamW = (canvas.clientWidth || 640) - marginL - marginR;
      var best = null, bestD = 30;
      beam.loads.forEach(function (L, i) {
        var sx = marginL + (L.x / beam.span) * beamW;
        var d = Math.abs(p.x - sx);
        if (d < bestD) { bestD = d; best = i; }
      });
      if (best != null) {
        beam.loads.splice(best, 1);
        analyse();
      }
    }
  }

  // ---------- Tools / mode ----------
  function setTool(name) {
    tool = name;
    memberFrom = null;
    document.querySelectorAll(".stage-toolbar .tool").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-tool") === name);
    });
    var hints = {
      select: "Select joints or members.",
      joint: "Click the canvas to place a joint (snap grid).",
      member: "Click two joints to add a member between them.",
      pin: "Click a joint to add a pin support (Hx and Hy).",
      roller: "Click a joint to add a roller support (vertical only).",
      load: "Click a joint to add a downward point load.",
      delete: "Click a joint or member to remove it."
    };
    setHint(hints[name] || "");
  }

  function setMode(m) {
    mode = m;
    document.body.classList.remove("mode-truss", "mode-beam");
    document.body.classList.add(m === "beam" ? "mode-beam" : "mode-truss");
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-mode") === m);
    });
    setTool("select");
    analyse();
  }

  function loadPreset(name) {
    if (name === "beam-simple") {
      setMode("beam");
      beam.cantilever = false;
      beam.span = 10;
      beam.loads = [{ id: "bL0", x: 5, p: 10 }];
      var chk = document.getElementById("beam-cantilever");
      if (chk) chk.checked = false;
      analyse();
      setHint("Simply supported beam with a central point load.");
      return;
    }
    if (name === "beam-cantilever") {
      setMode("beam");
      beam.cantilever = true;
      beam.span = 8;
      beam.loads = [{ id: "bL0", x: 8, p: 5 }];
      var chk2 = document.getElementById("beam-cantilever");
      if (chk2) chk2.checked = true;
      analyse();
      setHint("Cantilever with end load – fixed end provides moment and shear.");
      return;
    }
    setMode("truss");
    model.loadPreset(name);
    // Fit view roughly
    var maxX = 0, maxY = 0;
    model.joints.forEach(function (j) {
      maxX = Math.max(maxX, j.x);
      maxY = Math.max(maxY, j.y);
    });
    var w = canvas.clientWidth || 640;
    SCALE = Math.min(56, Math.max(28, (w - 120) / Math.max(maxX, 1)));
    originX = 70;
    originY = 360;
    analyse();
    setHint("Preset loaded. Blue members are in tension, red in compression.");
  }

  function clearAll() {
    if (mode === "truss") {
      model.clear();
      trussResult = null;
    } else {
      beam.loads = [];
      beam.result = null;
    }
    selected = null;
    memberFrom = null;
    analyse();
    setHint("Cleared. Place joints and members, or load a preset.");
  }

  function bind() {
    document.querySelectorAll(".mode-tabs button").forEach(function (btn) {
      btn.addEventListener("click", function () { setMode(btn.getAttribute("data-mode")); });
    });
    document.querySelectorAll(".stage-toolbar .tool").forEach(function (btn) {
      btn.addEventListener("click", function () { setTool(btn.getAttribute("data-tool")); });
    });
    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () { loadPreset(btn.getAttribute("data-preset")); });
    });
    var bc = document.getElementById("btn-clear");
    if (bc) bc.addEventListener("click", clearAll);
    var ba = document.getElementById("btn-analyse");
    if (ba) ba.addEventListener("click", analyse);

    var cant = document.getElementById("beam-cantilever");
    if (cant) {
      cant.addEventListener("change", function () {
        beam.cantilever = cant.checked;
        analyse();
      });
    }
    var spanInp = document.getElementById("beam-span");
    if (spanInp) {
      spanInp.addEventListener("change", function () {
        var v = parseFloat(spanInp.value);
        if (isFinite(v) && v > 1) { beam.span = v; analyse(); }
      });
    }

    canvas.addEventListener("mousedown", onDown);
    canvas.addEventListener("touchstart", onDown, { passive: false });
    window.addEventListener("resize", resize);
  }

  function init() {
    bind();
    document.body.classList.add("mode-truss");
    resize();
    loadPreset("triangle");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

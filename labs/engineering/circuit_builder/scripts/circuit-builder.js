/**
 * Circuit Builder UI – canvas placement, wiring, readouts.
 * Depends on CircuitModel (circuit-model.js).
 */
(function () {
  "use strict";

  var GRID = 24;
  var TERM_R = 6;
  var COMP_W = 72;
  var COMP_H = 28;

  var model = new CircuitModel();
  var view = []; // { id, type, x, y, value, closed, nodeA, nodeB }
  var tool = "select"; // select | battery | resistor | switch | wire | ammeter | voltmeter | delete
  var selectedId = null;
  var wireFrom = null; // { viewId, which: 'A'|'B' } pending wire start
  var lastResult = null;
  var reducedMotion = false;

  try {
    reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  } catch (e) { /* ignore */ }

  // ---------- DOM ----------
  var canvas = document.getElementById("circuit-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");
  var statusEl = document.getElementById("status-line");
  var propsEl = document.getElementById("props-box");
  var statsEl = document.getElementById("stats");
  var branchBody = document.getElementById("branch-body");
  var valInput = document.getElementById("prop-value");
  var valLabel = document.getElementById("prop-value-label");

  function resizeCanvas() {
    var rect = canvas.getBoundingClientRect();
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.max(320, Math.floor(rect.width * dpr));
    canvas.height = Math.max(360, Math.floor(480 * dpr));
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    draw();
  }

  // ---------- Helpers ----------
  function snap(v) {
    return Math.round(v / GRID) * GRID;
  }

  function findView(id) {
    for (var i = 0; i < view.length; i++) if (view[i].id === id) return view[i];
    return null;
  }

  function terminals(v) {
    // Horizontal component: A left, B right
    return {
      A: { x: v.x - COMP_W / 2, y: v.y },
      B: { x: v.x + COMP_W / 2, y: v.y }
    };
  }

  function hitTest(mx, my) {
    // Returns { kind:'comp', id } or { kind:'term', id, which } or null
    for (var i = view.length - 1; i >= 0; i--) {
      var v = view[i];
      var t = terminals(v);
      if (dist(mx, my, t.A.x, t.A.y) <= TERM_R + 4) return { kind: "term", id: v.id, which: "A" };
      if (dist(mx, my, t.B.x, t.B.y) <= TERM_R + 4) return { kind: "term", id: v.id, which: "B" };
    }
    for (var j = view.length - 1; j >= 0; j--) {
      var c = view[j];
      if (Math.abs(mx - c.x) <= COMP_W / 2 + 4 && Math.abs(my - c.y) <= COMP_H / 2 + 8) {
        return { kind: "comp", id: c.id };
      }
    }
    return null;
  }

  function dist(x1, y1, x2, y2) {
    var dx = x1 - x2, dy = y1 - y2;
    return Math.sqrt(dx * dx + dy * dy);
  }

  function setHint(text) {
    if (hintEl) hintEl.textContent = text;
  }

  function setStatus(text, cls) {
    if (!statusEl) return;
    statusEl.textContent = text || "";
    statusEl.className = "status-line" + (cls ? " " + cls : "");
  }

  // ---------- Sync model from view ----------
  function rebuildModel() {
    model.clear();
    // Union-find for nodes: each terminal starts separate; wires merge.
    // We assign each view component a pair of node ids, then merge via wire list.
    var parent = {};
    function find(a) {
      if (parent[a] == null) parent[a] = a;
      if (parent[a] !== a) parent[a] = find(parent[a]);
      return parent[a];
    }
    function union(a, b) {
      var ra = find(a), rb = find(b);
      if (ra !== rb) parent[rb] = ra;
    }

    // Assign provisional terminal node ids
    var termNode = {}; // key viewId+which -> provisional id
    var next = 0;
    view.forEach(function (v) {
      if (v.type === "wire") return; // wires only merge
      termNode[v.id + "A"] = next++;
      termNode[v.id + "B"] = next++;
    });

    // Wires merge terminals
    view.forEach(function (v) {
      if (v.type !== "wire") return;
      // wire stores fromId, fromWhich, toId, toWhich
      if (v.fromId && v.toId) {
        var a = termNode[v.fromId + v.fromWhich];
        var b = termNode[v.toId + v.toWhich];
        if (a != null && b != null) union(a, b);
      }
    });

    // Map provisional -> canonical
    var canon = {};
    var canonNext = 0;
    function can(p) {
      var r = find(p);
      if (canon[r] == null) canon[r] = canonNext++;
      return canon[r];
    }

    view.forEach(function (v) {
      if (v.type === "wire") return;
      var na = can(termNode[v.id + "A"]);
      var nb = can(termNode[v.id + "B"]);
      var c = model.addComponent(v.type, v.value, na, nb, { closed: v.closed !== false });
      // Keep view id in sync with model id for selection
      // Actually model generates new ids – store mapping
      v.modelId = c.id;
      v.nodeA = na;
      v.nodeB = nb;
    });

    model.nextNode = canonNext;
  }

  function analyse() {
    rebuildModel();
    lastResult = model.solve();
    renderReadouts();
    draw();
    if (lastResult.ok) setStatus(lastResult.message === "Solved." ? "Circuit solved." : lastResult.message, "ok");
    else setStatus(lastResult.message, "err");
  }

  // ---------- Drawing ----------
  function draw() {
    var w = canvas.clientWidth || 640;
    var h = 480;
    ctx.clearRect(0, 0, w, h);

    // Components
    view.forEach(function (v) {
      if (v.type === "wire") {
        drawWire(v);
        return;
      }
      drawComponent(v);
    });

    // Pending wire rubber-band is handled in pointer move if needed – skip for simplicity

    // Highlight selection
    if (selectedId) {
      var s = findView(selectedId);
      if (s && s.type !== "wire") {
        ctx.save();
        ctx.strokeStyle = "#b22222";
        ctx.lineWidth = 2;
        ctx.setLineDash([4, 3]);
        ctx.strokeRect(s.x - COMP_W / 2 - 6, s.y - COMP_H / 2 - 10, COMP_W + 12, COMP_H + 20);
        ctx.restore();
      }
    }
  }

  function drawWire(v) {
    var a = findView(v.fromId);
    var b = findView(v.toId);
    if (!a || !b) return;
    var ta = terminals(a)[v.fromWhich];
    var tb = terminals(b)[v.toWhich];
    ctx.save();
    ctx.strokeStyle = "#333";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(ta.x, ta.y);
    // simple orthogonal route
    var midX = (ta.x + tb.x) / 2;
    ctx.lineTo(midX, ta.y);
    ctx.lineTo(midX, tb.y);
    ctx.lineTo(tb.x, tb.y);
    ctx.stroke();
    ctx.restore();
  }

  function drawComponent(v) {
    var t = terminals(v);
    var x = v.x, y = v.y;
    ctx.save();

    // Terminals
    ctx.fillStyle = "#222";
    ctx.beginPath();
    ctx.arc(t.A.x, t.A.y, TERM_R, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(t.B.x, t.B.y, TERM_R, 0, Math.PI * 2);
    ctx.fill();

    // Body by type
    ctx.strokeStyle = "#1b1b1b";
    ctx.fillStyle = "#fff";
    ctx.lineWidth = 2;
    ctx.font = "600 11px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";

    if (v.type === "battery") {
      // long/short lines
      ctx.beginPath();
      ctx.moveTo(t.A.x, t.A.y);
      ctx.lineTo(x - 10, y);
      ctx.moveTo(t.B.x, t.B.y);
      ctx.lineTo(x + 10, y);
      ctx.stroke();
      // positive (long) near A side center, negative near B
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(x - 6, y - 12);
      ctx.lineTo(x - 6, y + 12);
      ctx.stroke();
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(x + 4, y - 7);
      ctx.lineTo(x + 4, y + 7);
      ctx.stroke();
      ctx.fillStyle = "#b22222";
      ctx.fillText(formatVal(v.value, "V"), x, y + 22);
    } else if (v.type === "resistor") {
      ctx.beginPath();
      ctx.moveTo(t.A.x, t.A.y);
      ctx.lineTo(x - 28, y);
      // zigzag
      var zx = x - 28;
      var segs = 6, step = 56 / segs;
      for (var i = 0; i < segs; i++) {
        var ny = y + (i % 2 === 0 ? -8 : 8);
        ctx.lineTo(zx + step * (i + 0.5), ny);
      }
      ctx.lineTo(x + 28, y);
      ctx.lineTo(t.B.x, t.B.y);
      ctx.stroke();
      ctx.fillStyle = "#1b1b1b";
      ctx.fillText(formatVal(v.value, "Ω"), x, y + 22);
    } else if (v.type === "switch") {
      ctx.beginPath();
      ctx.moveTo(t.A.x, t.A.y);
      ctx.lineTo(x - 16, y);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(x - 16, y, 3, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      if (v.closed !== false) {
        ctx.moveTo(x - 16, y);
        ctx.lineTo(x + 16, y);
      } else {
        ctx.moveTo(x - 16, y);
        ctx.lineTo(x + 12, y - 12);
      }
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(x + 16, y, 3, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(x + 16, y);
      ctx.lineTo(t.B.x, t.B.y);
      ctx.stroke();
      ctx.fillStyle = v.closed !== false ? "#2e7d32" : "#b22222";
      ctx.fillText(v.closed !== false ? "CLOSED" : "OPEN", x, y + 22);
    } else if (v.type === "ammeter") {
      ctx.beginPath();
      ctx.moveTo(t.A.x, t.A.y);
      ctx.lineTo(x - 16, y);
      ctx.moveTo(x + 16, y);
      ctx.lineTo(t.B.x, t.B.y);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(x, y, 14, 0, Math.PI * 2);
      ctx.fillStyle = "#fff";
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = "#1b1b1b";
      ctx.fillText("A", x, y);
      var cur = currentFor(v);
      if (cur != null) {
        ctx.fillStyle = "#b22222";
        ctx.fillText(formatVal(cur, "A"), x, y + 24);
      }
    } else if (v.type === "voltmeter") {
      ctx.beginPath();
      ctx.moveTo(t.A.x, t.A.y);
      ctx.lineTo(x - 16, y);
      ctx.moveTo(x + 16, y);
      ctx.lineTo(t.B.x, t.B.y);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(x, y, 14, 0, Math.PI * 2);
      ctx.fillStyle = "#fff";
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = "#1b1b1b";
      ctx.fillText("V", x, y);
      var volt = voltageFor(v);
      if (volt != null) {
        ctx.fillStyle = "#b22222";
        ctx.fillText(formatVal(volt, "V"), x, y + 24);
      }
    }

    ctx.restore();
  }

  function formatVal(n, unit) {
    if (n == null || !isFinite(n)) return "–";
    var a = Math.abs(n);
    if (a >= 1000) return (n / 1000).toFixed(2) + " k" + unit;
    if (a >= 100) return n.toFixed(1) + " " + unit;
    if (a >= 1) return n.toFixed(2) + " " + unit;
    if (a >= 0.01) return n.toFixed(3) + " " + unit;
    return n.toExponential(1) + " " + unit;
  }

  function currentFor(v) {
    if (!lastResult || !lastResult.ok) return null;
    for (var i = 0; i < lastResult.branches.length; i++) {
      if (lastResult.branches[i].id === v.modelId) return lastResult.branches[i].current;
    }
    return null;
  }

  function voltageFor(v) {
    if (!lastResult || !lastResult.ok) return null;
    for (var i = 0; i < lastResult.branches.length; i++) {
      if (lastResult.branches[i].id === v.modelId) return lastResult.branches[i].voltage;
    }
    return null;
  }

  // ---------- Readouts ----------
  function renderReadouts() {
    if (!lastResult) return;

    // Stats
    var supply = lastResult.totalPower || 0;
    var nodeCount = Object.keys(lastResult.nodeVoltage || {}).length;
    setText("s-power", formatVal(supply, "W"));
    setText("s-nodes", String(nodeCount));
    setText("s-comps", String(view.filter(function (v) { return v.type !== "wire"; }).length));

    // Branch table
    if (branchBody) {
      branchBody.innerHTML = "";
      (lastResult.branches || []).forEach(function (br) {
        if (br.type === "wire") return;
        var tr = document.createElement("tr");
        tr.innerHTML =
          "<td>" + labelType(br.type) + "</td>" +
          "<td class='num'>" + (br.type === "battery" || br.type === "resistor" ? formatVal(br.value, br.type === "battery" ? "V" : "Ω") : "–") + "</td>" +
          "<td class='num'>" + formatVal(br.voltage, "V") + "</td>" +
          "<td class='num'>" + formatVal(br.current, "A") + "</td>";
        branchBody.appendChild(tr);
      });
    }

    // Props for selection
    renderProps();
  }

  function setText(id, t) {
    var el = document.getElementById(id);
    if (el) el.textContent = t;
  }

  function labelType(t) {
    return ({
      battery: "Battery",
      resistor: "Resistor",
      switch: "Switch",
      ammeter: "Ammeter",
      voltmeter: "Voltmeter",
      wire: "Wire"
    })[t] || t;
  }

  function renderProps() {
    if (!propsEl) return;
    var v = selectedId ? findView(selectedId) : null;
    if (!v || v.type === "wire") {
      propsEl.className = "props-box empty";
      propsEl.innerHTML = "Select a component to edit its value or toggle a switch.";
      if (valInput) valInput.disabled = true;
      return;
    }
    propsEl.className = "props-box";
    var html = "<div class='prop-row'><span>" + labelType(v.type) + "</span><strong>" + v.id.slice(0, 6) + "</strong></div>";
    if (v.type === "battery" || v.type === "resistor") {
      html += "<div class='prop-row'><span>" + (v.type === "battery" ? "Voltage" : "Resistance") + "</span></div>";
      if (valLabel) valLabel.textContent = v.type === "battery" ? "Voltage (V)" : "Resistance (Ω)";
      if (valInput) {
        valInput.disabled = false;
        valInput.value = v.value;
        valInput.min = v.type === "battery" ? "0.1" : "1";
        valInput.max = v.type === "battery" ? "48" : "100000";
        valInput.step = v.type === "battery" ? "0.1" : "1";
      }
    } else if (v.type === "switch") {
      html += "<div class='prop-row'><span>State</span><strong>" + (v.closed !== false ? "Closed" : "Open") + "</strong></div>";
      html += "<p class='unit-note' style='margin:6px 0 0'>Click the switch on the canvas to toggle.</p>";
      if (valInput) valInput.disabled = true;
    } else {
      if (valInput) valInput.disabled = true;
      var reading = v.type === "ammeter" ? currentFor(v) : voltageFor(v);
      html += "<div class='prop-row'><span>Reading</span><strong>" + formatVal(reading, v.type === "ammeter" ? "A" : "V") + "</strong></div>";
    }
    propsEl.innerHTML = html;
  }

  // ---------- Interaction ----------
  function canvasPos(evt) {
    var rect = canvas.getBoundingClientRect();
    var clientX = evt.touches ? evt.touches[0].clientX : evt.clientX;
    var clientY = evt.touches ? evt.touches[0].clientY : evt.clientY;
    return {
      x: clientX - rect.left,
      y: clientY - rect.top
    };
  }

  function onPointerDown(evt) {
    evt.preventDefault();
    var p = canvasPos(evt);
    var hit = hitTest(p.x, p.y);

    if (tool === "delete") {
      if (hit && hit.kind === "comp") {
        removeView(hit.id);
        analyse();
      } else if (hit && hit.kind === "term") {
        // delete wires attached to this terminal
        removeWiresAt(hit.id, hit.which);
        analyse();
      }
      return;
    }

    if (tool === "wire") {
      if (hit && hit.kind === "term") {
        if (!wireFrom) {
          wireFrom = { id: hit.id, which: hit.which };
          setHint("Now click the second terminal to finish the wire.");
        } else {
          if (wireFrom.id === hit.id && wireFrom.which === hit.which) {
            wireFrom = null;
            setHint("Wire cancelled. Click a terminal to start a wire.");
            return;
          }
          // create wire
          view.push({
            id: "w" + Math.random().toString(36).slice(2, 8),
            type: "wire",
            fromId: wireFrom.id,
            fromWhich: wireFrom.which,
            toId: hit.id,
            toWhich: hit.which
          });
          wireFrom = null;
          setHint("Wire added. Click another terminal or choose a different tool.");
          analyse();
        }
      }
      return;
    }

    if (tool === "select") {
      if (hit && hit.kind === "comp") {
        var comp = findView(hit.id);
        if (comp && comp.type === "switch") {
          // toggle
          comp.closed = !(comp.closed !== false);
          selectedId = comp.id;
          analyse();
          return;
        }
        selectedId = hit.id;
        renderProps();
        draw();
      } else {
        selectedId = null;
        renderProps();
        draw();
      }
      return;
    }

    // Place component tools
    if (["battery", "resistor", "switch", "ammeter", "voltmeter"].indexOf(tool) >= 0) {
      var x = snap(p.x);
      var y = snap(p.y);
      // keep inside bounds
      x = Math.max(COMP_W / 2 + 8, Math.min((canvas.clientWidth || 640) - COMP_W / 2 - 8, x));
      y = Math.max(COMP_H + 8, Math.min(460, y));
      var nv = {
        id: "v" + Math.random().toString(36).slice(2, 8),
        type: tool,
        x: x,
        y: y,
        value: tool === "battery" ? 9 : tool === "resistor" ? 100 : 0,
        closed: true
      };
      view.push(nv);
      selectedId = nv.id;
      setHint(labelType(tool) + " placed. Use Wire to connect terminals.");
      analyse();
      // stay on same tool for rapid placement
    }
  }

  function removeView(id) {
    view = view.filter(function (v) {
      if (v.id === id) return false;
      if (v.type === "wire" && (v.fromId === id || v.toId === id)) return false;
      return true;
    });
    if (selectedId === id) selectedId = null;
  }

  function removeWiresAt(id, which) {
    view = view.filter(function (v) {
      if (v.type !== "wire") return true;
      if (v.fromId === id && v.fromWhich === which) return false;
      if (v.toId === id && v.toWhich === which) return false;
      return true;
    });
  }

  // ---------- Toolbar / presets ----------
  function setTool(name) {
    tool = name;
    wireFrom = null;
    document.querySelectorAll(".stage-toolbar .tool").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-tool") === name);
    });
    var hints = {
      select: "Select a component. Click a switch to open or close it.",
      battery: "Click the canvas to place a battery (default 9 V).",
      resistor: "Click the canvas to place a resistor (default 100 Ω).",
      switch: "Click the canvas to place a switch (starts closed).",
      wire: "Click two terminals in sequence to connect them.",
      ammeter: "Click the canvas to place an ammeter (series current).",
      voltmeter: "Click the canvas to place a voltmeter (across two nodes).",
      delete: "Click a component to remove it (attached wires go too)."
    };
    setHint(hints[name] || "");
  }

  function loadPreset(name) {
    model.loadPreset(name);
    // Build a simple visual layout from the abstract preset
    view = [];
    var comps = model.components.slice();
    // Layout along a horizontal line
    var startX = 120;
    var y = 200;
    var gap = 100;
    // We need a visual for each non-shared-node layout – approximate:
    // Place battery first, then others left to right, and add wires by shared nodes.
    var nodePos = {}; // node -> list of terminal anchors after placement
    var placed = [];

    comps.forEach(function (c, i) {
      var x = startX + i * gap;
      var v = {
        id: c.id,
        type: c.type,
        x: x,
        y: y,
        value: c.value,
        closed: c.closed !== false,
        nodeA: c.nodeA,
        nodeB: c.nodeB,
        modelId: c.id
      };
      view.push(v);
      placed.push(v);
    });

    // Auto-wire: for every pair of terminals that share a model node, add a wire
    // (except the internal connection of the same component)
    var terminalsList = [];
    placed.forEach(function (v) {
      terminalsList.push({ viewId: v.id, which: "A", node: v.nodeA });
      terminalsList.push({ viewId: v.id, which: "B", node: v.nodeB });
    });
    var seen = {};
    for (var i = 0; i < terminalsList.length; i++) {
      for (var j = i + 1; j < terminalsList.length; j++) {
        var a = terminalsList[i], b = terminalsList[j];
        if (a.node === b.node && a.viewId !== b.viewId) {
          var key = [a.viewId + a.which, b.viewId + b.which].sort().join("|");
          if (!seen[key]) {
            seen[key] = true;
            view.push({
              id: "w" + Math.random().toString(36).slice(2, 8),
              type: "wire",
              fromId: a.viewId,
              fromWhich: a.which,
              toId: b.viewId,
              toWhich: b.which
            });
          }
        }
      }
    }

    selectedId = null;
    analyse();
    setHint("Preset loaded: " + name + ". Edit values or add more components.");
  }

  function clearAll() {
    view = [];
    model.clear();
    selectedId = null;
    lastResult = null;
    wireFrom = null;
    renderReadouts();
    draw();
    setStatus("Circuit cleared.", "");
    setHint("Choose a tool and place components, or load a preset.");
  }

  // ---------- Bind UI ----------
  function bind() {
    document.querySelectorAll(".stage-toolbar .tool").forEach(function (btn) {
      btn.addEventListener("click", function () {
        setTool(btn.getAttribute("data-tool"));
      });
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        loadPreset(btn.getAttribute("data-preset"));
      });
    });

    var btnClear = document.getElementById("btn-clear");
    if (btnClear) btnClear.addEventListener("click", clearAll);

    var btnAnalyse = document.getElementById("btn-analyse");
    if (btnAnalyse) btnAnalyse.addEventListener("click", analyse);

    if (valInput) {
      valInput.addEventListener("change", function () {
        var v = selectedId ? findView(selectedId) : null;
        if (!v) return;
        var n = parseFloat(valInput.value);
        if (!isFinite(n) || n <= 0) return;
        v.value = n;
        analyse();
      });
    }

    canvas.addEventListener("mousedown", onPointerDown);
    canvas.addEventListener("touchstart", onPointerDown, { passive: false });

    window.addEventListener("resize", resizeCanvas);
  }

  // ---------- Init ----------
  function init() {
    bind();
    resizeCanvas();
    setTool("select");
    loadPreset("series");
    // Notify Jenny once if available
    if (window.Jenny && typeof window.Jenny.notifyNewTip === "function") {
      try { window.Jenny.notifyNewTip("circuit-builder"); } catch (e) { /* ignore */ }
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

/**
 * Logic Gates UI – place gates, wire ports, toggle inputs.
 */
(function () {
  "use strict";

  var GATE_W = 72;
  var GATE_H = 48;
  var PORT_R = 6;

  var model = new LogicGatesModel();
  var tool = "select";
  var selectedId = null;
  var wireFrom = null; // { id, port }
  var lastEval = null;

  var canvas = document.getElementById("logic-canvas");
  var ctx = canvas.getContext("2d");
  var hintEl = document.getElementById("hint-bar");
  var statusEl = document.getElementById("status-line");

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
    draw();
  }

  function level(id) {
    if (!lastEval || !lastEval.values) return 0;
    return lastEval.values[id] ? 1 : 0;
  }

  function portsFor(n) {
    var x = n.x, y = n.y;
    var ports = {};
    if (n.type === "INPUT") {
      ports.out = { x: x + GATE_W / 2, y: y };
    } else if (n.type === "OUTPUT") {
      ports.in0 = { x: x - GATE_W / 2, y: y };
    } else if (n.type === "NOT") {
      ports.in0 = { x: x - GATE_W / 2, y: y };
      ports.out = { x: x + GATE_W / 2, y: y };
    } else {
      ports.in0 = { x: x - GATE_W / 2, y: y - 12 };
      ports.in1 = { x: x - GATE_W / 2, y: y + 12 };
      ports.out = { x: x + GATE_W / 2, y: y };
    }
    return ports;
  }

  function hitNode(mx, my) {
    for (var i = model.nodes.length - 1; i >= 0; i--) {
      var n = model.nodes[i];
      if (Math.abs(mx - n.x) <= GATE_W / 2 + 4 && Math.abs(my - n.y) <= GATE_H / 2 + 4) {
        return n;
      }
    }
    return null;
  }

  function hitPort(mx, my) {
    for (var i = model.nodes.length - 1; i >= 0; i--) {
      var n = model.nodes[i];
      var ps = portsFor(n);
      for (var k in ps) {
        if (!Object.prototype.hasOwnProperty.call(ps, k)) continue;
        var p = ps[k];
        var dx = mx - p.x, dy = my - p.y;
        if (dx * dx + dy * dy <= (PORT_R + 5) * (PORT_R + 5)) {
          return { id: n.id, port: k, node: n };
        }
      }
    }
    return null;
  }

  // ---------- Draw ----------
  function draw() {
    var w = canvas.clientWidth || 640;
    ctx.clearRect(0, 0, w, 440);

    // Wires
    model.wires.forEach(function (w) {
      var a = model.getNode(w.fromId);
      var b = model.getNode(w.toId);
      if (!a || !b) return;
      var pa = portsFor(a)[w.fromPort];
      var pb = portsFor(b)[w.toPort];
      if (!pa || !pb) return;
      var hi = level(w.fromId);
      ctx.strokeStyle = hi ? "#2e7d32" : "#999";
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.moveTo(pa.x, pa.y);
      var mid = (pa.x + pb.x) / 2;
      ctx.bezierCurveTo(mid, pa.y, mid, pb.y, pb.x, pb.y);
      ctx.stroke();
    });

    // Nodes
    model.nodes.forEach(function (n) {
      drawNode(n);
    });

    // Selection
    if (selectedId) {
      var s = model.getNode(selectedId);
      if (s) {
        ctx.strokeStyle = "#b22222";
        ctx.lineWidth = 2;
        ctx.setLineDash([4, 3]);
        ctx.strokeRect(s.x - GATE_W / 2 - 6, s.y - GATE_H / 2 - 6, GATE_W + 12, GATE_H + 12);
        ctx.setLineDash([]);
      }
    }
  }

  function drawNode(n) {
    var x = n.x, y = n.y;
    var hi = level(n.id);
    var ps = portsFor(n);

    // Body
    ctx.lineWidth = 2;
    ctx.strokeStyle = "#1b1b1b";
    ctx.fillStyle = n.type === "INPUT" ? (hi ? "#e8f5e9" : "#f5f5f5")
      : n.type === "OUTPUT" ? (hi ? "#e8f5e9" : "#fafafa")
      : "#fff";

    if (n.type === "INPUT" || n.type === "OUTPUT") {
      roundRect(x - GATE_W / 2, y - 18, GATE_W, 36, 6);
      ctx.fill();
      ctx.stroke();
    } else {
      // Gate body – rounded rectangle
      roundRect(x - GATE_W / 2 + 4, y - GATE_H / 2, GATE_W - 8, GATE_H, 8);
      ctx.fill();
      ctx.stroke();
    }

    // Label
    ctx.fillStyle = "#1b1b1b";
    ctx.font = "700 12px DM Sans, Arial, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    var label = n.type === "INPUT" ? (hi ? "1" : "0")
      : n.type === "OUTPUT" ? (hi ? "1" : "0")
      : n.type;
    ctx.fillText(label, x, y);

    if (n.type === "INPUT") {
      ctx.font = "600 9px DM Sans, Arial, sans-serif";
      ctx.fillStyle = "#666";
      ctx.fillText("IN", x, y - 28);
    }
    if (n.type === "OUTPUT") {
      ctx.font = "600 9px DM Sans, Arial, sans-serif";
      ctx.fillStyle = "#666";
      ctx.fillText("OUT", x, y - 28);
    }

    // Ports
    Object.keys(ps).forEach(function (k) {
      var p = ps[k];
      var isOut = k === "out";
      var srcLevel = isOut ? hi : 0;
      if (!isOut) {
        // level from driving wire
        for (var i = 0; i < model.wires.length; i++) {
          var ww = model.wires[i];
          if (ww.toId === n.id && ww.toPort === k) {
            srcLevel = level(ww.fromId);
            break;
          }
        }
      }
      ctx.beginPath();
      ctx.arc(p.x, p.y, PORT_R, 0, Math.PI * 2);
      ctx.fillStyle = srcLevel ? "#2e7d32" : "#bbb";
      ctx.fill();
      ctx.strokeStyle = "#1b1b1b";
      ctx.lineWidth = 1.5;
      ctx.stroke();
    });
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

  // ---------- Evaluate / UI ----------
  function analyse() {
    lastEval = model.evaluate();
    if (lastEval.ok) setStatus(lastEval.message, "ok");
    else setStatus(lastEval.message, "err");
    setText("s-gates", String(model.nodes.filter(function (n) {
      return n.type !== "INPUT" && n.type !== "OUTPUT";
    }).length));
    setText("s-inputs", String(model.nodes.filter(function (n) { return n.type === "INPUT"; }).length));
    setText("s-wires", String(model.wires.length));
    updateTruth();
    draw();
  }

  function setText(id, t) {
    var el = document.getElementById(id);
    if (el) el.textContent = t;
  }

  function updateTruth() {
    var body = document.getElementById("truth-body");
    var head = document.getElementById("truth-head");
    if (!body || !head) return;
    var n = selectedId ? model.getNode(selectedId) : null;
    var type = n && TRUTH_TYPES[n.type] ? n.type : null;
    if (!type) {
      // default show AND
      type = "AND";
      head.textContent = "Truth table (AND)";
    } else {
      head.textContent = "Truth table (" + type + ")";
    }
    var rows = LogicGatesModel.truthTable(type);
    body.innerHTML = "";
    rows.forEach(function (r) {
      var tr = document.createElement("tr");
      if (r.b == null) {
        tr.innerHTML = "<td class='bit" + r.a + "'>" + r.a + "</td><td class='bit" + r.out + "'>" + r.out + "</td>";
      } else {
        tr.innerHTML = "<td class='bit" + r.a + "'>" + r.a + "</td><td class='bit" + r.b + "'>" + r.b + "</td><td class='bit" + r.out + "'>" + r.out + "</td>";
      }
      body.appendChild(tr);
    });
    // header cols
    var th = document.getElementById("truth-cols");
    if (th) {
      if (type === "NOT") th.innerHTML = "<th>A</th><th>Out</th>";
      else th.innerHTML = "<th>A</th><th>B</th><th>Out</th>";
    }
  }

  var TRUTH_TYPES = { NOT: 1, AND: 1, OR: 1, NAND: 1, NOR: 1, XOR: 1, XNOR: 1 };

  // ---------- Interaction ----------
  function canvasPos(evt) {
    var rect = canvas.getBoundingClientRect();
    var cx = evt.touches ? evt.touches[0].clientX : evt.clientX;
    var cy = evt.touches ? evt.touches[0].clientY : evt.clientY;
    return { x: cx - rect.left, y: cy - rect.top };
  }

  function onDown(evt) {
    evt.preventDefault();
    var p = canvasPos(evt);

    if (tool === "delete") {
      var hn = hitNode(p.x, p.y);
      if (hn) {
        model.removeNode(hn.id);
        if (selectedId === hn.id) selectedId = null;
        analyse();
      }
      return;
    }

    if (tool === "wire") {
      var hp = hitPort(p.x, p.y);
      if (!hp) return;
      if (!wireFrom) {
        if (hp.port !== "out") {
          setHint("Start a wire from an output port (right side of a gate or input).");
          return;
        }
        wireFrom = { id: hp.id, port: hp.port };
        setHint("Now click an input port to finish the wire.");
      } else {
        if (hp.port === "out") {
          setHint("Connect to an input port (left side), not another output.");
          return;
        }
        model.addWire(wireFrom.id, wireFrom.port, hp.id, hp.port);
        wireFrom = null;
        setHint("Wire added. Click an output port to start another wire.");
        analyse();
      }
      return;
    }

    if (tool === "select") {
      var node = hitNode(p.x, p.y);
      if (node) {
        if (node.type === "INPUT") {
          model.toggleInput(node.id);
          selectedId = node.id;
          analyse();
          return;
        }
        selectedId = node.id;
        updateTruth();
        draw();
        return;
      }
      selectedId = null;
      draw();
      return;
    }

    // Place tools
    var placeTypes = ["INPUT", "OUTPUT", "NOT", "AND", "OR", "NAND", "NOR", "XOR", "XNOR"];
    if (placeTypes.indexOf(tool) >= 0) {
      var x = Math.round(p.x / 20) * 20;
      var y = Math.round(p.y / 20) * 20;
      x = Math.max(50, Math.min((canvas.clientWidth || 640) - 50, x));
      y = Math.max(40, Math.min(400, y));
      var node = model.addNode(tool, x, y, tool === "INPUT" ? 0 : 0);
      selectedId = node.id;
      setHint(tool + " placed. Use Wire to connect ports. Click inputs to toggle.");
      analyse();
    }
  }

  function setTool(name) {
    tool = name;
    wireFrom = null;
    document.querySelectorAll(".stage-toolbar .tool").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-tool") === name);
    });
    var hints = {
      select: "Click an input to toggle 0/1. Click a gate to select it and show its truth table.",
      wire: "Click an output port, then an input port, to connect them.",
      delete: "Click a gate or input/output to remove it (wires go too).",
      INPUT: "Click the canvas to place a toggleable input switch.",
      OUTPUT: "Click the canvas to place an output probe.",
      NOT: "Place a NOT (inverter) gate.",
      AND: "Place an AND gate.",
      OR: "Place an OR gate.",
      NAND: "Place a NAND gate.",
      NOR: "Place a NOR gate.",
      XOR: "Place an XOR gate.",
      XNOR: "Place an XNOR gate."
    };
    setHint(hints[name] || "");
  }

  function loadPreset(name) {
    model.loadPreset(name);
    selectedId = null;
    wireFrom = null;
    analyse();
    setHint("Preset loaded. Click inputs to toggle and watch outputs change.");
  }

  function clearAll() {
    model.clear();
    selectedId = null;
    lastEval = null;
    wireFrom = null;
    analyse();
    setHint("Cleared. Place inputs, gates and outputs, then wire them.");
  }

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
    var bc = document.getElementById("btn-clear");
    if (bc) bc.addEventListener("click", clearAll);
    canvas.addEventListener("mousedown", onDown);
    canvas.addEventListener("touchstart", onDown, { passive: false });
    window.addEventListener("resize", resize);
  }

  function init() {
    bind();
    resize();
    setTool("select");
    loadPreset("halfAdder");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

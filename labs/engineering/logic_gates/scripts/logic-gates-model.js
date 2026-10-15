/**
 * LogicGatesModel – combinational gate graph + evaluator.
 */
(function (global) {
  "use strict";

  function uid(p) {
    return (p || "g") + Math.random().toString(36).slice(2, 9);
  }

  var TRUTH = {
    NOT: function (a) { return a ? 0 : 1; },
    AND: function (a, b) { return a && b ? 1 : 0; },
    OR: function (a, b) { return a || b ? 1 : 0; },
    NAND: function (a, b) { return a && b ? 0 : 1; },
    NOR: function (a, b) { return a || b ? 0 : 1; },
    XOR: function (a, b) { return a !== b ? 1 : 0; },
    XNOR: function (a, b) { return a === b ? 1 : 0; }
  };

  function LogicGatesModel() {
    this.nodes = []; // { id, type, x, y, value? for INPUT }
    this.wires = []; // { id, fromId, fromPort, toId, toPort }
  }

  LogicGatesModel.prototype.clear = function () {
    this.nodes = [];
    this.wires = [];
  };

  LogicGatesModel.prototype.addNode = function (type, x, y, value) {
    var n = {
      id: uid("n"),
      type: type,
      x: x,
      y: y,
      value: type === "INPUT" ? (value ? 1 : 0) : 0
    };
    this.nodes.push(n);
    return n;
  };

  LogicGatesModel.prototype.removeNode = function (id) {
    this.nodes = this.nodes.filter(function (n) { return n.id !== id; });
    this.wires = this.wires.filter(function (w) {
      return w.fromId !== id && w.toId !== id;
    });
  };

  LogicGatesModel.prototype.addWire = function (fromId, fromPort, toId, toPort) {
    // fromPort always 'out'; toPort 'in0' or 'in1'
    // Only one wire per input port
    this.wires = this.wires.filter(function (w) {
      return !(w.toId === toId && w.toPort === toPort);
    });
    if (fromId === toId) return null;
    var w = { id: uid("w"), fromId: fromId, fromPort: fromPort, toId: toId, toPort: toPort };
    this.wires.push(w);
    return w;
  };

  LogicGatesModel.prototype.removeWire = function (id) {
    this.wires = this.wires.filter(function (w) { return w.id !== id; });
  };

  LogicGatesModel.prototype.getNode = function (id) {
    for (var i = 0; i < this.nodes.length; i++) {
      if (this.nodes[i].id === id) return this.nodes[i];
    }
    return null;
  };

  LogicGatesModel.prototype.toggleInput = function (id) {
    var n = this.getNode(id);
    if (n && n.type === "INPUT") {
      n.value = n.value ? 0 : 1;
    }
  };

  /** Number of data inputs for a gate type */
  LogicGatesModel.inputCount = function (type) {
    if (type === "NOT" || type === "OUTPUT") return 1;
    if (type === "INPUT") return 0;
    return 2;
  };

  /**
   * Evaluate combinational circuit.
   * Returns { ok, message, values: { nodeId: 0|1 } }
   */
  LogicGatesModel.prototype.evaluate = function () {
    var nodes = this.nodes;
    var wires = this.wires;
    var values = {};
    var self = this;

    // Map: toId+toPort -> fromId
    var feed = {};
    wires.forEach(function (w) {
      feed[w.toId + ":" + w.toPort] = w.fromId;
    });

    // Kahn topological order among gate nodes
    var indeg = {};
    var adj = {};
    nodes.forEach(function (n) {
      indeg[n.id] = 0;
      adj[n.id] = [];
    });
    wires.forEach(function (w) {
      adj[w.fromId].push(w.toId);
      indeg[w.toId] = (indeg[w.toId] || 0) + 1;
    });

    var queue = [];
    nodes.forEach(function (n) {
      if ((indeg[n.id] || 0) === 0) queue.push(n.id);
    });
    var order = [];
    while (queue.length) {
      var id = queue.shift();
      order.push(id);
      (adj[id] || []).forEach(function (v) {
        indeg[v]--;
        if (indeg[v] === 0) queue.push(v);
      });
    }

    if (order.length < nodes.length) {
      return {
        ok: false,
        message: "Cycle detected — this lab is combinational only (no loops).",
        values: values
      };
    }

    order.forEach(function (id) {
      var n = self.getNode(id);
      if (!n) return;
      if (n.type === "INPUT") {
        values[id] = n.value ? 1 : 0;
        return;
      }
      if (n.type === "OUTPUT") {
        var src = feed[id + ":in0"];
        values[id] = src != null && values[src] != null ? values[src] : 0;
        return;
      }
      var a = 0, b = 0;
      var sa = feed[id + ":in0"];
      var sb = feed[id + ":in1"];
      if (sa != null && values[sa] != null) a = values[sa];
      if (sb != null && values[sb] != null) b = values[sb];
      var fn = TRUTH[n.type];
      if (n.type === "NOT") values[id] = fn(a);
      else if (fn) values[id] = fn(a, b);
      else values[id] = 0;
    });

    return { ok: true, message: "Evaluated.", values: values };
  };

  /** Truth table rows for a single gate type */
  LogicGatesModel.truthTable = function (type) {
    var rows = [];
    if (type === "NOT") {
      rows.push({ a: 0, out: TRUTH.NOT(0) });
      rows.push({ a: 1, out: TRUTH.NOT(1) });
    } else if (TRUTH[type]) {
      for (var a = 0; a <= 1; a++) {
        for (var b = 0; b <= 1; b++) {
          rows.push({ a: a, b: b, out: TRUTH[type](a, b) });
        }
      }
    }
    return rows;
  };

  // --- Presets ---
  LogicGatesModel.presets = {
    inverter: function () {
      return {
        nodes: [
          { id: "i0", type: "INPUT", x: 80, y: 160, value: 1 },
          { id: "g0", type: "NOT", x: 220, y: 160 },
          { id: "o0", type: "OUTPUT", x: 360, y: 160 }
        ],
        wires: [
          { id: "w0", fromId: "i0", fromPort: "out", toId: "g0", toPort: "in0" },
          { id: "w1", fromId: "g0", fromPort: "out", toId: "o0", toPort: "in0" }
        ]
      };
    },
    andOr: function () {
      return {
        nodes: [
          { id: "i0", type: "INPUT", x: 60, y: 100, value: 1 },
          { id: "i1", type: "INPUT", x: 60, y: 180, value: 1 },
          { id: "i2", type: "INPUT", x: 60, y: 260, value: 0 },
          { id: "g0", type: "AND", x: 200, y: 140 },
          { id: "g1", type: "OR", x: 340, y: 200 },
          { id: "o0", type: "OUTPUT", x: 480, y: 200 }
        ],
        wires: [
          { id: "w0", fromId: "i0", fromPort: "out", toId: "g0", toPort: "in0" },
          { id: "w1", fromId: "i1", fromPort: "out", toId: "g0", toPort: "in1" },
          { id: "w2", fromId: "g0", fromPort: "out", toId: "g1", toPort: "in0" },
          { id: "w3", fromId: "i2", fromPort: "out", toId: "g1", toPort: "in1" },
          { id: "w4", fromId: "g1", fromPort: "out", toId: "o0", toPort: "in0" }
        ]
      };
    },
    halfAdder: function () {
      // Sum = A XOR B, Carry = A AND B
      return {
        nodes: [
          { id: "i0", type: "INPUT", x: 60, y: 120, value: 1 },
          { id: "i1", type: "INPUT", x: 60, y: 220, value: 1 },
          { id: "g0", type: "XOR", x: 220, y: 120 },
          { id: "g1", type: "AND", x: 220, y: 220 },
          { id: "o0", type: "OUTPUT", x: 380, y: 120 },
          { id: "o1", type: "OUTPUT", x: 380, y: 220 }
        ],
        wires: [
          { id: "w0", fromId: "i0", fromPort: "out", toId: "g0", toPort: "in0" },
          { id: "w1", fromId: "i1", fromPort: "out", toId: "g0", toPort: "in1" },
          { id: "w2", fromId: "i0", fromPort: "out", toId: "g1", toPort: "in0" },
          { id: "w3", fromId: "i1", fromPort: "out", toId: "g1", toPort: "in1" },
          { id: "w4", fromId: "g0", fromPort: "out", toId: "o0", toPort: "in0" },
          { id: "w5", fromId: "g1", fromPort: "out", toId: "o1", toPort: "in0" }
        ]
      };
    },
    nandXor: function () {
      // XOR built from four NANDs (classic)
      return {
        nodes: [
          { id: "i0", type: "INPUT", x: 50, y: 120, value: 1 },
          { id: "i1", type: "INPUT", x: 50, y: 240, value: 0 },
          { id: "g0", type: "NAND", x: 180, y: 180 },
          { id: "g1", type: "NAND", x: 300, y: 120 },
          { id: "g2", type: "NAND", x: 300, y: 240 },
          { id: "g3", type: "NAND", x: 420, y: 180 },
          { id: "o0", type: "OUTPUT", x: 540, y: 180 }
        ],
        wires: [
          { id: "w0", fromId: "i0", fromPort: "out", toId: "g0", toPort: "in0" },
          { id: "w1", fromId: "i1", fromPort: "out", toId: "g0", toPort: "in1" },
          { id: "w2", fromId: "i0", fromPort: "out", toId: "g1", toPort: "in0" },
          { id: "w3", fromId: "g0", fromPort: "out", toId: "g1", toPort: "in1" },
          { id: "w4", fromId: "g0", fromPort: "out", toId: "g2", toPort: "in0" },
          { id: "w5", fromId: "i1", fromPort: "out", toId: "g2", toPort: "in1" },
          { id: "w6", fromId: "g1", fromPort: "out", toId: "g3", toPort: "in0" },
          { id: "w7", fromId: "g2", fromPort: "out", toId: "g3", toPort: "in1" },
          { id: "w8", fromId: "g3", fromPort: "out", toId: "o0", toPort: "in0" }
        ]
      };
    }
  };

  LogicGatesModel.prototype.loadPreset = function (name) {
    var p = LogicGatesModel.presets[name];
    if (!p) return;
    var data = p();
    this.nodes = data.nodes.map(function (n) {
      return { id: n.id, type: n.type, x: n.x, y: n.y, value: n.value || 0 };
    });
    this.wires = data.wires.map(function (w) {
      return { id: w.id, fromId: w.fromId, fromPort: w.fromPort, toId: w.toId, toPort: w.toPort };
    });
  };

  if (typeof module !== "undefined" && module.exports) module.exports = LogicGatesModel;
  global.LogicGatesModel = LogicGatesModel;
})(typeof window !== "undefined" ? window : global);

/**
 * CircuitModel – pure DC circuit graph + nodal solver for OOPA Circuit Builder.
 * Ideal resistors, ideal batteries, ideal open/closed switches, zero-R wires.
 * Exposed as window.CircuitModel (and module.exports when require'd).
 */
(function (global) {
  "use strict";

  var EPS = 1e-12;
  var G_WIRE = 1e6;      // siemens – near short
  var G_OPEN = 1e-12;    // siemens – near open
  var G_AMMETER = 1e6;   // treat like a wire for resistance

  function uid() {
    return "c" + Math.random().toString(36).slice(2, 9);
  }

  function CircuitModel() {
    this.components = []; // { id, type, value, nodeA, nodeB, closed? }
    this.nextNode = 0;
  }

  CircuitModel.prototype.clear = function () {
    this.components = [];
    this.nextNode = 0;
  };

  CircuitModel.prototype.addComponent = function (type, value, nodeA, nodeB, extra) {
    var c = {
      id: uid(),
      type: type,
      value: value == null ? defaultValue(type) : value,
      nodeA: nodeA,
      nodeB: nodeB,
      closed: extra && extra.closed != null ? !!extra.closed : true
    };
    this.components.push(c);
    if (nodeA >= this.nextNode) this.nextNode = nodeA + 1;
    if (nodeB >= this.nextNode) this.nextNode = nodeB + 1;
    return c;
  };

  CircuitModel.prototype.removeComponent = function (id) {
    this.components = this.components.filter(function (c) { return c.id !== id; });
  };

  CircuitModel.prototype.getComponent = function (id) {
    for (var i = 0; i < this.components.length; i++) {
      if (this.components[i].id === id) return this.components[i];
    }
    return null;
  };

  function defaultValue(type) {
    if (type === "battery") return 9;
    if (type === "resistor") return 100;
    return 0;
  }

  /** Conductance of a passive branch (not a battery). */
  function branchG(c) {
    if (c.type === "wire" || c.type === "ammeter") return G_WIRE;
    if (c.type === "voltmeter") return G_OPEN; // open circuit
    if (c.type === "switch") return c.closed ? G_WIRE : G_OPEN;
    if (c.type === "resistor") {
      var r = Math.max(c.value, 1e-9);
      return 1 / r;
    }
    return 0;
  }

  /**
   * Solve the circuit.
   * Returns {
   *   ok, message,
   *   nodeVoltage: { [nodeId]: volts },
   *   branches: [ { id, type, value, nodeA, nodeB, voltage, current, power, closed } ],
   *   totalPower, groundNode
   * }
   */
  CircuitModel.prototype.solve = function () {
    var comps = this.components;
    if (!comps.length) {
      return {
        ok: true,
        message: "Empty circuit.",
        nodeVoltage: {},
        branches: [],
        totalPower: 0,
        groundNode: 0
      };
    }

    // Collect used nodes
    var nodeSet = {};
    comps.forEach(function (c) {
      nodeSet[c.nodeA] = true;
      nodeSet[c.nodeB] = true;
    });
    var nodes = Object.keys(nodeSet).map(Number).sort(function (a, b) { return a - b; });
    if (nodes.length < 2) {
      return {
        ok: false,
        message: "Need at least two nodes.",
        nodeVoltage: {},
        branches: [],
        totalPower: 0,
        groundNode: nodes[0] || 0
      };
    }

    // Ground = negative terminal of the first battery (or lowest node if none)
    var batteries = comps.filter(function (c) { return c.type === "battery"; });
    var ground = batteries.length ? batteries[0].nodeB : nodes[0];

    // Map node id → matrix index (ground is excluded)
    var freeNodes = nodes.filter(function (n) { return n !== ground; });
    var n = freeNodes.length;
    var idx = {};
    freeNodes.forEach(function (node, i) { idx[node] = i; });

    if (n === 0) {
      // Only ground node
      var nv0 = {};
      nv0[ground] = 0;
      return finish(this, nv0, ground, "Only ground node present.");
    }

    // G x = b  (nodal, voltage sources stamped with modified approach:
    // each battery forces V_pos - V_neg = Vsource via a large conductance + current injection)
    var G = zeros(n, n);
    var b = zeros(n, 1);
    var SHORT_G = 1e6; // for ideal voltage source stamp

    // First stamp all passive branches
    comps.forEach(function (c) {
      if (c.type === "battery") return;
      var g = branchG(c);
      stampConductance(G, idx, c.nodeA, c.nodeB, g, ground);
    });

    // Stamp batteries as ideal voltage sources using large-G method:
    // G_big between pos and neg, inject G_big * V into the positive side equation.
    var shorted = false;
    batteries.forEach(function (bat) {
      var vp = bat.nodeA; // positive
      var vn = bat.nodeB; // negative
      if (vp === vn) {
        shorted = true;
        return;
      }
      // Check pure short elsewhere across same nodes with near-zero R
      stampConductance(G, idx, vp, vn, SHORT_G, ground);
      // Inject current into KCL at positive node: + SHORT_G * V
      if (vp !== ground && idx[vp] != null) {
        b[idx[vp]][0] += SHORT_G * bat.value;
      }
      if (vn !== ground && idx[vn] != null) {
        b[idx[vn]][0] -= SHORT_G * bat.value;
      }
    });

    if (shorted) {
      return {
        ok: false,
        message: "Battery terminals are shorted together.",
        nodeVoltage: {},
        branches: [],
        totalPower: 0,
        groundNode: ground
      };
    }

    // Detect near-singular (floating or pure short of source)
    var x;
    try {
      x = solveLinear(G, b);
    } catch (e) {
      return {
        ok: false,
        message: "Circuit cannot be solved (open loop, floating node, or shorted source).",
        nodeVoltage: {},
        branches: [],
        totalPower: 0,
        groundNode: ground
      };
    }

    var nodeVoltage = {};
    nodeVoltage[ground] = 0;
    freeNodes.forEach(function (node, i) {
      nodeVoltage[node] = x[i][0];
    });

    return finish(this, nodeVoltage, ground, "Solved.");
  };

  function finish(model, nodeVoltage, ground, message) {
    var branches = [];
    var totalPower = 0;
    model.components.forEach(function (c) {
      var va = nodeVoltage[c.nodeA];
      var vb = nodeVoltage[c.nodeB];
      if (va == null) va = 0;
      if (vb == null) vb = 0;
      var vDrop = va - vb; // voltage at A minus voltage at B
      var current = 0;
      var power = 0;

      if (c.type === "battery") {
        // Current out of positive terminal ≈ sum of currents leaving that node through other branches
        // Compute via Ohm on the large-G stamp residual is awkward; instead KCL on positive node.
        current = currentOutOfNode(model, c.nodeA, nodeVoltage, c.id);
        power = c.value * current; // power delivered by source (positive = supplying)
      } else if (c.type === "voltmeter") {
        current = 0;
        power = 0;
      } else {
        var g = branchG(c);
        current = g * vDrop; // from A to B
        power = vDrop * current;
      }

      if (c.type !== "battery") totalPower += Math.max(power, 0);

      branches.push({
        id: c.id,
        type: c.type,
        value: c.value,
        nodeA: c.nodeA,
        nodeB: c.nodeB,
        closed: c.closed,
        voltage: vDrop,
        current: current,
        power: power
      });
    });

    // Power check: sum of resistor dissipation should ≈ sum of battery supply
    var supply = 0;
    branches.forEach(function (br) {
      if (br.type === "battery") supply += br.power;
    });

    return {
      ok: true,
      message: message,
      nodeVoltage: nodeVoltage,
      branches: branches,
      totalPower: supply,
      groundNode: ground
    };
  }

  /** Net current leaving node through all branches except skipId (for battery current). */
  function currentOutOfNode(model, node, nodeVoltage, skipId) {
    var i = 0;
    model.components.forEach(function (c) {
      if (c.id === skipId) return;
      if (c.type === "battery") return; // other sources handled separately if needed
      var va = nodeVoltage[c.nodeA] || 0;
      var vb = nodeVoltage[c.nodeB] || 0;
      var g = branchG(c);
      if (c.nodeA === node) i += g * (va - vb);
      else if (c.nodeB === node) i += g * (vb - va);
    });
    return i;
  }

  function stampConductance(G, idx, na, nb, g, ground) {
    // Stamp +g on diagonal, -g off-diagonal for free nodes
    if (na !== ground && idx[na] != null) {
      G[idx[na]][idx[na]] += g;
    }
    if (nb !== ground && idx[nb] != null) {
      G[idx[nb]][idx[nb]] += g;
    }
    if (na !== ground && nb !== ground && idx[na] != null && idx[nb] != null) {
      G[idx[na]][idx[nb]] -= g;
      G[idx[nb]][idx[na]] -= g;
    }
  }

  function zeros(r, c) {
    var m = [];
    for (var i = 0; i < r; i++) {
      m[i] = [];
      for (var j = 0; j < c; j++) m[i][j] = 0;
    }
    return m;
  }

  /** Gaussian elimination with partial pivoting. Throws on singular. */
  function solveLinear(A, b) {
    var n = A.length;
    // Augment
    var M = [];
    for (var i = 0; i < n; i++) {
      M[i] = A[i].slice();
      M[i].push(b[i][0]);
    }
    for (var col = 0; col < n; col++) {
      // Pivot
      var max = Math.abs(M[col][col]);
      var piv = col;
      for (var r = col + 1; r < n; r++) {
        var v = Math.abs(M[r][col]);
        if (v > max) { max = v; piv = r; }
      }
      if (max < EPS) throw new Error("singular");
      if (piv !== col) {
        var tmp = M[col];
        M[col] = M[piv];
        M[piv] = tmp;
      }
      // Eliminate
      var diag = M[col][col];
      for (var r2 = col + 1; r2 < n; r2++) {
        var f = M[r2][col] / diag;
        for (var c2 = col; c2 <= n; c2++) M[r2][c2] -= f * M[col][c2];
      }
    }
    // Back-sub
    var x = zeros(n, 1);
    for (var i2 = n - 1; i2 >= 0; i2--) {
      var s = M[i2][n];
      for (var j = i2 + 1; j < n; j++) s -= M[i2][j] * x[j][0];
      if (Math.abs(M[i2][i2]) < EPS) throw new Error("singular");
      x[i2][0] = s / M[i2][i2];
    }
    return x;
  }

  // --- Preset builders (return { components, nextNode } plain data) ---

  CircuitModel.presets = {
    series: function () {
      // Battery 9V, two resistors 100 Ω and 200 Ω in series
      // nodes: 0 (gnd/bat-) -- bat -- 1 -- R100 -- 2 -- R200 -- 0
      return {
        nextNode: 3,
        components: [
          { id: "p1", type: "battery", value: 9, nodeA: 1, nodeB: 0, closed: true },
          { id: "p2", type: "resistor", value: 100, nodeA: 1, nodeB: 2, closed: true },
          { id: "p3", type: "resistor", value: 200, nodeA: 2, nodeB: 0, closed: true }
        ]
      };
    },
    parallel: function () {
      // Battery 9V, two resistors 100 Ω and 100 Ω in parallel
      // 0 (gnd) -- bat -- 1 ; 1 -- R -- 0 ; 1 -- R -- 0
      return {
        nextNode: 2,
        components: [
          { id: "p1", type: "battery", value: 9, nodeA: 1, nodeB: 0, closed: true },
          { id: "p2", type: "resistor", value: 100, nodeA: 1, nodeB: 0, closed: true },
          { id: "p3", type: "resistor", value: 100, nodeA: 1, nodeB: 0, closed: true }
        ]
      };
    },
    mixed: function () {
      // 12 V, R1 series, then R2 || R3
      // 0 -- bat -- 1 -- R100 -- 2 ; 2 -- R200 -- 0 ; 2 -- R200 -- 0
      return {
        nextNode: 3,
        components: [
          { id: "p1", type: "battery", value: 12, nodeA: 1, nodeB: 0, closed: true },
          { id: "p2", type: "resistor", value: 100, nodeA: 1, nodeB: 2, closed: true },
          { id: "p3", type: "resistor", value: 200, nodeA: 2, nodeB: 0, closed: true },
          { id: "p4", type: "resistor", value: 200, nodeA: 2, nodeB: 0, closed: true }
        ]
      };
    },
    withSwitch: function () {
      // Series with switch: bat -- switch -- R -- gnd
      return {
        nextNode: 3,
        components: [
          { id: "p1", type: "battery", value: 9, nodeA: 1, nodeB: 0, closed: true },
          { id: "p2", type: "switch", value: 0, nodeA: 1, nodeB: 2, closed: true },
          { id: "p3", type: "resistor", value: 150, nodeA: 2, nodeB: 0, closed: true }
        ]
      };
    }
  };

  CircuitModel.prototype.loadPreset = function (name) {
    var p = CircuitModel.presets[name];
    if (!p) return;
    var data = p();
    this.components = data.components.map(function (c) {
      return {
        id: c.id,
        type: c.type,
        value: c.value,
        nodeA: c.nodeA,
        nodeB: c.nodeB,
        closed: c.closed !== false
      };
    });
    this.nextNode = data.nextNode;
  };

  // Export
  if (typeof module !== "undefined" && module.exports) {
    module.exports = CircuitModel;
  }
  global.CircuitModel = CircuitModel;
})(typeof window !== "undefined" ? window : global);

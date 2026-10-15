/**
 * TrussModel – 2D pin-jointed truss + simple beam statics.
 * window.TrussModel / module.exports
 */
(function (global) {
  "use strict";

  var EPS = 1e-10;

  function uid(prefix) {
    return (prefix || "id") + Math.random().toString(36).slice(2, 9);
  }

  function TrussModel() {
    this.joints = [];   // { id, x, y }
    this.members = [];  // { id, jointA, jointB }
    this.supports = []; // { id, jointId, type: 'pin'|'roller' }
    this.loads = [];    // { id, jointId, fx, fy }
  }

  TrussModel.prototype.clear = function () {
    this.joints = [];
    this.members = [];
    this.supports = [];
    this.loads = [];
  };

  TrussModel.prototype.addJoint = function (x, y) {
    var j = { id: uid("j"), x: x, y: y };
    this.joints.push(j);
    return j;
  };

  TrussModel.prototype.addMember = function (jointA, jointB) {
    if (jointA === jointB) return null;
    // prevent duplicate
    for (var i = 0; i < this.members.length; i++) {
      var m = this.members[i];
      if ((m.jointA === jointA && m.jointB === jointB) ||
          (m.jointA === jointB && m.jointB === jointA)) return null;
    }
    var mem = { id: uid("m"), jointA: jointA, jointB: jointB };
    this.members.push(mem);
    return mem;
  };

  TrussModel.prototype.addSupport = function (jointId, type) {
    // one support per joint
    this.supports = this.supports.filter(function (s) { return s.jointId !== jointId; });
    var s = { id: uid("s"), jointId: jointId, type: type === "roller" ? "roller" : "pin" };
    this.supports.push(s);
    return s;
  };

  TrussModel.prototype.addLoad = function (jointId, fx, fy) {
    var L = { id: uid("L"), jointId: jointId, fx: fx || 0, fy: fy || 0 };
    this.loads.push(L);
    return L;
  };

  TrussModel.prototype.removeJoint = function (id) {
    this.joints = this.joints.filter(function (j) { return j.id !== id; });
    this.members = this.members.filter(function (m) { return m.jointA !== id && m.jointB !== id; });
    this.supports = this.supports.filter(function (s) { return s.jointId !== id; });
    this.loads = this.loads.filter(function (L) { return L.jointId !== id; });
  };

  TrussModel.prototype.removeMember = function (id) {
    this.members = this.members.filter(function (m) { return m.id !== id; });
  };

  TrussModel.prototype.removeSupport = function (id) {
    this.supports = this.supports.filter(function (s) { return s.id !== id; });
  };

  TrussModel.prototype.removeLoad = function (id) {
    this.loads = this.loads.filter(function (L) { return L.id !== id; });
  };

  function jointById(model, id) {
    for (var i = 0; i < model.joints.length; i++) {
      if (model.joints[i].id === id) return model.joints[i];
    }
    return null;
  }

  /**
   * Solve truss by global equilibrium of joints.
   * Unknowns: member forces (tension positive) + reaction components.
   * Returns { ok, message, memberForces: {id: N}, reactions: [{supportId, jointId, rx, ry}], jointCount, memberCount }
   */
  TrussModel.prototype.solveTruss = function () {
    var joints = this.joints;
    var members = this.members;
    var supports = this.supports;
    var loads = this.loads;

    if (joints.length < 2) {
      return { ok: false, message: "Add at least two joints.", memberForces: {}, reactions: [] };
    }
    if (members.length < 1) {
      return { ok: false, message: "Add members between joints.", memberForces: {}, reactions: [] };
    }

    // Count reaction unknowns
    var reactList = []; // { supportId, jointId, dir: 'x'|'y' }
    supports.forEach(function (s) {
      reactList.push({ supportId: s.id, jointId: s.jointId, dir: "y" });
      if (s.type === "pin") reactList.push({ supportId: s.id, jointId: s.jointId, dir: "x" });
    });

    var nEq = 2 * joints.length;
    var nUnk = members.length + reactList.length;

    if (nUnk !== nEq) {
      var hint = nUnk < nEq
        ? "Structure is unstable or a mechanism (too few members/supports)."
        : "Structure is statically indeterminate (too many members/supports for this solver).";
      return {
        ok: false,
        message: hint + " Equations " + nEq + ", unknowns " + nUnk + ".",
        memberForces: {},
        reactions: [],
        nEq: nEq,
        nUnk: nUnk
      };
    }

    // Map joint id -> row base (0, 2, 4, ...)
    var jIndex = {};
    joints.forEach(function (j, i) { jIndex[j.id] = i; });

    // Matrix A (nEq x nUnk), rhs b
    var A = zeros(nEq, nUnk);
    var b = zeros(nEq, 1);

    // Applied loads on RHS (force balance: sum F + reactions + member projections = 0
    // We write: member contributions + reactions = -applied
    loads.forEach(function (L) {
      var ji = jIndex[L.jointId];
      if (ji == null) return;
      b[2 * ji][0] -= L.fx;     // ΣFx = 0 → member+R = -Fapplied... wait
      b[2 * ji + 1][0] -= L.fy;
    });
    // Convention: equation is Σ (member axial projected) + Σ reactions + Σ applied = 0
    // So member*dir + R = -applied  → put applied on RHS as -applied already above... 
    // If ΣF = 0: mem + R + Fapp = 0 → mem + R = -Fapp. Yes.

    // Member columns: tension positive means member pulls on the joint (force on joint is toward the other joint? )
    // If member force T > 0 (tension), the member pulls joint A toward joint B, so force on A is in direction A→B.
    // Unit vector from A to B: (dx/L, dy/L). Force on A due to tension: +T * u_AB
    // Force on B due to tension: -T * u_AB
    members.forEach(function (m, mi) {
      var ja = jointById(this, m.jointA);
      var jb = jointById(this, m.jointB);
      if (!ja || !jb) return;
      var dx = jb.x - ja.x;
      var dy = jb.y - ja.y;
      var L = Math.sqrt(dx * dx + dy * dy);
      if (L < EPS) return;
      var ux = dx / L, uy = dy / L;
      var ia = jIndex[m.jointA];
      var ib = jIndex[m.jointB];
      // On joint A: +T * u
      A[2 * ia][mi] += ux;
      A[2 * ia + 1][mi] += uy;
      // On joint B: -T * u
      A[2 * ib][mi] -= ux;
      A[2 * ib + 1][mi] -= uy;
    }.bind(this));

    // Reaction columns
    reactList.forEach(function (r, ri) {
      var col = members.length + ri;
      var ji = jIndex[r.jointId];
      if (ji == null) return;
      if (r.dir === "x") A[2 * ji][col] = 1;
      else A[2 * ji + 1][col] = 1;
    });

    var x;
    try {
      x = solveLinear(A, b);
    } catch (e) {
      return {
        ok: false,
        message: "Could not solve (singular system – check supports and connectivity).",
        memberForces: {},
        reactions: []
      };
    }

    var memberForces = {};
    members.forEach(function (m, mi) {
      memberForces[m.id] = x[mi][0];
    });

    var reactions = [];
    var bySupport = {};
    reactList.forEach(function (r, ri) {
      var val = x[members.length + ri][0];
      if (!bySupport[r.supportId]) {
        bySupport[r.supportId] = { supportId: r.supportId, jointId: r.jointId, rx: 0, ry: 0 };
      }
      if (r.dir === "x") bySupport[r.supportId].rx = val;
      else bySupport[r.supportId].ry = val;
    });
    Object.keys(bySupport).forEach(function (k) { reactions.push(bySupport[k]); });

    return {
      ok: true,
      message: "Truss solved.",
      memberForces: memberForces,
      reactions: reactions,
      nEq: nEq,
      nUnk: nUnk
    };
  };

  /**
   * Simple beam: span L, pin at 0, roller at L, point loads [{x, p}] downward (p > 0 down).
   * Returns reactions Ra, Rb, and samples of shear V(x) and moment M(x).
   */
  TrussModel.solveBeam = function (span, loads, cantilever) {
    // loads: [{ x, p }] p positive downward, 0 <= x <= span
    span = Math.max(span, 1e-6);
    loads = (loads || []).slice().sort(function (a, b) { return a.x - b.x; });

    if (cantilever) {
      // Fixed at x=0, free at x=span. Reaction vertical + moment at fixed end.
      var totalP = 0, moment0 = 0;
      loads.forEach(function (L) {
        totalP += L.p;
        moment0 += L.p * L.x; // moment about fixed end (clockwise positive if y up loads down)
      });
      var Ra = totalP; // upward
      var Ma = -moment0; // resisting moment

      var samples = sampleBeam(span, loads, function (x) {
        // Shear: Ra until each load
        var V = Ra;
        loads.forEach(function (L) { if (L.x <= x + 1e-9) V -= L.p; });
        // Moment: Ma + Ra*x - sum P*(x-xi)
        var M = Ma + Ra * x;
        loads.forEach(function (L) {
          if (L.x <= x + 1e-9) M -= L.p * (x - L.x);
        });
        return { V: V, M: M };
      });

      return {
        ok: true,
        message: "Cantilever solved.",
        type: "cantilever",
        span: span,
        Ra: Ra,
        Rb: 0,
        Ma: Ma,
        samples: samples
      };
    }

    // Simply supported: pin at 0 (Ra), roller at L (Rb)
    var sumP = 0, sumPx = 0;
    loads.forEach(function (L) {
      sumP += L.p;
      sumPx += L.p * L.x;
    });
    var Rb = sumPx / span; // upward
    var Ra = sumP - Rb;

    var samples = sampleBeam(span, loads, function (x) {
      var V = Ra;
      loads.forEach(function (L) { if (L.x <= x + 1e-9) V -= L.p; });
      var M = Ra * x;
      loads.forEach(function (L) {
        if (L.x <= x + 1e-9) M -= L.p * (x - L.x);
      });
      return { V: V, M: M };
    });

    return {
      ok: true,
      message: "Simply supported beam solved.",
      type: "simple",
      span: span,
      Ra: Ra,
      Rb: Rb,
      Ma: 0,
      samples: samples
    };
  };

  function sampleBeam(span, loads, fn) {
    var pts = [0, span];
    loads.forEach(function (L) {
      pts.push(L.x);
      pts.push(Math.max(0, L.x - 1e-6));
      pts.push(Math.min(span, L.x + 1e-6));
    });
    // uniform samples too
    for (var i = 0; i <= 40; i++) pts.push(span * i / 40);
    pts = pts.filter(function (x, i, a) { return a.indexOf(x) === i; }).sort(function (a, b) { return a - b; });
    return pts.map(function (x) {
      var r = fn(x);
      return { x: x, V: r.V, M: r.M };
    });
  }

  // --- Presets (truss geometry in model units; y up) ---
  TrussModel.presets = {
    triangle: function () {
      // Simple triangle: base 0--1, apex 2. Pin at 0, roller at 1. Load down at 2.
      return {
        joints: [
          { id: "j0", x: 0, y: 0 },
          { id: "j1", x: 4, y: 0 },
          { id: "j2", x: 2, y: 3 }
        ],
        members: [
          { id: "m0", jointA: "j0", jointB: "j1" },
          { id: "m1", jointA: "j0", jointB: "j2" },
          { id: "m2", jointA: "j1", jointB: "j2" }
        ],
        supports: [
          { id: "s0", jointId: "j0", type: "pin" },
          { id: "s1", jointId: "j1", type: "roller" }
        ],
        loads: [
          { id: "L0", jointId: "j2", fx: 0, fy: -10 }
        ]
      };
    },
    roof: function () {
      // Small roof truss
      return {
        joints: [
          { id: "j0", x: 0, y: 0 },
          { id: "j1", x: 2, y: 0 },
          { id: "j2", x: 4, y: 0 },
          { id: "j3", x: 1, y: 1.5 },
          { id: "j4", x: 3, y: 1.5 }
        ],
        members: [
          { id: "m0", jointA: "j0", jointB: "j1" },
          { id: "m1", jointA: "j1", jointB: "j2" },
          { id: "m2", jointA: "j0", jointB: "j3" },
          { id: "m3", jointA: "j3", jointB: "j1" },
          { id: "m4", jointA: "j1", jointB: "j4" },
          { id: "m5", jointA: "j4", jointB: "j2" },
          { id: "m6", jointA: "j3", jointB: "j4" }
        ],
        supports: [
          { id: "s0", jointId: "j0", type: "pin" },
          { id: "s1", jointId: "j2", type: "roller" }
        ],
        loads: [
          { id: "L0", jointId: "j3", fx: 0, fy: -5 },
          { id: "L1", jointId: "j4", fx: 0, fy: -5 }
        ]
      };
    },
    bridge: function () {
      // Pratt-like short span
      return {
        joints: [
          { id: "j0", x: 0, y: 0 },
          { id: "j1", x: 2, y: 0 },
          { id: "j2", x: 4, y: 0 },
          { id: "j3", x: 6, y: 0 },
          { id: "j4", x: 2, y: 2 },
          { id: "j5", x: 4, y: 2 }
        ],
        members: [
          { id: "m0", jointA: "j0", jointB: "j1" },
          { id: "m1", jointA: "j1", jointB: "j2" },
          { id: "m2", jointA: "j2", jointB: "j3" },
          { id: "m3", jointA: "j0", jointB: "j4" },
          { id: "m4", jointA: "j4", jointB: "j5" },
          { id: "m5", jointA: "j5", jointB: "j3" },
          { id: "m6", jointA: "j1", jointB: "j4" },
          { id: "m7", jointA: "j2", jointB: "j5" },
          { id: "m8", jointA: "j1", jointB: "j5" },
          { id: "m9", jointA: "j2", jointB: "j4" }
        ],
        supports: [
          { id: "s0", jointId: "j0", type: "pin" },
          { id: "s1", jointId: "j3", type: "roller" }
        ],
        loads: [
          { id: "L0", jointId: "j1", fx: 0, fy: -8 },
          { id: "L1", jointId: "j2", fx: 0, fy: -8 }
        ]
      };
    }
  };

  TrussModel.prototype.loadPreset = function (name) {
    var p = TrussModel.presets[name];
    if (!p) return;
    var data = p();
    this.joints = data.joints.map(function (j) { return { id: j.id, x: j.x, y: j.y }; });
    this.members = data.members.map(function (m) { return { id: m.id, jointA: m.jointA, jointB: m.jointB }; });
    this.supports = data.supports.map(function (s) { return { id: s.id, jointId: s.jointId, type: s.type }; });
    this.loads = data.loads.map(function (L) { return { id: L.id, jointId: L.jointId, fx: L.fx, fy: L.fy }; });
  };

  function zeros(r, c) {
    var m = [];
    for (var i = 0; i < r; i++) {
      m[i] = [];
      for (var j = 0; j < c; j++) m[i][j] = 0;
    }
    return m;
  }

  function solveLinear(A, b) {
    var n = A.length;
    var M = [];
    for (var i = 0; i < n; i++) {
      M[i] = A[i].slice();
      M[i].push(b[i][0]);
    }
    for (var col = 0; col < n; col++) {
      var max = Math.abs(M[col][col]), piv = col;
      for (var r = col + 1; r < n; r++) {
        var v = Math.abs(M[r][col]);
        if (v > max) { max = v; piv = r; }
      }
      if (max < EPS) throw new Error("singular");
      if (piv !== col) { var t = M[col]; M[col] = M[piv]; M[piv] = t; }
      var diag = M[col][col];
      for (var r2 = col + 1; r2 < n; r2++) {
        var f = M[r2][col] / diag;
        for (var c2 = col; c2 <= n; c2++) M[r2][c2] -= f * M[col][c2];
      }
    }
    var x = zeros(n, 1);
    for (var i2 = n - 1; i2 >= 0; i2--) {
      var s = M[i2][n];
      for (var j = i2 + 1; j < n; j++) s -= M[i2][j] * x[j][0];
      if (Math.abs(M[i2][i2]) < EPS) throw new Error("singular");
      x[i2][0] = s / M[i2][i2];
    }
    return x;
  }

  if (typeof module !== "undefined" && module.exports) module.exports = TrussModel;
  global.TrussModel = TrussModel;
})(typeof window !== "undefined" ? window : global);

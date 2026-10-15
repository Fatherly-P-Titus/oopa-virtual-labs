/**
 * SMDModel – 1DOF spring-mass-damper, free & forced.
 */
(function (global) {
  "use strict";

  function SMDModel(opts) {
    opts = opts || {};
    this.m = opts.m != null ? opts.m : 1;
    this.k = opts.k != null ? opts.k : 40;
    this.c = opts.c != null ? opts.c : 2;
    this.F0 = opts.F0 != null ? opts.F0 : 0;
    this.omega = opts.omega != null ? opts.omega : 4;
    this.x = opts.x0 != null ? opts.x0 : 0.2;
    this.v = opts.v0 != null ? opts.v0 : 0;
    this.t = 0;
    this.history = []; // { t, x, v }
    this.maxHist = 800;
  }

  SMDModel.prototype.wn = function () {
    return Math.sqrt(Math.max(this.k, 1e-9) / Math.max(this.m, 1e-9));
  };

  SMDModel.prototype.zeta = function () {
    var m = Math.max(this.m, 1e-9);
    var k = Math.max(this.k, 1e-9);
    return this.c / (2 * Math.sqrt(m * k));
  };

  SMDModel.prototype.regime = function () {
    var z = this.zeta();
    if (z < 0.999) return "underdamped";
    if (z > 1.001) return "overdamped";
    return "critical";
  };

  /** Steady-state amplitude for harmonic force F0 cos(ωt) */
  SMDModel.prototype.steadyAmplitude = function () {
    var m = this.m, k = this.k, c = this.c, w = this.omega, F0 = this.F0;
    if (F0 === 0) return 0;
    var denom = Math.sqrt(Math.pow(k - m * w * w, 2) + Math.pow(c * w, 2));
    return F0 / Math.max(denom, 1e-12);
  };

  SMDModel.prototype.accel = function (x, v, t) {
    var F = this.F0 * Math.cos(this.omega * t);
    return (F - this.c * v - this.k * x) / Math.max(this.m, 1e-9);
  };

  /** RK4 step, dt in seconds */
  SMDModel.prototype.step = function (dt) {
    var x = this.x, v = this.v, t = this.t;
    var self = this;
    function a(xx, vv, tt) { return self.accel(xx, vv, tt); }

    var k1x = v;
    var k1v = a(x, v, t);

    var k2x = v + 0.5 * dt * k1v;
    var k2v = a(x + 0.5 * dt * k1x, v + 0.5 * dt * k1v, t + 0.5 * dt);

    var k3x = v + 0.5 * dt * k2v;
    var k3v = a(x + 0.5 * dt * k2x, v + 0.5 * dt * k2v, t + 0.5 * dt);

    var k4x = v + dt * k3v;
    var k4v = a(x + dt * k3x, v + dt * k3v, t + dt);

    this.x = x + (dt / 6) * (k1x + 2 * k2x + 2 * k3x + k4x);
    this.v = v + (dt / 6) * (k1v + 2 * k2v + 2 * k3v + k4v);
    this.t = t + dt;

    this.history.push({ t: this.t, x: this.x, v: this.v });
    if (this.history.length > this.maxHist) this.history.shift();
  };

  SMDModel.prototype.reset = function (x0, v0) {
    this.x = x0 != null ? x0 : 0.2;
    this.v = v0 != null ? v0 : 0;
    this.t = 0;
    this.history = [{ t: 0, x: this.x, v: this.v }];
  };

  if (typeof module !== "undefined" && module.exports) module.exports = SMDModel;
  global.SMDModel = SMDModel;
})(typeof window !== "undefined" ? window : global);

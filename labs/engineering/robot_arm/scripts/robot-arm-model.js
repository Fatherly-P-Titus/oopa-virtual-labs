/**
 * RobotArmModel – planar 2R forward / inverse kinematics.
 */
(function (global) {
  "use strict";

  function deg2rad(d) { return (d * Math.PI) / 180; }
  function rad2deg(r) { return (r * 180) / Math.PI; }

  function RobotArmModel() {
    this.L1 = 1.0;
    this.L2 = 0.75;
    this.theta1 = 40; // degrees
    this.theta2 = 50;
    this.elbowUp = true;
  }

  RobotArmModel.prototype.forward = function (t1deg, t2deg) {
    var t1 = deg2rad(t1deg != null ? t1deg : this.theta1);
    var t2 = deg2rad(t2deg != null ? t2deg : this.theta2);
    var x1 = this.L1 * Math.cos(t1);
    var y1 = this.L1 * Math.sin(t1);
    var x = x1 + this.L2 * Math.cos(t1 + t2);
    var y = y1 + this.L2 * Math.sin(t1 + t2);
    return {
      joint: { x: x1, y: y1 },
      end: { x: x, y: y },
      theta1: t1deg != null ? t1deg : this.theta1,
      theta2: t2deg != null ? t2deg : this.theta2
    };
  };

  /**
   * Inverse kinematics for target (x, y).
   * Returns { ok, theta1, theta2, alt } or { ok: false, message }.
   */
  RobotArmModel.prototype.inverse = function (x, y, elbowUp) {
    var L1 = this.L1, L2 = this.L2;
    var r2 = x * x + y * y;
    var r = Math.sqrt(r2);
    var rMax = L1 + L2;
    var rMin = Math.abs(L1 - L2);
    if (r > rMax + 1e-9 || r < rMin - 1e-9) {
      return { ok: false, message: "Target outside workspace." };
    }
    var cosT2 = (r2 - L1 * L1 - L2 * L2) / (2 * L1 * L2);
    cosT2 = Math.max(-1, Math.min(1, cosT2));
    var sinT2 = Math.sqrt(Math.max(0, 1 - cosT2 * cosT2));
    if (elbowUp === false) sinT2 = -sinT2;
    var t2 = Math.atan2(sinT2, cosT2);
    var t1 = Math.atan2(y, x) - Math.atan2(L2 * sinT2, L1 + L2 * cosT2);
    return {
      ok: true,
      theta1: rad2deg(t1),
      theta2: rad2deg(t2),
      message: "IK solved."
    };
  };

  RobotArmModel.prototype.workspace = function () {
    return {
      rMin: Math.abs(this.L1 - this.L2),
      rMax: this.L1 + this.L2
    };
  };

  if (typeof module !== "undefined" && module.exports) module.exports = RobotArmModel;
  global.RobotArmModel = RobotArmModel;
})(typeof window !== "undefined" ? window : global);

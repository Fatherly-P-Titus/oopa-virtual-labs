/**
 * Single-celled organisms model (OOPA Virtual Labs / Biology) - pure logic, no DOM.
 *
 * Agent-based: each cell has a position, heading, energy and age.
 *   Feeding      - touching a food particle gives FOOD_E energy (capped at 1.5 x divide energy).
 *   Movement     - swims along its heading; with sensing it steers to the nearest food in range,
 *                  otherwise it runs and tumbles at random. Every cell pays upkeep() energy per second.
 *   Growth       - radius follows energy (R0 when empty, R1 at the divide energy).
 *   Reproduction - at the divide energy the cell splits in two; each half keeps half the energy
 *                  (minus FISSION_COST in total) and starts again at age 0.
 *   Death        - energy reaching 0 (starved) or age reaching the lifespan (old age).
 * Time is in seconds, distances in model units. The dish is W x H with bouncing walls.
 * Loaded by the page (window.CellModel) and usable from Node.
 */
(function (root) {
  "use strict";

  var W = 800, H = 500;
  var FR = 3;                  // food particle radius
  var R0 = 5, R1 = 11;         // empty and full cell radius
  var FOOD_E = 10;             // energy in one food particle
  var FISSION_COST = 2;        // energy lost when a cell splits
  var TURN = 5;                // max steering rate toward food, rad/s
  var MAX_CELLS = 300, MAX_FOOD = 500;
  var AGE_OFF = 600;           // lifespan slider value that means "no limit"
  var FX_LIFE = 1.2;           // seconds an event ring stays visible
  var G = 40, GW = Math.ceil(W / G), GH = Math.ceil(H / G);   // food lookup grid

  function mulberry32(seed) {
    var a = seed >>> 0;
    return function () {
      a = (a + 0x6D2B79F5) >>> 0;
      var t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  /** Energy a cell spends per second (resting use plus swimming). vf is the cell's own speed factor. */
  function upkeep(p, vf) { return p.metab + 0.01 * p.speed * (vf === undefined ? 1 : vf); }
  function radius(p, E) { return R0 + (R1 - R0) * Math.min(1, Math.max(0, E / p.divide)); }
  function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }

  function newCell(s, p, x, y, E) {
    var rn = s.rng;
    return { id: s.nextId++, x: x, y: y, th: rn() * 6.2832, E: E, age: 0, vf: 0.8 + 0.4 * rn(),
             tumble: 0.5 + rn() * 2, fed: 0, target: false, r: radius(p, E) };
  }

  function addFood(s) {
    s.food.push({ x: 8 + s.rng() * (W - 16), y: 8 + s.rng() * (H - 16), dead: false });
  }

  /** Fresh dish: n0 cells with partly full energy, food0 food particles. */
  function init(p, n0, food0, seed) {
    var s = { t: 0, rng: mulberry32(seed), nextId: 1, cells: [], food: [], fx: [], grid: [],
              births: 0, starved: 0, aged: 0, eaten: 0, spawnAcc: 0, watch: 0, watchFate: "" };
    var i;
    for (i = 0; i < GW * GH; i++) s.grid.push([]);
    for (i = 0; i < n0; i++) {
      s.cells.push(newCell(s, p, 20 + s.rng() * (W - 40), 20 + s.rng() * (H - 40), p.divide * (0.4 + 0.4 * s.rng())));
    }
    for (i = 0; i < food0; i++) addFood(s);
    return s;
  }

  /** Advance the dish by dt seconds. p may be edited between calls. */
  function step(p, s, dt) {
    var rn = s.rng, grid = s.grid, food = s.food, cells = s.cells;
    var i, j, gx, gy, f, c, list;

    // food arrives at a steady average rate
    s.spawnAcc += p.foodRate * dt;
    while (s.spawnAcc >= 1) { s.spawnAcc -= 1; if (food.length < MAX_FOOD) addFood(s); }

    // bucket the food so each cell only looks at nearby particles
    for (i = 0; i < grid.length; i++) grid[i].length = 0;
    for (i = 0; i < food.length; i++) {
      f = food[i];
      grid[Math.min(GH - 1, Math.floor(f.y / G)) * GW + Math.min(GW - 1, Math.floor(f.x / G))].push(f);
    }

    var survivors = [], born = [], eatenNow = 0, limitAge = p.maxAge < AGE_OFF;
    var eatR, qR, best, bd, gx0, gx1, gy0, gy1, dx, dy, d2, diff, turn, sp, e, ang, off, ch;

    for (i = 0; i < cells.length; i++) {
      c = cells[i];

      // look for the nearest food particle
      eatR = c.r + FR;
      qR = Math.max(p.sense, eatR);
      gx0 = Math.max(0, Math.floor((c.x - qR) / G)); gx1 = Math.min(GW - 1, Math.floor((c.x + qR) / G));
      gy0 = Math.max(0, Math.floor((c.y - qR) / G)); gy1 = Math.min(GH - 1, Math.floor((c.y + qR) / G));
      best = null; bd = qR * qR;
      for (gy = gy0; gy <= gy1; gy++) {
        for (gx = gx0; gx <= gx1; gx++) {
          list = grid[gy * GW + gx];
          for (j = 0; j < list.length; j++) {
            f = list[j];
            if (f.dead) continue;
            dx = f.x - c.x; dy = f.y - c.y; d2 = dx * dx + dy * dy;
            if (d2 < bd) { bd = d2; best = f; }
          }
        }
      }

      // steer toward food it can sense, otherwise run and tumble
      c.target = false;
      if (best && p.sense > 0 && bd <= p.sense * p.sense) {
        c.target = true;
        diff = Math.atan2(best.y - c.y, best.x - c.x) - c.th;
        diff = Math.atan2(Math.sin(diff), Math.cos(diff));
        turn = TURN * dt;
        c.th += clamp(diff, -turn, turn);
      } else {
        c.tumble -= dt;
        if (c.tumble <= 0) { c.th = rn() * 6.2832; c.tumble = 0.5 - Math.log(1 - rn()) * 1.5; }
      }

      // swim, bouncing off the dish walls
      sp = p.speed * c.vf;
      c.x += Math.cos(c.th) * sp * dt;
      c.y += Math.sin(c.th) * sp * dt;
      if (c.x < c.r) { c.x = c.r; c.th = Math.PI - c.th; }
      else if (c.x > W - c.r) { c.x = W - c.r; c.th = Math.PI - c.th; }
      if (c.y < c.r) { c.y = c.r; c.th = -c.th; }
      else if (c.y > H - c.r) { c.y = H - c.r; c.th = -c.th; }

      // eat if touching the food it was heading for
      if (best && !best.dead) {
        dx = best.x - c.x; dy = best.y - c.y;
        if (dx * dx + dy * dy <= eatR * eatR) {
          best.dead = true; eatenNow++; s.eaten++;
          c.E = Math.min(c.E + FOOD_E, 1.5 * p.divide);
          c.fed = 0.6;
        }
      }

      // live: spend energy, get older, resize
      c.E -= upkeep(p, c.vf) * dt;
      c.age += dt;
      c.fed = Math.max(0, c.fed - dt);
      c.r = radius(p, c.E);

      // death
      if (c.E <= 0 || (limitAge && c.age >= p.maxAge)) {
        if (c.E <= 0) { s.starved++; s.fx.push({ x: c.x, y: c.y, t: s.t, k: "starved" }); if (c.id === s.watch) s.watchFate = "starved"; }
        else { s.aged++; s.fx.push({ x: c.x, y: c.y, t: s.t, k: "age" }); if (c.id === s.watch) s.watchFate = "age"; }
        continue;
      }

      // reproduction: binary fission into two cells that share the energy
      if (c.E >= p.divide && cells.length + born.length < MAX_CELLS) {
        e = (c.E - FISSION_COST) / 2;
        c.E = e; c.age = 0; c.r = radius(p, e);
        ch = newCell(s, p, c.x, c.y, e);
        ang = c.th + Math.PI / 2; off = c.r * 0.7;
        ch.x = clamp(c.x + Math.cos(ang) * off, ch.r, W - ch.r);
        ch.y = clamp(c.y + Math.sin(ang) * off, ch.r, H - ch.r);
        c.x = clamp(c.x - Math.cos(ang) * off, c.r, W - c.r);
        c.y = clamp(c.y - Math.sin(ang) * off, c.r, H - c.r);
        s.births++;
        s.fx.push({ x: c.x, y: c.y, t: s.t, k: "divide" });
        born.push(ch);
      }
      survivors.push(c);
    }

    s.cells = survivors.concat(born);
    if (eatenNow > 0) s.food = food.filter(function (q) { return !q.dead; });
    while (s.fx.length && s.t - s.fx[0].t > FX_LIFE) s.fx.shift();
    s.t += dt;
  }

  /** Short stage label for one cell. */
  function phase(c, p) {
    if (c.E >= 0.9 * p.divide) return "Ready to divide";
    if (c.E < 0.25 * p.divide) return "Starving";
    if (c.fed > 0) return "Feeding";
    if (c.target) return "Heading for food";
    return "Exploring";
  }

  /** Dish-wide averages for the readouts. fed is average energy as a fraction of the divide energy. */
  function summary(p, s) {
    var n = s.cells.length, sumE = 0, sumR = 0, i;
    for (i = 0; i < n; i++) { sumE += s.cells[i].E; sumR += s.cells[i].r; }
    return { n: n, food: s.food.length, fed: n ? sumE / n / p.divide : 0, size: n ? sumR / n : 0 };
  }

  function status(p, s) {
    var m = summary(p, s);
    if (!m.n) return "All cells have died. Press Reset to start again.";
    if (m.n >= MAX_CELLS) return "The dish is full, so cells cannot divide until some die.";
    if (!m.food) return "No food is left. Cells will starve.";
    if (m.fed < 0.25) return "Food is scarce. Most cells are hungry.";
    return "Cells are feeding, growing and dividing.";
  }

  var api = { W: W, H: H, FR: FR, R0: R0, R1: R1, FOOD_E: FOOD_E, MAX_CELLS: MAX_CELLS, MAX_FOOD: MAX_FOOD,
              AGE_OFF: AGE_OFF, FX_LIFE: FX_LIFE, upkeep: upkeep, init: init, step: step, phase: phase,
              summary: summary, status: status };
  if (typeof module !== "undefined" && module.exports) module.exports = api; else root.CellModel = api;
})(typeof window !== "undefined" ? window : this);

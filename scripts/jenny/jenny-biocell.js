/**
 * BioCell Sim – Lab page Jenny integration (Phase 5)
 *
 * - Sets page context to "lab" after the start menu is dismissed / sim begins
 * - Watches simulation stats for stress conditions and notifies Jenny
 * - Hooks common UI buttons for first-time tips
 */

"use strict";

(function () {
  // Wait until both Jenny and the controller/sim are available
  function whenReady(fn) {
    if (window.Jenny && window.BioCell) {
      fn();
      return;
    }
    let tries = 0;
    const t = setInterval(function () {
      tries++;
      if (window.Jenny && window.BioCell) {
        clearInterval(t);
        fn();
      } else if (tries > 50) {
        clearInterval(t);
        // Jenny alone is enough for basic page context
        if (window.Jenny) fn();
      }
    }, 100);
  }

  // ------------------------------------------------------------------
  // Contextual triggers
  // ------------------------------------------------------------------
  const LabJenny = {
    _playClicked: false,
    _collapseWarned: false,
    _stressWarned: false,
    _watchTimer: null,

    init: function () {
      // Default context – do not auto-show until user is past the start modal
      Jenny.setPage("lab", { autoShow: false });

      this._hookStartMenu();
      this._hookPlayButton();
      this._hookRuntimeActions();
      this._startStatWatch();
    },

    /** When the start modal is closed / simulation is configured, introduce the lab. */
    _hookStartMenu: function () {
      const modal = document.getElementById("start-modal");
      if (!modal) {
        // No modal – show lab tips shortly after load
        setTimeout(function () {
          Jenny.setPage("lab", { autoShow: true });
        }, 600);
        return;
      }

      // Observe class changes (modal gets .hidden when dismissed)
      const observer = new MutationObserver(function (mutations) {
        mutations.forEach(function (m) {
          if (m.attributeName === "class" && modal.classList.contains("hidden")) {
            Jenny.setPage("lab", { autoShow: true });
            observer.disconnect();
          }
        });
      });
      observer.observe(modal, { attributes: true });

      // Also catch explicit start buttons as a fallback
      ["btn-start-preset", "btn-start-custom"].forEach(function (id) {
        const btn = document.getElementById(id);
        if (btn) {
          btn.addEventListener("click", function () {
            setTimeout(function () {
              Jenny.setPage("lab", { autoShow: true });
            }, 300);
          }, { once: true });
        }
      });
    },

    /** First Play click – gentle reminder about monitoring stats. */
    _hookPlayButton: function () {
      const btn = document.getElementById("btn-play");
      if (!btn) return;

      btn.addEventListener("click", function () {
        if (LabJenny._playClicked) return;
        LabJenny._playClicked = true;
        // Soft notify – pulse FAB; user can open if they want
        if (window.Jenny) {
          Jenny.notifyNewTip("lab");
        }
      });
    },

    /** Runtime action buttons can surface caution tips the first time they are used. */
    _hookRuntimeActions: function () {
      const map = {
        "btn-temp-up": "lab-stress",
        "btn-temp-down": "lab-stress",
        "btn-ph-up": "lab-stress",
        "btn-ph-down": "lab-stress"
      };

      Object.keys(map).forEach(function (id) {
        const el = document.getElementById(id);
        if (!el) return;
        el.addEventListener("click", function () {
          if (LabJenny._stressWarned) return;
          LabJenny._stressWarned = true;
          if (window.Jenny) Jenny.notifyNewTip("lab");
        }, { once: true });
      });
    },

    /**
     * Poll lightweight stats exposed on the page / sim object.
     * If population is very low or average energy is critically low, warn once.
     */
    _startStatWatch: function () {
      this._watchTimer = setInterval(function () {
        if (LabJenny._collapseWarned) return;

        // Prefer live DOM stats (header)
        const popEl = document.getElementById("stat-pop");
        const energyEl = document.getElementById("stat-energy");
        let pop = popEl ? parseInt(popEl.textContent, 10) : NaN;
        let avgE = energyEl ? parseFloat(energyEl.textContent) : NaN;

        // Fallback: read from Simulation instance if controller exposes it
        if ((isNaN(pop) || isNaN(avgE)) && window.sim && window.sim.cells) {
          pop = window.sim.cells.length;
          if (pop > 0) {
            let sum = 0;
            window.sim.cells.forEach(function (c) { sum += c.energy; });
            avgE = sum / pop;
          } else {
            avgE = 0;
          }
        }

        // Collapse conditions
        if (!isNaN(pop) && !isNaN(avgE) && pop > 0 && (pop < 5 || avgE < 2.5)) {
          LabJenny._collapseWarned = true;
          if (window.Jenny) {
            // Jump to the population-collapse warning if still available
            const convo = Jenny.getConvo("lab");
            const idx = convo.findIndex(function (m) { return m.id === "lab-collapse"; });
            if (idx >= 0 && !Jenny._isDismissed(convo[idx])) {
              Jenny.show("lab", idx);
            } else {
              Jenny.notifyNewTip("lab");
            }
          }
        }
      }, 4000);
    }
  };

  whenReady(function () {
    LabJenny.init();
  });

  // Expose for debugging
  window.LabJenny = LabJenny;
})();

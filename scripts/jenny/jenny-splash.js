/**
 * OOPA Virtual Labs – Welcome Splash Controller
 *
 * Shows a full-viewport intro on first visit.
 * Preference "don't show again" is stored in localStorage.
 * Can also be forced open for demos / settings.
 */

"use strict";

(function (global) {
  const STORAGE_KEY = "jenny_splash_seen";           // localStorage: opted out for good
  const SESSION_KEY = "jenny_splash_session";        // sessionStorage: already shown this visit

  function ssGet(key) {
    try { return sessionStorage.getItem(key); } catch (_) { return null; }
  }
  function ssSet(key, val) {
    try { sessionStorage.setItem(key, val); } catch (_) { /* private mode */ }
  }

  function lsGet(key) {
    try { return localStorage.getItem(key); } catch (_) { return null; }
  }
  function lsSet(key, val) {
    try { localStorage.setItem(key, val); } catch (_) { /* private mode */ }
  }

  const Splash = {
    $root: null,
    $primary: null,
    $skip: null,
    $remember: null,
    isOpen: false,
    _onContinue: null,   // callback supplied by host

    /**
     * Initialise DOM refs and wire buttons.
     * Call once after the splash markup is in the document.
     */
    init: function () {
      this.$root = document.getElementById("jenny-splash");
      if (!this.$root) {
        console.warn("[Splash] #jenny-splash not found.");
        return;
      }

      this.$primary = document.getElementById("splash-continue");
      this.$skip = document.getElementById("splash-skip");
      this.$remember = document.getElementById("splash-remember");

      if (this.$primary) {
        this.$primary.addEventListener("click", () => this._continue(false));
      }
      if (this.$skip) {
        this.$skip.addEventListener("click", () => this._continue(true));
      }

      // Escape closes (treated as skip for this session only)
      document.addEventListener("keydown", (e) => {
        if (!this.isOpen) return;
        if (e.key === "Escape") {
          e.preventDefault();
          this._continue(true);
        } else if (e.key === "Tab") {
          // keep keyboard focus inside the modal splash
          const f = Array.prototype.filter.call(
            this.$root.querySelectorAll("button, input, a[href]"),
            (el) => !el.disabled && el.offsetParent !== null
          );
          if (!f.length) return;
          const first = f[0], last = f[f.length - 1];
          if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
          else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
          else if (!this.$root.contains(document.activeElement)) { e.preventDefault(); first.focus(); }
        }
      });
    },

    /**
     * Whether the user has opted out of the splash permanently.
     */
    hasSeen: function () {
      return lsGet(STORAGE_KEY) === "1";
    },

    /**
     * Show the splash.
     * @param {object} [opts]
     * @param {boolean} [opts.force=false] - show even if already seen
     * @param {function} [opts.onContinue] - called after close (arg: { skipped })
     */
    show: function (opts) {
      opts = opts || {};
      if (!this.$root) return;

      if (!opts.force && this.hasSeen()) {
        // User previously chose "don't show again"
        if (typeof opts.onContinue === "function") {
          opts.onContinue({ skipped: true, alreadySeen: true });
        }
        return;
      }

      this._onContinue = typeof opts.onContinue === "function" ? opts.onContinue : null;

      // Reset checkbox
      if (this.$remember) this.$remember.checked = false;

      this._opener = document.activeElement;
      this.$root.classList.remove("closing");
      this.$root.classList.add("visible");
      this.isOpen = true;
      ssSet(SESSION_KEY, "1");
      document.body.classList.add("splash-open");

      // Focus primary CTA
      if (this.$primary) {
        setTimeout(() => this.$primary.focus(), 40);
      }
    },

    /**
     * Attempt to show only on first visit (respects "don't show again").
     * Convenience wrapper used by host pages on load.
     */
    showIfFirstVisit: function (opts) {
      opts = opts || {};
      // Skip if opted out permanently, or already shown earlier in this browser session
      if (this.hasSeen() || ssGet(SESSION_KEY) === "1") {
        if (typeof opts.onContinue === "function") {
          opts.onContinue({ skipped: true, alreadySeen: true });
        }
        return;
      }
      this.show(opts);
    },

    hide: function () {
      if (!this.$root || !this.isOpen) return;

      this.$root.classList.add("closing");
      this.isOpen = false;
      document.body.classList.remove("splash-open");

      const root = this.$root;
      let finished = false;
      const done = (ev) => {
        if (ev && ev.target && ev.target !== root) return; // ignore bubbled child transitions
        if (finished) return;
        finished = true;
        root.classList.remove("visible", "closing");
        root.removeEventListener("transitionend", done);
        const op = this._opener; this._opener = null;
        if (op && typeof op.focus === "function" && document.contains(op)) { try { op.focus(); } catch (_) { /* gone */ } }
      };

      // Fallback if no transition
      const prefersReduced =
        window.matchMedia &&
        window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      if (prefersReduced) {
        done();
      } else {
        root.addEventListener("transitionend", done);
        setTimeout(done, 450); // safety
      }
    },

    /**
     * Clear the "don't show again" preference (settings / debug).
     */
    reset: function () {
      try { localStorage.removeItem(STORAGE_KEY); } catch (_) { /* ignore */ }
      try { sessionStorage.removeItem(SESSION_KEY); } catch (_) { /* ignore */ }
    },

    // ------------------------------------------------------------------
    _continue: function (skipped) {
      // Persist preference if checkbox checked (or if they used primary with it on)
      if (this.$remember && this.$remember.checked) {
        lsSet(STORAGE_KEY, "1");
      }

      this.hide();

      const cb = this._onContinue;
      this._onContinue = null;
      if (cb) {
        // small delay so the fade can start
        setTimeout(() => cb({ skipped: !!skipped, alreadySeen: false }), 50);
      }
    }
  };

  // Auto-init when DOM ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => Splash.init());
  } else {
    Splash.init();
  }

  global.JennySplash = Splash;
})(typeof window !== "undefined" ? window : this);

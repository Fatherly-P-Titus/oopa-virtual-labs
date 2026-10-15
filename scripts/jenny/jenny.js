/**
 * OOPA Virtual Labs – Jenny Agu Dialog Controller
 * Phase 1: Foundation
 * Phase 2: Sequences, typewriter, type styling, ARIA
 * Phase 3: Persistence, auto-show, dismiss-forever, FAB badge/pulse
 */

"use strict";

(function (global) {
  const TEXTS = global.JENNY_TEXTS || {};

  const PREFERS_REDUCED_MOTION =
    typeof window !== "undefined" &&
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Storage keys
  const SK = {
    OPEN: "jenny_is_open",           // session: was dialog open?
    SEEN_PAGES: "jenny_seen_pages",  // session: pages auto-shown this session
    DISMISSED: "jenny_dismissed",    // local: message ids user permanently dismissed
    BADGE: "jenny_badge_pages"       // session: pages that still have unseen tips
  };

  // ------------------------------------------------------------------
  // Storage helpers (safe – never throw)
  // ------------------------------------------------------------------
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

  function loadJSON(getter, key, fallback) {
    try {
      const raw = getter(key);
      if (raw) return JSON.parse(raw);
    } catch (_) { /* corrupt */ }
    return fallback;
  }

  function saveJSON(setter, key, obj) {
    try { setter(key, JSON.stringify(obj)); } catch (_) { /* ignore */ }
  }

  // ------------------------------------------------------------------
  // Jenny controller
  // ------------------------------------------------------------------
  const Jenny = {
    currentPage: null,
    currentIndex: 0,
    isOpen: false,
    isTyping: false,
    autoShowEnabled: true,   // can be turned off by host page
    defaultPage: "welcome",  // used by toggle() before any page is set
    _notice: null,           // page name while the "all tips hidden" notice is showing
    _avatars: { idle: "", speaking: "" },
    _typeTimer: null,
    _lastFocused: null,
    _dismissed: {},          // { messageId: true }
    _seenPages: {},          // { pageName: true } this session
    _badgePages: {},         // { pageName: true } has unseen tips

    // DOM
    $dialog: null,
    $textBox: null,
    $title: null,
    $body: null,
    $fab: null,
    $progress: null,
    $typeIcon: null,
    $dontShow: null,
    $avatar: null,

    // ------------------------------------------------------------------
    // Init
    // ------------------------------------------------------------------
    init: function () {
      this.$dialog = document.getElementById("dialog-box");
      this.$textBox = document.getElementById("text-box");
      this.$fab = document.getElementById("jenny-fab");
      this.$avatar = document.getElementById("avatar");

      if (!this.$dialog || !this.$textBox) {
        console.warn("[Jenny] Dialog elements not found in DOM.");
        return;
      }

      // Build internal structure if missing
      if (!this.$textBox.querySelector(".jenny-title")) {
        this.$textBox.innerHTML =
          '<div class="jenny-header">' +
          '  <span class="jenny-type-icon" aria-hidden="true"></span>' +
          '  <p class="jenny-title" id="jenny-title"></p>' +
          '  <span class="jenny-progress" aria-hidden="true"></span>' +
          "</div>" +
          '<p class="jenny-text" id="jenny-body"></p>' +
          '<div class="jenny-controls">' +
          '  <button type="button" id="jenny-prev" hidden aria-label="Previous message">Back</button>' +
          '  <button type="button" id="jenny-next" hidden aria-label="Next message">Next</button>' +
          '  <label class="jenny-dont-show" id="jenny-dont-show-label">' +
          '    <input type="checkbox" id="jenny-dont-show" />' +
          '    <span>Don\'t show again</span>' +
          '  </label>' +
          '  <button type="button" id="jenny-dismiss" aria-label="Dismiss guide">Dismiss</button>' +
          "</div>";
      }

      this.$title = this.$textBox.querySelector(".jenny-title");
      this.$body = this.$textBox.querySelector(".jenny-text");
      this.$progress = this.$textBox.querySelector(".jenny-progress");
      this.$typeIcon = this.$textBox.querySelector(".jenny-type-icon");
      this.$dontShow = document.getElementById("jenny-dont-show");

      // ARIA
      this.$dialog.setAttribute("role", "dialog");
      this.$dialog.setAttribute("aria-modal", "false");
      this.$dialog.setAttribute("aria-labelledby", "jenny-title");
      this.$dialog.setAttribute("aria-describedby", "jenny-body");
      this.$dialog.setAttribute("aria-live", "polite");

      // Load persistence
      this._dismissed = loadJSON(lsGet, SK.DISMISSED, {});
      this._seenPages = loadJSON(ssGet, SK.SEEN_PAGES, {});
      this._badgePages = loadJSON(ssGet, SK.BADGE, {});

      // FAB
      if (this.$fab) {
        this.$fab.addEventListener("click", () => this.toggle());
        this.$fab.setAttribute("aria-expanded", "false");
        this.$fab.setAttribute("aria-controls", "dialog-box");
        // Ensure badge element exists
        if (!this.$fab.querySelector(".jenny-badge")) {
          const badge = document.createElement("span");
          badge.className = "jenny-badge";
          badge.setAttribute("aria-hidden", "true");
          this.$fab.appendChild(badge);
        }
        this._refreshBadge();
      }

      // Controls
      const dismissBtn = document.getElementById("jenny-dismiss");
      if (dismissBtn) {
        dismissBtn.addEventListener("click", () => {
          this._handleDismissClick();
        });
      }

      const nextBtn = document.getElementById("jenny-next");
      if (nextBtn) nextBtn.addEventListener("click", () => this.next());

      const prevBtn = document.getElementById("jenny-prev");
      if (prevBtn) prevBtn.addEventListener("click", () => this.prev());

      // Keyboard
      document.addEventListener("keydown", (e) => {
        if (!this.isOpen) return;
        if (e.key === "Escape") {
          e.preventDefault();
          this._handleDismissClick();
        } else if (e.key === "ArrowRight" || e.key === "Enter") {
          // Enter on a focused button/checkbox is that control's own job
          const ae = document.activeElement;
          if (e.key === "Enter" && ae && (ae.tagName === "BUTTON" || ae.tagName === "INPUT" || ae.tagName === "A")) return;
          if (e.key === "ArrowRight" && ae && ae.tagName === "INPUT" && ae.type !== "checkbox") return;
          const next = document.getElementById("jenny-next");
          if (next && !next.hidden) {
            e.preventDefault();
            this.next();
          }
        } else if (e.key === "ArrowLeft") {
          const prev = document.getElementById("jenny-prev");
          if (prev && !prev.hidden) {
            e.preventDefault();
            this.prev();
          }
        }
      });

      // Restore open state from this session (optional – only if host wants it)
      // Disabled by default so pages control when Jenny appears.
    },

    /**
     * Host configuration.
     * @param {object} cfg
     * @param {string} [cfg.avatarIdle]     image shown while Jenny is idle
     * @param {string} [cfg.avatarSpeaking] image shown while text is typing
     * @param {string} [cfg.defaultPage]    page used when toggled before setPage()
     */
    configure: function (cfg) {
      cfg = cfg || {};
      if (cfg.avatarIdle) this._avatars.idle = cfg.avatarIdle;
      if (cfg.avatarSpeaking) this._avatars.speaking = cfg.avatarSpeaking;
      if (cfg.defaultPage) this.defaultPage = cfg.defaultPage;
      if (this._avatars.speaking) { try { new Image().src = this._avatars.speaking; } catch (_) { /* ignore */ } }
      this._setAvatar(false);
    },

    _setAvatar: function (speaking) {
      if (!this.$avatar) return;
      const src = speaking && this._avatars.speaking ? this._avatars.speaking : this._avatars.idle;
      if (src && this.$avatar.getAttribute("src") !== src) this.$avatar.setAttribute("src", src);
    },

    // ------------------------------------------------------------------
    // Page context
    // ------------------------------------------------------------------
    /**
     * Set page context.
     * @param {string} pageName
     * @param {boolean|object} [opts] - true = autoShow, or { autoShow, force }
     */
    setPage: function (pageName, opts) {
      const prev = this.currentPage;
      this.currentPage = pageName;
      this.currentIndex = 0;

      if (typeof this.onPageChange === "function" && prev !== pageName) {
        this.onPageChange(pageName, prev);
      }

      // Normalise opts
      let autoShow = false;
      let force = false;
      if (opts === true) {
        autoShow = true;
      } else if (opts && typeof opts === "object") {
        autoShow = !!opts.autoShow;
        force = !!opts.force;
      }

      // Determine if we should auto-show
      if (this.autoShowEnabled && autoShow) {
        const alreadySeen = this._seenPages[pageName];
        const hasVisible = this._firstVisibleIndex(pageName) !== -1;

        if (hasVisible && (force || !alreadySeen)) {
          this._seenPages[pageName] = true;
          saveJSON(ssSet, SK.SEEN_PAGES, this._seenPages);
          // Clear badge for this page – user is seeing the tips
          delete this._badgePages[pageName];
          saveJSON(ssSet, SK.BADGE, this._badgePages);
          this._refreshBadge();
          this.show(pageName, this._firstVisibleIndex(pageName));
          return;
        }
      }

      // Even without auto-show, mark badge if there are unseen messages
      this._updateBadgeForPage(pageName);
    },

    getConvo: function (pageName) {
      const page = TEXTS[pageName || this.currentPage];
      return page && Array.isArray(page.page_convo) ? page.page_convo : [];
    },

    getMessageCount: function (pageName) {
      return this.getConvo(pageName).length;
    },

    /** Return only messages the user has not permanently dismissed. */
    getVisibleConvo: function (pageName) {
      return this.getConvo(pageName).filter((m) => {
        const id = m.id || null;
        return !id || !this._dismissed[id];
      });
    },

    // ------------------------------------------------------------------
    // Show / sequence
    // ------------------------------------------------------------------
    show: function (pageName, index, opts) {
      if (!this.$dialog) return;
      pageName = pageName || this.currentPage || this.defaultPage;
      index = typeof index === "number" ? index : 0;
      opts = opts || {};
      this._notice = null;
      const animate = opts.animate !== false && !PREFERS_REDUCED_MOTION;

      // Work with full convo for index mapping, but skip dismissed
      const full = this.getConvo(pageName);
      if (!full.length) {
        console.warn("[Jenny] No messages for page:", pageName);
        return;
      }

      // Find a non-dismissed message at or after index
      let resolved = index;
      while (resolved < full.length && this._isDismissed(full[resolved])) {
        resolved++;
      }
      if (resolved >= full.length) {
        // Nothing left to show on this page
        this.hide();
        return;
      }

      const item = full[resolved];
      this.currentPage = pageName;
      this.currentIndex = resolved;

      // Type styling
      this.$dialog.classList.remove("type-info", "type-caution", "type-warning");
      const type = item.type || "info";
      this.$dialog.classList.add("type-" + type);

      if (this.$typeIcon) {
        this.$typeIcon.textContent = this._iconForType(type);
        this.$typeIcon.className = "jenny-type-icon icon-" + type;
      }

      // Progress among *visible* messages
      const visible = this.getVisibleConvo(pageName);
      const visIndex = visible.findIndex((m) => m === item || (m.id && m.id === item.id));
      if (this.$progress) {
        this.$progress.textContent =
          visible.length > 1 && visIndex >= 0
            ? visIndex + 1 + " / " + visible.length
            : "";
      }

      this.$title.textContent = item.title || "";

      // Typewriter
      this._stopTyping();
      if (animate) {
        this._typeText(item.text || "");
      } else {
        this.$body.textContent = item.text || "";
        this.$body.classList.remove("typing");
        this._setAvatar(false);
      }

      // Don't-show checkbox – reset each message
      if (this.$dontShow) {
        this.$dontShow.checked = false;
        // Only show the option when the message has a stable id
        const label = document.getElementById("jenny-dont-show-label");
        if (label) {
          label.hidden = !item.id;
        }
      }

      this._updateControls(resolved, full.length, pageName);

      // Open
      const wasOpen = this.isOpen;
      this.$dialog.classList.add("visible");
      this._markOpen(true);
      if (this.$fab) {
        this.$fab.classList.add("active");
        this.$fab.setAttribute("aria-expanded", "true");
      }
      this.isOpen = true;
      ssSet(SK.OPEN, "1");

      // Clear badge for this page
      if (this._badgePages[pageName]) {
        delete this._badgePages[pageName];
        saveJSON(ssSet, SK.BADGE, this._badgePages);
        this._refreshBadge();
      }

      if (!wasOpen) {
        this._lastFocused = document.activeElement;
        const nextBtn = document.getElementById("jenny-next");
        const dismissBtn = document.getElementById("jenny-dismiss");
        const focusTarget = nextBtn && !nextBtn.hidden ? nextBtn : dismissBtn;
        if (focusTarget) setTimeout(() => focusTarget.focus(), 30);
      }
    },

    next: function () {
      if (this._notice) {
        const page = this._notice;
        this.restorePage(page);
        this.show(page, 0);
        return;
      }
      if (this.isTyping) {
        this._finishTyping();
        return;
      }
      // Persist don't-show for current before advancing
      this._applyDontShowIfChecked();

      const full = this.getConvo();
      let nextIdx = this.currentIndex + 1;
      while (nextIdx < full.length && this._isDismissed(full[nextIdx])) {
        nextIdx++;
      }
      if (nextIdx < full.length) {
        this.show(this.currentPage, nextIdx);
      } else {
        this.hide();
      }
    },

    prev: function () {
      if (this._notice) return;
      if (this.isTyping) {
        this._finishTyping();
        return;
      }
      const full = this.getConvo();
      let prevIdx = this.currentIndex - 1;
      while (prevIdx >= 0 && this._isDismissed(full[prevIdx])) {
        prevIdx--;
      }
      if (prevIdx >= 0) {
        this.show(this.currentPage, prevIdx);
      }
    },

    hide: function () {
      if (!this.$dialog) return;
      this._stopTyping();
      this._notice = null;
      this.$dialog.classList.remove("visible");
      this._markOpen(false);
      if (this.$fab) {
        this.$fab.classList.remove("active");
        this.$fab.setAttribute("aria-expanded", "false");
      }
      this.isOpen = false;
      ssSet(SK.OPEN, "0");

      if (this._lastFocused && typeof this._lastFocused.focus === "function") {
        try { this._lastFocused.focus(); } catch (_) { /* gone */ }
      }
      this._lastFocused = null;
    },

    toggle: function () {
      if (this.isOpen) {
        this.hide();
        return;
      }
      const page = this.currentPage || this.defaultPage;
      const start = this._firstVisibleIndex(page);
      if (start === -1) {
        // User hid every tip on this page – say so instead of doing nothing
        this._showAllHiddenNotice(page);
      } else {
        this.show(page, start);
      }
    },

    _markOpen: function (open) {
      document.body.classList.toggle("jenny-open", open);
      document.documentElement.classList.toggle("jenny-open", open);
    },

    /** Notice shown when the FAB is pressed but every tip was dismissed. */
    _showAllHiddenNotice: function (pageName) {
      if (!this.$dialog) return;
      this._stopTyping();
      this._notice = pageName;
      this.currentPage = pageName;
      this.$dialog.classList.remove("type-info", "type-caution", "type-warning");
      this.$dialog.classList.add("type-info");
      if (this.$typeIcon) {
        this.$typeIcon.textContent = this._iconForType("info");
        this.$typeIcon.className = "jenny-type-icon icon-info";
      }
      if (this.$progress) this.$progress.textContent = "";
      this.$title.textContent = "Tips Hidden";
      this.$body.classList.remove("typing");
      this.$body.textContent = "You chose to hide every tip on this page. Select Restore tips if you would like to see them again.";
      const label = document.getElementById("jenny-dont-show-label");
      if (label) label.hidden = true;
      const nextBtn = document.getElementById("jenny-next");
      const prevBtn = document.getElementById("jenny-prev");
      if (nextBtn) { nextBtn.hidden = false; nextBtn.textContent = "Restore tips"; }
      if (prevBtn) prevBtn.hidden = true;
      this._setAvatar(false);
      this._lastFocused = document.activeElement;
      this.$dialog.classList.add("visible");
      this._markOpen(true);
      if (this.$fab) { this.$fab.classList.add("active"); this.$fab.setAttribute("aria-expanded", "true"); }
      this.isOpen = true;
    },

    /** Un-dismiss every message of one page (public API). */
    restorePage: function (pageName) {
      pageName = pageName || this.currentPage;
      this.getConvo(pageName).forEach((m) => { if (m.id) delete this._dismissed[m.id]; });
      saveJSON(lsSet, SK.DISMISSED, this._dismissed);
    },

    // ------------------------------------------------------------------
    // Dismiss / don't-show
    // ------------------------------------------------------------------
    _handleDismissClick: function () {
      this._applyDontShowIfChecked();
      this.hide();
    },

    _applyDontShowIfChecked: function () {
      if (!this.$dontShow || !this.$dontShow.checked) return;
      const full = this.getConvo();
      const item = full[this.currentIndex];
      if (item && item.id) {
        this._dismissed[item.id] = true;
        saveJSON(lsSet, SK.DISMISSED, this._dismissed);
      }
    },

    _isDismissed: function (item) {
      return !!(item && item.id && this._dismissed[item.id]);
    },

    _firstVisibleIndex: function (pageName) {
      const full = this.getConvo(pageName);
      for (let i = 0; i < full.length; i++) {
        if (!this._isDismissed(full[i])) return i;
      }
      return -1;
    },

    /**
     * Permanently dismiss a message by id (public API).
     * @param {string} messageId
     */
    dismissMessage: function (messageId) {
      if (!messageId) return;
      this._dismissed[messageId] = true;
      saveJSON(lsSet, SK.DISMISSED, this._dismissed);
    },

    /**
     * Clear all permanent dismissals (for settings / debug).
     */
    resetDismissals: function () {
      this._dismissed = {};
      saveJSON(lsSet, SK.DISMISSED, {});
      this._refreshBadge();
    },

    /**
     * Clear session seen-pages and badges (for settings / debug).
     */
    resetSession: function () {
      this._seenPages = {};
      this._badgePages = {};
      saveJSON(ssSet, SK.SEEN_PAGES, {});
      saveJSON(ssSet, SK.BADGE, {});
      this._refreshBadge();
    },

    // ------------------------------------------------------------------
    // Badge / pulse
    // ------------------------------------------------------------------
    _updateBadgeForPage: function (pageName) {
      const hasVisible = this._firstVisibleIndex(pageName) !== -1;
      const alreadySeen = this._seenPages[pageName];
      if (hasVisible && !alreadySeen) {
        this._badgePages[pageName] = true;
      } else {
        delete this._badgePages[pageName];
      }
      saveJSON(ssSet, SK.BADGE, this._badgePages);
      this._refreshBadge();
    },

    /**
     * Manually flag a page as having a new tip (e.g. after a sim event).
     * Causes the FAB to pulse until the user opens Jenny on that page.
     */
    notifyNewTip: function (pageName) {
      pageName = pageName || this.currentPage;
      if (!pageName) return;
      // Only if there is something visible to show
      if (this._firstVisibleIndex(pageName) === -1) return;
      this._badgePages[pageName] = true;
      // Allow auto-show again for this page if desired later
      delete this._seenPages[pageName];
      saveJSON(ssSet, SK.BADGE, this._badgePages);
      saveJSON(ssSet, SK.SEEN_PAGES, this._seenPages);
      this._refreshBadge();
    },

    _refreshBadge: function () {
      if (!this.$fab) return;
      const badge = this.$fab.querySelector(".jenny-badge");
      const hasBadge = Object.keys(this._badgePages).length > 0;
      if (hasBadge) {
        this.$fab.classList.add("has-badge");
        if (badge) badge.hidden = false;
      } else {
        this.$fab.classList.remove("has-badge");
        if (badge) badge.hidden = true;
      }
    },

    // ------------------------------------------------------------------
    // Typewriter
    // ------------------------------------------------------------------
    _typeText: function (fullText) {
      this.isTyping = true;
      this._setAvatar(true);
      this.$body.textContent = "";
      this.$body.classList.add("typing");
      let i = 0;
      const speed = 14;
      const step = () => {
        if (i < fullText.length) {
          const chunk = fullText.slice(i, i + 2);
          this.$body.textContent += chunk;
          i += chunk.length;
          this._typeTimer = setTimeout(step, speed);
        } else {
          this._finishTyping();
        }
      };
      step();
    },

    _finishTyping: function () {
      this._stopTyping();
      const full = this.getConvo();
      const item = full[this.currentIndex];
      if (item) this.$body.textContent = item.text || "";
      this.$body.classList.remove("typing");
      this.isTyping = false;
      this._setAvatar(false);
    },

    _stopTyping: function () {
      if (this._typeTimer) {
        clearTimeout(this._typeTimer);
        this._typeTimer = null;
      }
      this.isTyping = false;
      this._setAvatar(false);
    },

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    _iconForType: function (type) {
      switch (type) {
        case "caution": return "\u26A0";
        case "warning": return "!";
        default: return "i";
      }
    },

    _updateControls: function (index, total, pageName) {
      const full = this.getConvo(pageName);
      const nextBtn = document.getElementById("jenny-next");
      const prevBtn = document.getElementById("jenny-prev");

      // Is there a later non-dismissed message?
      let hasNext = false;
      for (let i = index + 1; i < full.length; i++) {
        if (!this._isDismissed(full[i])) { hasNext = true; break; }
      }
      // Is there an earlier non-dismissed message?
      let hasPrev = false;
      for (let i = index - 1; i >= 0; i--) {
        if (!this._isDismissed(full[i])) { hasPrev = true; break; }
      }

      if (nextBtn) {
        nextBtn.hidden = !hasNext;
        nextBtn.textContent = hasNext ? "Next" : "Done";
      }
      if (prevBtn) {
        prevBtn.hidden = !hasPrev;
      }
    }
  };

  // Auto-init
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => Jenny.init());
  } else {
    Jenny.init();
  }

  global.Jenny = Jenny;
})(typeof window !== "undefined" ? window : this);

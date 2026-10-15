/**
 * OOPA Virtual Labs – Jenny Agu loader
 *
 * One tag per page integrates Jenny; no markup or path juggling needed:
 *
 *   <script defer src="scripts/jenny/jenny-loader.js"
 *           data-page="main-menu" data-splash></script>
 *
 * (use "../scripts/jenny/jenny-loader.js" from pages inside /labs)
 *
 * Attributes
 *   data-page      key in JENNY_TEXTS (default "welcome")
 *   data-splash    show the welcome splash (first visit / once per session)
 *   data-autoshow  "false" = only pulse the button, don't open on load
 *   data-extras    comma list of optional modules, e.g. "biocell"
 *
 * Buttons anywhere on the page can use:
 *   data-jenny-action="replay-intro"   re-open the welcome splash
 *   data-jenny-action="toggle"         open / close Jenny
 *
 * All asset URLs are resolved from this script's own location, so the
 * same tag works from the root and from sub-folders.
 */
(function () {
  "use strict";

  var tag = document.currentScript;
  if (!tag || !tag.src) return;
  if (window.__jennyLoaded) return;
  window.__jennyLoaded = true;

  var ROOT = new URL("../../", tag.src).href;           // project root
  var PAGE = tag.getAttribute("data-page") || "welcome";
  var AUTOSHOW = tag.getAttribute("data-autoshow") !== "false";
  var EXTRAS = (tag.getAttribute("data-extras") || "").split(",").map(function (s) { return s.trim(); }).filter(Boolean);
  var IMG = {
    idle: ROOT + "assets/jenny/jenny-lab.jpg",
    speaking: ROOT + "assets/jenny/jenny-speaking.jpg",
    banner: ROOT + "assets/jenny/oopa-splash-banner.jpg"
  };

  /** Resolves when the stylesheet has loaded (or failed), so markup never shows unstyled. */
  function addCSS(path) {
    return new Promise(function (resolve) {
      var l = document.createElement("link");
      l.rel = "stylesheet";
      l.href = ROOT + path;
      l.onload = l.onerror = function () { resolve(); };
      document.head.appendChild(l);
    });
  }

  function loadScript(path) {
    return new Promise(function (resolve, reject) {
      var s = document.createElement("script");
      s.src = ROOT + path;
      s.async = false;
      s.onload = resolve;
      s.onerror = function () { reject(new Error("Could not load " + path)); };
      document.head.appendChild(s);
    });
  }

  function el(name, attrs, children) {
    var n = document.createElement(name);
    Object.keys(attrs || {}).forEach(function (k) { n.setAttribute(k, attrs[k]); });
    (children || []).forEach(function (c) { n.appendChild(typeof c === "string" ? document.createTextNode(c) : c); });
    return n;
  }

  /** <img> that swaps to a letter if the file is missing. */
  function avatarImg(src, attrs, fallbackText) {
    var img = el("img", Object.assign({ src: src }, attrs));
    img.addEventListener("error", function () {
      var parent = img.parentElement;
      img.remove();
      if (parent) parent.appendChild(el("span", { "class": "fab-fallback", "aria-hidden": "true" }, [fallbackText]));
    });
    return img;
  }

  function buildDialogAndFab() {
    var dialog = el("div", { id: "dialog-box", role: "dialog", "aria-modal": "false", "aria-labelledby": "jenny-title", "aria-describedby": "jenny-body", "aria-live": "polite" }, [
      el("div", { id: "avatar-box" }, [avatarImg(IMG.idle, { id: "avatar", alt: "Jenny Agu" }, "J")]),
      el("div", { id: "text-box" })
    ]);
    var fab = el("button", { type: "button", id: "jenny-fab", title: "Ask Jenny Agu", "aria-label": "Open or close Jenny Agu guide", "aria-controls": "dialog-box", "aria-expanded": "false" }, [
      avatarImg(IMG.idle, { alt: "" }, "J")
    ]);
    document.body.appendChild(dialog);
    document.body.appendChild(fab);
  }

  function buildSplash() {
    if (document.getElementById("jenny-splash")) return;
    var root = el("div", { id: "jenny-splash", role: "dialog", "aria-modal": "true", "aria-labelledby": "splash-heading", "aria-describedby": "splash-desc" });
    var card = el("div", { "class": "splash-card" });

    var banner = el("div", { "class": "splash-banner" }, [
      el("img", { src: IMG.banner, alt: "OOPA Virtual Labs: Explore, Experiment, Discover" })
    ]);
    var h1 = el("h1", { id: "splash-heading" }, ["Welcome to OOPA ", el("span", {}, ["Virtual Labs"])]);
    var brand = el("div", { "class": "splash-brand" }, [h1, el("p", { "class": "splash-tagline" }, ["Explore \u2022 Experiment \u2022 Discover"])]);

    var mini = el("div", { "class": "mini-avatar" }, [avatarImg(IMG.idle, { alt: "" }, "J")]);
    var jennyLine = el("div", { "class": "splash-jenny-line" }, [
      mini,
      el("p", {}, ["I am ", el("strong", {}, ["Jenny Agu"]), ", your on-screen guide. I will offer short tips on every page. Open or close me at any time with the button in the lower-right corner."])
    ]);
    var body = el("div", { "class": "splash-body", id: "splash-desc" }, [
      el("p", {}, ["Step into interactive virtual laboratories in physics, chemistry, biology, mathematics and engineering. Change variables, observe outcomes and learn by doing."]),
      jennyLine
    ]);
    var actions = el("div", { "class": "splash-actions" }, [
      el("button", { type: "button", "class": "btn-splash-primary", id: "splash-continue" }, ["Explore the Laboratories"]),
      el("button", { type: "button", "class": "btn-splash-skip", id: "splash-skip" }, ["Skip intro"])
    ]);
    var remember = el("label", { "class": "splash-remember" }, [
      el("input", { type: "checkbox", id: "splash-remember" }),
      el("span", {}, ["Don\u2019t show this intro again"])
    ]);

    [banner, brand, body, actions, remember].forEach(function (n) { card.appendChild(n); });
    root.appendChild(card);
    document.body.appendChild(root);
  }

  function boot(needSplash) {
    Jenny.configure({ avatarIdle: IMG.idle, avatarSpeaking: IMG.speaking, defaultPage: PAGE });

    function start() { Jenny.setPage(PAGE, { autoShow: AUTOSHOW }); }

    if (needSplash && window.JennySplash && tag.hasAttribute("data-splash")) {
      JennySplash.showIfFirstVisit({ onContinue: start });
    } else {
      start();
    }

    document.addEventListener("click", function (e) {
      var t = e.target.closest ? e.target.closest("[data-jenny-action]") : null;
      if (!t) return;
      var action = t.getAttribute("data-jenny-action");
      if (action === "replay-intro" && window.JennySplash) { e.preventDefault(); JennySplash.show({ force: true }); }
      else if (action === "toggle") { e.preventDefault(); Jenny.toggle(); }
    });
  }

  function run() {
    var needSplash = tag.hasAttribute("data-splash") || !!document.querySelector('[data-jenny-action="replay-intro"]');

    var css = [addCSS("styles/jenny.css")];
    if (needSplash) css.push(addCSS("styles/jenny-splash.css"));

    // Order matters: styles -> markup -> scripts (the engine self-initialises on load
    // and needs its markup already in the page).
    return Promise.all(css).then(function () {
      buildDialogAndFab();
      if (needSplash) buildSplash();
      var chain = loadScript("scripts/jenny/jenny_texts.js")
        .then(function () { return loadScript("scripts/jenny/jenny.js"); });
      if (needSplash) chain = chain.then(function () { return loadScript("scripts/jenny/jenny-splash.js"); });
      EXTRAS.forEach(function (x) {
        if (!/^[a-z0-9-]+$/i.test(x)) return;   // plain module names only
        chain = chain.then(function () { return loadScript("scripts/jenny/jenny-" + x + ".js"); });
      });
      return chain;
    }).then(function () { boot(needSplash); })
      .catch(function (err) { console.warn("[Jenny] not started:", err.message); });
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", run);
  else run();
})();

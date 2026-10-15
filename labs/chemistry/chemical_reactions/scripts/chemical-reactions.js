/**
 * Chemical Reactions UI – periodic table + reaction results.
 */
(function () {
  "use strict";

  var model = new ReactionsModel();
  var ptRoot = document.getElementById("pt-grid");
  var reactantBar = document.getElementById("reactant-bar");
  var resultBox = document.getElementById("result-box");
  var hintEl = document.getElementById("hint-bar");

  function setHint(t) { if (hintEl) hintEl.textContent = t; }
  function setText(id, t) {
    var el = document.getElementById(id);
    if (el) el.textContent = t;
  }

  function buildPT() {
    if (!ptRoot) return;
    ptRoot.innerHTML = "";
    ReactionsModel.PT_ORDER.forEach(function (row) {
      row.forEach(function (sym) {
        var btn = document.createElement("button");
        btn.type = "button";
        btn.className = "pt-cell";
        if (!sym) {
          btn.disabled = true;
          ptRoot.appendChild(btn);
          return;
        }
        var el = ReactionsModel.ELEMENTS[sym];
        if (!el) {
          btn.disabled = true;
          ptRoot.appendChild(btn);
          return;
        }
        btn.textContent = sym;
        btn.title = el.name + " (Z=" + el.Z + ")";
        btn.setAttribute("data-sym", sym);
        btn.classList.add(el.cat === "metal" ? "metal" : el.cat === "noble" ? "noble" : el.cat === "metalloid" ? "metalloid" : "nonmetal");
        btn.addEventListener("click", function () {
          model.toggle(sym);
          render();
        });
        ptRoot.appendChild(btn);
      });
    });
  }

  function render() {
    // PT selection state
    document.querySelectorAll(".pt-cell[data-sym]").forEach(function (btn) {
      var sym = btn.getAttribute("data-sym");
      btn.classList.toggle("selected", model.selected.indexOf(sym) >= 0);
    });

    // Reactant bar
    if (reactantBar) {
      if (!model.selected.length) {
        reactantBar.innerHTML = "<span class='placeholder'>Click elements on the table (up to 3)</span>";
      } else {
        var html = "";
        model.selected.forEach(function (sym, i) {
          if (i) html += "<span class='plus'>+</span>";
          var el = ReactionsModel.ELEMENTS[sym];
          html += "<span class='chip'>" + sym +
            " <small style='font-weight:600;color:#888'>" + el.form + "</small>" +
            " <button type='button' data-rm='" + sym + "' aria-label='Remove'>×</button></span>";
        });
        reactantBar.innerHTML = html;
        reactantBar.querySelectorAll("button[data-rm]").forEach(function (b) {
          b.addEventListener("click", function () {
            model.toggle(b.getAttribute("data-rm"));
            render();
          });
        });
      }
    }

    var res = model.solve();
    renderResult(res);
    updateStats(res);
  }

  function renderResult(res) {
    if (!resultBox) return;
    if (res.status === "empty") {
      resultBox.innerHTML = "<p class='empty'>" + res.message + "</p>";
      return;
    }
    if (res.status === "single") {
      resultBox.innerHTML = "<p class='empty'>" + res.message + "</p>";
      return;
    }
    if (res.status === "none") {
      resultBox.innerHTML =
        "<div class='type'>no simple reaction</div>" +
        "<p class='notes'>" + escapeHtml(res.message || res.notes || "") + "</p>" +
        (res.notes && res.message !== res.notes ? "<p class='notes'>" + escapeHtml(res.notes) + "</p>" : "");
      return;
    }
    // reaction
    resultBox.innerHTML =
      "<div class='type'>" + escapeHtml(res.type) + "</div>" +
      "<p class='eq'>" + escapeHtml(res.equation) + "</p>" +
      "<p class='product'>" + escapeHtml(res.product) + " — " + escapeHtml(res.productName) + "</p>" +
      "<p class='notes'>" + escapeHtml(res.notes) + "</p>" +
      "<p class='cond'>Conditions: " + escapeHtml(res.conditions) + "</p>";
  }

  function escapeHtml(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function updateStats(res) {
    setText("s-count", String(model.selected.length));
    setText("s-reactants", model.selected.length
      ? model.selected.map(function (s) {
          return ReactionsModel.ELEMENTS[s].form;
        }).join(" + ")
      : "–");
    setText("s-product", res.product || "–");
    setText("s-type", res.type || "–");
  }

  function bind() {
    document.getElementById("btn-clear").addEventListener("click", function () {
      model.clear();
      render();
      setHint("Selection cleared. Pick elements to react.");
    });

    document.querySelectorAll("[data-preset]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var p = btn.getAttribute("data-preset");
        model.clear();
        if (p === "ammonia") {
          model.selected = ["N", "H"];
          setHint("N₂ + 3H₂ → 2NH₃ — ammonia, not NH₂. Stoichiometry matters.");
        } else if (p === "water") {
          model.selected = ["H", "O"];
          setHint("2H₂ + O₂ → 2H₂O — synthesis of water.");
        } else if (p === "salt") {
          model.selected = ["Na", "Cl"];
          setHint("2Na + Cl₂ → 2NaCl — classic salt synthesis.");
        } else if (p === "mgo") {
          model.selected = ["Mg", "O"];
          setHint("2Mg + O₂ → 2MgO — bright white flame demonstration.");
        } else if (p === "hcl") {
          model.selected = ["H", "Cl"];
          setHint("H₂ + Cl₂ → 2HCl — hydrogen chloride.");
        } else if (p === "noble") {
          model.selected = ["Ne", "O"];
          setHint("Noble gases do not form ordinary compounds under standard conditions.");
        }
        render();
      });
    });
  }

  function init() {
    buildPT();
    bind();
    render();
    setHint("Select up to three elements. Known pairs show a balanced equation and product. Try N + H for ammonia.");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();

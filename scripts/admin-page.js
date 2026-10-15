$(function () {
  $("#current-year").text(new Date().getFullYear());

  // The dashboard guard is only a convenience for this front-end demo.
  if (sessionStorage.getItem("oopa_admin_demo_access") !== "granted") {
    window.location.replace("admin-login.html");
    return;
  }

  $("#logout-button").on("click", function () {
    sessionStorage.removeItem("oopa_admin_demo_access");
    window.location.href = "admin-login.html";
  });
});

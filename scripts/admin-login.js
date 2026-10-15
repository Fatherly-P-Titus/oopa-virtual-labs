$(function () {
  $("#current-year").text(new Date().getFullYear());

  // Demo-only client-side passcode. Do not use this for real security.
  const DEMO_PASSCODE = "12346";

  $("#toggle-passcode").on("click", function () {
    const $input = $("#passcode");
    const show = $input.attr("type") === "password";
    $input.attr("type", show ? "text" : "password");
    $(this).text(show ? "Hide" : "Show").attr("aria-label", show ? "Hide passcode" : "Show passcode");
    $input.trigger("focus");
  });

  $("#login-form").on("submit", function (event) {
    event.preventDefault();
    const entered = $("#passcode").val().trim();
    const $message = $("#form-message");

    if (!entered) {
      $message.removeClass("success").text("Please enter the administrator passcode.");
      $("#passcode").trigger("focus");
      return;
    }

    if (entered === DEMO_PASSCODE) {
      $message.addClass("success").text("Access granted. Opening dashboard…");
      sessionStorage.setItem("oopa_admin_demo_access", "granted");
      window.setTimeout(function () {
        window.location.href = "admin-page.html";
      }, 350);
    } else {
      $message.removeClass("success").text("Incorrect passcode. Please try again.");
      $("#passcode").val("").trigger("focus");
    }
  });
});

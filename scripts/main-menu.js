$(function () {
  $("#current-year").text(new Date().getFullYear());

  $(".menu-toggle").on("click", function () {
    const $nav = $(".topnav");
    const isOpen = $nav.hasClass("is-open");
    $nav.toggleClass("is-open", !isOpen);
    $(this).attr("aria-expanded", String(!isOpen));
    $(this).attr("aria-label", isOpen ? "Open navigation" : "Close navigation");
    $(this).text(isOpen ? "☰" : "×");
  });

  $(".topnav a").on("click", function () {
    $(".topnav").removeClass("is-open");
    $(".menu-toggle").attr("aria-expanded", "false").attr("aria-label", "Open navigation").text("☰");
  });

  $(".lab-card").on("pointerdown", function () {
    $(this).addClass("is-pressed");
  }).on("pointerup pointerleave", function () {
    $(this).removeClass("is-pressed");
  });
});

/* Destaca a plataforma do visitante. Opcional: sem JS a página funciona igual. Não carrega o jogo. */
(function () {
  var ua = navigator.userAgent || "";
  var ios = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  var os = ios ? "ios" : /Android/i.test(ua) ? "android" : /Windows/i.test(ua) ? "windows" : "web";
  // Android e Windows ainda não têm instalador: recomenda o navegador.
  if (os === "android" || os === "windows") os = "web";
  var card = document.querySelector('.plat[data-os="' + os + '"]');
  if (card) card.classList.add("is-you");
  if (ios) {
    var safari = /Safari/.test(ua) && !/CriOS|FxiOS|EdgiOS|OPiOS|OPT\//.test(ua);
    if (!safari) { var n = document.getElementById("ios-note"); if (n) n.hidden = false; }
  }
})();

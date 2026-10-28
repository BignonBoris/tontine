// Landing VizioBox — guide d'installation de l'APK.
// Fichier externe (la CSP de helmet interdit les scripts inline).
// Sans JavaScript, les liens de téléchargement fonctionnent normalement.
(function () {
  var dialog = document.getElementById('install-guide');
  if (!dialog || typeof dialog.showModal !== 'function') return;

  var ua = navigator.userAgent;
  var isAndroid = /android/i.test(ua);
  // iPadOS se présente comme un Mac : on le reconnaît à l'écran tactile.
  var isIOS = /iphone|ipad|ipod/i.test(ua) || (/macintosh/i.test(ua) && navigator.maxTouchPoints > 1);

  function open(variant) {
    dialog.setAttribute('data-variant', variant);
    // Le titre annoncé par les lecteurs d'écran suit la variante affichée.
    dialog.setAttribute('aria-labelledby', 'guide-title-' + variant);
    if (!dialog.open) dialog.showModal();
  }

  document.addEventListener('click', function (event) {
    var link = event.target.closest('a[data-download]');
    if (!link) return;

    if (isAndroid) {
      // Le téléchargement suit son cours (le serveur renvoie un fichier, la page reste affichée).
      open('android');
      return;
    }

    // iPhone ou ordinateur : l'APK n'y est pas installable.
    event.preventDefault();
    open(isIOS ? 'ios' : 'other');
  });

  dialog.addEventListener('click', function (event) {
    if (event.target.closest('[data-close]')) {
      dialog.close();
      return;
    }
    // Clic sur le fond assombri.
    if (event.target !== dialog) return;
    var rect = dialog.getBoundingClientRect();
    var outside =
      event.clientX < rect.left || event.clientX > rect.right ||
      event.clientY < rect.top || event.clientY > rect.bottom;
    if (outside) dialog.close();
  });
})();

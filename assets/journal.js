// Underwater paper journal: pages settle in and pencil marks draw as you reach them.
(function () {
  var root = document.documentElement;
  root.classList.add('js');
  var pages = document.querySelectorAll('.page');
  if (!('IntersectionObserver' in window)) {
    pages.forEach(function (p) { p.classList.add('is-seen'); });
    return;
  }
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (en) {
      if (!en.isIntersecting) return;
      en.target.classList.add('is-seen');
      io.unobserve(en.target);
    });
  }, { threshold: .12 });
  pages.forEach(function (p) { io.observe(p); });
})();

// Tap a photo to see it big.
(function () {
  var links = document.querySelectorAll('[data-zoom]');
  if (!links.length || typeof HTMLDialogElement === 'undefined') return;
  var dlg = document.createElement('dialog');
  dlg.className = 'zoom';
  dlg.innerHTML = '<figure><img alt=""><figcaption></figcaption></figure><button type="button">close &times;</button>';
  document.body.appendChild(dlg);
  var img = dlg.querySelector('img'), cap = dlg.querySelector('figcaption');
  links.forEach(function (a) {
    a.addEventListener('click', function (e) {
      e.preventDefault();
      var inner = a.querySelector('img');
      img.src = a.getAttribute('href');
      img.alt = inner ? inner.alt : '';
      cap.textContent = a.getAttribute('data-caption') || '';
      cap.hidden = !cap.textContent;
      dlg.showModal();
    });
  });
  dlg.addEventListener('click', function () { dlg.close(); });
  dlg.addEventListener('close', function () { img.removeAttribute('src'); });
})();

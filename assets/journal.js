// Underwater paper journal: pages settle in and pencil marks draw as you reach them.
// A page is revealed as soon as its top comes into view. This is checked on load,
// scroll, resize and hash jumps (with an observer as a backup), so a page can never
// stay hidden, no matter how tall it is.
(function () {
  // clean URLs: an old /venture.html link shows as /venture
  if (/\.html$/.test(location.pathname)) history.replaceState(null, '', location.pathname.replace(/\.html$/, '') + location.search + location.hash);
  var root = document.documentElement;
  root.classList.add('js');
  var pages = Array.prototype.slice.call(document.querySelectorAll('.page'));
  function reveal(p) { p.classList.add('is-seen'); }
  function check() {
    var limit = window.innerHeight * 0.92;
    pages = pages.filter(function (p) {
      if (p.getBoundingClientRect().top < limit) { reveal(p); return false; }
      return true;
    });
    if (!pages.length) {
      window.removeEventListener('scroll', check);
      window.removeEventListener('resize', check);
      window.removeEventListener('hashchange', check);
    }
  }
  window.addEventListener('scroll', check, { passive: true });
  window.addEventListener('resize', check);
  window.addEventListener('hashchange', check);
  window.addEventListener('load', check);
  check();

  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        reveal(en.target);
        io.unobserve(en.target);
      });
    }, { threshold: 0, rootMargin: '0px 0px -8% 0px' });
    pages.forEach(function (p) { io.observe(p); });
  }
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

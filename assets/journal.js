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

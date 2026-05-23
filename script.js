// ── Inject shared elements ────────────────────────────────
const dot   = Object.assign(document.createElement('div'), { className: 'cursor-dot' });
const ring  = Object.assign(document.createElement('div'), { className: 'cursor-ring' });
const grain = Object.assign(document.createElement('div'), { className: 'grain' });
document.body.append(dot, ring, grain);

// ── Cursor ────────────────────────────────────────────────
let mx = 0, my = 0, rx = 0, ry = 0;
let hnX = 0, hnY = 0, hnTX = 0, hnTY = 0;
const isHome = document.body.classList.contains('page-home');
const heroNameEl = document.getElementById('heroName');

document.addEventListener('mousemove', e => {
  mx = e.clientX; my = e.clientY;
  if (isHome && heroNameEl) {
    hnTX = (e.clientX / window.innerWidth  - .5) * -26;
    hnTY = (e.clientY / window.innerHeight - .5) * -12;
  }
});

(function tick() {
  dot.style.left = mx + 'px';
  dot.style.top  = my + 'px';
  rx += (mx - rx) * .1;
  ry += (my - ry) * .1;
  ring.style.left = rx + 'px';
  ring.style.top  = ry + 'px';
  if (isHome && heroNameEl) {
    hnX += (hnTX - hnX) * .04;
    hnY += (hnTY - hnY) * .04;
    heroNameEl.style.transform = `translate(${hnX.toFixed(2)}px,${hnY.toFixed(2)}px)`;
  }
  requestAnimationFrame(tick);
})();

document.querySelectorAll('a, button, .honors-list li').forEach(el => {
  el.addEventListener('mouseenter', () => document.body.classList.add('hovered'));
  el.addEventListener('mouseleave', () => document.body.classList.remove('hovered'));
});

// ── Active nav link ───────────────────────────────────────
const currentFile = window.location.pathname.split('/').pop() || 'index.html';
document.querySelectorAll('.nav-link').forEach(link => {
  if (link.getAttribute('href') === currentFile) link.classList.add('active');
});

// ── Page transitions (fade out → navigate) ────────────────
document.querySelectorAll('a[href]').forEach(link => {
  const href = link.getAttribute('href');
  if (!href || href.startsWith('#') || href.startsWith('mailto:') ||
      href.startsWith('tel:') || href.startsWith('http')) return;
  link.addEventListener('click', e => {
    if (link.href === window.location.href) return;
    e.preventDefault();
    document.body.style.transition = 'opacity .28s ease';
    document.body.style.opacity = '0';
    setTimeout(() => { window.location.href = href; }, 290);
  });
});

// ── Inner pages: fade in on load ──────────────────────────
if (!isHome) {
  document.body.classList.add('fade-in');
  requestAnimationFrame(() =>
    requestAnimationFrame(() => document.body.classList.add('visible'))
  );
  // Scroll reveal
  const io = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      const sibs = [...entry.target.parentElement.querySelectorAll('.reveal:not(.in)')];
      setTimeout(() => entry.target.classList.add('in'), Math.max(0, sibs.indexOf(entry.target)) * 100);
      io.unobserve(entry.target);
    });
  }, { threshold: .08 });
  document.querySelectorAll('.reveal').forEach(el => io.observe(el));
}

// ── Home: loader → name draw sequence ────────────────────
if (isHome) {
  window.addEventListener('load', () => {
    const loader = document.getElementById('loader');
    const hero   = document.querySelector('.hero');

    setTimeout(() => {
      if (loader) {
        loader.classList.add('out');
        setTimeout(() => {
          if (loader) loader.style.display = 'none';
          if (hero)   hero.classList.add('animate');
        }, 700);
      }
    }, 2600);
  });
}

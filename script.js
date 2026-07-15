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

// ── Home: gong gate → name draw sequence ──────────────────
if (isHome) {
  const gate    = document.getElementById('gongGate');
  const gongBtn = document.getElementById('gongBtn');
  const gateCta = document.getElementById('gateCta');
  const dots    = gate ? [...gate.querySelectorAll('.gate-dot')] : [];
  const hero    = document.querySelector('.hero');
  const palette = ['#ff6b57', '#f2ae40', '#2f9e94', '#7c6bd8', '#e7527a'];
  let hits = 0;
  let onCooldown = false;
  const HIT_COOLDOWN_MS = 1000;

  const gongSound      = new Audio('assets/gong-hit.mp3');
  const gongSoundFinal = new Audio('assets/gong-hit-3.mp3');
  gongSound.preload      = 'auto';
  gongSoundFinal.preload = 'auto';

  function playGongHit(isFinal) {
    try {
      const sound = (isFinal ? gongSoundFinal : gongSound).cloneNode();
      sound.play().catch(() => {});
    } catch (e) { /* audio unsupported — visuals still play */ }
  }

  function spawnSplash(x, y) {
    const s = document.createElement('div');
    const size = 60 + Math.random() * 120;
    s.className = 'splash';
    s.style.left = (x - size / 2) + 'px';
    s.style.top  = (y - size / 2) + 'px';
    s.style.width = s.style.height = size + 'px';
    s.style.background = palette[Math.floor(Math.random() * palette.length)];
    document.body.appendChild(s);
    setTimeout(() => s.remove(), 950);
  }

  function ringPing() {
    const ring = document.createElement('span');
    ring.className = 'gong-ring ping';
    gongBtn.appendChild(ring);
    setTimeout(() => ring.remove(), 950);
  }

  function startHero() {
    if (hero) hero.classList.add('animate');
  }

  if (gongBtn) {
    gongBtn.addEventListener('mouseenter', () => document.body.classList.add('mallet-cursor'));
    gongBtn.addEventListener('mouseleave', () => document.body.classList.remove('mallet-cursor'));

    gongBtn.addEventListener('click', e => {
      if (hits >= 3 || onCooldown) return;
      hits++;
      playGongHit(hits === 3);
      ringPing();
      spawnSplash(e.clientX, e.clientY);
      gongBtn.classList.remove('hit');
      void gongBtn.offsetWidth;
      gongBtn.classList.add('hit');
      if (dots[hits - 1]) dots[hits - 1].classList.add('hit');
      if (gateCta) gateCta.textContent = hits < 3 ? `${hits} of 3 — bang again!` : 'Entering…';

      if (hits < 3) {
        onCooldown = true;
        gongBtn.classList.add('cooldown');
        setTimeout(() => {
          onCooldown = false;
          gongBtn.classList.remove('cooldown');
        }, HIT_COOLDOWN_MS);
      }

      if (hits === 3) {
        setTimeout(() => {
          gate.classList.add('leaving');
          setTimeout(() => {
            gate.style.display = 'none';
            startHero();
          }, 900);
        }, 500);
      }
    });
  } else {
    startHero();
  }
}

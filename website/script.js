// Scale the 1440×900 hero desktop to its container.
const mockup = document.getElementById('hero-mockup');
const desktop = mockup?.querySelector('.desktop');
if (mockup && desktop && 'ResizeObserver' in window) {
  new ResizeObserver(([entry]) => {
    desktop.style.setProperty('--z', entry.contentRect.width / 1440);
  }).observe(mockup);
}

// Nav hairline once the page scrolls.
const nav = document.querySelector('.nav');
const onScroll = () => nav.classList.toggle('is-scrolled', window.scrollY > 4);
window.addEventListener('scroll', onScroll, { passive: true });
onScroll();

// Hero timer counts down like the real app (25:00 session, starting at 24:38).
const SESSION = 25 * 60;
let remaining = 24 * 60 + 38;
const timeEls = document.querySelectorAll('[data-live-time]');
const fmt = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;

setInterval(() => {
  remaining = remaining > 0 ? remaining - 1 : SESSION;
  timeEls.forEach((el) => { el.textContent = fmt(remaining); });
}, 1000);

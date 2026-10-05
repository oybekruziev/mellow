// Mellow landing — one module, one shared store.
// Every section reads the store, so picking a companion, starting the demo or
// playing music updates the hero, the nav chip, the garden and the keycaps together.

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');
const finePointer = matchMedia('(pointer: fine)');
const touchOnly = matchMedia('(hover: none)');
const isMac = /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);

// ---------- Store ----------

const today = new Date().toDateString();
const load = (key, fallback) => {
  try { const v = localStorage.getItem(key); return v == null ? fallback : JSON.parse(v); } catch { return fallback; }
};
const save = (key, value) => { try { localStorage.setItem(key, JSON.stringify(value)); } catch {} };

const COMPANIONS = ['plant', 'cat', 'candle', 'fox', 'coffee', 'moon', 'cactus'];
const savedFlowers = load('mellow.todayFlowers', null);

const store = {
  companion: COMPANIONS.includes(load('mellow.companion', 'cat')) ? load('mellow.companion', 'cat') : 'cat',
  demo: 'idle', // idle | typing | running | paused | done
  demoRemaining: 25 * 60,
  musicPlaying: false,
  todayFlowers: savedFlowers && savedFlowers.date === today ? savedFlowers.count : 0,
};
const listeners = new Set();
function set(patch) {
  Object.assign(store, patch);
  if ('companion' in patch) save('mellow.companion', store.companion);
  if ('todayFlowers' in patch) save('mellow.todayFlowers', { date: today, count: store.todayFlowers });
  listeners.forEach((fn) => fn(store, patch));
}
const subscribe = (fn) => { listeners.add(fn); fn(store, {}); };

const companionSrc = (type, stage) => `assets/companions/${type}-${stage}.webp`;
const fmt = (s) => {
  s = Math.max(0, Math.ceil(s));
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
};
const scrollToEl = (el) => el.scrollIntoView({ behavior: reduceMotion.matches ? 'auto' : 'smooth', block: 'start' });

// ---------- Toast + live region ----------

const toastEl = $('[data-toast]');
let toastTimer;
function toast(text) {
  toastEl.textContent = text;
  toastEl.classList.add('is-on');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toastEl.classList.remove('is-on'), 2600);
}
const live = $('[data-live]');
const announce = (text) => { live.textContent = text; };

// Pause CSS loops while their section is off-screen or the tab is hidden.
function pauseOffscreen(el) {
  if (!('IntersectionObserver' in window)) return;
  new IntersectionObserver(([e]) => el.classList.toggle('paused-anim', !e.isIntersecting)).observe(el);
}
const pausedStyle = document.createElement('style');
pausedStyle.textContent = '.paused-all *, .paused-all *::before, .paused-all *::after { animation-play-state: paused !important; }';
document.head.append(pausedStyle);
document.addEventListener('visibilitychange', () => document.body.classList.toggle('paused-all', document.hidden));

// ---------- Nav ----------

const nav = $('.nav');
const onScroll = () => nav.classList.toggle('is-scrolled', scrollY > 4);
addEventListener('scroll', onScroll, { passive: true });
onScroll();

$$('.nav-links a[href^="#"], .f-links a[href^="#"]').forEach((a) => {
  a.addEventListener('click', (e) => {
    const target = $(a.getAttribute('href'));
    if (!target) return;
    e.preventDefault();
    scrollToEl(target);
    history.replaceState(null, '', a.getAttribute('href'));
    if (a.hasAttribute('data-try')) setTimeout(() => taskInput.focus({ preventScroll: true }), reduceMotion.matches ? 0 : 450);
  });
});

const navChip = $('[data-nav-chip]');
const chipTime = $('[data-chip-time]');
navChip.addEventListener('click', () => scrollToEl($('#try')));

// Version line from latest.json (scripts/publish.sh writes it). The links work without it.
fetch('/download/latest.json', { cache: 'no-cache' })
  .then((res) => (res.ok ? res.json() : Promise.reject(res.status)))
  .then(({ version }) => {
    if (!version) return;
    $$('[data-version]').forEach((el) => { el.textContent = `Version ${version} · Free · macOS 26 Tahoe and later`; });
  })
  .catch(() => {});

// ---------- Audio (lofi + chime share one context, created on a gesture) ----------

let audioCtx;
function ctx() {
  if (!audioCtx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    audioCtx = new AC();
  }
  if (audioCtx.state === 'suspended') audioCtx.resume();
  return audioCtx;
}

function chime() {
  const ac = ctx();
  if (!ac) return;
  const t = ac.currentTime;
  [[880, 0.16], [1318.5, 0.09], [1760, 0.04]].forEach(([freq, peak], i) => {
    const osc = ac.createOscillator();
    const g = ac.createGain();
    osc.type = 'sine';
    osc.frequency.value = freq;
    g.gain.setValueAtTime(0, t + i * 0.06);
    g.gain.linearRampToValueAtTime(peak, t + i * 0.06 + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t + i * 0.06 + 1.8);
    osc.connect(g).connect(ac.destination);
    osc.start(t + i * 0.06);
    osc.stop(t + i * 0.06 + 1.9);
  });
}

// ---------- Hero demo ----------

const SPEED = 25; // 25:00 plays in one minute
const panel = $('[data-demo-panel]');
const capsule = $('[data-capsule]');
const taskInput = $('[data-task-input]');
const taskForm = $('[data-task-form]');
const views = Object.fromEntries($$('.view', panel).map((v) => [v.dataset.viewName, v]));
const readyTime = $('[data-ready-time]');
const focusTime = $('[data-focus-time]');
const focusTask = $('[data-focus-task]');
const focusStatus = $('[data-focus-status]');
const focusProgress = $('[data-focus-progress]');
const completeTask = $('[data-complete-task]');
const pauseBtn = $('[data-action="pause"]', panel);
const mbTime = $('[data-mb-time]');
const mbItem = $('[data-mb-item]');
const mbClock = $('[data-mb-clock]');
const stage = $('[data-stage]');

let durationMin = 25;
let lastFrame = 0;
let rafId = 0;
let quarter = 0;
let confirmOpen = false;
let compact = false;
let taskName = 'Finish the article';

Object.values(views).forEach((v) => { if (!v.classList.contains('is-active')) v.inert = true; });

function animateHeight(change) {
  const from = panel.offsetHeight;
  change();
  panel.style.height = 'auto';
  const to = panel.offsetHeight;
  if (reduceMotion.matches || from === to) { panel.style.height = ''; return; }
  panel.style.height = `${from}px`;
  panel.offsetHeight; // commit the start height
  panel.style.height = `${to}px`;
  const done = (e) => {
    if (e && e.propertyName !== 'height') return;
    panel.style.height = '';
    panel.removeEventListener('transitionend', done);
  };
  panel.addEventListener('transitionend', done);
  setTimeout(done, 700);
}

function showView(name) {
  const next = views[name];
  const cur = $('.view.is-active', panel);
  if (cur === next) return;
  animateHeight(() => {
    cur.classList.remove('is-active');
    cur.classList.add('is-leaving');
    cur.inert = true;
    cur.setAttribute('aria-hidden', 'true');
    next.classList.add('is-active');
    next.inert = false;
    next.removeAttribute('aria-hidden');
    panel.dataset.view = name;
  });
  setTimeout(() => cur.classList.remove('is-leaving'), 260);
}

function setConfirm(open) {
  if (confirmOpen === open) return;
  confirmOpen = open;
  animateHeight(() => panel.classList.toggle('is-confirm', open));
  if (open) {
    setCompact(false);
    $('[data-action="keep"]', panel).focus({ preventScroll: true });
  }
}

function setCompact(on) {
  compact = on;
  panel.hidden = on;
  capsule.hidden = !on;
  renderHero();
}

function stageFor(remaining) {
  const total = durationMin * 60;
  const progress = 1 - remaining / total;
  return clamp(Math.floor(progress * 4) + 1, 1, 4);
}

function renderHero() {
  const { demo, demoRemaining, companion } = store;
  const running = demo === 'running' || demo === 'paused';
  const total = durationMin * 60;
  focusTime.textContent = fmt(demoRemaining);
  focusProgress.style.width = `${(1 - demoRemaining / total) * 100}%`;
  focusStatus.textContent = demo === 'paused' ? 'Paused' : 'Focusing · demo';
  panel.classList.toggle('is-paused', demo === 'paused');
  pauseBtn.setAttribute('aria-label', demo === 'paused' ? 'Resume' : 'Pause');
  $('.ic', pauseBtn).className = `ic ${demo === 'paused' ? 'ic-play' : 'ic-pause'}`;

  const stageImg = demo === 'done' ? 'done' : running ? stageFor(demoRemaining) : 1;
  $$('[data-companion-img]').forEach((img) => {
    const src = companionSrc(companion, stageImg);
    if (!img.src.endsWith(src)) img.src = src;
  });
  $$('[data-companion-done]').forEach((img) => { img.src = companionSrc(companion, 'done'); });

  // Nav chip: the menu-bar timer while a session is on.
  navChip.hidden = !running;
  chipTime.textContent = fmt(demoRemaining);
  mbTime.hidden = !running;
  mbTime.textContent = fmt(demoRemaining);
  mbItem.classList.toggle('is-on', running);

  // Compact capsule mirrors the panel.
  $('[data-cap-time]').textContent = running ? fmt(demoRemaining) : demo === 'done' ? 'Done' : `${String(durationMin).padStart(2, '0')}:00`;
  $('[data-cap-state]').textContent = demo === 'paused' ? 'Paused' : demo === 'running' ? 'Focus' : demo === 'done' ? 'Complete' : 'Ready';
  capsule.classList.toggle('is-paused', demo === 'paused');
  $('[data-cap-icon]').className = `ic ${demo === 'running' ? 'ic-pause' : 'ic-play'}`;
}

function renderCounts() {
  const base = 3 + store.todayFlowers;
  $$('[data-panel-flowers]').forEach((el) => {
    const isNew = el.hasAttribute('data-new');
    const n = Math.min(base, 6);
    el.innerHTML = Array.from({ length: n }, (_, i) => `<i${isNew && i === n - 1 ? ' class="new"' : ''}></i>`).join('');
  });
  $$('[data-panel-count]').forEach((el) => {
    el.textContent = `${base} session${base === 1 ? '' : 's'} today`;
  });
}

function tick() {
  if (store.demo !== 'running') return;
  const now = performance.now();
  const dt = (now - lastFrame) / 1000;
  lastFrame = now;
  const remaining = Math.max(0, store.demoRemaining - dt * SPEED);
  const total = durationMin * 60;
  const q = Math.floor((1 - remaining / total) * 4);
  if (q > quarter && q < 4) {
    quarter = q;
    announce(['', 'A quarter done. Your companion grew.', 'Halfway there.', 'Three quarters done.'][q]);
  }
  set({ demoRemaining: remaining });
  if (remaining <= 0) complete();
}

function start() {
  ctx(); // unlock audio inside the gesture
  taskName = taskInput.value.trim() || 'Finish the article';
  focusTask.textContent = taskName;
  completeTask.textContent = taskName;
  quarter = 0;
  set({ demo: 'running', demoRemaining: durationMin * 60 });
  showView('focus');
  document.body.classList.add('focus-mode');
  lastFrame = performance.now();
  clearInterval(rafId);
  rafId = setInterval(tick, 100);
  announce(`Focus started: ${taskName}. ${durationMin} minutes, played at 25 times speed.`);
  if (musicFocus.checked) music.play();
}

function pause() {
  if (store.demo === 'running') {
    set({ demo: 'paused' });
    clearInterval(rafId);
    announce('Paused.');
    if (store.musicPlaying) music.pause();
  } else if (store.demo === 'paused') {
    set({ demo: 'running' });
    lastFrame = performance.now();
    clearInterval(rafId);
    rafId = setInterval(tick, 100);
    announce('Resumed.');
    if (musicFocus.checked) music.play();
  }
}

function stopToReady() {
  clearInterval(rafId);
  setConfirm(false);
  set({ demo: 'idle', demoRemaining: durationMin * 60 });
  showView('ready');
  document.body.classList.remove('focus-mode');
  if (store.musicPlaying) music.pause();
}

function complete() {
  clearInterval(rafId);
  setConfirm(false);
  set({ demo: 'done', demoRemaining: 0, todayFlowers: store.todayFlowers + 1 });
  showView('complete');
  document.body.classList.remove('focus-mode');
  if (store.musicPlaying) music.pause();
  chime();
  announce('Session complete. A flower for today.');
  garden.deliver();
}

function toggle() {
  if (store.demo === 'idle' || store.demo === 'typing' || store.demo === 'done') start();
  else pause();
}
function openConfirm() {
  if (store.demo === 'running' || store.demo === 'paused') setConfirm(true);
}

taskForm.addEventListener('submit', (e) => { e.preventDefault(); start(); });
taskInput.addEventListener('focus', () => { if (store.demo === 'idle') set({ demo: 'typing' }); });
taskInput.addEventListener('blur', () => { if (store.demo === 'typing') set({ demo: 'idle' }); });

const seg = $('[data-seg]');
const segButtons = $$('button', seg);
function pickDuration(btn) {
  segButtons.forEach((b) => { b.setAttribute('aria-checked', String(b === btn)); b.tabIndex = b === btn ? 0 : -1; });
  durationMin = Number(btn.dataset.min);
  readyTime.textContent = `${String(durationMin).padStart(2, '0')}:00`;
  if (store.demo === 'idle' || store.demo === 'typing') set({ demoRemaining: durationMin * 60 });
}
segButtons.forEach((b) => {
  b.tabIndex = b.getAttribute('aria-checked') === 'true' ? 0 : -1;
  b.addEventListener('click', () => pickDuration(b));
  b.addEventListener('keydown', (e) => {
    const i = segButtons.indexOf(b);
    const step = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
    if (!step) return;
    e.preventDefault();
    const next = segButtons[(i + step + segButtons.length) % segButtons.length];
    pickDuration(next);
    next.focus();
  });
});

const actions = {
  start,
  pause,
  toggle,
  end: openConfirm,
  keep: () => setConfirm(false),
  'confirm-end': stopToReady,
  later: stopToReady,
  break: () => { stopToReady(); toast('Break time. In the app a 5-minute timer starts.'); },
  compact: () => setCompact(!compact),
  hide: () => toast('In the app this hides the panel to the menu bar.'),
  settings: () => toast('Settings live in the app'),
  plans: () => scrollToEl($('#plans')),
  music: () => music.toggle(),
};
$('.panel-wrap').addEventListener('click', (e) => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;
  actions[btn.dataset.action]?.();
});

let heroVisible = true;
if ('IntersectionObserver' in window) {
  new IntersectionObserver(([e]) => { heroVisible = e.isIntersecting; }).observe(stage);
}
pauseOffscreen($('#try'));
// The desktop's menu bar clock, like the real one.
const dayFmt = new Intl.DateTimeFormat('en-US', { weekday: 'short' });
const hourFmt = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' });
const tickClock = () => { const d = new Date(); mbClock.textContent = `${dayFmt.format(d)} ${hourFmt.format(d)}`; };
tickClock();
setInterval(tickClock, 30000);

subscribe((s, patch) => {
  renderHero();
  if ('todayFlowers' in patch || !Object.keys(patch).length) renderCounts();
});

// ---------- Session story (scroll-scrubbed) ----------

const story = $('[data-story]');
const steps = $$('.step', story);
const stepsEl = $('[data-steps]');
const rail = $('[data-story-rail]');
const maskPath = $('[data-story-mask]');
const storyTime = $('[data-story-time]');
const storyCompanion = $('[data-story-companion]');
const storyProgress = $('[data-story-progress]');
const sticky = $('.story-sticky', story);
const dots = $$('[data-story-dots] i');
const pathLen = maskPath.getTotalLength();
maskPath.style.strokeDasharray = `${pathLen}`;

const wide = matchMedia('(min-width: 1200px)');
function setActiveStep(i) {
  steps.forEach((s, n) => s.classList.toggle('is-active', n === i));
  dots.forEach((d, n) => d.classList.toggle('is-on', n === i));
}
function scrubStory() {
  if (!story.classList.contains('is-scrub')) return;
  const rect = story.getBoundingClientRect();
  const top = parseFloat(getComputedStyle(sticky).top) || 0;
  const travel = story.offsetHeight - 160 - sticky.offsetHeight;
  const p = clamp((top - rect.top) / travel, 0, 1);
  setActiveStep(Math.min(3, Math.floor(p * 4)));
  rail.style.width = `${p * 100}%`;
  maskPath.style.strokeDashoffset = `${pathLen * (1 - p)}`;
  // Between steps 2 and 3 the timer tweens 19:40 → 06:12 and the companion moves up a stage.
  const t = clamp((p - 0.375) / 0.25, 0, 1);
  storyTime.textContent = fmt(1180 + (372 - 1180) * t);
  storyProgress.style.width = `${(0.5 + 0.25 * t) * 100}%`;
  const src = companionSrc('plant', t < 0.5 ? 3 : 4);
  if (!storyCompanion.src.endsWith(src)) storyCompanion.src = src;
}
function setupStory() {
  const scrub = wide.matches && !reduceMotion.matches;
  story.classList.toggle('is-scrub', scrub);
  stepsEl.classList.toggle('is-scrubbing', scrub);
  if (scrub) { scrubStory(); return; }
  // Static, as drawn: step two is active, the path fully drawn.
  rail.style.width = '';
  maskPath.style.strokeDashoffset = '0';
  storyTime.textContent = '06:12';
  storyProgress.style.width = '75%';
  storyCompanion.src = companionSrc('plant', 4);
  setActiveStep(wide.matches ? 1 : 0);
}
addEventListener('scroll', scrubStory, { passive: true });
addEventListener('resize', scrubStory, { passive: true });
wide.addEventListener('change', setupStory);
reduceMotion.addEventListener('change', setupStory);
setupStory();
stepsEl.addEventListener('scroll', () => {
  if (story.classList.contains('is-scrub')) return;
  const w = steps[0].offsetWidth + 16;
  setActiveStep(clamp(Math.round(stepsEl.scrollLeft / w), 0, 3));
}, { passive: true });

// ---------- Meet the crew ----------

const cardsEl = $('[data-cards]');
const cards = $$('.pal', cardsEl);
const cqText = $('[data-cq-text]');
const cqName = $('[data-cq-name]');
const cqState = $('[data-cq-state]');
const nameOf = (card) => $('.pal-name', card).textContent;

// One quote above the shelf follows whichever companion you point at, else the picked one.
function showQuote(card) {
  const picked = card.getAttribute('aria-checked') === 'true';
  cqText.textContent = card.dataset.quote;
  cqName.textContent = nameOf(card);
  cqState.textContent = picked ? 'keeping you company' : touchOnly.matches ? 'tap to pick' : 'click to pick';
}
const pickedCard = () => cards.find((c) => c.getAttribute('aria-checked') === 'true') || cards[1];

cards.forEach((card) => {
  const t = card.dataset.type;
  card.style.setProperty('--still', `url(${companionSrc(t, 1)})`);
  card.style.setProperty('--done', `url(${companionSrc(t, 'done')})`);
  card.style.setProperty('--loop', `url(assets/sprites/${t}-loop.webp)`);
  if (!card.hasAttribute('data-nowake')) card.style.setProperty('--wake', `url(assets/sprites/${t}-wake.webp)`);
  card.setAttribute('aria-label', `${nameOf(card)}: ${card.dataset.quote}`);
  card.addEventListener('pointerenter', () => { card.classList.add('is-hover'); showQuote(card); });
  card.addEventListener('pointerleave', () => { card.classList.remove('is-hover'); showQuote(pickedCard()); });
  card.addEventListener('focus', () => { if (card.matches(':focus-visible')) card.classList.add('is-hover'); showQuote(card); });
  card.addEventListener('blur', () => { card.classList.remove('is-hover'); showQuote(pickedCard()); });
  card.addEventListener('click', () => pickCard(card));
  card.addEventListener('keydown', (e) => {
    const i = cards.indexOf(card);
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); pickCard(card); return; }
    const step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[e.key];
    if (!step) return;
    e.preventDefault();
    const next = cards[(i + step + cards.length) % cards.length];
    cards.forEach((c) => { c.tabIndex = c === next ? 0 : -1; });
    next.focus();
  });
});
function pickCard(card) {
  const wasSelected = card.getAttribute('aria-checked') === 'true';
  set({ companion: card.dataset.type });
  if (!card.hasAttribute('data-nowake') && !reduceMotion.matches && !wasSelected) {
    card.classList.add('is-waking');
    setTimeout(() => card.classList.remove('is-waking'), 1000);
  }
}
subscribe((s, patch) => {
  if (!('companion' in patch) && Object.keys(patch).length) return;
  cards.forEach((c) => {
    const on = c.dataset.type === s.companion;
    c.setAttribute('aria-checked', String(on));
    if (on && !cardsEl.contains(document.activeElement)) cards.forEach((x) => { x.tabIndex = x === c ? 0 : -1; });
  });
  const hovered = cards.find((c) => c.classList.contains('is-hover'));
  showQuote(hovered || pickedCard());
});
pauseOffscreen($('#companions'));

// ---------- Plan timeline ----------

const timeline = (() => {
  const card = $('[data-timeline]');
  const track = $('[data-tl-track]');
  const grid = $('[data-tl-grid]');
  const list = $('[data-tl-blocks]');
  const nowLine = $('[data-tl-now]');
  const tip = $('[data-tl-tip]');
  const hint = $('[data-tl-hint]');
  const summary = $('[data-tl-summary]');
  const count = $('[data-tl-count]');
  const addForm = $('[data-tl-add]');
  const addInput = $('[data-tl-input]');
  const timeFmt = new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' });
  const BREAK = 5;
  const MAX = 20;
  let uid = 0;
  let tasks = [
    { id: ++uid, name: 'Write the intro', min: 25 },
    { id: ++uid, name: 'Reply to design feedback', min: 15 },
    { id: ++uid, name: 'Review pull request', min: 45 },
    { id: ++uid, name: 'Inbox zero', min: 25 },
  ];
  let activeId = 3;
  let ppm = 1; // px per minute
  let dragging = null;

  const start = new Date();
  start.setSeconds(0, 0);
  start.setMinutes(Math.ceil((start.getMinutes() + 1) / 5) * 5);
  const at = (min) => new Date(start.getTime() + min * 60000);
  const totalMin = () => tasks.reduce((sum, t) => sum + t.min, 0) + Math.max(0, tasks.length - 1) * BREAK;
  const dur = (m) => (m >= 60 ? `${Math.floor(m / 60)}h${m % 60 ? ` ${m % 60}m` : ''}` : `${m}m`);

  function texts() {
    const total = totalMin();
    summary.textContent = tasks.length ? `Starts ${timeFmt.format(start)} · done by ${timeFmt.format(at(total))}` : 'Add a task to start a plan';
    const b = Math.max(0, tasks.length - 1);
    count.textContent = `${tasks.length} task${tasks.length === 1 ? '' : 's'} · ${b} break${b === 1 ? '' : 's'} · ${dur(total)}`;
  }

  function layout(scaleFromTrack = true) {
    const total = Math.max(totalMin(), 30);
    if (scaleFromTrack) ppm = track.clientWidth / total;
    // Grid labels every 30 minutes
    const marks = Math.floor(total / 30) + 1;
    grid.innerHTML = Array.from({ length: marks }, (_, i) => `<span style="left:${i * 30 * ppm}px">${timeFmt.format(at(i * 30))}</span>`).join('');
    let cursor = 0;
    $$('.tl-block', list).forEach((el) => {
      const min = Number(el.dataset.min);
      el.style.left = `${cursor * ppm + 2}px`;
      el.style.width = `${Math.max(min * ppm - 4, 8)}px`;
      el.classList.toggle('is-narrow', min * ppm < 150);
      cursor += min;
    });
    placeNow();
    placeHint();
  }

  function placeNow() {
    const mins = (Date.now() - start.getTime()) / 60000;
    const inside = mins >= 0 && mins <= totalMin();
    nowLine.hidden = !inside;
    if (inside) nowLine.style.left = `${mins * ppm}px`;
  }

  function placeHint() {
    const el = list.querySelector(`[data-id="${activeId}"]`);
    if (!el || hint.classList.contains('is-gone')) { hint.hidden = true; return; }
    hint.hidden = false;
    hint.style.left = `${el.offsetLeft + el.offsetWidth - 31}px`;
  }

  function render(newId) {
    list.innerHTML = '';
    tasks.forEach((t, i) => {
      if (i > 0) {
        const br = document.createElement('li');
        br.className = 'tl-block tl-break';
        br.dataset.min = BREAK;
        br.setAttribute('aria-label', '5-minute break');
        br.innerHTML = '<i class="ic ic-cup" aria-hidden="true"></i><span class="tl-break-label" aria-hidden="true"><b>+5</b>Break<br>Next</span>';
        if (t.id === newId) br.classList.add('is-new');
        list.append(br);
      }
      const li = document.createElement('li');
      li.className = `tl-block tl-task${t.id === activeId ? ' is-active' : ''}${t.id === newId ? ' is-new' : ''}`;
      li.dataset.min = t.min;
      li.dataset.id = t.id;
      li.tabIndex = 0;
      li.setAttribute('aria-label', `${t.name}, ${t.min} minutes. Left and right arrows change the length.`);
      li.innerHTML = `
        <span class="tl-name" title="Rename"></span>
        <span class="tl-min">${t.min} min</span>
        <button class="tl-remove" type="button" aria-label="Remove ${t.name.replace(/"/g, '&quot;')}"><i class="ic ic-close"></i></button>
        <span class="tl-steppers"><button type="button" data-step="-5" aria-label="5 minutes shorter"><i class="ic ic-minus"></i></button><button type="button" data-step="5" aria-label="5 minutes longer"><i class="ic ic-plus"></i></button></span>
        <span class="tl-handle" aria-hidden="true"></span>`;
      $('.tl-name', li).textContent = t.name;
      list.append(li);
    });
    texts();
    layout();
  }

  function resize(task, min, live = false) {
    task.min = clamp(Math.round(min / 5) * 5, 5, 120);
    const el = list.querySelector(`[data-id="${task.id}"]`);
    el.dataset.min = task.min;
    $('.tl-min', el).textContent = `${task.min} min`;
    el.setAttribute('aria-label', `${task.name}, ${task.min} minutes. Left and right arrows change the length.`);
    texts();
    layout(!live);
  }

  function showTip(el, from, to) {
    tip.textContent = `${from} → ${to} min · done by ${timeFmt.format(at(totalMin()))}`;
    tip.hidden = false;
    tip.style.left = `${el.offsetLeft + el.offsetWidth}px`;
  }

  list.addEventListener('pointerdown', (e) => {
    const handle = e.target.closest('.tl-handle');
    if (!handle) return;
    const el = handle.closest('.tl-task');
    const task = tasks.find((t) => `${t.id}` === el.dataset.id);
    e.preventDefault();
    handle.setPointerCapture(e.pointerId);
    activate(task.id);
    dragging = { task, el, x: e.clientX, min: task.min, scale: ppm };
    el.classList.add('is-dragging');
    hint.classList.add('is-gone');
    showTip(el, task.min, task.min);
  });
  list.addEventListener('pointermove', (e) => {
    if (!dragging) return;
    const { task, el, x, min, scale } = dragging;
    const next = clamp(Math.round((min + (e.clientX - x) / scale) / 5) * 5, 5, 120);
    if (next !== task.min) resize(task, next, true);
    showTip(el, min, task.min);
  });
  const endDrag = () => {
    if (!dragging) return;
    dragging.el.classList.remove('is-dragging');
    dragging = null;
    tip.hidden = true;
    layout();
  };
  list.addEventListener('pointerup', endDrag);
  list.addEventListener('pointercancel', endDrag);

  function activate(id) {
    activeId = id;
    $$('.tl-task', list).forEach((el) => el.classList.toggle('is-active', el.dataset.id === `${id}`));
  }

  list.addEventListener('click', (e) => {
    const el = e.target.closest('.tl-task');
    if (!el) return;
    const task = tasks.find((t) => `${t.id}` === el.dataset.id);
    if (e.target.closest('.tl-remove')) {
      tasks = tasks.filter((t) => t !== task);
      render();
      toast(`Removed “${task.name}”`);
      return;
    }
    const stepBtn = e.target.closest('[data-step]');
    if (stepBtn) { resize(task, task.min + Number(stepBtn.dataset.step)); return; }
    activate(task.id);
    const name = e.target.closest('.tl-name');
    if (name && name.contentEditable !== 'true') rename(name, task);
  });

  function rename(nameEl, task) {
    nameEl.contentEditable = 'true';
    nameEl.focus();
    getSelection().selectAllChildren(nameEl);
    const finish = (commit) => {
      nameEl.contentEditable = 'false';
      const value = nameEl.textContent.trim().slice(0, 40);
      if (commit && value) task.name = value;
      nameEl.textContent = task.name;
      nameEl.removeEventListener('keydown', onKey);
      nameEl.removeEventListener('blur', onBlur);
      nameEl.closest('.tl-task').setAttribute('aria-label', `${task.name}, ${task.min} minutes. Left and right arrows change the length.`);
    };
    const onKey = (e) => {
      e.stopPropagation();
      if (e.key === 'Enter') { e.preventDefault(); finish(true); nameEl.closest('.tl-task').focus(); }
      if (e.key === 'Escape') { finish(false); nameEl.closest('.tl-task').focus(); }
    };
    const onBlur = () => finish(true);
    nameEl.addEventListener('keydown', onKey);
    nameEl.addEventListener('blur', onBlur);
  }

  list.addEventListener('keydown', (e) => {
    const el = e.target.closest('.tl-task');
    if (!el || e.target !== el) return;
    const task = tasks.find((t) => `${t.id}` === el.dataset.id);
    if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
      e.preventDefault();
      activate(task.id);
      resize(task, task.min + (e.key === 'ArrowRight' ? 5 : -5));
      hint.classList.add('is-gone');
      announce(`${task.name}: ${task.min} minutes, done by ${timeFmt.format(at(totalMin()))}`);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      rename($('.tl-name', el), task);
    } else if (e.key === 'Delete' || e.key === 'Backspace') {
      e.preventDefault();
      tasks = tasks.filter((t) => t !== task);
      render();
    }
  });

  addForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const name = addInput.value.trim();
    if (!name) return;
    if (tasks.length >= MAX) { toast('A plan holds up to 20 tasks'); return; }
    const t = { id: ++uid, name: name.slice(0, 40), min: 25 };
    tasks.push(t);
    addInput.value = '';
    render(reduceMotion.matches ? undefined : t.id);
    announce(`Added ${t.name}, 25 minutes`);
  });

  $$('.tl-toggle button', card).forEach((b) => {
    b.addEventListener('click', () => {
      $$('.tl-toggle button', card).forEach((x) => x.setAttribute('aria-checked', String(x === b)));
      card.classList.toggle('is-choose', b.dataset.breaks === 'choose');
    });
  });

  addEventListener('resize', () => layout(), { passive: true });
  setInterval(placeNow, 30000);
  render();
  return { focusAdd: () => { scrollToEl($('#plans')); setTimeout(() => addInput.focus({ preventScroll: true }), reduceMotion.matches ? 0 : 450); } };
})();

// ---------- Lofi player ----------

const musicFocus = $('[data-music-focus]');
const music = (() => {
  const playBtn = $('[data-play]');
  const playIcon = $('[data-play-icon]');
  const vinyl = $('[data-vinyl]');
  const arm = $('[data-tonearm]');
  const eq = $('[data-eq]');
  const bars = $$('i', eq);
  const volume = $('[data-volume]');
  const note = $('.lofi-note');
  let audio, fadeGain, volGain, analyser, data, spin, eqRaf, fadeTimer;
  let angle = 0;
  eq.classList.add('is-idle');

  function ensure() {
    if (audio) return;
    audio = new Audio('assets/audio/lofi.m4a');
    audio.loop = true;
    audio.preload = 'auto';
    const ac = ctx();
    try {
      const src = ac.createMediaElementSource(audio);
      fadeGain = ac.createGain();
      volGain = ac.createGain();
      analyser = ac.createAnalyser();
      analyser.fftSize = 64;
      data = new Uint8Array(analyser.frequencyBinCount);
      fadeGain.gain.value = 0;
      volGain.gain.value = volume.value / 100;
      src.connect(fadeGain).connect(volGain).connect(analyser).connect(ac.destination);
    } catch {
      analyser = null;
      audio.volume = 0;
    }
  }

  function setVolume() {
    const v = volume.value / 100;
    volume.style.setProperty('--v', `${volume.value}%`);
    if (volGain) volGain.gain.value = v;
    else if (audio && store.musicPlaying) audio.volume = v;
  }
  volume.addEventListener('input', setVolume);

  function currentAngle() {
    const r = getComputedStyle(vinyl).rotate;
    return r && r !== 'none' ? parseFloat(r) : angle;
  }

  function drawEq() {
    if (!analyser) return;
    analyser.getByteFrequencyData(data);
    bars.forEach((b, i) => {
      const v = data[[1, 3, 5, 8, 12][i]] / 255;
      b.style.height = `${4 + v * 22}px`;
    });
    eqRaf = requestAnimationFrame(drawEq);
  }

  function ui(on) {
    playBtn.setAttribute('aria-pressed', String(on));
    playBtn.setAttribute('aria-label', on ? 'Pause lofi music' : 'Play lofi music');
    playIcon.className = `ic ${on ? 'ic-pause' : 'ic-play'}`;
    $$('[data-action="music"]').forEach((b) => {
      b.setAttribute('aria-pressed', String(on));
      b.setAttribute('aria-label', on ? 'Pause lofi music' : 'Play lofi music');
    });
  }

  function play() {
    if (store.musicPlaying) return;
    ensure();
    set({ musicPlaying: true });
    ui(true);
    note.classList.add('is-gone');
    clearTimeout(fadeTimer);
    audio.play().catch(() => { set({ musicPlaying: false }); ui(false); toast('Your browser blocked the audio. Press play again.'); });
    const ac = ctx();
    if (fadeGain && ac) {
      fadeGain.gain.cancelScheduledValues(ac.currentTime);
      fadeGain.gain.setValueAtTime(fadeGain.gain.value, ac.currentTime);
      fadeGain.gain.linearRampToValueAtTime(1, ac.currentTime + 1);
    } else if (audio) {
      audio.volume = volume.value / 100;
    }
    arm.classList.add('is-on');
    eq.classList.remove('is-idle');
    if (analyser) { cancelAnimationFrame(eqRaf); drawEq(); } else eq.classList.add('is-css');
    if (!reduceMotion.matches) {
      setTimeout(() => {
        if (!store.musicPlaying) return;
        spin?.cancel();
        angle = currentAngle();
        spin = vinyl.animate([{ rotate: `${angle}deg` }, { rotate: `${angle + 360}deg` }], { duration: 1800, iterations: Infinity, easing: 'linear' });
      }, 600);
    }
  }

  function pause() {
    if (!store.musicPlaying) return;
    set({ musicPlaying: false });
    ui(false);
    const ac = ctx();
    if (fadeGain && ac) {
      fadeGain.gain.cancelScheduledValues(ac.currentTime);
      fadeGain.gain.setValueAtTime(fadeGain.gain.value, ac.currentTime);
      fadeGain.gain.linearRampToValueAtTime(0, ac.currentTime + 0.4);
    }
    fadeTimer = setTimeout(() => audio?.pause(), 420);
    arm.classList.remove('is-on');
    cancelAnimationFrame(eqRaf);
    eq.classList.remove('is-css');
    eq.classList.add('is-idle');
    bars.forEach((b) => { b.style.height = ''; });
    if (spin) {
      angle = currentAngle();
      spin.cancel();
      spin = vinyl.animate([{ rotate: `${angle}deg` }, { rotate: `${angle + 70}deg` }], { duration: 800, easing: 'cubic-bezier(.2,.8,.2,1)', fill: 'forwards' });
      angle += 70;
    }
  }

  playBtn.addEventListener('click', () => (store.musicPlaying ? pause() : play()));
  return { play, pause, toggle: () => (store.musicPlaying ? pause() : play()) };
})();
pauseOffscreen($('#music'));

// ---------- End early ----------

(() => {
  const demo = $('[data-end-demo]');
  const panelEl = $('[data-end-panel]');
  const time = $('[data-end-time]');
  const square = $('[data-end-square]');
  const pauseB = $('[data-end-pause]');
  const restart = $('[data-end-restart]');
  const pulse = $('.pulse', square);
  const right = $('[data-end-right]');
  const hint = $('.end-hint', demo);
  const statusText = $('[data-end-status-text]');
  const status = $('[data-end-status]');
  const companion = $('[data-end-companion]');
  const progress = $('[data-end-progress]');
  let remaining = 24 * 60 + 38;
  let state = 'running';
  let visible = false;

  const setState = (s) => {
    state = s;
    panelEl.dataset.state = s;
    const ready = s === 'ready';
    restart.hidden = !ready;
    $('.p-dot', status).hidden = ready;
    statusText.textContent = ready ? 'Ready to focus' : s === 'paused' ? 'Paused' : 'Focusing · 25 min';
    pauseB.setAttribute('aria-label', s === 'paused' ? 'Resume' : 'Pause');
    $('.ic', pauseB).className = `ic ${s === 'paused' ? 'ic-play' : 'ic-pause'}`;
    render();
  };
  const render = () => {
    time.textContent = fmt(remaining);
    progress.style.width = `${clamp(0.25 + (1478 - remaining) / 1500, 0, 1) * 100}%`;
  };

  if ('IntersectionObserver' in window) new IntersectionObserver(([e]) => { visible = e.isIntersecting; demo.classList.toggle('paused-anim', !visible); }).observe(demo);
  setInterval(() => {
    if (!visible || document.hidden || (state !== 'running' && state !== 'confirm')) return;
    remaining = remaining > 0 ? remaining - 1 : 1500;
    render();
  }, 1000);

  square.addEventListener('click', () => {
    pulse.classList.add('is-done');
    hint.classList.add('is-gone');
    setState('confirm');
    right.classList.remove('is-replay');
    right.offsetWidth;
    if (!reduceMotion.matches) right.classList.add('is-replay');
    $('[data-end-keep]').focus({ preventScroll: true });
  });
  pauseB.addEventListener('click', () => setState(state === 'paused' ? 'running' : 'paused'));
  $('[data-end-keep]').addEventListener('click', () => {
    if (state === 'ready') { remaining = 1500; companion.src = companionSrc('plant', 3); }
    setState('running');
      });
  $('[data-end-confirm]').addEventListener('click', () => {
    pulse.classList.add('is-done');
    hint.classList.add('is-gone');
    remaining = 1500;
    companion.src = companionSrc('plant', 'done'); // the happy pose
    setState('ready');
    toast('Nothing wilted. Today’s flowers stay.');
  });
  restart.addEventListener('click', () => {
    remaining = 1500;
    companion.src = companionSrc('plant', 3);
    setState('running');
  });
  render();
})();

// ---------- Reveal on first view ----------

function revealOnView(el, cls = 'is-revealed', threshold = 0.3) {
  if (!('IntersectionObserver' in window) || reduceMotion.matches) return;
  el.classList.add('will-reveal');
  const io = new IntersectionObserver(([e]) => {
    if (!e.isIntersecting) return;
    el.classList.add(cls);
    io.disconnect();
  }, { threshold });
  io.observe(el);
}
revealOnView($('[data-promises]'));
revealOnView($('#facts'), 'is-revealed', 0.2);

// ---------- Garden week ----------

const garden = (() => {
  const el = $('[data-garden]');
  const days = $('[data-days]');
  const tip = $('[data-g-tip]');
  const NAMES = [['Mon', 'Monday', 3], ['Tue', 'Tuesday', 5], ['Wed', 'Wednesday', 2], ['Thu', 'Thursday', 4], ['Fri', 'Friday', 6], ['Sat', 'Saturday', 1], ['Sun', 'Today', 0]];
  const W = 1000;
  const centerX = (i) => 71 + i * 142.9;
  let revealed = false;
  let pending = 0;
  const dur = (n) => { const m = n * 25; return m >= 60 ? `${Math.floor(m / 60)}h${m % 60 ? ` ${m % 60}m` : ''}` : `${m}m`; };

  function col(i) {
    const [short, long, sample] = NAMES[i];
    const isToday = i === 6;
    const n = isToday ? store.todayFlowers : sample;
    const li = document.createElement('li');
    li.className = `day${isToday ? ' is-today' : ''}`;
    li.style.left = `${(centerX(i) / W) * 100}%`;
    li.tabIndex = 0;
    li.dataset.index = i;
    li.setAttribute('aria-label', `${isToday ? 'Today' : long}: ${n} session${n === 1 ? '' : 's'}, ${n ? dur(n) : 'no focus yet'}`);
    const stack = document.createElement('div');
    stack.className = 'day-stack';
    for (let k = 0; k < n; k++) stack.append(flower(k, i));
    if (isToday) {
      const slot = document.createElement('span');
      slot.className = 'slot';
      slot.dataset.slot = '';
      slot.style.setProperty('--i', n);
      stack.append(slot);
    }
    li.append(stack);
    li.insertAdjacentHTML('beforeend', `<span class="day-label">${short}</span>${isToday ? '<span class="hand today-hand" aria-hidden="true">today</span>' : ''}`);
    return li;
  }
  function flower(k, i) {
    const f = document.createElement('span');
    f.className = 'flower';
    // Position comes from CSS (--i, odd/even) so the stack scales with the layout.
    f.className = `flower ${k % 2 ? 'odd' : 'even'}`;
    f.style.setProperty('--i', k);
    f.style.setProperty('--delay', `${(i * 6 + k) * 40}ms`);
    return f;
  }
  function render() {
    days.innerHTML = '';
    NAMES.forEach((_, i) => days.append(col(i)));
    moveTip(3);
    // On small screens the resting tooltip covers the next day; show it on tap instead.
    if (matchMedia('(max-width: 767px)').matches) tip.classList.add('is-hidden');
  }
  function moveTip(i) {
    const li = days.children[i];
    if (!li) return;
    const [, long] = NAMES[i];
    const n = i === 6 ? store.todayFlowers : NAMES[i][2];
    $('strong', tip).textContent = i === 6 ? 'Today' : long;
    $('span', tip).textContent = `${n} session${n === 1 ? '' : 's'} · ${n ? dur(n) : '0m'}`;
    const stack = $('.day-stack', li).lastElementChild;
    const top = stack ? stack.offsetTop - tip.offsetHeight - 12 : 0;
    const half = tip.offsetWidth / 2 + 6;
    tip.style.left = `${clamp(li.offsetLeft + li.offsetWidth / 2, half, el.clientWidth - half)}px`;
    tip.style.top = `${Math.max(top, -10)}px`;
    tip.classList.remove('is-hidden');
  }
  days.addEventListener('pointerover', (e) => { const li = e.target.closest('.day'); if (li) moveTip(Number(li.dataset.index)); });
  days.addEventListener('focusin', (e) => { const li = e.target.closest('.day'); if (li) moveTip(Number(li.dataset.index)); });
  el.addEventListener('pointerleave', () => { if (!touchOnly.matches) moveTip(3); });

  function popToday(count) {
    const li = days.children[6];
    const stack = $('.day-stack', li);
    const slot = $('[data-slot]', li);
    for (let k = store.todayFlowers - count; k < store.todayFlowers; k++) {
      const f = flower(k, 0);
      f.style.setProperty('--delay', '0ms');
      f.classList.add('pop');
      stack.insertBefore(f, slot);
    }
    slot.style.setProperty('--i', store.todayFlowers);
    li.setAttribute('aria-label', `Today: ${store.todayFlowers} session${store.todayFlowers === 1 ? '' : 's'}, ${dur(store.todayFlowers)}`);
    moveTip(6);
  }

  function inView() {
    const r = el.getBoundingClientRect();
    return r.top < innerHeight && r.bottom > 0;
  }

  // A finished hero demo: fly a flower from the panel if both are on screen, else wait.
  function deliver() {
    const from = $('.view-complete .p-flowers .new', panel);
    const slot = $('[data-slot]', days);
    if (reduceMotion.matches || !from || !slot || !inView()) { pending++; if (inView()) flush(); return; }
    const a = from.getBoundingClientRect();
    const b = slot.getBoundingClientRect();
    const flyer = document.createElement('span');
    flyer.className = 'flyer';
    document.body.append(flyer);
    const p0 = { x: a.left + a.width / 2 - 18, y: a.top + a.height / 2 - 18 };
    const p2 = { x: b.left + b.width / 2 - 18, y: b.top + b.height / 2 - 18 };
    const p1 = { x: (p0.x + p2.x) / 2, y: Math.min(p0.y, p2.y) - 160 };
    const frames = Array.from({ length: 21 }, (_, i) => {
      const t = i / 20;
      const x = (1 - t) ** 2 * p0.x + 2 * (1 - t) * t * p1.x + t ** 2 * p2.x;
      const y = (1 - t) ** 2 * p0.y + 2 * (1 - t) * t * p1.y + t ** 2 * p2.y;
      return { transform: `translate(${x}px, ${y}px) rotate(${t * 240}deg) scale(${0.6 + 0.4 * Math.sin(t * Math.PI) + 0.5 * t})`, offset: t };
    });
    flyer.animate(frames, { duration: 900, easing: 'cubic-bezier(.4,0,.2,1)' }).finished.then(() => {
      flyer.remove();
      popToday(1);
    });
  }
  function flush() {
    if (!pending) return;
    const n = pending;
    pending = 0;
    popToday(n);
  }

  render();
  if ('IntersectionObserver' in window && !reduceMotion.matches) {
    el.classList.add('will-reveal');
    new IntersectionObserver(([e]) => {
      if (!e.isIntersecting) return;
      if (!revealed) {
        revealed = true;
        $$('.flower', days).forEach((f) => f.classList.add('pop'));
        el.classList.remove('will-reveal');
      }
      flush();
    }, { threshold: 0.35 }).observe(el);
  } else {
    revealed = true;
  }
  return { deliver };
})();

// ---------- Keyboard ----------

(() => {
  const caps = $$('.keycap');
  $$('[data-mod]').forEach((m) => { if (!isMac) m.textContent = 'Ctrl'; });
  if (!isMac) {
    $$('.keycap[aria-label]').forEach((k) => k.setAttribute('aria-label', k.getAttribute('aria-label').replace('Command', 'Control')));
  }
  const capsFor = (key) => caps.filter((c) => c.dataset.key === key);
  const press = (list, on) => list.forEach((c) => c.classList.toggle('is-pressed', on));
  const flash = (list) => { press(list, true); setTimeout(() => press(list, false), 160); };

  const run = {
    space: toggle,
    p: () => timeline.focusAdd(),
    m: () => { setCompact(!compact); if (!heroVisible) scrollToEl($('#try')); },
    '.': () => { if (store.demo === 'running' || store.demo === 'paused') { openConfirm(); if (!heroVisible) scrollToEl($('#try')); } else toast(`Start the demo first, then ${isMac ? '⌘' : 'Ctrl'}. asks to end it`); },
    ',': () => toast('Settings live in the app'),
  };

  const typing = (t) => t instanceof Element && t.closest('input, textarea, select, [contenteditable="true"]');
  addEventListener('keydown', (e) => {
    if (typing(e.target)) return;
    const mod = isMac ? e.metaKey : e.ctrlKey;
    if (e.key === ' ' && !mod && !e.altKey) {
      if (e.target instanceof Element && e.target.closest('button, a, [role="radio"], [tabindex="0"]')) return; // let focused controls handle Space
      e.preventDefault();
      press(capsFor('space'), true);
      if (!e.repeat) run.space();
      return;
    }
    const k = e.key.toLowerCase();
    if (mod && !e.altKey && !e.shiftKey && k in run && k !== 'space') {
      e.preventDefault();
      press(capsFor(k), true);
      if (!e.repeat) run[k]();
    }
  });
  addEventListener('keyup', (e) => {
    if (e.key === 'Meta' || e.key === 'Control') { press(caps, false); return; }
    if (e.key === ' ') press(capsFor('space'), false);
    const k = e.key.toLowerCase();
    if (k in run) press(capsFor(k), false);
  });
  addEventListener('blur', () => press(caps, false));

  caps.forEach((c) => c.addEventListener('click', () => {
    const k = c.dataset.key;
    flash(capsFor(k));
    run[k]();
  }));
})();

// ---------- Final CTA: fireflies pause off-screen, magnetic Download ----------

pauseOffscreen($('[data-cta]'));
(() => {
  const btn = $('[data-magnetic]');
  let raf = 0;
  let near = false;
  addEventListener('pointermove', (e) => {
    if (!finePointer.matches || reduceMotion.matches || raf) return;
    raf = requestAnimationFrame(() => {
      raf = 0;
      const r = btn.getBoundingClientRect();
      const cx = r.left + r.width / 2;
      const cy = r.top + r.height / 2;
      const dx = Math.max(r.left - e.clientX, 0, e.clientX - r.right);
      const dy = Math.max(r.top - e.clientY, 0, e.clientY - r.bottom);
      const inside = Math.hypot(dx, dy) < 80;
      if (inside) {
        btn.classList.add('is-near');
        btn.style.setProperty('--mx', `${clamp((e.clientX - cx) * 0.12, -8, 8)}px`);
        btn.style.setProperty('--my', `${clamp((e.clientY - cy) * 0.18, -8, 8)}px`);
      } else if (near) {
        btn.classList.remove('is-near');
        btn.style.setProperty('--mx', '0px');
        btn.style.setProperty('--my', '0px');
      }
      near = inside;
    });
  }, { passive: true });
})();

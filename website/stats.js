// Visit and download counts for /admin, kept in the D1 database bound as STATS.
// No cookies and no IPs are stored: a visitor is a hash of IP + user agent with a salt that
// changes every day, so one person counts once per day and can't be followed across days.

const TIME_ZONE = 'Asia/Tashkent';
const BOTS = /bot|crawl|spider|slurp|preview|facebookexternalhit|embedly|curl|wget|python|httpclient|go-http|headless|lighthouse|pingdom|uptime|monitor/i;
const OWN_HOSTS = /(^|\.)bemellow\.cc$|\.workers\.dev$/;

const dayOf = (date = new Date()) =>
  new Intl.DateTimeFormat('en-CA', { timeZone: TIME_ZONE, year: 'numeric', month: '2-digit', day: '2-digit' }).format(date);

async function visitorId(request, env, day) {
  const ip = request.headers.get('cf-connecting-ip') || '';
  const ua = request.headers.get('user-agent') || '';
  const data = new TextEncoder().encode(`${env.STATS_SALT || 'mellow'}|${day}|${ip}|${ua}`);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', data));
  return [...digest.slice(0, 8)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function isHuman(request) {
  const ua = request.headers.get('user-agent') || '';
  return ua.length > 0 && !BOTS.test(ua);
}

function externalReferrer(request) {
  try {
    const host = new URL(request.headers.get('referer') || '').hostname.replace(/^www\./, '');
    return host && !OWN_HOSTS.test(host) ? host : null;
  } catch {
    return null;
  }
}

// A page view of the landing page.
export async function recordVisit(request, env) {
  if (!env.STATS || request.method !== 'GET' || !isHuman(request)) return;
  const day = dayOf();
  const id = await visitorId(request, env, day);
  await env.STATS.batch([
    env.STATS.prepare('INSERT INTO daily (day, pageviews) VALUES (?1, 1) ON CONFLICT(day) DO UPDATE SET pageviews = pageviews + 1').bind(day),
    env.STATS.prepare('INSERT OR IGNORE INTO visitors (day, id, country, referrer) VALUES (?1, ?2, ?3, ?4)')
      .bind(day, id, request.cf?.country || null, externalReferrer(request)),
  ]);
}

// A started DMG download. Resumed downloads (Range not starting at 0) aren't counted again.
export async function recordDownload(request, env) {
  if (!env.STATS || request.method !== 'GET' || !isHuman(request)) return;
  const range = request.headers.get('range');
  if (range && !/^bytes=0-/.test(range)) return;
  const day = dayOf();
  const id = await visitorId(request, env, day);
  await env.STATS.batch([
    env.STATS.prepare('INSERT INTO daily (day, downloads) VALUES (?1, 1) ON CONFLICT(day) DO UPDATE SET downloads = downloads + 1').bind(day),
    env.STATS.prepare('INSERT OR IGNORE INTO downloaders (day, id, country) VALUES (?1, ?2, ?3)')
      .bind(day, id, request.cf?.country || null),
  ]);
}

// ---------- /admin ----------

function unauthorized() {
  return new Response('Login required', {
    status: 401,
    headers: { 'www-authenticate': 'Basic realm="Mellow admin", charset="UTF-8"', 'cache-control': 'no-store' },
  });
}

async function sameText(a, b) {
  const enc = new TextEncoder();
  const [x, y] = await Promise.all([crypto.subtle.digest('SHA-256', enc.encode(a)), crypto.subtle.digest('SHA-256', enc.encode(b))]);
  return crypto.subtle.timingSafeEqual(x, y);
}

async function authorized(request, env) {
  const header = request.headers.get('authorization') || '';
  if (!header.startsWith('Basic ')) return false;
  let decoded;
  try { decoded = atob(header.slice(6)); } catch { return false; }
  const password = decoded.slice(decoded.indexOf(':') + 1);
  return sameText(password, env.ADMIN_PASSWORD);
}

const RANGES = { 7: '7 days', 30: '30 days', 90: '90 days' };

export async function adminPage(request, env) {
  const headers = { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store', 'x-robots-tag': 'noindex, nofollow' };
  if (!env.ADMIN_PASSWORD) {
    return new Response('Admin is not set up yet: run `npx wrangler secret put ADMIN_PASSWORD` in website/.', { status: 503, headers: { ...headers, 'content-type': 'text/plain; charset=utf-8' } });
  }
  if (!(await authorized(request, env))) return unauthorized();
  if (!env.STATS) return new Response('The STATS database is not bound.', { status: 500, headers });

  const requested = Number(new URL(request.url).searchParams.get('days'));
  const days = RANGES[requested] ? requested : 30;
  const today = dayOf();
  const from = dayOf(new Date(Date.now() - (days - 1) * 86400000));

  const q = (sql, ...args) => env.STATS.prepare(sql).bind(...args);
  const [daily, visitorsByDay, downloadersByDay, totals, countries, referrers, latest] = await Promise.all([
    q('SELECT day, pageviews, downloads FROM daily WHERE day >= ?1 ORDER BY day', from).all(),
    q('SELECT day, COUNT(*) AS n FROM visitors WHERE day >= ?1 GROUP BY day', from).all(),
    q('SELECT day, COUNT(*) AS n FROM downloaders WHERE day >= ?1 GROUP BY day', from).all(),
    q(`SELECT (SELECT COALESCE(SUM(downloads), 0) FROM daily) AS downloads,
              (SELECT COUNT(*) FROM downloaders) AS downloaders,
              (SELECT COUNT(*) FROM visitors) AS visitors,
              (SELECT MIN(day) FROM daily) AS since`).first(),
    q(`SELECT country, COUNT(*) AS n FROM visitors WHERE day >= ?1 AND country IS NOT NULL
       GROUP BY country ORDER BY n DESC LIMIT 8`, from).all(),
    q(`SELECT referrer, COUNT(*) AS n FROM visitors WHERE day >= ?1 AND referrer IS NOT NULL
       GROUP BY referrer ORDER BY n DESC LIMIT 8`, from).all(),
    env.DOWNLOADS?.get('latest.json').then((o) => (o ? o.json() : null)).catch(() => null),
  ]);

  const byDay = new Map();
  for (let i = days - 1; i >= 0; i--) {
    const day = dayOf(new Date(Date.now() - i * 86400000));
    byDay.set(day, { day, pageviews: 0, downloads: 0, visitors: 0, downloaders: 0 });
  }
  for (const r of daily.results) Object.assign(byDay.get(r.day) || {}, { pageviews: r.pageviews, downloads: r.downloads });
  for (const r of visitorsByDay.results) if (byDay.has(r.day)) byDay.get(r.day).visitors = r.n;
  for (const r of downloadersByDay.results) if (byDay.has(r.day)) byDay.get(r.day).downloaders = r.n;
  const series = [...byDay.values()];
  const sum = (key) => series.reduce((s, d) => s + d[key], 0);
  const t = byDay.get(today) || { visitors: 0, downloads: 0, downloaders: 0, pageviews: 0 };

  return new Response(render({
    days, series, today: t, version: latest?.version,
    range: { visitors: sum('visitors'), pageviews: sum('pageviews'), downloads: sum('downloads'), downloaders: sum('downloaders') },
    totals, countries: countries.results, referrers: referrers.results,
  }), { headers });
}

// ---------- page ----------

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const num = (n) => new Intl.NumberFormat('en-US').format(n || 0);
const people = (n) => `${num(n)} ${n === 1 ? 'person' : 'people'}`;
const pct = (a, b) => (b ? `${Math.round((a / b) * 1000) / 10}%` : '—');
const flag = (cc) => (/^[A-Z]{2}$/.test(cc) ? String.fromCodePoint(...[...cc].map((c) => 127397 + c.charCodeAt(0))) : '🏳️');
const countryName = (cc) => { try { return new Intl.DisplayNames(['en'], { type: 'region' }).of(cc); } catch { return cc; } };
const shortDay = (day) => new Date(`${day}T12:00:00Z`).toLocaleDateString('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' });

function chart(series) {
  const w = 1000, h = 220, pad = 24;
  const max = Math.max(1, ...series.map((d) => Math.max(d.visitors, d.downloads)));
  const step = (w - pad * 2) / series.length;
  const bar = Math.max(2, Math.min(14, step / 2 - 2));
  const y = (v) => h - pad - (v / max) * (h - pad * 2);
  const bars = series.map((d, i) => {
    const x = pad + i * step + step / 2;
    const tip = `${shortDay(d.day)}: ${d.visitors} visitors, ${d.downloads} downloads`;
    return `<g><title>${esc(tip)}</title>
      <rect class="b-visit" x="${(x - bar - 1).toFixed(1)}" y="${y(d.visitors).toFixed(1)}" width="${bar.toFixed(1)}" height="${(h - pad - y(d.visitors)).toFixed(1)}" rx="2"/>
      <rect class="b-down" x="${(x + 1).toFixed(1)}" y="${y(d.downloads).toFixed(1)}" width="${bar.toFixed(1)}" height="${(h - pad - y(d.downloads)).toFixed(1)}" rx="2"/></g>`;
  }).join('');
  const labelEvery = Math.ceil(series.length / 8);
  // Count from the end so today is always labelled and labels never crowd each other.
  const labels = series.map((d, i) => ((series.length - 1 - i) % labelEvery === 0
    ? `<text x="${(pad + i * step + step / 2).toFixed(1)}" y="${h - 4}">${esc(shortDay(d.day))}</text>` : '')).join('');
  return `<svg viewBox="0 0 ${w} ${h}" role="img" aria-label="Daily visitors and downloads">
    <line class="axis" x1="${pad}" x2="${w - pad}" y1="${h - pad}" y2="${h - pad}"/>
    <text class="max" x="${pad}" y="${pad - 8}">${num(max)}</text>${bars}${labels}</svg>`;
}

function list(rows, label, empty) {
  if (!rows.length) return `<p class="empty">${empty}</p>`;
  const top = rows[0].n;
  return `<ul class="list">${rows.map((r) => `<li><span>${label(r)}</span><span class="n">${num(r.n)}</span>
    <i style="width:${Math.max(4, (r.n / top) * 100).toFixed(0)}%"></i></li>`).join('')}</ul>`;
}

function render(s) {
  const card = (title, value, sub) => `<div class="card"><p class="label">${title}</p><p class="value">${value}</p><p class="sub">${sub}</p></div>`;
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Mellow admin</title>
<link rel="icon" href="/favicon-32.png">
<style>
:root { --bg:#FBF8F4; --card:#fff; --ink:#1C1C1E; --ink2:#6E6E73; --line:rgba(0,0,0,.08); --green:#1F8A3F; --pink:#E8588A; --track:rgba(0,0,0,.05); }
@media (prefers-color-scheme: dark) { :root { --bg:#141416; --card:#1F1F22; --ink:#F5F5F7; --ink2:#A1A1A6; --line:rgba(255,255,255,.1); --green:#30D158; --pink:#FF7EA8; --track:rgba(255,255,255,.07); } }
* { box-sizing:border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:15px/1.45 -apple-system,BlinkMacSystemFont,system-ui,sans-serif; -webkit-font-smoothing:antialiased; }
main { max-width:1100px; margin:0 auto; padding:32px 16px 64px; }
header { display:flex; align-items:center; justify-content:space-between; gap:16px; flex-wrap:wrap; margin-bottom:24px; }
.brand { display:flex; align-items:center; gap:10px; font:700 20px ui-rounded,"SF Pro Rounded",system-ui; }
.brand img { width:28px; height:28px; }
.brand small { font:500 13px -apple-system,system-ui; color:var(--ink2); margin-left:4px; }
.ranges { display:flex; gap:4px; padding:3px; border-radius:999px; background:var(--track); }
.ranges a { padding:6px 14px; border-radius:999px; color:var(--ink2); text-decoration:none; font-size:13px; font-weight:500; }
.ranges a[aria-current] { background:var(--card); color:var(--ink); box-shadow:0 1px 3px rgba(0,0,0,.12); }
.cards { display:grid; grid-template-columns:repeat(4,1fr); gap:12px; }
.card, .panel { background:var(--card); border:1px solid var(--line); border-radius:18px; padding:18px 20px; }
.label { margin:0; font-size:13px; color:var(--ink2); font-weight:500; }
.value { margin:6px 0 2px; font:600 34px/1.1 ui-rounded,"SF Pro Rounded",system-ui; letter-spacing:-.02em; font-variant-numeric:tabular-nums; }
.sub { margin:0; font-size:13px; color:var(--ink2); }
.panel { margin-top:12px; }
.panel h2 { margin:0 0 12px; font-size:15px; }
.chart { overflow-x:auto; }
.legend { display:flex; gap:16px; font-size:13px; color:var(--ink2); margin:-4px 0 8px; }
.legend i { display:inline-block; width:10px; height:10px; border-radius:3px; margin-right:6px; vertical-align:-1px; }
svg { width:100%; height:auto; display:block; }
svg text { fill:var(--ink2); font-size:11px; text-anchor:middle; }
svg .max { text-anchor:start; }
.axis { stroke:var(--line); }
.b-visit, .lg-visit { fill:var(--green); background:var(--green); opacity:.85; }
.b-down, .lg-down { fill:var(--pink); background:var(--pink); }
.cols { display:grid; grid-template-columns:1fr 1fr; gap:12px; }
.list { list-style:none; margin:0; padding:0; }
.list li { position:relative; display:flex; justify-content:space-between; padding:7px 10px; border-radius:8px; overflow:hidden; }
.list li i { position:absolute; inset:0 auto 0 0; background:var(--track); border-radius:8px; z-index:0; }
.list li span { position:relative; z-index:1; }
.list .n { font-variant-numeric:tabular-nums; color:var(--ink2); }
.empty { color:var(--ink2); font-size:14px; margin:0; }
footer { margin-top:20px; font-size:12px; color:var(--ink2); }
@media (max-width:820px) { .cards { grid-template-columns:repeat(2,1fr); } .cols { grid-template-columns:1fr; } .chart svg { min-width:640px; } }
@media (max-width:420px) { .value { font-size:28px; } }
</style>
</head>
<body>
<main>
  <header>
    <div class="brand"><img src="/assets/logo.png" alt="">Mellow <small>admin${s.version ? ` · v${esc(s.version)} live` : ''}</small></div>
    <nav class="ranges" aria-label="Range">${Object.entries(RANGES).map(([d, l]) =>
      `<a href="?days=${d}"${Number(d) === s.days ? ' aria-current="page"' : ''}>${l}</a>`).join('')}</nav>
  </header>

  <section class="cards">
    ${card('Visitors today', num(s.today.visitors), `${num(s.today.pageviews)} page views`)}
    ${card(`Visitors · ${RANGES[s.days]}`, num(s.range.visitors), `${num(s.range.pageviews)} page views`)}
    ${card('Downloads today', num(s.today.downloads), people(s.today.downloaders))}
    ${card(`Downloads · ${RANGES[s.days]}`, num(s.range.downloads), `${people(s.range.downloaders)} · ${pct(s.range.downloaders, s.range.visitors)} of visitors`)}
  </section>

  <section class="panel">
    <h2>Every day</h2>
    <div class="legend"><span><i class="lg-visit"></i>Visitors</span><span><i class="lg-down"></i>Downloads</span></div>
    <div class="chart">${chart(s.series)}</div>
  </section>

  <section class="cols">
    <div class="panel"><h2>Countries</h2>${list(s.countries, (r) => `${flag(r.country)} ${esc(countryName(r.country))}`, 'No visitors yet.')}</div>
    <div class="panel"><h2>Came from</h2>${list(s.referrers, (r) => esc(r.referrer), 'No links from other sites yet.')}</div>
  </section>

  <section class="panel">
    <h2>All time${s.totals?.since ? ` · since ${esc(shortDay(s.totals.since))}` : ''}</h2>
    <p class="sub">${num(s.totals?.visitors)} visitors · ${num(s.totals?.downloads)} downloads by ${people(s.totals?.downloaders || 0)}</p>
  </section>

  <footer>Days run on Tashkent time. A visitor is counted once per day (no cookies, no IPs stored), so a range adds up daily visitors. Bots and resumed downloads aren't counted.</footer>
</main>
<script>for (const el of document.querySelectorAll('.chart')) el.scrollLeft = el.scrollWidth; // newest days first on small screens</script>
</body>
</html>`;
}

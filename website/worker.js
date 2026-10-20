// Serves the static site, the DMG and latest.json from R2 under /download/, and GitHub
// stats for the nav button under /api/github.
// Same-origin downloads keep working on every domain this Worker answers on,
// including ones where download.bemellow.cc is unreachable.
const FILES = {
  '/download/Mellow.dmg': 'Mellow.dmg',
  '/download/latest.json': 'latest.json',
};

// Stars and watchers for the nav button, cached for ten minutes. GitHub's API often refuses
// Workers (shared IPs run through the unauthenticated limit fast), so shields.io, which keeps its
// own cache of GitHub's numbers, is the fallback.
const REPO = 'oybekruziev/mellow';

async function fromGitHub() {
  const res = await fetch(`https://api.github.com/repos/${REPO}`, {
    headers: { 'user-agent': 'bemellow.cc', accept: 'application/vnd.github+json' },
    signal: AbortSignal.timeout(4000),
  });
  if (!res.ok) throw new Error(`github ${res.status}`);
  const repo = await res.json();
  return { stars: repo.stargazers_count, watchers: repo.subscribers_count };
}

async function fromShields() {
  const read = async (metric) => {
    const res = await fetch(`https://img.shields.io/github/${metric}/${REPO}.json`, { signal: AbortSignal.timeout(4000) });
    if (!res.ok) throw new Error(`shields ${res.status}`);
    const { value } = await res.json();
    return /^\d+$/.test(value) ? Number(value) : value; // large counts come as "1.2k"
  };
  const [stars, watchers] = await Promise.all([read('stars'), read('watchers')]);
  return { stars, watchers };
}

async function githubStats(ctx) {
  const cache = caches.default;
  const cacheKey = new Request('https://bemellow.cc/api/github');
  const cached = await cache.match(cacheKey);
  if (cached) return cached;
  let stats;
  try {
    stats = await fromGitHub();
  } catch {
    try { stats = await fromShields(); } catch { return Response.json({ error: 'unavailable' }, { status: 502 }); }
  }
  const body = Response.json(stats, { headers: { 'cache-control': 'public, max-age=600' } });
  ctx.waitUntil(cache.put(cacheKey, body.clone()));
  return body;
}

export default {
  async fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);
    if (pathname === '/api/github') return githubStats(ctx);
    const key = FILES[pathname];
    if (!key) return env.ASSETS.fetch(request);
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method not allowed', { status: 405, headers: { allow: 'GET, HEAD' } });
    }

    const object = request.method === 'HEAD'
      ? await env.DOWNLOADS.head(key)
      : await env.DOWNLOADS.get(key, { range: request.headers, onlyIf: request.headers });
    if (!object) return new Response('Not found', { status: 404 });

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    headers.set('accept-ranges', 'bytes');
    if (key === 'Mellow.dmg') headers.set('content-disposition', 'attachment; filename="Mellow.dmg"');

    if (!('body' in object)) {
      // HEAD, or a conditional GET that matched (If-None-Match etc.)
      headers.set('content-length', String(object.size));
      return new Response(null, { status: request.method === 'HEAD' ? 200 : 304, headers });
    }
    if (request.headers.has('range') && object.range && 'offset' in object.range) {
      const { offset, length = object.size - offset } = object.range;
      headers.set('content-range', `bytes ${offset}-${offset + length - 1}/${object.size}`);
      return new Response(object.body, { status: 206, headers });
    }
    return new Response(object.body, { headers });
  },
};

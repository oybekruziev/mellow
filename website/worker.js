// Serves the static site, plus the DMG and latest.json from R2 under /download/.
// Same-origin downloads keep working on every domain this Worker answers on,
// including ones where download.bemellow.cc is unreachable.
const FILES = {
  '/download/Mellow.dmg': 'Mellow.dmg',
  '/download/latest.json': 'latest.json',
};

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
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

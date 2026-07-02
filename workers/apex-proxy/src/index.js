// Apex reverse proxy for ringdrill.app (ADR-0039 Phase 3).
//
// Why this exists:
// Cloudflare Pages serves the apex, but Pages `_redirects` cannot 200-proxy to
// an external origin — that only works on Netlify. So the dynamic apex paths
// that must keep the `ringdrill.app` URL (share/install links, .drill
// downloads, brief links, and the legacy `/.netlify/functions/*` calls from
// cached PWAs) fell through to the Astro landing page after the DNS flip.
//
// This Worker restores the proxy. It is bound (see wrangler.toml `routes`)
// ONLY to the path prefixes that need the API origin; every other path stays
// on the Pages site because Worker routes take precedence over Pages only for
// the routes they match.
//
// It forwards the request verbatim to api.ringdrill.app and returns the
// upstream response unchanged. `redirect: "manual"` lets the `/brief/*` 302
// pass through to the browser instead of being followed here, and preserves
// upstream status, Content-Type and Content-Disposition (so the .drill
// download and its attachment header survive).

const API_ORIGIN = 'api.ringdrill.app';

export default {
  async fetch(request) {
    const url = new URL(request.url);
    url.hostname = API_ORIGIN;
    url.protocol = 'https:';
    url.port = '';

    // Copies method, headers and body from the incoming request onto the new
    // URL. The runtime sets the Host header from the URL when the subrequest
    // is dispatched, so the upstream sees Host: api.ringdrill.app.
    const proxied = new Request(url, request);

    return fetch(proxied, { redirect: 'manual' });
  },
};

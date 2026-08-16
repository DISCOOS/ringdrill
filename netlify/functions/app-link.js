import { appOrigin, corsPreflight, pwaOrigin, withCors } from "./lib/shared.js";

/**
 * The browser fallback for the two links RingDrill emails (ADR-0080).
 *
 * `/s/<challengeId>/<code>` signs in; `/j/<token>` joins from an invitation.
 * Both are registered as universal links on the apex, so **on a phone with the
 * app installed this function is never reached** — the operating system takes
 * the tap straight to the app. What lands here is everything else: a desktop
 * browser, a phone without the app, and a mail scanner.
 *
 * **It redirects, it does not act.** The credential is handed to the PWA, whose
 * own route decides what to do with it, and that route waits for a button in a
 * browser. Nothing is redeemed by this request, which is the whole point:
 * corporate mail security and link-preview generators fetch URLs before anybody
 * sees them, and a challenge is single-use. A function that redeemed on `GET`
 * would spend the sign-in on the scanner, and the person would be told their
 * link was "unknown or used" — a failure they cannot reproduce and we cannot
 * see.
 *
 * A redirect rather than a rendered page, which is where this departs from
 * `/i/*`'s shape. The PWA already owns both routes and both are already
 * localised; serving a second, server-rendered copy of the same two screens
 * would be two places to keep saying the same thing in two languages.
 */

const json = (body, status) =>
    new Response(JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
    });

/**
 * `/s/<challengeId>/<code>` and `/j/<token>`, with the path taken from the
 * request rather than a query parameter, so the apex URL and the PWA URL are
 * the same shape and a reader can see they are the same link.
 */
export function parseLinkPath(pathname) {
    const clean = String(pathname ?? "").replace(/^\/+|\/+$/g, "");
    const parts = clean.split("/").filter(Boolean);

    // Tolerate the `/.netlify/functions/app-link/...` form, which Netlify serves
    // whether or not a redirect names it.
    const at = parts.indexOf("app-link");
    const segs = at >= 0 ? parts.slice(at + 1) : parts;

    if (segs[0] === "s" && segs.length === 3) {
        return { kind: "s", path: `/s/${segs[1]}/${segs[2]}` };
    }
    if (segs[0] === "j" && segs.length === 2) {
        return { kind: "j", path: `/j/${segs[1]}` };
    }
    return null;
}

export function createHandler({ env = process.env } = {}) {
    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        const parsed = parseLinkPath(new URL(request.url).pathname);
        if (!parsed) return withCors(request, json({ error: "not_found" }, 404));

        // Both origins are required rather than defaulted, for the reason
        // appOrigin documents: a hardcoded host outlives the move it was meant
        // to survive. `appOrigin` is read here only to fail loudly in the same
        // place, so a misconfigured deploy is caught by the first person who
        // taps a link rather than by the first person who cannot sign in.
        appOrigin(env);
        const target = `${pwaOrigin(env)}${parsed.path}`;

        return withCors(request, new Response(null, {
            status: 302,
            headers: {
                location: target,
                // Never cached, anywhere. The URL contains a single-use
                // credential, and a cached redirect is a copy of it sitting in
                // somebody's proxy.
                "cache-control": "no-store",
                referrer_policy: "no-referrer",
            },
        }));
    };
}

export default createHandler();

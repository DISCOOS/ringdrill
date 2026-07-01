import {
    getSlugRecord as _getSlugRecord,
    readJson as _readJson,
    keysFor,
    corsPreflight,
    withCors,
} from "./_shared.js";

const STRINGS = {
    nb: {
        openOnWeb:      "Åpne planen",
        download:       "Last ned .drill",
        notFound:       "Ikke funnet",
        exerciseUnit:   "øvelse",
        exercisePlural: "øvelser",
        kicker:         "Delt øvelsesplan",
        updated:        "Oppdatert",
        tagline:        "Rullering uten regneark",
        about:          "RingDrill planlegger og kjører rullerende øvelser. Åpne planen for å se poster, lag og tider.",
        moreAt:         "Mer på",
    },
    en: {
        openOnWeb:      "Open the plan",
        download:       "Download .drill",
        notFound:       "Not found",
        exerciseUnit:   "exercise",
        exercisePlural: "exercises",
        kicker:         "Shared drill plan",
        updated:        "Updated",
        tagline:        "Rotation without spreadsheets",
        about:          "RingDrill plans and runs rotating drills. Open the plan to see stations, teams and timings.",
        moreAt:         "More at",
    },
};

export function pickLocale(request) {
    const url = new URL(request.url);
    const lang = url.searchParams.get("lang");
    if (lang === "nb" || lang === "en") return lang;

    const accept = request.headers.get("accept-language") ?? "";
    if (!accept) return "nb";

    const items = accept.split(",").map(s => {
        const parts = s.trim().split(";");
        const tag = parts[0].trim().toLowerCase();
        const qPart = parts.find(p => p.trim().startsWith("q="));
        const q = qPart ? parseFloat(qPart.split("=")[1]) : 1.0;
        return { tag, q };
    }).sort((a, b) => b.q - a.q);

    for (const { tag } of items) {
        if (tag === "nb" || tag.startsWith("nb-")) return "nb";
        if (tag === "en" || tag.startsWith("en-")) return "en";
    }
    return "nb";
}

function esc(str) {
    return String(str ?? "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

export function renderHtml({ slug, meta, locale }) {
    const s = STRINGS[locale] ?? STRINGS.nb;
    const ogLocale = locale === "en" ? "en_US" : "nb_NO";
    const name = meta.name ?? slug;
    const tags = Array.isArray(meta.tags) ? meta.tags : [];
    const tagStr = tags.join(", ");
    const description = [name, tagStr].filter(Boolean).join(" · ");
    const ogDesc = description.length > 200 ? description.slice(0, 199) + "…" : description;
    const canonical = `https://ringdrill.app/i/${slug}`;
    const webUrl = `https://web.ringdrill.app/i/${slug}`;
    const downloadUrl = `https://ringdrill.app/d/${slug}`;

    const tagsHtml = tags.length
        ? `<p class="tags">${tags.map(t => `<span>${esc(t)}</span>`).join(" ")}</p>`
        : "";
    const countLine = meta.exerciseCount != null
        ? `<p class="meta">${meta.exerciseCount} ${meta.exerciseCount !== 1 ? s.exercisePlural : s.exerciseUnit}</p>`
        : "";

    return `<!DOCTYPE html>
<html lang="${locale}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(name)} · RingDrill</title>
<meta name="description" content="${esc(ogDesc)}">
<meta property="og:title" content="${esc(name)}">
<meta property="og:description" content="${esc(ogDesc)}">
<meta property="og:url" content="${canonical}">
<meta property="og:type" content="website">
<meta property="og:locale" content="${ogLocale}">
<link rel="canonical" href="${canonical}">
<link rel="alternate" hreflang="nb" href="${canonical}">
<link rel="alternate" hreflang="en" href="${canonical}">
<link rel="alternate" hreflang="x-default" href="${canonical}">
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:system-ui,sans-serif;background:#fff;color:#334155;line-height:1.6;padding:2rem 1rem}
main{max-width:640px;margin:0 auto}
h1{color:#0f172a;font-size:1.75rem;margin-bottom:.5rem}
.tags{color:#64748b;font-size:.875rem;margin-bottom:.5rem}
.tags span+span::before{content:"·";margin:0 .25rem}
.meta{color:#64748b;font-size:.875rem;margin-bottom:1.5rem}
.actions{display:flex;flex-wrap:wrap;gap:.75rem;margin:1.25rem 0}
.btn{display:inline-block;padding:.625rem 1.25rem;border-radius:.375rem;font-size:.9375rem;font-weight:600;text-decoration:none;text-align:center}
.btn-primary{background:#0f172a;color:#fff}
.btn-secondary{background:#f1f5f9;color:#0f172a;border:1px solid #e5e7eb}
.download{font-size:.8125rem;margin-top:.25rem}
.download a{color:#64748b}
a:hover{opacity:.85}
</style>
</head>
<body>
<main>
<h1>${esc(name)}</h1>
${tagsHtml}${countLine}
<div class="actions">
<a class="btn btn-primary" href="${webUrl}">${s.openOnWeb}</a>
</div>
<p class="download"><a href="${downloadUrl}">${s.download}</a></p>
</main>
</body>
</html>`;
}

function notFoundHtml(locale) {
    const s = STRINGS[locale] ?? STRINGS.nb;
    return `<!DOCTYPE html><html lang="${locale}"><head><meta charset="utf-8"><title>${s.notFound} · RingDrill</title></head><body><h1>${s.notFound}</h1></body></html>`;
}

export function createHandler({ getSlugRecord = _getSlugRecord, readJson = _readJson } = {}) {
    return async function (request) {
        const preflight = corsPreflight(request);
        if (preflight) return preflight;

        try {
            const url = new URL(request.url);

            // Slug comes from ?slug=:splat injected by the netlify.toml redirect.
            // Fall back to parsing the pathname for direct function invocations
            // (e.g. local netlify dev hitting /.netlify/functions/drills-preview/foo).
            let slug = url.searchParams.get("slug") || null;
            if (!slug) {
                let tail = url.pathname
                    .replace(/^.*\/\.netlify\/functions\/drills-preview\//, "")
                    .replace(/^\/i\//, "")
                    .replace(/^\/+/, "");
                try { tail = decodeURIComponent(tail); } catch {}
                slug = tail || null;
            }

            if (!slug) {
                const locale = pickLocale(request);
                return withCors(request, new Response(notFoundHtml(locale), {
                    status: 404,
                    headers: { "content-type": "text/html; charset=utf-8", "vary": "Accept-Language" },
                }));
            }

            const rec = await getSlugRecord(slug);
            if (!rec) {
                const locale = pickLocale(request);
                return withCors(request, new Response(notFoundHtml(locale), {
                    status: 404,
                    headers: { "content-type": "text/html; charset=utf-8", "vary": "Accept-Language" },
                }));
            }

            const { meta: metaKey } = keysFor({ ownerId: rec.ownerId, programId: rec.programId, version: "latest" });
            const meta = await readJson(metaKey, null);

            if (!meta || !meta.published) {
                const locale = pickLocale(request);
                return withCors(request, new Response(notFoundHtml(locale), {
                    status: 404,
                    headers: { "content-type": "text/html; charset=utf-8", "vary": "Accept-Language" },
                }));
            }

            const locale = pickLocale(request);
            const html = renderHtml({ slug, meta, locale });

            return withCors(request, new Response(html, {
                status: 200,
                headers: {
                    "content-type": "text/html; charset=utf-8",
                    "cache-control": "public, max-age=300, s-maxage=600",
                    "content-language": locale,
                    "vary": "Accept-Language",
                },
            }));
        } catch (e) {
            return withCors(request, new Response(`Preview error: ${e.message || e}`, { status: 500 }));
        }
    };
}

export default createHandler();

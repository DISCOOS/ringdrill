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
        kicker:         "Delt øvingsplan",
        updated:        "Oppdatert",
        tagline:        "Rullering uten regneark.",
        about:          "RingDrill holder styr på rundetider, rullering og briefer til lag, veiledere og markører.",
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
        tagline:        "Rotation without the spreadsheet.",
        about:          "RingDrill keeps track of round times, rotation and briefs for teams, trainers and role-players.",
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
        ? `<ul class="tags">${tags.map(t => `<li>${esc(t)}</li>`).join("")}</ul>`
        : "";

    // ---- Derived meta bits (count + last-updated) rendered as one row ----
    const metaBits = [];
    if (meta.exerciseCount != null) {
        const unit = meta.exerciseCount !== 1 ? s.exercisePlural : s.exerciseUnit;
        metaBits.push(`<span>${meta.exerciseCount} ${unit}</span>`);
    }
    const versions = Array.isArray(meta.versions) ? meta.versions : [];
    const updatedIso = versions.reduce(
        (acc, v) => (v && v.updatedAt && v.updatedAt > acc ? v.updatedAt : acc),
        "",
    );
    if (updatedIso) {
        let updatedStr = updatedIso.slice(0, 10);
        try {
            updatedStr = new Date(updatedIso).toLocaleDateString(
                locale === "en" ? "en-US" : "nb-NO",
                { day: "numeric", month: "short", year: "numeric" },
            );
        } catch { /* keep ISO date fallback */ }
        metaBits.push(`<span>${s.updated} <time datetime="${esc(updatedIso)}">${esc(updatedStr)}</time></span>`);
    }
    const metaHtml = metaBits.length
        ? `<p class="meta">${metaBits.join('<span class="sep" aria-hidden="true">·</span>')}</p>`
        : "";

    const desc = typeof meta.description === "string" ? meta.description.trim() : "";
    const descHtml = desc ? `<p class="desc">${esc(desc)}</p>` : "";

    // Brand ring mark — ported from the app's RingRotationFigure (SVG viewBox
    // 240×212): dashed ring, three station nodes, three rotation arrows.
    const ringMark = `<svg class="mark" viewBox="0 0 240 212" role="img" aria-label="RingDrill" xmlns="http://www.w3.org/2000/svg">
<defs><marker id="ah" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="var(--accent)"/></marker></defs>
<circle cx="120" cy="108" r="70" fill="none" stroke="var(--ring)" stroke-width="1.5" stroke-dasharray="4 6"/>
<path d="M146 43 A70 70 0 0 1 189.3 118.1" fill="none" stroke="var(--brand-2)" stroke-width="3" stroke-linecap="round" marker-end="url(#ah)"/>
<path d="M163.2 163.1 A70 70 0 0 1 76.8 163.1" fill="none" stroke="var(--brand-2)" stroke-width="3" stroke-linecap="round" marker-end="url(#ah)"/>
<path d="M50.7 118.1 A70 70 0 0 1 94 43" fill="none" stroke="var(--brand-2)" stroke-width="3" stroke-linecap="round" marker-end="url(#ah)"/>
<g fill="var(--node-fill)" stroke="var(--brand)" stroke-width="2">
<circle cx="120" cy="38" r="20"/><circle cx="59" cy="143" r="20"/><circle cx="181" cy="143" r="20"/>
</g></svg>`;

    return `<!DOCTYPE html>
<html lang="${locale}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(name)} · RingDrill</title>
<meta name="description" content="${esc(ogDesc)}">
<meta name="theme-color" content="#00536E" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#002C3F" media="(prefers-color-scheme: dark)">
<meta property="og:title" content="${esc(name)}">
<meta property="og:description" content="${esc(ogDesc)}">
<meta property="og:url" content="${canonical}">
<meta property="og:type" content="website">
<meta property="og:locale" content="${ogLocale}">
<meta property="og:site_name" content="RingDrill">
<link rel="canonical" href="${canonical}">
<link rel="alternate" hreflang="nb" href="${canonical}">
<link rel="alternate" hreflang="en" href="${canonical}">
<link rel="alternate" hreflang="x-default" href="${canonical}">
<style>
:root{
--brand-deep:#002C3F;--brand:#00536E;--brand-2:#1F7B8A;--accent:#F0982C;--path:#5FB1C0;
--bg:#E9EFF1;--bg2:#F5F8F9;--card:#FFFFFF;--card-border:#DCE6EA;
--ink:#0B1F2A;--muted:#3E5560;--chip-bg:#E4EDF0;--chip-ink:#00536E;
--ring:#9FC3CC;--node-fill:#EAF2F4;--btn-ink:#FFFFFF;
--shadow:0 1px 2px rgba(11,31,42,.06),0 12px 32px -12px rgba(11,31,42,.22);
}
@media (prefers-color-scheme:dark){:root{
--bg:#04222E;--bg2:#002C3F;--card:#073F54;--card-border:#0E5066;
--ink:#E6EEF2;--muted:#9FB4BD;--chip-bg:#0E5066;--chip-ink:#9FD3DE;
--ring:#2C6274;--node-fill:#0B4A61;--btn-ink:#002C3F;
--shadow:0 1px 2px rgba(0,0,0,.3),0 18px 40px -14px rgba(0,0,0,.55);
}}
*{box-sizing:border-box;margin:0;padding:0}
html{-webkit-text-size-adjust:100%}
body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;color:var(--ink);line-height:1.6;
background:radial-gradient(120% 120% at 50% 0%,var(--bg2),var(--bg));min-height:100vh;
display:flex;align-items:center;justify-content:center;padding:2.5rem 1.25rem}
main{width:100%;max-width:34rem}
.card{background:var(--card);border:1px solid var(--card-border);border-radius:1.25rem;
box-shadow:var(--shadow);padding:2.25rem 2rem;text-align:center}
.mark{width:5rem;height:auto;display:block;margin:0 auto .75rem}
.kicker{font-size:.75rem;font-weight:700;letter-spacing:.09em;text-transform:uppercase;color:var(--brand-2)}
h1{color:var(--ink);font-size:1.65rem;line-height:1.25;font-weight:750;margin:.4rem 0 .85rem;overflow-wrap:break-word}
.tags{list-style:none;display:flex;flex-wrap:wrap;gap:.4rem;justify-content:center;margin:0 0 .9rem}
.tags li{background:var(--chip-bg);color:var(--chip-ink);font-size:.75rem;font-weight:600;
padding:.2rem .6rem;border-radius:999px}
.meta{color:var(--muted);font-size:.85rem;margin-bottom:1rem}
.meta .sep{margin:0 .45rem;opacity:.6}
.desc{color:var(--muted);font-size:.95rem;margin:0 auto 1.4rem;max-width:26rem}
.actions{margin:1.4rem 0 .35rem}
.btn{display:block;width:100%;padding:.85rem 1.25rem;border-radius:.7rem;font-size:1rem;font-weight:650;
text-decoration:none;text-align:center;transition:transform .06s ease,box-shadow .15s ease,background .15s ease}
.btn-primary{background:var(--brand);color:var(--btn-ink);box-shadow:0 6px 16px -6px rgba(0,83,110,.6)}
.btn-primary:hover{background:var(--brand-deep)}
.btn-primary:active{transform:translateY(1px)}
@media (prefers-color-scheme:dark){.btn-primary{background:var(--accent)}.btn-primary:hover{filter:brightness(1.06)}}
.download{font-size:.9rem;margin-top:.85rem}
.download a{color:var(--brand-2);text-decoration:none;font-weight:600;border-bottom:1px solid transparent;padding-bottom:1px}
.download a:hover{border-bottom-color:currentColor}
.foot{text-align:center;margin:1.75rem auto 0;max-width:30rem}
.brandline{display:inline-flex;align-items:center;gap:.45rem;font-weight:700;color:var(--ink);font-size:.95rem}
.brandline .dot{width:.55rem;height:.55rem;border-radius:999px;background:var(--accent);box-shadow:0 0 0 3px rgba(240,152,44,.22)}
.brandline .tl{color:var(--muted);font-weight:500}
.about{color:var(--muted);font-size:.85rem;margin:.5rem 0 .35rem}
.foot a{color:var(--brand-2);text-decoration:none;font-weight:600}
.foot a:hover{text-decoration:underline}
:focus-visible{outline:2px solid var(--accent);outline-offset:3px;border-radius:.4rem}
</style>
</head>
<body>
<main>
<section class="card">
${ringMark}
<p class="kicker">${s.kicker}</p>
<h1>${esc(name)}</h1>
${tagsHtml}${metaHtml}${descHtml}
<div class="actions">
<a class="btn btn-primary" href="${webUrl}">${s.openOnWeb}</a>
</div>
<p class="download"><a href="${downloadUrl}">${s.download}</a></p>
</section>
<footer class="foot">
<span class="brandline"><span class="dot" aria-hidden="true"></span>RingDrill <span class="tl">— ${s.tagline}</span></span>
<p class="about">${s.about}</p>
<p>${s.moreAt} <a href="https://ringdrill.app">ringdrill.app</a></p>
</footer>
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
                    "cache-control": "public, max-age=0, s-maxage=600, must-revalidate",
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

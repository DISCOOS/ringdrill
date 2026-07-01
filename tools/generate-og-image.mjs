// Generates the Open Graph share card used by the /i/<slug> preview
// (og:image, 1200x630). Rebuilds the card from the brand mark
// (site/public/brand/logo-mark.png) plus the RingDrill wordmark and tagline,
// then writes it to both apex roots so /og-default.png resolves regardless of
// which origin serves the apex:
//   - web/og-default.png         (Flutter PWA build, apex today)
//   - site/public/og-default.png (Astro site, apex after ADR-0039)
//
// Run: npm run og:image   (requires the @resvg/resvg-js devDependency)
// Re-run whenever the brand mark, wordmark or tagline changes, then commit the
// regenerated PNGs.

import { Resvg } from "@resvg/resvg-js";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const rel = (p) => join(repoRoot, p);

const TAGLINE = "Rullering uten regneark.";
const WIDTH = 1200;
const HEIGHT = 630;

const logo = readFileSync(rel("site/public/brand/logo-mark.png"));
const logoHref = "data:image/png;base64," + logo.toString("base64");
const LOGO = 400;
const LX = 108;
const LY = (HEIGHT - LOGO) / 2;

const svg = `<svg width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#04222E"/>
      <stop offset="0.55" stop-color="#00364A"/>
      <stop offset="1" stop-color="#00536E"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.28" cy="0.45" r="0.55">
      <stop offset="0" stop-color="#1F7B8A" stop-opacity="0.30"/>
      <stop offset="1" stop-color="#1F7B8A" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="${WIDTH}" height="${HEIGHT}" fill="url(#bg)"/>
  <rect width="${WIDTH}" height="${HEIGHT}" fill="url(#glow)"/>
  <image href="${logoHref}" x="${LX}" y="${LY}" width="${LOGO}" height="${LOGO}"/>
  <text x="588" y="292" font-family="Poppins" font-weight="700" font-size="118" fill="#FFFFFF">RingDrill</text>
  <text x="590" y="360" font-family="Poppins" font-weight="500" font-size="42" fill="#9FD3DE">${TAGLINE}</text>
  <circle cx="604" cy="432" r="9" fill="#F0982C"/>
  <text x="626" y="441" font-family="Poppins" font-weight="600" font-size="30" fill="#C9DDE4">ringdrill.app</text>
</svg>`;

const png = new Resvg(svg, {
  fitTo: { mode: "width", value: WIDTH },
  font: { loadSystemFonts: true },
}).render().asPng();

const targets = ["web/og-default.png", "site/public/og-default.png"];
for (const t of targets) writeFileSync(rel(t), png);
console.log(`Wrote ${WIDTH}x${HEIGHT} og-default.png (${png.length} bytes) to: ${targets.join(", ")}`);

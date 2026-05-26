// Post-deploy smoke test for the RingDrill web app.
//
// Catches the class of failure that widget tests cannot: the app
// compiles, the bundle ships, the engine boots — but the deploy is
// actually broken (engine fails to instantiate, function endpoints
// return 404, the page never paints anything).
//
// Why we DO NOT inspect flt-glass-pane / flt-semantics size:
//   The dart2wasm build uses Flutter's skwasm renderer, which paints
//   into an OffscreenCanvas owned by a Web Worker. flt-glass-pane is
//   only a shadow-DOM host on the main thread and stays at 0×0 even
//   when the app renders perfectly. Semantics nodes are not created
//   until accessibility is explicitly activated (screen reader, tab
//   focus, etc.). Both signals are unreliable under skwasm.
//
// What we check instead:
//   1. The page returns HTTP 200 and reaches networkidle so all
//      bundle assets (main.dart.wasm, skwasm.wasm, canvaskit) have
//      a chance to download.
//   2. window._flutter_skwasmInstance (or window._flutter at minimum)
//      exists after boot — the engine instantiated.
//   3. A viewport screenshot has enough pixel variety that the page
//      is not "one solid color of background" — i.e. something
//      actually painted into the canvas.
//   4. No uncaught console errors during boot (soft warning).
//   5. The /api/market/feed function endpoint returns 2xx — catches
//      the kind of functions-dir misconfiguration we hit earlier.
//
// Screenshots are written to scripts/.smoke-screenshots/ so a failing
// run can be diagnosed visually from the GH Actions artifact upload.

import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const BASE = process.env.SMOKE_URL || "https://ringdrill.app";
const PATHS = ["/", "/program", "/map", "/stations", "/teams"];
const NAV_TIMEOUT = 60_000;
// dart2wasm builds take noticeably longer than dart2js to reach first
// paint (~3MB .wasm to fetch, instantiate and link). Give it a real
// budget; we still fail well inside the 25-minute job timeout.
const BOOT_WAIT_MS = 12_000;
// Empirically a fully-blank Flutter page (just the indigo background)
// compresses to ~6–10 KB. Real UI lands at 40 KB and up. 25 KB is a
// safe split.
const MIN_SCREENSHOT_BYTES = 25_000;

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCREENSHOT_DIR = join(__dirname, ".smoke-screenshots");

const hardFailures = [];
const softWarnings = [];

function ok(msg) { console.log(`  ok    ${msg}`); }
function warn(msg, url) { softWarnings.push(`[${url}] ${msg}`); console.log(`  warn  ${msg}`); }
function fail(msg, url) { hardFailures.push(`[${url}] ${msg}`); console.log(`  FAIL  ${msg}`); }

function slug(path) {
  return path.replace(/^\/+|\/+$/g, "").replace(/[^a-z0-9]+/gi, "_") || "root";
}

async function checkPath(browser, path) {
  const url = BASE + path;
  console.log(`\n> ${url}`);
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });
  const consoleErrors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });
  page.on("pageerror", (err) => consoleErrors.push(String(err)));

  try {
    const response = await page.goto(url, {
      waitUntil: "networkidle2",
      timeout: NAV_TIMEOUT,
    });

    if (!response || !response.ok()) {
      fail(`HTTP ${response?.status() ?? "no response"} on initial load`, url);
      return;
    }
    ok(`HTTP ${response.status()} reached networkidle`);

    // Give Flutter time to instantiate the WASM engine and paint the
    // first frame. We do not poll DOM signals here because skwasm
    // does not expose any reliable main-thread DOM signal for "ready".
    await new Promise((r) => setTimeout(r, BOOT_WAIT_MS));

    const engineReady = await page.evaluate(() => {
      return Boolean(window._flutter_skwasmInstance || window._flutter);
    });
    if (!engineReady) {
      fail("Flutter engine did not instantiate (no _flutter on window)", url);
      return;
    }
    ok("Flutter engine instantiated");

    // Screenshot the visible viewport and use compressed file size as
    // a proxy for "actually rendered something". A fully blank page
    // compresses tiny; real UI compresses much larger. The screenshot
    // is also written to disk so a CI artifact upload can capture it
    // for visual diagnosis after a failure.
    await mkdir(SCREENSHOT_DIR, { recursive: true });
    const screenshotPath = join(SCREENSHOT_DIR, `${slug(path)}.png`);
    const buf = await page.screenshot({ type: "png", fullPage: false });
    await writeFile(screenshotPath, buf);
    if (buf.length < MIN_SCREENSHOT_BYTES) {
      fail(
        `screenshot only ${buf.length} bytes (< ${MIN_SCREENSHOT_BYTES}); page likely blank — see ${screenshotPath}`,
        url,
      );
    } else {
      ok(`screenshot ${buf.length} bytes (saved ${screenshotPath})`);
    }

    if (consoleErrors.length > 0) {
      warn(
        `${consoleErrors.length} console error(s); first: ${consoleErrors[0].slice(0, 200)}`,
        url,
      );
    } else {
      ok("no console errors");
    }
  } catch (err) {
    fail(`navigation/wait failed: ${err.message}`, url);
  } finally {
    try {
      await page.close();
    } catch {
      // ignore — the CDP connection may already be gone
    }
  }
}

async function checkFunction(path) {
  const url = BASE + path;
  console.log(`\n> ${url}`);
  try {
    const res = await fetch(url, { redirect: "follow" });
    if (res.ok) {
      ok(`HTTP ${res.status}`);
    } else {
      fail(`HTTP ${res.status} ${res.statusText}`, url);
    }
  } catch (err) {
    fail(`fetch failed: ${err.message}`, url);
  }
}

async function main() {
  console.log(`Smoke testing ${BASE}`);
  const browser = await puppeteer.launch({
    headless: "new",
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });
  try {
    for (const p of PATHS) {
      await checkPath(browser, p);
    }
    await checkFunction("/api/market/feed?limit=1");
  } finally {
    await browser.close();
  }

  console.log("\n────────────────────────────");
  if (softWarnings.length > 0) {
    console.log(`Warnings (${softWarnings.length}):`);
    softWarnings.forEach((w) => console.log(`  - ${w}`));
  }
  if (hardFailures.length > 0) {
    console.log(`\nFailures (${hardFailures.length}):`);
    hardFailures.forEach((f) => console.log(`  - ${f}`));
    process.exit(1);
  }
  console.log("All smoke checks passed.");
}

main().catch((err) => {
  console.error("Smoke test crashed:", err);
  process.exit(1);
});

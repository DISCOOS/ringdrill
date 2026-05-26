// Post-deploy smoke test for the RingDrill web app.
//
// Catches the class of failure that widget tests cannot: the app
// compiles, the bundle ships, the engine boots — but nothing paints
// because of a layout/sizing bug, a missing function deploy, an
// uncaught error during boot, or similar.
//
// Each check is intentionally simple so a failure points at one
// concrete thing. The script exits non-zero on the first hard
// failure; soft warnings are collected and printed at the end.
//
// Run locally:    SMOKE_URL=https://ringdrill.app node scripts/smoke-test-web.mjs
// Run from CI:    make smoke-web (see Makefile)

import puppeteer from "puppeteer";

const BASE = process.env.SMOKE_URL || "https://ringdrill.app";
const PATHS = ["/", "/program", "/map", "/stations", "/teams"];
const NAV_TIMEOUT = 30_000;
const PAINT_TIMEOUT = 30_000;

const hardFailures = [];
const softWarnings = [];

function ok(msg) {
  console.log(`  ok    ${msg}`);
}
function warn(msg, url) {
  softWarnings.push(`[${url}] ${msg}`);
  console.log(`  warn  ${msg}`);
}
function fail(msg, url) {
  hardFailures.push(`[${url}] ${msg}`);
  console.log(`  FAIL  ${msg}`);
}

async function checkPath(browser, path) {
  const url = BASE + path;
  console.log(`\n> ${url}`);
  const page = await browser.newPage();
  const consoleErrors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });
  page.on("pageerror", (err) => consoleErrors.push(String(err)));

  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });

    // Wait for the Flutter glass pane to take real size. This is the
    // single most informative check: if it stays at 0x0 the engine
    // is alive but the widget tree didn't lay out properly. That was
    // exactly today's regression (Stack without StackFit.expand).
    try {
      await page.waitForFunction(
        () => {
          const gp = document.querySelector("flt-glass-pane");
          if (!gp) return false;
          const r = gp.getBoundingClientRect();
          return r.width > 200 && r.height > 200;
        },
        { timeout: PAINT_TIMEOUT },
      );
      ok("flt-glass-pane sized > 200x200");
    } catch {
      const dims = await page.evaluate(() => {
        const gp = document.querySelector("flt-glass-pane");
        const r = gp?.getBoundingClientRect();
        return r ? { w: r.width, h: r.height } : null;
      });
      fail(
        `flt-glass-pane never reached visible size (got ${JSON.stringify(dims)})`,
        url,
      );
      await page.close();
      return;
    }

    // Semantics nodes only appear once Flutter has actually laid out
    // and painted widgets. Zero semantics with a sized glass pane
    // means the app rendered an empty screen.
    const semCount = await page.evaluate(
      () => document.querySelectorAll("flt-semantics").length,
    );
    if (semCount === 0) {
      fail("glass pane is sized but zero flt-semantics rendered", url);
    } else {
      ok(`flt-semantics count: ${semCount}`);
    }

    if (consoleErrors.length > 0) {
      // Console errors during boot are a soft warning, not a hard
      // fail — third-party scripts (extensions, ads) sometimes log
      // here. We surface them so they are reviewable.
      warn(`${consoleErrors.length} console error(s); first: ${consoleErrors[0].slice(0, 200)}`, url);
    } else {
      ok("no console errors");
    }
  } catch (err) {
    fail(`navigation/wait failed: ${err.message}`, url);
  } finally {
    await page.close();
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
    // Netlify functions: hitting one proves the [functions] block in
    // netlify.toml was honored. Today's earlier 404 on market-feed
    // (after we forgot functions-dir) would have been caught here.
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

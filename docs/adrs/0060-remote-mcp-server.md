---
status: accepted
date: 2026-07-30
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0060: Serve the MCP server remotely as a Netlify function, with the compiler cross-compiled to JavaScript

## Context and problem statement

[DESIGN-014](../design/014-source-format-and-plan-compiler.md) stage 4 shipped an MCP server ([`mcp/`](../../mcp/README.md)) that lets an agent read the catalog, scaffold, check, compile and render a drill plan. It speaks MCP over **stdio**, which means the client spawns it as a local subprocess. Running it therefore needs a git checkout, the Dart SDK, Node ≥ 22.13 and a `make mcp`.

That is a developer's setup, and the people the feature is for are not developers. A SAR instructor drafting an exercise plan has Claude in a browser or a desktop app; they do not have a Dart toolchain, and telling them to get one is telling them not to use the feature. Stdio serves the person building RingDrill; it does not serve the person using it. Remote hosting is what makes stage 4 reach its actual audience.

The toolchain is not the only barrier, and probing the local server established a second, independent one: a stdio server does not run inside the Cowork sandbox. One configured in the desktop app is bridged in and runs on the host — which is why it reaches a locally built binary at all — so it works in the desktop app only, and a remote session gets no local servers to bridge. Even a developer therefore cannot use the stdio server everywhere they use Claude. See [`mcp/README.md`](../../mcp/README.md) for the detail.

The obstacle was assumed to be structural. Every tool shells out to the `ringdrill` CLI — a native binary — which no function runtime can hold: Cloudflare Workers are V8 isolates with no subprocesses at all, and a Netlify function bundling a platform-specific executable is a build problem nobody wants. The apparent options were a container (a new infrastructure category for this repo) or a hand-written JavaScript port of the compiler, which [ADR-0058](./0058-source-format-and-plan-compiler.md) rejected precisely to avoid a second implementation of the format.

That assumption turned out to be wrong, and measurement is what settled it (see Decision outcome). The compiler is Flutter-free pure Dart, and Dart cross-compiles to JavaScript.

## Decision drivers

* **Reach.** The target user has a browser, not a toolchain. If installation requires a checkout, the feature is developer-only in practice.
* **One implementation of the source format.** ADR-0058's load-bearing constraint. Whatever runs remotely must be *the same Dart source* as the app and the CLI, not a parallel JS reimplementation that drifts the first time the field table changes.
* **Fits the existing origin split.** [ADR-0039](./0039-site-pwa-api-origins.md) put the API on Netlify (`api.ringdrill.app`) and the site/PWA on Cloudflare. The catalog data the MCP tools read is already on Netlify.
* **The tool surface needs no secrets.** Every tool maps to a public CLI command; `publish` is deliberately absent (DESIGN-014). So the security question is abuse, not authorization — a materially cheaper problem.
* **Author privacy is a real constraint, not a formality.** A remote server means the plan text leaves the author's machine. Real plans are marked staff-only — the anchor plan in the catalog opens with "KUN FOR STAB" — so a hosted option must not be the *only* option, and must not retain what it is sent.
* **No new infrastructure category if avoidable.** This repo already spans Netlify functions, Cloudflare Pages and a Cloudflare Worker. A fourth runtime to operate is a real ongoing cost for a one-person project.

## Considered options

* **Option A — Stdio only; do not host.** Document the checkout path and accept that the audience is developers.
* **Option B — A Netlify function serving MCP over Streamable HTTP, with the compiler cross-compiled to JavaScript by `dart compile js` and called in-process.**
* **Option C — A Cloudflare Worker serving the same cross-compiled JavaScript.**
* **Option D — A container running the native CLI** (Fly.io, Cloud Run) behind the existing API origin.
* **Option E — Port the compiler to JavaScript by hand.**

## Decision outcome

Chosen option: **Option B**, because a spike showed the entire pipeline runs as JavaScript in-process — removing the subprocess constraint that made hosting look expensive — and because Netlify is where the API and the catalog data already are.

### What the spike established

`dart compile js` over an entry point that calls `SourceCompiler`, `SourceAnalyzer`, `SourceSchema` and `BriefRenderer`:

* **It compiles and runs.** 1.4 MB of JavaScript from a 13 MB input graph, in under three seconds.
* **The whole pipeline works**, not just the parts that look portable: the content hash is computed, the rotation schedule derived, the analyzer runs clean, and a brief renders at 433 bytes with `{{station.loc.lkp.utm}}` resolved to a real UTM coordinate and no tokens left unsubstituted. That last point matters most — UTM projection goes through `proj4dart`, which was the dependency most likely to be a native-only surprise.
* **One shim is needed, of two lines.** `Random.secure()` compiles to `_JSSecureRandom`, which reads `self` — defined in browsers and in Cloudflare Workers, but not in bare Node. `globalThis.self = globalThis` plus `globalThis.crypto ??= webcrypto` fixes it. Worth recording because the failure mode is opaque: an async `main` swallows it and the process exits 0 with no output.

So the choice is no longer "container or hand-port". It is "which function runtime", and the compiler stays the single Dart implementation ADR-0058 requires — cross-compiled, not rewritten.

### Why Netlify rather than Cloudflare

Both would work, and Workers arguably fit the compiled output *better* (they define `self` natively, so no shim). Netlify wins on two grounds that outweigh that:

* `search_catalog` and `get_plan` read the catalog, which lives in Netlify Blobs behind the Netlify functions. On Netlify those are a local call; on a Worker every catalog read is a cross-origin hop back to `api.ringdrill.app`.
* The 1.4 MB bundle is comfortable inside a function's limits and uncomfortably close to a Worker's, which would make bundle size a standing constraint on a compiler that is expected to grow.

### Transport and statelessness

MCP's remote transport is **Streamable HTTP**. Every tool here is request/response with no server-initiated messages, so the server runs **stateless** — no sessions, no SSE stream to hold open — which is what makes it a function rather than a service. That is a property of the current tool surface, and a future tool that streams progress would reopen it.

### Access and abuse

The server is **unauthenticated**, consistent with the catalog feed it reads, which is already public. No tool needs a secret, and `publish` is absent, so there is nothing to authorize. What is needed is abuse control: a request-size cap on `document`, a rate limit, and a compile timeout. This is deliberately *not* an OAuth decision — adopting the MCP spec's auth story would be a significant commitment, and it buys nothing while no tool touches private state. When account-aware publishing arrives ([ADR-0024](./0024-account-and-identity-model.md), [ADR-0025](./0025-authorization-and-publish-policy.md)), that is the moment to revisit.

> **All three now exist.** The size cap and the timeout shipped with the endpoint; the rate limit did not, and was still missing when the endpoint went live — 60 requests per minute per caller, declared in the function's own `config` export rather than as a `[redirects.rate_limit]` block, because the function answers on three routes (`/mcp`, `/api/mcp`, and the native `/.netlify/functions/mcp` that no redirect gates) and one rule there covers all three out of a small per-project budget. Asserted in `netlify/tests/mcp-packaging.test.mjs` against the bundler's `trafficRules` output rather than the source export, since a field name the bundler does not recognise drops the rule while leaving the source looking correct. `windowSize` caps at 180 seconds, so this bounds the burst and the per-request caps bound each call inside it; there is no per-hour ceiling available at this layer.

### Stdio stays

The remote server is an addition, not a replacement, and the two share one tool table. Stdio remains the path for development, for offline work, and — most importantly — for an author who does not want a staff-only plan leaving their machine. The hosted server **must not persist documents**: it compiles what it is sent and returns the result. That is a requirement of this decision, not an implementation detail, and it belongs in the server's own documentation where a user will see it.

> **Amended by [ADR-0064](./0064-mcp-payload-economy.md).** The requirement now reads: the hosted server does not retain what it is sent **unless the caller asks it to**, in which case it holds that document under its own content hash for a stated and short period. Retention stays off by default, so this paragraph still describes what every caller gets who does not opt in. ADR-0064 records why the trade is worth making — large plans are the normal case for the users who matter — and what consent plus a TTL does not fix.

> **The user-facing half of this is discharged by `/docs/mcp` on the site** (`site/src/pages/docs/mcp.md`, and `en/docs/mcp.md`, alongside the plan-format and CLI pages that page depends on). "Belongs in the server's own documentation where a user will see it" went unmet for as long as the promise lived only here and in code comments — an author choosing between hosted and local could not read it. That page states all three cases rather than the headline: nothing retained by default, a document held 30 minutes on `cache: true` with the dead-drop property named, and the archive `build_plan` holds by default under [ADR-0070](./0070-build-artifact-delivery.md) with `inline: true` as the way out. It also says plainly that a staff-only plan belongs on the stdio server, which is the sentence this section exists to make possible. Anything that changes a retention window or adds a default now has a fourth place to update, and it is the only one a user reads.

### Consequences

* Good: the feature reaches people without a toolchain, which is the entire point of stage 4.
* Good: one implementation of the format survives. The JavaScript is a build artifact of the same Dart source the app and CLI use, so the field table stays the single description.
* Good: no new infrastructure category — it is a function alongside the existing ones, on the origin that already holds the data.
* Good: it makes **ADR-0041** cheaper rather than harder. That number is reserved (see the index) for "brief pre-rendering port from Dart to Node", and DESIGN-014 stage 5 already removed the need for a *port*: the renderer is Flutter-free and `ringdrill render` produces the markdown. With the compiler cross-compiled here, brief pre-rendering becomes a second caller of the same bundle rather than a subsystem rewrite.
* Bad: a second build artifact to keep current. A stale bundle serves old compiler behaviour with no symptom, so it needs a CI step and the same kind of staleness guard the local server already has.
* Bad: the shim is a sharp edge. It is two lines, but the failure it prevents is silent, so it needs a test that would catch its removal.
* Bad: `dart compile js` output is not exercised by the existing test suite, which runs on the VM. Behaviour that differs between the two — numeric precision is the classic one, and this code computes coordinates and a SHA-256 — would not be caught. A JS-target smoke test asserting the same content hash as the VM produces is the mitigation.
* Bad: a hosted endpoint is an operational surface with a cost and an abuse profile, where before there was none.

## Pros and cons of the options

### Option A — stdio only
* Good: nothing to host, nothing to operate, no document ever leaves the author's machine.
* Bad: restricts the feature to people with a Dart SDK and a checkout, which is not the audience DESIGN-014 was written for.

### Option B — Netlify function, cross-compiled compiler
* Good: co-located with the catalog data; comfortable bundle limits; one Dart implementation; no new runtime to operate.
* Bad: needs the `self` shim; a second build artifact; JS-target behaviour is untested by the VM suite.

### Option C — Cloudflare Worker, cross-compiled compiler
* Good: `self` exists natively, so no shim; the repo already operates a Worker.
* Bad: every catalog read becomes a cross-origin hop to the API; a 1.4 MB bundle sits close enough to the Worker size limit to become a standing constraint on the compiler.

### Option D — container running the native CLI
* Good: runs the exact binary the CLI ships, so there is no second target and no cross-compilation risk at all.
* Bad: a new infrastructure category to run, pay for and keep patched, for a subprocess-per-request design — when the spike shows the subprocess is not needed.

### Option E — hand-written JavaScript port
* Good: no cross-compilation, idiomatic JS, small bundle.
* Bad: a second implementation of the source format, which is the thing ADR-0058 exists to prevent. It would drift from the field table on the first change and there is no test that could reliably catch it.

## Links

* Related design: [DESIGN-014](../design/014-source-format-and-plan-compiler.md) (stage 4 is the server this hosts; stage 5 made the renderer headless)
* Related ADRs: [ADR-0005](./0005-cli-must-remain-flutter-free.md) (why the compiler is portable at all), [ADR-0039](./0039-site-pwa-api-origins.md) (the origin split this fits into), ADR-0041 (reserved, no file yet; this decision changes its premise — see the index), [ADR-0048](./0048-flutter-free-field-resolver.md) (amended by DESIGN-014 stage 5), [ADR-0058](./0058-source-format-and-plan-compiler.md) (one implementation of the format), [ADR-0024](./0024-account-and-identity-model.md) / [ADR-0025](./0025-authorization-and-publish-policy.md) (when auth becomes a real question)
* Related code: `mcp/ringdrill-mcp.mjs` (the stdio server whose tool table is shared), `lib/data/source/` (the compiler being cross-compiled), `netlify/functions/` (where the hosted endpoint would live)

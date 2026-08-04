---
status: accepted
date: 2026-08-04
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0070: Deliver a built archive by handle, not through the transcript

## Context and problem statement

`build_plan` returns the compiled `.drill` archive base64-encoded, as a field inside
the JSON that becomes the tool result's single `text` content block. For the 2026
LSOR booklet — the plan this whole surface exists to serve — that is an 80 KB archive
arriving as **107,376 characters of base64**, roughly 27k tokens, in the middle of the
agent's transcript.

A cold run against the hosted endpoint from ChatGPT/Codex found what that costs. Every
tool did its job: `analyze_plan` came back clean, `render_plan` produced the brief,
`build_plan` reported a valid archive. And then the run could not produce the file.
The client's own words:

> the MCP tool returns the archive blob only inside the tool result text, and the
> chat/tool display truncates large blobs … Returning a ~95 KB base64 string through
> chat text is not a reliable artifact channel.

Two distinct failures, and only the first is client-specific:

* **No artifact channel at all.** A client that truncates or reflows a long text block
  has destroyed the bytes, and there is no recovery — the agent cannot re-derive what
  it was shown. The build succeeded and the deliverable was unobtainable.
* **A payload no agent reads.** Even where the bytes survive intact, no agent ever
  *inspects* an archive. It can only pass it through, which is the one thing a
  language model does badly. This is the largest response the server can emit and the
  only one whose content is never used, on every transport including the ones that
  work.

[ADR-0064](./0064-mcp-payload-economy.md) is the same concern one step earlier. It cut
the document out of the *input* side (`document_path`, `document_hash`) and narrowed
*render* output (`format: 'summary'`), and its framing applies here without change:
the cost is the agent's context window, not bandwidth. It simply did not look at
`build_plan`'s output, where the effect is largest and the content least useful.

Worth naming what does *not* fix this. The MCP spec has a content block for exactly
this shape — `{type: "resource", resource: {uri, mimeType, blob}}` — and the server
should use it where it can. But it does not solve the problem: the blob still crosses
the same transport into the same transcript. The failure is *size in the transcript*,
and re-tagging bytes does not remove them. Only a handle removes them.

The hosted transport is where a handle is awkward, for the reason ADR-0060 gives: the
server is stateless and does not retain what it is sent. A URL to an artifact is
retention by definition.

## Decision drivers

* A successful build must yield a file the user can actually open, on every transport
  the server claims to support. Codex and ChatGPT are the clients ADR-0060 exists for;
  a build that cannot hand them the archive is not a working build.
* Stop paying context for bytes nobody reads. ADR-0064's principle, applied to the one
  response it skipped.
* Keep one tool table with one meaning per field, so a response shape does not depend
  on which backend answered.
* Retention must be weighed against what it buys, and the cost stated where a user
  will read it — the standard ADR-0064 set for the document cache.
* Add no capability a transport does not already have.

## Considered options

* Option A — Status quo: inline base64, and a large hosted build is simply not
  deliverable to a chat client.
* Option B — Type it as an MCP embedded resource (`blob`), still inline.
* Option C — Handles on both transports: a written file locally, a short-lived
  download URL when hosted; inline bytes on request.
* Option D — Route the archive through the existing publish path, so the download URL
  is a catalog URL.
* Option E — Chunked retrieval: `build_plan` returns a handle and a `get_chunk` tool
  reassembles the bytes through the transcript.

## Decision outcome

Chosen option: **C**, mirroring ADR-0064's own split — the local transport gets the
answer that retains nothing, the hosted transport gets the one that makes a large plan
first-class.

`build_plan` gains two arguments and replaces `drillBase64` with one discriminated
`archive` object. The discriminator is what keeps the tool table honest: the field is
present in every response from both backends, and its `kind` says how the bytes are
being handed over.

**`archive.kind: "file"` — stdio.** The backend passes the CLI an `--out` path and
returns it. With `output_path` that is the author's chosen location; without it, a
content-addressed path under the OS temp directory, so a rebuild of the same document
lands on the same file rather than accumulating. No new capability: the CLI has always
written wherever it was told, as this user, and the backend already wrote the archive
to a scratch directory in order to base64 it — this stops deleting it.

**`archive.kind: "url"` — hosted.** The archive is held under its own `contentHash`
and the response carries a URL at `/mcp/artifact/<hash>.drill`, with `expires_at`. A
GET there answers the bytes with `content-disposition: attachment`; an expired or
unknown hash is a 404. Served by its own function so a byte read does not load the
compiler bundle, and so `/mcp` keeps being POST-only and stateless.

**`archive.kind: "inline"` — either, on request.** `inline: true` returns
`archive.base64` and retains nothing anywhere. This is the current behaviour, kept for
a programmatic caller that genuinely wants bytes, and as the escape hatch for an
author who does not want a derived artifact held at all.

`output_path` is stdio-only and the hosted backend refuses it with a reason naming the
cause, exactly as it already does for `document_path`.

### What this amends, and how far

ADR-0060's retention requirement, for the second time — and this amendment is
stronger than ADR-0064's, which is the part worth being explicit about rather than
folding into a footnote.

ADR-0064 made retention **opt-in**: "retention is never implicit, so ADR-0060's
promise holds unchanged for every caller who does not ask." Hosted `build_plan` now
holds the archive **by default**. That is a real reversal of that sentence for this one
tool, and the argument for it is that the two cases are not alike:

* A *source document* is retained to save resending something the caller already has.
  Not retaining it costs a slower loop. Opt-in is free.
* A *built archive* exists only because the server made it, and it is the entire point
  of the call. There is no useful reading of "build this plan but give me no way to
  obtain it". Holding it for minutes **is** the delivery mechanism, not an
  optimisation on top of one.

Three properties bound it, the same three ADR-0064 relied on:

* **Content-addressed.** The key is the compiler's own `contentHash` of the plan, so a
  client cannot choose keys, a retrieval cannot return anything other than what was
  stored under that content, and the URL is unguessable — a capability key, in the
  same family as an unguessable share link.
* **Expiring.** A short TTL, on the order of an authoring session, stated in the
  response as `expires_at`.
* **Escapable.** `inline: true` retains nothing, so an author who will not have a
  staff-only plan's archive sitting in a blob store has a supported way to say so —
  and the stdio transport remains the answer for one that should never be sent at all.

The promise in the server's user-facing documentation becomes: *the hosted server does
not retain what it is sent unless you ask; it does hold what it builds for you, under
that plan's content hash, for a stated and short period, unless you ask for the bytes
inline instead.*

### Consequences

* Good: a hosted build is deliverable to a chat client. The URL survives a transcript
  that truncates a blob, and needs no client capability beyond following a link.
* Good: a build costs a handle instead of ~27k tokens, on every transport. The largest
  and least useful payload in the surface is gone from the default path.
* Good: one field, one meaning, both backends — `archive.kind` is a value to read
  rather than a key whose presence depends on which server answered, so the parity
  check keeps working.
* Good: local authoring gets a real file at a path the author chose, which is what
  they wanted from a build in the first place.
* Bad: hosted retention of a derived artifact is now the default, which is a genuine
  narrowing of ADR-0064's "never implicit". Stated above rather than discovered.
* Bad: the dead-drop property stops being a side effect and becomes the mechanism. A
  document-cache hash was a handle an author might incidentally share; a download URL
  is *meant* to be handed to someone, and whoever holds it holds the archive until it
  expires. The archive of a staff-only plan is exactly as sensitive as its source.
* Bad: a second storage namespace with its own TTL and no owner, so no listing and no
  delete — inherited from ADR-0064 and resolved the same way, by ADR-0024/0025
  identity when it arrives. Owned drafts (ADR-0064's Option B3) should absorb this.
* Bad: a new public GET route on the API origin that serves author content, where
  before every hosted MCP interaction was a POST that answered and forgot. It is
  content-addressed and expiring, but it is new surface to abuse-test.
* Bad: **the hosted handle depends on a client capability MCP does not guarantee.** A
  `url` is only a deliverable to a caller that can issue a GET, and nothing in the
  protocol promises one — a sandboxed agent, an offline session, or a client under a
  network policy gets a build it cannot obtain, which is the original failure relocated
  rather than removed. `inline: true` is the answer for that caller, so the mitigation
  exists; what it costs is that the tool's guidance has to name *both* paths and say
  when each applies. The first draft of that guidance said only "do not ask for
  `inline: true`", which left such a client with no sanctioned route at all — found by
  a cold run whose agent was (correctly) forbidden to reach RingDrill by any means
  except the supplied tools, and which therefore had no way to follow the url it was
  handed. Serving the archive as an MCP resource instead would need no HTTP client, but
  the bytes still cross the transport at full size: that is `inline` with extra steps,
  not a third option.
* Bad: an agent that reads `archive.base64` unconditionally breaks. The field is now
  absent unless asked for, which is a breaking change to the one tool most likely to
  have a script pointed at it.
* Bad: stdio now leaves a file behind by default. Under the OS temp directory and
  content-addressed, so it is bounded and idempotent, but it is a write the caller did
  not explicitly request.

## Pros and cons of the options

### Option A — Status quo
* Good: nothing to build; retains nothing.
* Bad: fails the clients ADR-0060 exists to serve, at the last step, after every other
  tool has worked. The worst possible place for a surface to fail.
* Bad: spends a quarter of a small context window on bytes that are never read.

### Option B — Embedded resource, still inline
* Good: protocol-correct, and a client that materialises a `blob` as an attachment
  gets a file for free.
* Good: cheap, and composes with C rather than competing with it.
* Bad: does not address the actual failure. The bytes still traverse the transcript at
  full size, so a client that truncates still truncates.
* Bad: "a client that materialises a blob" is not the clients we have; Codex is the
  one that reported the problem.

### Option C — Handles on both transports
* Good: the only option that removes the bytes from the transcript, which is the
  failure being fixed.
* Good: symmetric with ADR-0064 — the local half retains nothing and the hosted half
  is what makes a large plan viable, which is the same trade already accepted once.
* Good: `inline: true` preserves the old behaviour and the zero-retention path, so
  nothing is taken away.
* Bad: hosted retention by default, and a public GET route serving author content.

### Option D — Publish, and hand back a catalog URL
* Good: no new storage, no new route, no new TTL; the catalog already serves archives
  with the right headers.
* Bad: publishing is a human step by design (DESIGN-014), and `publish` is absent from
  this surface deliberately. Making a build publish would be the largest policy change
  available, to solve a delivery problem.
* Bad: a draft is not a publication. Most builds during authoring are not fit to be in
  a shared corpus, and the catalog is public.

### Option E — Chunked retrieval
* Good: no retention beyond a request, and no new route.
* Bad: reassembling 107 KB of base64 through the transcript is the problem, paid in
  instalments. It multiplies round trips and still ends with the bytes in context.
* Bad: correct reassembly depends on the agent concatenating in order without
  paraphrasing — the exact capability that cannot be relied on.

## Links

* Related ADRs: [ADR-0064](./0064-mcp-payload-economy.md) (payload economy, and the
  opt-in retention this narrows), [ADR-0060](./0060-remote-mcp-server.md)
  (statelessness and the original retention requirement),
  [ADR-0058](./0058-source-format-and-plan-compiler.md) (the compiler and
  `contentHash`)
* Related code: `mcp/tools.mjs` (the shared tool table),
  `mcp/backend-cli.mjs` (stdio: `--out`),
  `netlify/functions/lib/mcp-backend.js` (the artifact cache),
  `netlify/functions/mcp-artifact.js` (the download route),
  `netlify.toml` (`/mcp/artifact/*`)
* Future ADRs referenced: owned drafts (ADR-0064's Option B3), which should absorb
  both this namespace and the document cache once ADR-0024/0025 provide an identity
* Amends: ADR-0064's "retention is never implicit", which becomes "never implicit for
  a document you sent; implicit and bounded for an artifact you asked the server to
  build, escapable with `inline: true`"
* Origin: a cold run of the hosted endpoint from ChatGPT/Codex, where every tool
  succeeded and the archive could not be written to a file.

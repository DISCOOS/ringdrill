---
status: proposed
date: 2026-07-31
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0064: Cut the document out of the authoring loop, and stop over-answering

## Context and problem statement

Every document-taking MCP tool — `analyze_plan`, `build_plan`, `render_plan` —
takes the source document as inline text, and the authoring loop calls them
repeatedly on the *same* document: write, analyze, fix, analyze, render, read,
fix, build. Converting the 2026 LSOR course booklet produced an 84 KB source
document and a 75 KB director brief. At roughly four tokens to the ten characters,
one analyze-render-build cycle moves something like 60k tokens of text that has
not changed since the previous cycle.

The cost is not bandwidth and not a server limit — `MAX_DOCUMENT_CHARS` is 512 KB
and the compile timeout is 10 s, both comfortable. The cost is the **agent's
context window**, spent twice: once producing the document, once reading back an
answer that mostly repeats it. That is what made this session abandon the MCP
tools for the real work: the CLI takes a file path, so the same loop costs a
filename. An MCP client not sitting in the checkout has no such escape.

Two halves, with different constraints.

**Output has none.** `render_plan` returns the whole brief and its only scoping is
`exercise`. What an iterating author needs is narrower — "did any token fail to
resolve", "show me station 3a" — and narrowing a response retains nothing.

**Input runs into ADR-0060.** The obvious fix is to cache the document
server-side under a content hash and let later calls reference the hash.
[ADR-0060](./0060-remote-mcp-server.md) currently forbids that: "the hosted
server **must not persist documents** … a requirement of this decision, not an
implementation detail", on author-privacy grounds — real plans are staff-only (the
catalog's anchor plan opens "KUN FOR STAB"), so a hosted option that retained what
it was sent would not be a safe default. The hosted backend has no write path at
all, deliberately.

That requirement is open to revision, so this ADR weighs caching on its merits
rather than treating it as settled. Two things about it are worth separating,
because only one is actually in tension:

* ADR-0060's first claim — "a hosted option must not be the *only* option" — is
  satisfied by stdio existing, and no option here touches it.
* The second — "must not retain what it is sent" — is what caching needs, and it
  is a promise about what the service *is*, not a limit on what it can do.

The stdio transport is different in kind, and that difference is already
load-bearing in ADR-0060: it exists for development, offline work, and the author
who does not want a staff-only plan leaving their machine. There the document is
*already* on the local filesystem, and the backend writes the inline text to a
temp file in order to shell out to the CLI. The round trip through the agent's
context buys nothing at all.

## Decision drivers

* Fix the case that actually hurt — a large document under repeated local
  iteration — rather than the case that is easiest to describe.
* Keep one tool table across both transports, so a parameter cannot mean two
  things depending on which server answered.
* Add no capability either transport does not already have.
* Weigh retention against what it buys, and say which use case is paying. "Tokens"
  and "a staff-only plan sits in a blob store" are not the same kind of cost, and
  the trade is only worth making for a use case that exists.
* An agent must be able to tell what happened without re-reading the whole
  artifact.

## Considered options

* Option A — Status quo: inline text every call; reach for the CLI when the
  document is large.
* Option B1 — Durable content-addressed cache: `document_hash` in place of
  `document`, stored in Netlify Blobs with a short TTL, typed "unknown document,
  resend" on a miss. Amends ADR-0060.
* Option B2 — Best-effort in-memory cache: the same handle, held only in a warm
  function container, never written to storage. A narrower reading of 0060 rather
  than a reversal.
* Option C — `document_path` on stdio, rejected by the hosted transport, plus
  response scoping on `render_plan`. No retention anywhere.
* Option D — A server-side authoring session mutated by structured edit
  operations.
* Option E — One combined call returning diagnostics *and* the brief, so a single
  upload answers both questions the loop asks.

## Decision outcome

Chosen option: **Option C now, in two independent parts, with Option E as the next
step and B1 held open on evidence.**

**Input, stdio.** The document-taking tools accept `document_path` as an
alternative to `document`. The stdio backend reads that file directly instead of
writing inline text to a temp file — the same file the author is editing, never
leaving the machine. The hosted backend rejects it with a diagnostic naming the
reason ("a path is meaningful only to a local server; send `document`"), so the
parameter keeps one meaning in the shared table and a transport that cannot honour
it says so rather than guessing. No new capability: the stdio backend already
invokes a CLI that reads whatever path it is given, as the user.

**Output, both transports.** `render_plan` gains `station` — a 1-based station
within the scoped exercise — and `format: 'summary'`, which returns headings, the
sections present under each, and any unresolved-token diagnostics, without the
prose. Those are the two questions an iterating author asks, answered in a page.

**On caching.** Not now, and not because ADR-0060 says so. The benefit accrues
specifically to *hosted* iteration on a *large* plan, and that is the use case
ADR-0060 deliberately steers away from — a large real plan is staff-only, which is
what stdio is for. Before trading the retention promise for it, the thing to know
is whether anyone authors large plans against the hosted server at all; that is
measurable from the hosted tool's own request sizes, and nothing here has measured
it. If it turns out to be a real pattern, **B1 is the right shape** — content
addressing makes the cache idempotent and the miss case well defined — and it
supersedes ADR-0060's retention requirement explicitly rather than eroding it.
Option E gets a large share of the same win with no retention at all, so it comes
first regardless.

### Consequences

* Good: local authoring of a large document stops paying for the document on every
  call — a filename replaces 84 KB, which is the case that drove this.
* Good: `format: 'summary'` answers "does this render" without reading the brief,
  which is the check the authoring skill prescribes at every iteration, and it
  helps both transports.
* Good: ADR-0060's promise is left intact *by choice*, with the conditions for
  revisiting it written down, so the next person to propose a cache inherits the
  argument instead of restarting it.
* Good: nothing about the archive, the compiler or the source format changes.
* Bad: the transports are no longer interchangeable at the parameter level. An
  agent developed against stdio and moved to the hosted server must fall back to
  `document`, and learns that from an error rather than the schema, because a
  schema cannot express "only on some servers".
* Bad: `document_path` lets an agent name a file the user did not mention, and a
  diagnostic quoting the offending line echoes a little of its content back. The
  capability already exists through the CLI, but this makes it one tool call away,
  so diagnostics must keep quoting at most a short snippet.
* Bad: the hosted transport keeps paying full price on input. An author iterating
  on a large plan there is still better served by the CLI, and this ADR declines to
  fix that rather than failing to notice it.
* Bad: two more parameters on `render_plan`, and `format` will attract further
  values (a diff mode, a token report) unless held to a small vocabulary.

## Pros and cons of the options

### Option A — Status quo
* Good: nothing to build; the CLI already solves it for anyone in the checkout.
* Bad: makes the MCP tools the second-best way to author anything large, which is
  the opposite of why the server exists.
* Bad: the failure is invisible until an agent has spent a context window
  discovering it.

### Option B1 — Durable content-addressed cache
* Good: the largest win available, and the only option that helps hosted input —
  an author could iterate for the cost of a hash.
* Good: content addressing makes the cache idempotent, the key verifiable and the
  miss case well defined; a TTL bounds retention.
* Bad: needs ADR-0060's retention requirement superseded. That is allowed, but it
  changes what the hosted server *is* — "we keep your draft for ten minutes" is a
  different promise from "we compile what we are sent and return the result", and
  the plans most likely to be large are the ones most likely to be staff-only.
* Bad: every client must implement resend-on-miss regardless, so the cache adds a
  branch to each of them.
* Bad: inherits the store's documented token-expiry footgun (`_shared.js` explains
  why a `getStore()` result must not be memoized).

### Option B2 — Best-effort in-memory cache
* Good: no durable write, so the strongest reading of "must not persist" survives —
  the document lives no longer than the container that compiled it.
* Good: a tight loop often hits the same warm container, so the practical hit rate
  may be high.
* Bad: "often" is not a contract. Unpredictable cost is worse for an agent than
  predictable cost, because it cannot plan around it.
* Bad: the client still needs the full resend-on-miss path, which is most of B1's
  complexity for a fraction of its guarantee — and if that path must exist anyway,
  B1 is the honest version.

### Option C — Path input on stdio, plus response scoping
* Good: fixes the measured case, retains nothing, adds no capability.
* Good: the two halves are independent; the output half helps every transport and
  could land alone.
* Bad: transport-asymmetric parameter; hosted input unimproved.

### Option D — Server-side authoring session
* Good: the smallest per-edit payload, and structured edits are checkable in a way
  whole-document replacement is not.
* Bad: needs more retention than B1, not less — a session is a document held across
  calls by definition.
* Bad: turns the MCP server into an editor API, with a state machine, concurrency
  and invalidation, for a format whose premise is that the document is the artifact
  the author owns and edits.

### Option E — One combined call
* Good: cuts the loop's uploads with no retention, and helps hosted input where
  nothing else here does.
* Good: matches what the authoring skill actually prescribes — analyze, then read
  the brief.
* Bad: a tool that both validates and renders has two failure modes behind one
  response shape, and an agent wanting one still pays for the other.
* Bad: worth more *after* `format: 'summary'` exists, because the combination to
  make is "analyze plus a summary render", not "analyze plus 75 KB". Sequenced
  after C rather than guessed at now.

## Links

* Related ADRs: [ADR-0060](./0060-remote-mcp-server.md) (statelessness, and the
  retention requirement B1 would supersede),
  [ADR-0058](./0058-source-format-and-plan-compiler.md),
  [ADR-0044](./0044-render-preview-on-site.md)
* Related code: `mcp/tools.mjs` (the shared tool table),
  `mcp/backend-cli.mjs` (stdio: temp file plus CLI),
  `netlify/functions/lib/mcp-backend.js` (`MAX_DOCUMENT_CHARS`, no write path),
  `netlify/functions/_shared.js` (the store caveat B1 would inherit)
* Future ADRs referenced: the combined analyze-plus-summary call (Option E), and a
  hosted document cache (Option B1) if hosted request sizes show the use case is
  real
* Origin: authoring the converted 2026 LSOR booklet, where an 84 KB source document
  and a 75 KB brief made the CLI the only practical loop.

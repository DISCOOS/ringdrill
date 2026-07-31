---
status: accepted
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

That requirement is open to revision, and the use case it was weighed against is
now settled rather than hypothetical: **the users who matter produce large plans**,
routinely. A design that makes a large plan second-class on the hosted transport
therefore fails precisely the people it exists for, and "use the CLI instead" is
not an answer for a client with no checkout.

One more fact shapes what retention can look like. The hosted server is
**unauthenticated on purpose** (ADR-0060: "nothing to authorize… deliberately *not*
an OAuth decision", revisited when account-aware publishing arrives with
[ADR-0024](./0024-account-and-identity-model.md) and
[ADR-0025](./0025-authorization-and-publish-policy.md)). So anything it holds
cannot be *owned* by anybody yet — there is no identity to attribute a draft to, or
to authorize its deletion.

Two things about the retention requirement are worth separating, because only one
is actually in tension:

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

* Fix the case that actually hurt — a large document under repeated iteration —
  on both transports. Large plans are what the users who matter produce, so a
  hosted server that only handles small ones is not serving them.
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
* Option B3 — Owned drafts: the document becomes a first-class stored object with
  the catalog's ownership and access policy, referenced by id.
* Option C — `document_path` on stdio, rejected by the hosted transport, plus
  response scoping on `render_plan`. No retention anywhere.
* Option D — A server-side authoring session mutated by structured edit
  operations.
* Option E — One combined call returning diagnostics *and* the brief, so a single
  upload answers both questions the loop asks.

## Decision outcome

Chosen option: **C and B1 together** — C because it costs nothing and fixes local
iteration outright, B1 because large plans on the hosted transport are the normal
case and nothing else addresses them.

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

**Input, hosted: an opt-in, content-addressed, expiring cache.** A call may pass
`cache: true`; the response then carries `document_hash`, the server's SHA-256 of
the exact bytes it compiled, and later calls may send `document_hash` in place of
`document`. A miss returns a typed diagnostic telling the client to resend, so a
cold cache is a slower loop rather than a failure.

Three properties do the work, and none of them needs an account:

* **Opt-in.** Retention is never implicit, so ADR-0060's promise holds unchanged
  for every caller who does not ask. The tool description says when to ask: when
  you intend to iterate.
* **Content-addressed.** The server computes the key from the content, so a client
  cannot choose keys — the cache cannot be used as a general store, and a hash is
  only obtainable by having already held the document. It is a capability key, in
  the same family as an unguessable URL.
* **Expiring.** A short TTL, on the order of an authoring session rather than a
  day, bounded and stated.

This **amends** ADR-0060's retention requirement rather than deleting it. The
promise becomes: *the hosted server does not retain what it is sent, unless you ask
it to, in which case it holds that document under its own content hash for a stated
and short period.* That sentence has to reach the server's own user-facing
documentation, which ADR-0060 already requires of the original promise.

Sequencing: C first, since it is small and unblocks local work; then Option E, the
combined analyze-plus-summary call, which cuts hosted round trips with no retention
at all and is worth more once `format: 'summary'` exists; then B1. When account-aware
publishing lands, **B3 is B1's successor** — an owned, listable, deletable draft is
a better answer than an invisible cache, and at that point the identity to hang it
on will exist.

### Consequences

* Good: local authoring of a large document stops paying for the document on every
  call — a filename replaces 84 KB.
* Good: hosted authoring of a large plan becomes viable, which is what the users who
  matter are doing. A loop costs one upload and then hashes.
* Good: `format: 'summary'` answers "does this render" without reading the brief,
  which is the check the authoring skill prescribes at every iteration, and it helps
  both transports.
* Good: the default promise is unchanged. An author who never sets `cache` gets
  exactly the server ADR-0060 described.
* Good: content addressing keeps the cache out of the general-storage business and
  makes the key verifiable, so a retrieval cannot return something other than what
  was stored under it.
* Bad: the hosted server now retains author content on request, and the plans most
  likely to be large are the ones most likely to be staff-only. The mitigation is
  consent plus a short TTL, not encryption — the server has to read the document to
  compile it, so there is no design here where it holds only ciphertext.
* Bad: an unauthenticated cache is a dead-drop surface — an author who shares a hash
  shares the document. Bounded by the TTL and by the content being plan-shaped text,
  but it is a real property to document rather than discover.
* Bad: no owner means no listing and no delete. A cached document is unreachable
  except by hash and disappears on its own, which is the best available answer
  without identity and a worse one than B3 will be.
* Bad: `cache: true` is a decision the agent makes on the author's behalf. The skill
  has to say when it is appropriate, and an agent that sets it reflexively has
  quietly opted its user into retention.
* Bad: the transports are no longer interchangeable at the parameter level —
  `document_path` on one, `document_hash` on both but only useful on the hosted one.
  An agent learns the difference from an error rather than the schema, because a
  schema cannot express "only on some servers".
* Bad: `document_path` lets an agent name a file the user did not mention, and a
  diagnostic quoting the offending line echoes a little of its content back. The
  capability already exists through the CLI, but this makes it one tool call away, so
  diagnostics must keep quoting at most a short snippet.
* Bad: more surface on `render_plan`, and `format` will attract further values (a
  diff mode, a token report) unless held to a small vocabulary.

## Pros and cons of the options

### Option A — Status quo
* Good: nothing to build; the CLI already solves it for anyone in the checkout.
* Bad: makes the MCP tools the second-best way to author anything large, which is
  the opposite of why the server exists.
* Bad: the failure is invisible until an agent has spent a context window
  discovering it.

### Option B1 — Durable content-addressed cache
* Good: the largest win available, and the only option that helps hosted input —
  an author iterates for the cost of a hash.
* Good: content addressing makes the cache idempotent, the key verifiable and the
  miss case well defined; a TTL bounds retention; opt-in bounds who is exposed to
  it at all.
* Bad: amends ADR-0060's retention requirement, so what the hosted server *is*
  changes for anyone who opts in.
* Bad: every client must implement resend-on-miss regardless, so the cache adds a
  branch to each of them.
* Bad: inherits the store's documented token-expiry footgun (the shared blob helper
  explains why a `getStore()` result must not be memoized).

### Option B3 — Owned drafts
* Good: the right long-term shape. A draft that can be listed, shared with a
  co-author and deleted answers the author's problem, not just the token problem.
* Good: reuses storage, ownership and access policy the catalog already has, rather
  than inventing retention semantics beside them.
* Bad: needs an authenticated caller, and the hosted server is unauthenticated on
  purpose — this is the OAuth commitment ADR-0060 deferred until account-aware
  publishing. Unavailable now, not undesirable.
* Bad: without identity it degenerates into B1 with more machinery.

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
* Future ADRs referenced: the combined analyze-plus-summary call (Option E), and
  owned drafts (Option B3) once account-aware publishing provides the identity to
  attribute one to
* Amends: ADR-0060's "must not persist documents" requirement, which becomes
  "does not retain unless asked, by content hash, for a stated short period".
  ADR-0060's *Transport and statelessness* section carries a pointer here.
* Origin: authoring the converted 2026 LSOR booklet, where an 84 KB source document
  and a 75 KB brief made the CLI the only practical loop.

---
status: proposed
date: 2026-07-31
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0065: Ship the authoring conventions over MCP, not only as a local skill

## Context and problem statement

The authoring conventions live in `skills/ringdrill-plan-authoring/` — a local
directory. They carry everything the schema cannot: numbering comes from list
position so never write it into a name, a token is content and not something to
resolve while writing, a variable is declared once, scenario data belongs to a
station, a role play inherits by omission, never invent staff, `numberOfTeams` must
be ≤ the station count, a station is a scenario rather than a label, time it
honestly.

An MCP client that is not sitting in this checkout gets none of it. It gets the
field list and no conventions, which is the case the skill itself names: "Generated
plans that skip this step read like a template." The consequences are not only
aesthetic. Converting the LSOR booklet in this session, the skill is what stopped
real volunteers' names and duty numbers going into `director_notes` — the schema
guards `persons` ("Never a real human — that is Staff") but says nothing about free
prose, and `director_notes` is not stripped at publish. It is also what stopped
`"2a) Fisker"` being written as a station name under a renderer that already
derives `2a`.

The servers have no channel for any of this. Both advertise
`capabilities: { tools: {} }` — no `instructions` string at `initialize`, no
resources, no prompts. The only guidance an MCP-only client can currently receive
is what fits in tool descriptions, plus whatever a diagnostic happens to say.

Two decisions bound the answer. [ADR-0060](./0060-remote-mcp-server.md) makes the
two transports share one tool table, so guidance must not differ by transport
either — an agent's behaviour should not depend on which server answered.
[ADR-0064](./0064-mcp-payload-economy.md) has just established that per-call
payload is the scarce resource, so pasting a guide into every response would
reintroduce exactly what it fixed.

## Decision drivers

* The rules whose violation is *unsafe* — real people in prose, a spoiler in a
  participant-visible field — must reach every client, not only the ones with the
  repo.
* Guaranteed-read channels are tiny. Long-form guidance has to be pull-based, and
  something always in context has to advertise it.
* One source of truth. The skill markdown already exists; a second copy in a JS
  string would drift, and this session has already fixed that class of drift three
  times (the facet list, the `.utm` resolvers, `build` versus `analyze`).
* Client support varies. Resources and prompts are optional MCP capabilities; tool
  descriptions and `instructions` are what every client handles.
* Do not reintroduce per-call payload (ADR-0064).
* Where a rule can be a check, it should be a check. Prose is the fallback, not the
  mechanism.

## Considered options

* Option A — Status quo: the skill for local users, nothing for hosted ones.
* Option B — Fold the essentials into tool descriptions only.
* Option C — An `instructions` string at `initialize` only.
* Option D — Layered: short `instructions`, the skill served verbatim as
  resources, a prompt for the workflow, invariants also in tool descriptions.
* Option E — Return guidance in tool output — `create_plan` prepending the
  conventions to its scaffold, and so on.

## Decision outcome

Chosen option: **Option D**, because no single channel is both guaranteed-read and
large enough, so the guidance has to be split by how much it costs to always carry.

**`instructions` at `initialize`** — short, and only the rules whose violation is
unsafe or unrecoverable: no real people in any field, numbering is derived, tokens
are content, teams ≤ stations, a withheld field is withheld by declaration. Ends
with a pointer to the resources. This is the one channel most clients inject into
the system prompt, so it is the only place a rule is certain to be seen — and that
certainty is exactly why it must stay short.

**Resources** — `ringdrill://guide/authoring` and `ringdrill://guide/format`,
served **from the skill's own markdown files** so there is one source and no second
copy to drift. Capabilities gain `resources: {}`. On stdio the server reads them
from disk; on the hosted transport they ship with the function via
`[functions."mcp"] included_files`, the same mechanism the compiler bundle uses —
scoped to that function, since the other pattern copied 700 KB into all sixteen
deployment packages.

**A prompt** — `author_plan`, carrying the call order (`schema`, read the catalog,
`create_plan`, write, `analyze`, `render`, `build`). Capabilities gain
`prompts: {}`. Clients that surface prompts give a user the skill as something they
can pick; clients that do not lose nothing they had.

**Tool descriptions keep the invariants**, because they are the only channel with
universal support, and `schema`'s field descriptions already carry several
(`stationNumberFormat` explaining `alpha`, `variantSuffix` being display-only).

Option E is adopted **where it is cheap and load-bearing**: a diagnostic that names
the rule it enforced is worth more than the same sentence in a guide nobody
fetched. `analyze` already does this — the facet warning names ADR-0050's rename —
and that pattern is the reason the mistake was findable at all. It is not extended
to prepending prose to every tool result, which would be the payload problem again.

### Consequences

* Good: an MCP-only client can author to the same conventions as a local one, which
  is the difference between a plan that reads like a template and one that does not.
* Good: one source. The resources are the skill files, so a convention cannot be
  right in the skill and stale in the server.
* Good: a resource is fetched once per session rather than pasted per call, so this
  composes with ADR-0064 instead of fighting it.
* Good: the unsafe-output rules stop depending on whether the client happens to
  have the repo checked out.
* Bad: two more optional capabilities to implement, test and keep working on both
  transports, where today there is one.
* Bad: `instructions` is client-dependent — some clients ignore it entirely — so it
  cannot be the only channel, and its content will drift from the skill unless
  something checks. A test should assert that every rule named in `instructions`
  still appears in the skill it summarises.
* Bad: prompts are user-triggered. An agent that never lists them gains nothing, so
  the prompt is a convenience rather than a guarantee, and the ADR should not be
  read as making it one.
* Bad: nothing here makes an agent *read* a resource, let alone follow it. The
  honest reading of this decision is that it removes an excuse, not that it
  guarantees an outcome; the guarantees stay in `analyze`, in the fail-closed
  audience declaration, and in `build` refusing a known-broken document.
* Bad: shipping markdown into the function is another `included_files` entry, and
  that mechanism has already caused one deployment-size incident here. Scoped to
  the `mcp` function deliberately.

## Pros and cons of the options

### Option A — Status quo
* Good: nothing to build; the skill already serves the case it was written for.
* Bad: hosted authoring is the case the users who matter will hit (ADR-0064), and
  it is the one with no conventions at all.
* Bad: leaves the PII rule reachable only by contributors, which is the wrong rule
  to make optional.

### Option B — Tool descriptions only
* Good: universal client support, always in context, no new capability.
* Bad: the tool list is the tightest budget there is. The skill is thousands of
  words; a paragraph per tool cannot carry "a station is a scenario, not a label"
  with the worked examples that make it actionable.
* Bad: pushes prose into a place read on every request, which is ADR-0064's problem
  in a different coat.

### Option C — `instructions` only
* Good: one field, no capability negotiation, injected into the system prompt by
  most clients.
* Bad: same size problem as B, and worse support variance — a client that ignores
  `instructions` would then get nothing.

### Option D — Layered
* Good: each rule sits in the cheapest channel that can carry it reliably.
* Good: one source of truth, and no per-call cost.
* Bad: three channels to keep consistent, and a drift test to write.

### Option E — Guidance in tool output
* Good: guaranteed to be read, because the agent asked for the result it is
  attached to. Diagnostics that name their rule demonstrably work.
* Bad: as a general mechanism it inflates every response, which ADR-0064 has just
  ruled out.
* Bad: guidance attached to output arrives *after* the mistake. Adopted for
  diagnostics, where after-the-fact is the point, and rejected as a way to deliver
  conventions up front.

## Links

* Related ADRs: [ADR-0060](./0060-remote-mcp-server.md) (one tool table, two
  transports), [ADR-0064](./0064-mcp-payload-economy.md) (per-call payload is the
  scarce resource), [ADR-0058](./0058-source-format-and-plan-compiler.md),
  [ADR-0063](./0063-per-field-brief-visibility.md) (the fail-closed declaration this
  ADR leans on rather than duplicating)
* Related code: `mcp/tools.mjs` (the shared table and the `initialize` result),
  `netlify/functions/mcp.js`, `netlify.toml` (`[functions."mcp"] included_files`),
  `skills/ringdrill-plan-authoring/SKILL.md` and `reference/format.md` (the source
  the resources serve)
* Origin: converting the 2026 LSOR booklet, where the local skill prevented real
  volunteers' names reaching `director_notes` and a hosted client would have had no
  equivalent.

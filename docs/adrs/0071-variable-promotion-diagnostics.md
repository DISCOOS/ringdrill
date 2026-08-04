---
status: proposed
date: 2026-08-04
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0071: Report a literal that wants to be a variable, instead of only advising it

## Context and problem statement

A cold agent with nothing but the hosted MCP server converted the 2026 LSOR booklet
into a plan that compiles clean — 0 errors, 0 warnings — and contains **no tokens at
all**. Measured against the hand-authored plan for the same source:

| | cold agent | hand-authored |
|---|---|---|
| `mode:` / `groups:` | 3 / 1 | 3 / 1 |
| `executionTime` / `evaluationTime` / `rotationTime` | 10 / 7 / 9 | 10 / 7 / 9 |
| `leader_answers` / `critical_questions` / `roleplays` | 17 / 15 / 11 | 17 / 15 / 11 |
| `{{var.*}}` / `{{station.*}}` / `{{exercise.*}}` | **0 / 0 / 0** | 49 / 77 / 3 |
| `persons:` / `locations:` / `variableOverrides` | **0 / 0 / 0** | 24 / 23 / 5 |

The structural layer is *exact*. Modes, split groups, per-station time overrides — the
things that are hard to get right and easy to get wrong — match the human's plan
occurrence for occurrence. The relational layer is absent entirely.

That is not carelessness, and the difference between the two halves is the whole
finding: **everything the compiler enforces was done, and everything only the prose
asks for was skipped.** `numberOfTeams <= stations`, the mode vocabulary, the
group/round arithmetic — a wrong answer there is rejected, so it got a right one. A
talegruppe typed into eleven fields is accepted silently, so it stayed typed into
eleven fields.

The guidance is not missing and not vague. It names the exact literals:

> Nothing derives a talegruppe, a duty phone number, a meeting place or a team
> designation … promote a literal that appears in three or more fields, or one decided
> late or changed on the day.

It is present in the always-injected instructions *and* in the authoring skill, with a
worked example (`Lag 2.X`, 39 occurrences, one variable). It was read and not acted on.

Two things about how it is written explain that. It is framed as a **discretionary
cleanup sweep** — "sweep for these once the draft is written" — and a later optional
pass is the first casualty when an agent is converging on done. And it is the only
authoring rule of its class with **no enforcement anywhere**: the agent ran
`analyze_plan` and fixed everything it reported, which is the behaviour we want. It
reported nothing here.

What the missing layer costs is not tidiness. A hardcoded talegruppe or duty number is
wrong for the author the moment it changes on the day, in eleven places, in a document
they now have to grep. That is the failure the variable layer exists to prevent, and
it lands on the person running the exercise rather than on the agent that wrote it.

One clarification shapes the whole design. **An operational contact value belongs in a
plan** — a duty phone number, a KO number, a talegruppe are facts the exercise needs.
The fault is never that the value is present, only that it is typed into prose instead
of declared once. So this is a *modelling* diagnostic, not a PII scanner. (Real people
are a separate rule with a separate answer: drop the name, keep the role. Nothing here
changes it.)

## Decision drivers

* Convert a rule an agent demonstrably skips into output it demonstrably acts on. The
  evidence that diagnostics work is in the same cold run: everything `analyze_plan`
  reported got fixed.
* Do not become a PII scanner. An operational value in a plan is correct content; only
  its location is wrong. A diagnostic that reads as "remove this" teaches the opposite
  of the rule.
* **A false positive is more expensive than a miss.** This repo has already removed a
  warning rather than repaired it for exactly this reason
  (commit `51377382`, and the comment it left in `mcp/backend-cli.mjs`): the CLI
  staleness check fired on essentially
  every server start and named a file that could not be the cause, so it taught people
  to stop reading stderr — "a warning that is always on is a banner". A suggestion that
  fires on ordinary prose would do the same to `analyze_plan`, which is the one channel
  currently working.
* A heuristic must not be able to fail a build. `--strict` promotes warnings to errors,
  so severity is a real decision here, not a detail.
* Actionable, in the existing shape: a `path` at the offending field and a `hint`
  naming the remedy, so an agent can act without re-reading the guide.
* One implementation for every surface. The analyzer is shared by the CLI, both MCP
  backends and the app, so this must not become an MCP-only feature.

## Considered options

* Option A — Status quo: prose only, in two channels.
* Option B — Repeated-literal diagnostic: a value-shaped literal appearing in N or more
  distinct fields.
* Option C — Pattern diagnostic: a contact-shaped literal (phone number) anywhere, at a
  single occurrence.
* Option D — B and C together, as one diagnostic family with one remedy.
* Option E — A separate `suggest_variables` tool, or an `analyze_plan` mode, rather than
  diagnostics in the main stream.
* Option F — Auto-promotion: the compiler declares the variable and rewrites the fields.

## Decision outcome

Chosen option: **D**, both rules, emitted by `SourceAnalyzer` as a new severity that
`--strict` does not promote.

### The two rules

**B — repeated value-shaped literal.** Fires when the same literal occurs in **three or
more distinct fields**, matching the threshold the guidance already states. Distinct
*fields*, not occurrences: `Lag 2.X` thirty-nine times inside one `method` is one field
and one editing site, while the same string across eleven station `comms` is eleven.

The false-positive defence is not a stop-word list, it is a shape restriction:
**only value-shaped literals are candidates.** A literal qualifies when it contains a
digit, or is upper-case with internal punctuation (`RK-VFOLD-ØV4`, `DMO-ANDRE-1`), or is
a known contact shape. Ordinary prose words never qualify, which is the concrete meaning
of the guidance's "do not promote a word that merely recurs in prose."

**C — contact-shaped literal, at one occurrence.** A phone number does not need to
repeat to want a variable: the guidance's second criterion is "decided late or changed
on the day", and a duty number is the canonical case. The corpus shows the shape
plainly — `93258930`, `97525282`, `39414813` — and shows what must *not* match, all of
which are real content:

| Looks similar | Actually | Discriminator |
|---|---|---|
| `987654-1`, `987660-1` | AMIS incident numbers | six digits + `-` + digit |
| `32V 0580307E 6552025N` | UTM coordinate | embedded letters |
| `EK35989`, `SV41219` | vehicle registrations | leading letters |
| `(46)`, `(17)` | a person's age | parenthesised, two digits |

So the pattern is a run of exactly 8 digits, optionally in the 2-2-2-2 or 3-2-3 groups
Norwegian numbers are written in, not adjacent to another digit and not followed by
`-<digit>`; plus explicit international forms (`+47 …`).

### Severity: a third level, and why

`SourceDiagnostic` is binary today — `error` or `warning`, with `isError` as the only
predicate. Both new rules are heuristics, and `build --strict` promotes warnings to
errors. A heuristic that can fail a build is a heuristic that gets switched off, so a
third level is added:

```
enum DiagnosticSeverity { error, warning, suggestion }
```

`suggestion` is never promoted by `--strict`, never affects an exit code, and is counted
separately in `--json` so `errors`/`warnings` keep their current meaning for every
existing caller. That is the smallest change that keeps "warnings are things `--strict`
may reasonably refuse a build over" true, which it would stop being if a naming
suggestion sat among them.

The cost is honest: a third counter in the JSON envelope, a third label in the CLI's
output, and a level an agent may learn to ignore precisely *because* it cannot fail
anything. The mitigation is that it says what to do and where, not that it shouts.

### Consequences

* Good: the layer a cold agent skips becomes output it acts on, through the one
  mechanism that has been observed to work on it.
* Good: the rule the prose already states gets one enforcement point, shared by the CLI,
  both MCP backends and the app, rather than being restated in a third channel.
* Good: the author is the beneficiary. A promoted talegruppe is one edit on the day
  instead of eleven.
* Good: it flags the *location* of a legitimate value, so it teaches the rule rather
  than teaching people to delete operational content.
* Bad: **a Norwegian phone shape hardcoded in a format that declares its own
  `language:`.** An eight-digit run is a national convention, and a plan in another
  language will both miss real numbers and risk matching something else. Accepted rather
  than solved: the corpus is Norwegian today, the pattern is one constant, and a
  language-scoped table is the extension point when a second language arrives. Naming it
  here so the next contributor finds a decision rather than an oversight.
* Bad: a third severity is a wire-format change. Every consumer of the `--json`
  envelope and of `analyze_plan` sees a new field, and the app's diagnostic rendering
  needs a third case.
* Bad: heuristics accumulate. "Value-shaped" and "contact-shaped" will attract a next
  case (door codes, callsigns, meeting places, times of day), and the shape restriction
  is what keeps that bounded — a proposal that needs a stop-word list is out of scope by
  construction.
* Bad: it cannot see the strongest case for a variable, which is semantic. A meeting
  place written three different ways in three fields is three distinct literals and
  will not fire.
* Bad: it does nothing about the other absent halves — `persons`, `locations` and the
  `{{station.*}}` cross-references were also zero, and a repeated-literal rule does not
  reach them. This ADR fixes the cheapest third of the finding.

### What this deliberately does not fix

The cold run had a second cause, and it is not a diagnostic problem: **the published
corpus teaches flat plans.** The prescribed order says to read a published plan with
`get_plan` "so a generated plan matches how real ones are written", and the plan in the
catalog has zero tokens, zero `persons`, zero `locations`, everything crammed into one
`description`, and station names carrying the numbering the rules forbid. An agent that
matches the corpus has obeyed the instruction it was given, and a concrete example beats
prose every time.

Diagnostics would at least fire on that plan too. But the corpus is a content problem
with a content fix, tracked separately from this decision.

## Pros and cons of the options

### Option A — Status quo
* Good: nothing to build; no false positives possible.
* Bad: measured to fail. The rule is present in both channels, specific, worked-example
  backed, and produced zero variables.
* Bad: the cost lands on the author on exercise day, not on the agent, so nobody who
  could fix it feels it.

### Option B — Repeated literal only
* Good: the threshold is already written down and already argued for.
* Good: catches the highest-volume case (`RK-VFOLD-ØV4` in six fields).
* Bad: misses the single duty number, which the guidance's own second criterion covers
  and which is the most likely value to change on the day.

### Option C — Pattern only
* Good: catches the sharpest case at n=1, and the exclusions are enumerable from the
  corpus.
* Bad: leaves talegrupper and team designations — the bulk of the actual repetition —
  unreported.
* Bad: a pattern list with no repetition rule invites growth toward a general PII
  scanner, which is explicitly not the goal.

### Option D — Both
* Good: covers both criteria the guidance states, with one remedy and one hint.
* Good: the two rules constrain each other — repetition needs a value shape, patterns
  need enumerated exclusions — so neither drifts into matching prose.
* Bad: two heuristics to tune instead of one.

### Option E — A separate tool or analyze mode
* Good: cannot pollute the diagnostic stream, so the false-positive risk is contained by
  construction.
* Good: could be more speculative, since nothing depends on it.
* Bad: opt-in guidance is what already failed. A tool an agent must know to call is the
  same discretionary sweep with an API in front of it, and the cold run shows what
  happens to discretionary steps.
* Bad: a second analysis surface to keep in step with the first, on both transports.

### Option F — Auto-promotion
* Good: the highest compliance available — the output is simply correct.
* Bad: the premise of the format is that the source document is the artifact the author
  owns and edits (ADR-0058). A compiler that invents `variables` entries and rewrites
  prose produces a document its author did not write and cannot predict.
* Bad: naming is the hard part and is semantic. `var.tlf_ko` versus `var.tlf` versus
  `var.narve` is an authoring judgement, and a generated slug would be wrong often
  enough to be worse than a suggestion.

## Links

* Related ADRs: [ADR-0058](./0058-source-format-and-plan-compiler.md) (the source
  document is the author's artifact, which rules out Option F),
  [ADR-0065](./0065-authoring-guidance-over-mcp.md) (the channel split this shows the
  limits of — guidance reaching an agent is not the same as an agent acting on it),
  [ADR-0068](./0068-cascaded-fields-and-scoped-overrides.md) (`variableOverrides`, also
  zero in the cold plan)
* Related code: `lib/data/source/source_diagnostic.dart` (the severity enum this
  extends), `lib/data/source/source_analyzer.dart` (where both rules belong),
  `mcp/tools.mjs` (`analyze_plan`'s description and the instructions that state the
  rule), `skills/ringdrill-plan-authoring/SKILL.md` (the promotion criteria and the
  `Lag 2.X` worked example)
* Precedent cited: commit `51377382`, removing a staleness warning rather than repairing
  it — the in-repo argument that an over-firing warning is worse than none.
* Origin: a cold MCP-only run of the 2026 LSOR booklet that compiled clean with zero
  tokens, alongside a hand-authored plan of the same source with 129.

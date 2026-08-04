---
status: proposed
date: 2026-08-04
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0071: Report a modelling shortcut, instead of only advising against it

## Context and problem statement

A cold agent with nothing but the hosted MCP server converted the 2026 LSOR booklet into
a plan that compiles clean — 0 errors, 0 warnings — and contains **no entities and no
tokens at all**. Measured against the hand-authored plan for the same source booklet:

| | cold agent | hand-authored |
|---|---|---|
| `mode:` / `groups:` | 3 / 1 | 3 / 1 |
| `executionTime` / `evaluationTime` / `rotationTime` | 10 / 7 / 9 | 10 / 7 / 9 |
| `roleplays` / `leader_answers` / `critical_questions` | 11 / 17 / 15 | 11 / 17 / 15 |
| `persons:` / `locations:` / `variableOverrides` | **0 / 0 / 0** | 24 / 23 / 5 |
| `{{var.*}}` / `{{station.*}}` / `{{exercise.*}}` | **0 / 0 / 0** | 49 / 77 / 3 |

The structural layer is *exact*. Modes, split groups, per-station time overrides, even
the count of role plays and of the staff-facing markdown fields — the things that are
hard to get right and easy to get wrong — match the human's plan occurrence for
occurrence. The **relational** layer is absent entirely.

That is not carelessness, and the split between the two halves is the whole finding:
**everything the compiler enforces was done, and everything only the prose asks for was
skipped.** `numberOfTeams <= stations`, the mode vocabulary, the group arithmetic — a
wrong answer there is rejected, so it got a right one. A talegruppe typed into eleven
fields, a coordinate typed into a sentence, a role play that invents its own person: all
accepted silently, so all of them stayed.

The guidance is neither missing nor vague. It names the exact literals ("a talegruppe, a
duty phone number, a meeting place or a team designation"), gives a worked example
(`Lag 2.X`, 39 occurrences, one variable), and ships in the always-injected instructions
*and* in the authoring skill. It was read and not acted on.

Two things about how it is written explain that. It is framed as a **discretionary
cleanup sweep** — "sweep for these once the draft is written" — and a later optional pass
is the first casualty when an agent is converging on done. And it is the only class of
authoring rule with **no enforcement anywhere**: the agent ran `analyze_plan` and fixed
everything it reported, which is exactly the behaviour we want. It reported none of this.

What the missing layer costs is not tidiness:

* A hardcoded talegruppe or duty number is wrong the moment it changes on the day, in
  eleven places, in a document the author now has to grep.
* A coordinate typed into prose is invisible to the map, so a station with five named
  places (IPP, KO, the find, the marker, the ambulance rendezvous) shows one pin.
* A role play that carries its own identity cannot inherit a correction to the person it
  portrays, and the person does not exist to be corrected.

All of it lands on the person running the exercise, not on the agent that wrote it.

### The measured discriminators

The reason this is now a decision rather than a wish is that each shortcut has a
signal with a clean separation, taken from the two documents above:

| Shortcut | Signal | cold | human |
|---|---|---|---|
| location never modelled | coordinate literal as a `position:` **value** | 0 | 46 |
| " | coordinate literal inside a **markdown field** | **23** | **1** |
| person never modelled | role play carrying `personRef` | 0 / 11 | 11 / 11 |
| value never promoted | `RK-VFOLD-ØV4` and friends, inline across fields | 6, 4, 3 | 0 |

Three of the four are **structural**, not statistical: a coordinate either sits in the
field built for it or in a sentence, and a role play either names the person it portrays
or invents one. No threshold is needed and there is nothing to tune. The human plan's
single prose coordinate against the cold plan's 23 is the difference between an exception
and a method.

### One clarification that shapes everything

**An operational contact value belongs in a plan.** A duty phone number, a KO number, a
talegruppe are facts the exercise needs. The fault is never that the value is present,
only that it is typed into prose instead of declared once. So every rule here is a
*modelling* diagnostic, and none is a PII scanner. Real people are a separate rule with a
separate answer — drop the name, keep the role — and nothing here changes it.

## Decision drivers

* Convert rules an agent demonstrably skips into output it demonstrably acts on. The
  evidence that diagnostics work is in the same cold run: everything `analyze_plan`
  reported got fixed.
* Prefer a structural signal to a statistical one. Three of these need no threshold, and
  a rule with nothing to tune cannot be tuned wrong.
* Do not become a PII scanner. An operational value in a plan is correct content; only
  its location is wrong. A diagnostic that reads as "remove this" teaches the opposite of
  the rule.
* **A false positive is more expensive than a miss.** This repo has already removed a
  warning rather than repair it for exactly this reason (commit `51377382`, and the
  comment it left in `mcp/backend-cli.mjs`): the CLI staleness check fired on essentially
  every server start and named a file that could not be the cause, so it taught people to
  stop reading stderr — "a warning that is always on is a banner". A suggestion that
  fires on ordinary prose would do that to `analyze_plan`, the one channel currently
  working.
* A heuristic must not be able to fail a build. `--strict` promotes warnings to errors,
  so severity is a real decision here.
* **Precision over recall.** These are suggestions on a document that already compiles,
  and the guidance still states every rule in prose, so a miss costs a sentence nobody
  read while a false positive costs the channel. Every tuning choice below resolves that
  way, including the localised contact shape.
* Nothing may assume a Norwegian plan. The format declares its own content language and
  the app ships in two, so a rule that reads as general must behave sensibly in any
  language even where it cannot be equally sharp.
* Actionable in the existing shape: a `path` at the offending field and a `hint` naming
  the remedy, so an agent can act without re-reading the guide.
* One implementation for every surface. `SourceAnalyzer` is shared by the CLI, both MCP
  backends and the app, so none of this may become MCP-only.

## Considered options

* Option A — Status quo: prose only, in two channels.
* Option B — Variables only: the repeated-literal and contact-shape rules.
* Option C — The three structural rules only (location, person, cross-reference), leaving
  variables to prose.
* Option D — All four, as one diagnostic family with one severity.
* Option E — A separate `suggest_entities` tool, or an `analyze_plan` mode, rather than
  diagnostics in the main stream.
* Option F — Auto-promotion: the compiler declares the entities and rewrites the fields.

## Decision outcome

Chosen option: **D**, four rules emitted by `SourceAnalyzer` under a new severity that
`--strict` does not promote.

They are ordered deliberately: the first three say *this entity was never declared*, and
the fourth says *it was declared and then not used*. Acting on the first three is what
makes the fourth able to fire, which is how the 77 missing `{{station.*}}` references get
reached — no rule can ask for a cross-reference to an entity that does not exist.

### Rule 1 — a coordinate in a markdown field wants a location

Fires when a UTM or lat/lng literal appears in any markdown field. The format has a
first-class home for it: a station-owned `location` with a `position`, referenced as
`{{station.loc.<slug>.position}}`. `position:` accepts the UTM string form directly
(ADR-0061), so the remedy costs the author nothing in notation.

Near-zero false-positive risk, because nobody writes a coordinate into a sentence for
narrative reasons. Measured 23 against 1.

### Rule 2 — a role play that invents its own person wants a `personRef`

The field table defines a role play as "a role portraying one of the station's persons.
Identity fields are inherited from that person unless written here." Writing `name`,
`age`, `gender` and `description` directly is *legal* — they are declared overrides — but
doing it on a station that declares **no persons at all** means the person was never
modelled, and the override mechanism is being used to avoid the entity rather than to
adjust it.

Scoped to that conjunction on purpose: identity written inline **and** no `persons` on
the owning station. A plan that models its persons and then adds one odd role — a
dispatcher, a bystander — must not be nagged. Measured 11 of 11 against 0 of 11.

### Rule 3 — a declared entity named as a literal wants a token

Once a station owns a location or a person, its `name` or `position` appearing verbatim
in that station's prose is a missed cross-reference. This is the rule that produces the
tokens, and it is exact rather than heuristic: the analyzer is comparing prose against
strings the author declared in the same document.

It reports nothing on a plan with no entities, which is why it cannot stand alone.

### Rule 4 — a value used in many places wants a variable

Two triggers, matching the two criteria the guidance already states.

**Repetition:** the same literal in **three or more distinct fields**. Distinct *fields*,
not occurrences — `Lag 2.X` thirty-nine times inside one `method` is one editing site,
while the same string across eleven station `comms` is eleven.

**Contact shape, at a single occurrence:** a phone number does not need to repeat, since
the guidance's second criterion is "decided late or changed on the day" and a duty number
is the canonical case.

This is the only rule with tuning in it, so the false-positive defence is a **shape
restriction rather than a stop-word list**: a literal qualifies only if it contains a
digit, or is upper-case with internal punctuation (`RK-VFOLD-ØV4`, `DMO-ANDRE-1`), or
matches a known contact shape. Ordinary prose words never qualify, which is the concrete
meaning of "do not promote a word that merely recurs in prose."

The corpus supplies the exclusions, all of which are real content:

| Looks similar | Actually | Discriminator |
|---|---|---|
| `987654-1`, `987660-1` | AMIS incident numbers | six digits + `-` + digit |
| `32V 0580307E 6552025N` | a coordinate — **rule 1's** business | embedded letters |
| `EK35989`, `SV41219` | vehicle registrations | leading letters |
| `(46)`, `(17)` | a person's age | parenthesised, two digits |

### The contact shape is localised, in three layers

A phone number is written differently per country, so a single pattern would be a
Norwegian rule wearing a general name. But the obvious fix — key the pattern off the
plan's `language:` — does not work either, and the reason is worth stating rather than
discovering during implementation: **language is not region.** `nb` and `nn` imply Norway
unambiguously, but `en` implies no numbering plan at all — `+44 7700 900123`,
`(555) 019-2837` and `021 1234 5678` are all English-language plans with nothing in
common. The format carries `language` (ISO 639-1 content language) and **no region
field**, so a language-keyed table would be right for `nb` and a guess everywhere else.

So the rule is layered, most portable first, and each layer stands alone:

1. **International form — language-independent, always on.** An E.164-shaped literal
   (`+47 …`, `+44 …`, `+1 …`) is a phone number in every locale and in every plan. No
   table, no region, no ambiguity.
2. **Label adjacency — the localised part is the *word*, not the number.** A digit run
   next to a contact label is a phone number whatever the numbering plan:
   `ØVLE: 93258930`, `KO 97525282 (Narve)`, `ring Narve på …` — every real example in the
   corpus is labelled. The lexicon is per language (`tlf`, `telefon`, `mob`,
   `vakttelefon`, `ring` / `phone`, `tel`, `mobile`, `call`, `contact`) and lives beside
   the other localised authoring strings, so adding a language is adding words rather
   than writing a regex. This is the layer that generalises, because a label survives
   reformatting and a numbering plan does not.
3. **Numbering-plan patterns — only where the language fixes the region.** `nb`/`nn` →
   Norway: eight digits, optionally grouped `NN NN NN NN` or `NNN NN NNN`. Where the
   language does not fix a region — `en` today — there is **no** bare-local pattern, and
   the plan gets layers 1 and 2 only.

The residual is a **miss, not a false positive**: an unlabelled bare local number in an
English plan will not fire. That is the right side to err on for a suggestion, where the
guidance still says the rule and the cost of a banner is higher than the cost of a
silence. It also gives a clean extension point — a stated region, whether inferred from a
richer locale tag or authored — that adds recall without changing any of the three layers.
Not proposed here; noted so the shape is deliberate.

### Severity: a third level, and why

`SourceDiagnostic` is binary today — `error` or `warning`, with `isError` the only
predicate — and `build --strict` promotes warnings to errors. A heuristic that can fail a
build is a heuristic that gets switched off, so:

```
enum DiagnosticSeverity { error, warning, suggestion }
```

`suggestion` is never promoted by `--strict`, never affects an exit code, and is counted
separately in `--json` so `errors`/`warnings` keep their present meaning for every
existing caller. That is the smallest change that keeps "a warning is something
`--strict` may reasonably refuse a build over" true, which it would stop being with
naming suggestions among them.

### Consequences

* Good: the entire relational layer a cold agent skips becomes output it acts on, through
  the one mechanism observed to work on it.
* Good: three of the four rules are structural, so the tuning risk is confined to rule 4.
* Good: rules 1–3 compose into a sequence — declare the entity, then reference it — so
  the fix for the 77 missing cross-references is reachable rather than merely described.
* Good: one enforcement point in `SourceAnalyzer`, shared by the CLI, both MCP backends
  and the app, rather than the rule being restated in a third prose channel.
* Good: the author is the beneficiary. A promoted talegruppe is one edit on the day
  instead of eleven; a modelled location is a pin on the map instead of a sentence.
* Good: it flags the *location* of legitimate content, so it teaches the rule rather than
  teaching people to delete operational detail.
* Bad: the contact shape needs three layers to be locale-honest, where one regex would
  have looked adequate — and the layer that generalises best (label adjacency) is a word
  list, so every new content language needs its lexicon extended or its plans quietly get
  weaker coverage. A missing lexicon entry fails silently, which is the worst failure mode
  a localised table has.
* Bad: **a language code cannot fix a region**, so an English plan gets no bare-local
  number pattern and will miss `(555) 019-2837` unless it is labelled. Chosen as a miss
  over a false positive, but it does mean the rule is strongest for exactly the locale
  that produced the evidence and weaker everywhere else — the honest cost of having one
  corpus.
* Bad: a third severity is a wire-format change. Every consumer of the `--json` envelope
  and of `analyze_plan` sees a new counter, and the app's diagnostic rendering needs a
  third case.
* Bad: rule 3 compares prose against declared strings, so a plan with many short entity
  names (`Bua`, `KO`) can match them inside unrelated words or sentences. Needs
  whole-token matching and probably a minimum length, which is tuning smuggled into an
  otherwise exact rule.
* Bad: rule 2 reads intent from an absence. A station that legitimately has a marker but
  no scenario subject will be told to declare one, and the hint has to be phrased as a
  question rather than an instruction.
* Bad: heuristics accumulate. Rule 4 will attract a next case — door codes, callsigns,
  meeting places, times of day — and the shape restriction is what keeps that bounded: a
  proposal needing a stop-word list is out of scope by construction.
* Bad: none of this reaches the strongest case for a variable, which is semantic. A
  meeting place written three different ways in three fields is three distinct literals
  and will not fire.

### What this deliberately does not fix

The cold run had a second cause, and it is not a diagnostic problem: **the published
corpus teaches flat plans.** The prescribed order says to read a published plan with
`get_plan` "so a generated plan matches how real ones are written", and the plan in the
catalog has zero tokens, zero persons, zero locations, everything crammed into one
`description`, and station names carrying the numbering the rules forbid. An agent that
matches the corpus has obeyed the instruction it was given, and a concrete example beats
prose every time.

These rules would at least fire on that plan too. But the corpus is a content problem
with a content fix, tracked separately from this decision.

## Pros and cons of the options

### Option A — Status quo
* Good: nothing to build; no false positives possible.
* Bad: measured to fail. The rules are present in both channels, specific,
  worked-example backed, and produced zero entities and zero tokens.
* Bad: the cost lands on the author on exercise day, so nobody who could fix it feels it.

### Option B — Variables only
* Good: smallest change; the threshold is already written down and argued for.
* Bad: addresses the cheapest third of the finding. Locations and persons are the larger
  absence and have *better* signals.
* Bad: leaves the cross-reference rule unreachable, since it needs declared entities.

### Option C — Structural rules only
* Good: no tuning at all — every rule is an either/or, so the false-positive argument is
  won by construction rather than by care.
* Good: covers the two-thirds of the finding with the cleanest evidence.
* Bad: leaves the repeated talegruppe and the inline duty number, which are the ones that
  hurt the author on the day.
* Bad: the guidance would still have one class of rule that nothing checks, so the
  original diagnosis is only partly answered.

### Option D — All four
* Good: covers the whole measured finding, and the structural rules carry the risky one:
  rule 1 removes coordinates from rule 4's candidate pool outright.
* Good: one severity, one hint style, one review.
* Bad: four rules to tune and explain instead of one, and the weakest of them sets the
  perceived quality of all four.

### Option E — A separate tool or analyze mode
* Good: cannot pollute the diagnostic stream, so the false-positive risk is contained by
  construction.
* Good: could afford to be more speculative, since nothing depends on it.
* Bad: opt-in guidance is what already failed. A tool an agent must know to call is the
  discretionary sweep with an API in front of it, and the cold run shows what becomes of
  discretionary steps.
* Bad: a second analysis surface to keep in step with the first, on both transports.

### Option F — Auto-promotion
* Good: the highest compliance available — the output is simply correct.
* Bad: the premise of the format is that the source document is the artifact the author
  owns and edits (ADR-0058). A compiler that invents `locations`, `persons` and
  `variables` entries and rewrites prose produces a document its author did not write and
  cannot predict.
* Bad: naming is the hard part and is semantic. `loc.ipp` versus `loc.start` versus
  `loc.utgangspunkt`, `var.tlf_ko` versus `var.narve` — authoring judgements a generated
  slug would get wrong often enough to be worse than a suggestion.

## Links

* **The ADRs this enforces**, which is the point of it —
  [ADR-0046](./0046-plan-variables.md) (plan variables, rule 4) and
  [ADR-0047](./0047-scenario-locations-and-persons.md) (scenario locations and persons,
  rules 1–3). Both decided the feature; neither has anything that notices when a document
  does without it. This ADR adds nothing to the format — it makes two accepted decisions
  observable.
* Related ADRs: [ADR-0058](./0058-source-format-and-plan-compiler.md) (the source
  document is the author's artifact, which rules out Option F),
  [ADR-0061](./0061-utm-coordinate-input-in-source-format.md) (`position:` takes the UTM
  string form, so rule 1's remedy costs no notation),
  [ADR-0065](./0065-authoring-guidance-over-mcp.md) (the channel split this shows the
  limits of — guidance reaching an agent is not the same as an agent acting on it),
  [ADR-0068](./0068-cascaded-fields-and-scoped-overrides.md) (`variableOverrides`, also
  zero in the cold plan)
* Related code: `lib/data/source/source_diagnostic.dart` (the severity enum this
  extends), `lib/data/source/source_analyzer.dart` (where all four rules belong),
  `lib/data/source/source_fields.dart` (the `location` and `person` scopes, and
  `personRef` — the definitions rules 1–3 enforce), `mcp/tools.mjs`,
  `skills/ringdrill-plan-authoring/SKILL.md`
* Open question for implementation: **where the contact-label lexicon lives.** The
  analyzer must stay Flutter-free (AGENTS.md rule 7), so it cannot read
  `AppLocalizations`. The `lib/l10n/app_*.arb` → `make labels` →
  `lib/l10n/headless_labels.g.dart` path already produces a Flutter-free localised subset
  for the CLI and would get these words translated alongside everything else — but that
  file exists for brief rendering, so putting analyzer vocabulary in it is a decision to
  make rather than assume.
* Precedent cited: commit `51377382`, removing a staleness warning rather than repairing
  it — the in-repo argument that an over-firing warning is worse than none.
* Origin: a cold MCP-only conversion of the 2026 LSOR booklet that compiled clean with 0
  entities and 0 tokens, beside a hand-authored plan of the same booklet with 47 entities
  and 129 tokens.

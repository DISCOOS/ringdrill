---
name: ringdrill-plan-authoring
description: >-
  Write or edit a RingDrill drill plan in the source format, then compile it to a
  `.drill`. Use when asked to create, draft, generate, extend or fix a drill plan
  or exercise plan — including from an existing plan in the catalog, from a
  template, or from a description of what an exercise should train. Carries the
  format's vocabulary, the authoring rules that are not obvious from the schema,
  and the order to call the tools in.
---

# Authoring a RingDrill plan

## What you are writing

A **source document**: one YAML file describing a drill plan. A deterministic
compiler turns it into a `.drill` archive and fills in everything that can be
derived. You never write the derived parts, and the format has no way to express
them.

```
you write intent  →  ringdrill build  →  .drill (the artifact the app opens)
                  ←  ringdrill decompile  ←
```

Read [`reference/format.md`](reference/format.md) for the vocabulary. Call the
`schema` tool for the authoritative field list — it is generated from the same
table the compiler validates against, so it cannot be out of date.

## The order to work in

1. **`schema`** — once, before writing anything.
2. **`search_catalog`** then **`get_plan`** on one or two results. Real published
   plans show how much prose a station actually carries, how exercises are timed
   across a day, and what the domain language looks like. Generated plans that
   skip this step read like a template.
3. **`create_plan`** for a skeleton, unless you are editing an existing plan (then
   start from `get_plan`).
4. Write the content.
5. **`analyze_plan`** — always. Fix everything it reports.
6. **`render_plan --audience=director`** — read the brief. This is where a plan
   that is structurally fine but useless becomes obvious. `analyze` passing tells
   you the references resolve, nothing about whether the output reads. Look for:
   a heading rendered twice because a field opens with its own heading; a
   `**Bold**` sub-heading duplicating a section the template already emits; a
   location token printing a place the prose just named; a derived schedule that
   contradicts times you wrote in prose.
7. **`render_plan --audience=participant`** when the plan has anything to hide.
   Every markdown field declares which audiences may see it (ADR-0063), so this is
   how you confirm a spoiler sits in the field that owns it rather than one a
   participant reads.
8. **`build_plan`** when it is right.

## Not resending the document on every call

A real plan runs to tens of kilobytes, and this loop touches it five or six times.
Two ways to stop paying for it, and which one applies depends on where the server
is (ADR-0064):

**Local (stdio) server: use `document_path`.** The file is already on the machine
the server runs on, so pass the path you are editing instead of the text. Nothing
is copied and nothing is retained. There is no reason not to do this — if you have
a path, use it.

**Hosted server: `cache: true`, and only when you mean it.** The hosted server has
no access to your filesystem, so the alternative is asking it to hold the document
under its content hash for about half an hour. The response then carries a
`document_hash` you can send instead of the text.

That is retention, and it is the author's call, not yours to make casually:

- **Set `cache: true`** when you are about to iterate — you have a document in
  hand and expect to analyze, fix, render and build it over the next few minutes.
  One upload, then hashes.
- **Leave it off** for a one-shot call (a single `analyze_plan`, rendering a plan
  you just fetched with `get_plan`), and whenever you have not been asked to work
  on this plan repeatedly. Off is the default because off is the server's promise:
  it compiles what it is sent and keeps nothing.
- **Ask first** if the plan is marked staff-only, names real people, or the author
  has said anything about not wanting it to leave their machine. A plan whose
  `director_notes` carry duty numbers is exactly the plan not to park on a server
  for half an hour without saying so. Offer the local server instead.
- **Never set it to work around a miss.** If `document_hash` comes back unknown or
  expired, resend the document — with `cache: true` again only if the first point
  still applies.

A miss is not a failure: it costs one resend. Losing a user's trust because an
agent opted them into retention silently is not recoverable the same way.

Publishing is not available to you, by design. Hand the built archive to the
person you are working with; they publish it.

## Rules that are not in the schema

These are the mistakes that get made. None of them fails at build time.

**Break markdown fields at sentence ends, never at a column.** Every coding agent
reaches for an 80-column wrap. Do not: an author edits these fields in the app's
section editor, which honours your newlines and then wraps again at its own width,
so a wrapped line arrives as a ragged break mid-sentence. The damage is invisible in
the source *and* in the rendered brief — markdown collapses soft breaks — and
obvious only in the one place nobody looks while writing. One sentence per line.
Keep a list item or table row on a single line however long it gets.

**Numbering comes from position. Never write it into a name.** The app renders
"#2" and "2.1" itself, from list order and the plan's number format. A station
named `"2a) Fisker"` renders as "2.1 2a) Fisker". Some older plans in the catalog
do carry baked-in numbers — that is a pre-automatic-numbering habit, preserved
because it is the author's content, not an example to copy.

**Names are opaque.** No tool parses one. A name is free text in whatever
convention the domain uses.

**Tokens are content, not something to resolve while writing.** Write
`{{var.talegruppe}}`, `{{station.person.magnus}}`, `{{station.loc.lkp.position}}`
literally. They resolve at render, which is why a coordinate lives in one place
and the prose stays in sync when it changes. Resolving them yourself defeats the
mechanism and produces prose that goes stale.

**A variable is declared once, on the plan.** Exercises and stations may only
*override its value*. `variableOverrides` cannot introduce a name.

**Scenario data belongs to a station.** A location or a person is declared under
the station that uses it, and addressed by slug from that station's prose only. A
`{{station.loc.lkp}}` in a plan-level field cannot resolve anywhere.

**A role play inherits by omission.** It portrays one of its station's persons via
`personRef`. Leave `name`/`age`/`gender`/`description` out and it takes the
person's; write one and it overrides. Restating every field makes it look like a
deliberate override of everything.

**Never invent staff.** Real people are a local, private layer that is stripped at
publish. `persons` are fictional scenario subjects and carry no PII.

**And never write staff into prose.** The stripping applies to Staff, not to the
markdown fields, so a real name or a duty number in `director_notes` publishes
with the plan. Source documents are full of them — a marker roster in a tips
column, "ring Narve på …", a contact person for a venue. Drop the names and keep
the role ("markør tildeles av veileder"). Operational numbers that genuinely
belong in the plan go in a variable, where they are easy to find and change before
publishing.

**More teams than stations cannot rotate.** `numberOfTeams` must be ≤ the station
count. The reverse is fine and common: a full-scale exercise often runs
`numberOfTeams: 1` over several stations, with the real teams grouped into one.

**Not every exercise is a rotation, and some cannot be expressed.** Every round
is the same length, and two stations cannot run concurrently. Real booklets
contain both. Read *What the rotation cannot express* in
[`reference/format.md`](reference/format.md) before you force an exercise into a
grid it does not fit — the honest move is sometimes a correct per-station duration
plus a note that the derived schedule does not apply.

## Writing content that is worth reading

The format will happily accept a plan that is structurally perfect and trains
nothing. What makes a plan usable:

- **A station is a scenario, not a label.** `situation` should say who is missing,
  from where, when they were last seen, and what the team is being asked to do.
  One or two sentences of specifics beats a paragraph of generalities.
- **`mission` is the order, `situation` is the picture.** Keep them separate.
- **Put a secret in the field that owns it.** The marker's script goes in
  `behavior`, intel to withhold in `leader_answers`, and `director_notes` is for
  notes to whoever runs the station — not a bucket for everything sensitive. Each is
  withheld from participants on its own declaration, so the structure survives.
  Note that none of them is stripped at publish: that applies to Staff only.
- **Vary the stations.** A rotation where every station is "search for a missing
  person" teaches one thing four times.
- **Time it honestly.** `executionTime` is how long a team gets at a station.
  15 minutes is a short task; 90 is a full-scale scenario. `rotationTime` has to
  cover the walk.
- **Ask what the exercise is for.** If you were not told, ask, rather than
  guessing at learning goals.

## Cold start

The catalog is small. Until it grows, [`reference/format.md`](reference/format.md)
and the scaffold from `create_plan` carry more of the format's conventions than
the corpus does — but a real plan from `get_plan` is still the better model for
*content*, so read one even if you only take the shape of its prose from it.

## Provenance

When you generate a plan from published ones, say which in the plan
`description`, and say it was machine-drafted. It costs one line and makes the
lineage of a shared corpus traceable.

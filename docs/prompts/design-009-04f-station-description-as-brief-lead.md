# Implement DESIGN-009 — Station description as the brief lead

You are working in the RingDrill repository, on `design-009`. A small, self-contained change: `Station.description` ("Postbeskrivelse") is shown only in the app today, never in the brief, so scenario text written there is lost from the generated document. Make it render in the brief as the station's **lead paragraph**, and make an empty description collapse to a "Legg til beskrivelse" affordance in the editor. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md), `docs/design/009-scenario-locations-and-persons.md` ("The station description as the brief lead") and [DESIGN-004](../design/brief-template.md) are authoritative. Read `AGENTS.md` rule 9.

**Visual reference:** `docs/design/mockups/station-description-as-brief-lead.html` (A filled/simple, B empty/section-rich, C brief output).

**No model change, no schema bump.** The `description` field is reused as-is. It stays in the base section alongside name and position — it is **not** moved into the section switcher and is not a removable section. Simple stations need only this field; rich stations add the labeled sections below.

## Behavior

* **Brief lead.** `station.description` renders as the station's lead paragraph, directly under the station heading (`### {{stationCode}} – {{name}}`) and **before** the "Post … plassering:" line, with **no** section heading of its own. It is markdown and resolves tokens like any other field (the description is already token-aware in the editor; 4c withholds `station.description` from its own field, so no self-reference). An absent or empty description renders no lead paragraph and no blank line. Shown to every audience (it is general narrative, not gated).
* **Editor collapse.** In the station editor's base section, when the description is empty and unfocused, show a compact "Legg til beskrivelse" affordance (a tappable row) instead of an empty text box; tapping it reveals the field, focused. A non-empty description shows the field directly, as today. Name and position are unchanged — the position field is already the reflowed `PositionFormField` row variant (`position-card-reflow`, shipped: thumbnail · single-line coord · chevron, full width beneath the full-width name). **Do not touch the name/position layout**; only the description beneath it changes. The mockup shows this reflowed layout.

## Ground rules

* The brief templates are `assets/templates/ringdrill-standard-v1.nb.md.mustache` and `…en.md.mustache` — **edit both**, kept in sync. Use a `{{#descriptionMd}}` section with triple-brace `{{{descriptionMd}}}` (markdown must not be HTML-escaped), matching how `{{{situationMd}}}` etc. are emitted.
* `BriefRenderer._buildStationContext` returns the station map (the one `{{#stations}}` iterates). Add `'descriptionMd': resolveField(station.description)` to it, alongside `situationMd`/`missionMd` — so the lead is resolved through the same pipeline. Do not touch `stationRefContext`'s existing `description` entry (that is the cross-reference source and stays).
* Reuse the existing `RingDrillTextArea` for the description; keep `tokenAware: true` and its `planFields`/create hooks. The collapse is an editor-view concern, not a field-widget change if avoidable — prefer a small wrapper in `station_form_screen.dart` over changing the shared field.
* User-facing strings via ARB, then `make i18n` ("Legg til beskrivelse" / "Add description" — reuse an existing key if one already fits).
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted tests (`flutter test test/views/ test/services/`); `make i18n` only on ARB change; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Three commits.

### Commit 1. Render description as the brief lead

Add `descriptionMd` to the station template map in `brief_renderer.dart`, and insert the lead block in both mustache templates between the heading and the plassering line:

```
{{#descriptionMd}}
{{{descriptionMd}}}

{{/descriptionMd}}
```

Update the station-block description in `docs/design/brief-template.md` (DESIGN-004) to note the lead paragraph.

Files: `lib/services/brief/brief_renderer.dart`, both `assets/templates/ringdrill-standard-v1.*.md.mustache`, `docs/design/brief-template.md`. `flutter analyze` + `flutter test test/services/`. Commit: `feat(brief): render the station description as the brief lead paragraph`.

### Commit 2. Collapse the empty description in the editor

In `station_form_screen.dart`'s base section, render the description as a "Legg til beskrivelse" affordance when empty and unfocused; tapping reveals the focused field. Add the ARB label; `make i18n`.

Files: `lib/views/station_form_screen.dart`, `lib/l10n/*.arb` + regenerated localizations. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): collapse the empty station description to an add affordance`.

### Commit 3. Tests

* **Brief (services):** a station with a description renders it as the lead paragraph, positioned before the "plassering" line and with no heading; a `{{...}}` token in the description resolves in the lead; an empty/absent description produces no lead paragraph and no stray blank line. Both nb and en templates.
* **Editor (views):** an empty description shows the "Legg til beskrivelse" affordance; tapping it reveals the focused field; a non-empty description shows the field directly; saving round-trips the text.

`flutter analyze`, `flutter test test/views/ test/services/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/services/` and `test/views/`. Commit: `test: cover the station description brief lead and editor collapse`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke: a station with a description shows it as the lead paragraph in the brief (tokens resolved), above "plassering"; clearing the description hides the lead entirely; in the editor an empty description is a "Legg til beskrivelse" affordance that expands on tap, and name/position are unchanged.
4. `git diff --stat` touches `lib/services/brief/…`, `assets/templates/…`, `lib/views/…`, `lib/l10n/…`, `docs/design/…`, `test/…`. No model or schema change.
5. Clean tree; localizations committed with ARB changes; both templates edited in sync.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the station description now renders as the brief lead (reusing the field, no schema change) and collapses to an add affordance when empty.

ADR-0047, DESIGN-009 and DESIGN-004 are authoritative. The read-only rollup of sections and the detail sheet becoming that rollup are **DESIGN-010** (stage 3), out of scope here — this prompt is only the brief lead and the editor collapse. If the change needs anything beyond the renderer map, the two templates, the editor collapse, ARB, and tests, stop and report.

# DESIGN-013 follow-up: replace the `rdchip:` chip sentinel with a structured `ringdrill://chip?…` URI

You are on branch `design-013`, after the DESIGN-013 commits
(`docs/prompts/design-013-actionable-field-chips.md`) have landed. This is a
focused refactor of the **internal** action-chip encoding introduced in
ADR-0050 — no user-visible behaviour change, and no change to briefs (which
never emit the scheme). Read `docs/adrs/0050-per-output-format-chip-formatting.md`
and `docs/design/013-actionable-field-chips.md` §1/§4 first, plus `AGENTS.md`
(rule 9 test discipline, rule 12 docs-in-English).

## Why

The `rdchip:<action>` sentinel is terse and not self-explanatory. Replace it
with a real, structured URI so the encoding is legible and extensible to more
actions and parameters later (a `label`, a future second action).

## The new encoding

`ActionChipFormatter` (in `lib/services/brief/field_resolver.dart`) emits a
markdown link whose href is a `ringdrill://chip` URI with query parameters,
built with `Uri(...).toString()` so values are properly encoded:

- Position → `[display](ringdrill://chip?action=map&lat=<lat>&lng=<lng>)`
- Phone → `[display](ringdrill://chip?action=call&tel=<number>)`

Grammar: scheme `ringdrill`, host `chip`, `action` ∈ `map | call`; `map`
carries `lat` + `lng`, `call` carries `tel`. Keep the flutter-free,
degrade-to-copy-chip behaviour (no coordinate / empty number → `briefCopyChip`).
The query form leaves room for a future `label` and additional actions; do not
add them now.

## The renderer

In `lib/views/widgets/brief_markdown.dart`, the link-tag generator recognizes
an action chip by `uri.scheme == 'ringdrill' && uri.host == 'chip'` (parse with
`Uri.tryParse`), reads `uri.queryParameters`, and dispatches on `action`:

- `map` → launch `https://www.google.com/maps/search/?api=1&query=<lat>,<lng>`
- `call` → launch `tel:<tel>`

via `url_launcher`, guarded by `canLaunchUrl`. Everything else about
`_ActionChip` is unchanged — the pill look, the copy icon, and the tap rule
(single action runs directly; a context menu only once a chip has more than one
action). Any link that is not a `ringdrill://chip` URI falls through to the
existing `LinkConfig`.

## Sweep

Replace every occurrence of the old `rdchip:` scheme — in code, tests, and the
docs that mention it: `docs/design/013-actionable-field-chips.md`,
`docs/adrs/0050-per-output-format-chip-formatting.md`, and (if the DESIGN-013
work referenced the scheme there) `docs/variables.md` / `docs/template.md`.
Update ADR-0050's encoding description and DESIGN-013 §1/§4 to the
`ringdrill://chip?…` form, with a one-line rationale (legible, extensible query
form). ADR-0050 and DESIGN-013 stay `Accepted` — this is a same-decision
refinement, not a new decision; record it inline.

## Guardrails

- The scheme is **internal**: it must never reach a copied/clipboard value or a
  non-app surface, and briefs must stay byte-identical (they never emit it).
- Keep `field_resolver.dart` free of `package:flutter/*` (ADR-0005) — the URI is
  built with `Uri`, pure Dart.
- Do not launch by any means other than `url_launcher`; guard with
  `canLaunchUrl`.

## Verify

`flutter analyze` + the targeted tests (`field_resolver` formatter tests, the
`brief_markdown` action-chip widget test — update the expected href), then the
full `flutter test` once as the gate. Commit everything (exclude
`.claude/settings.local.json`); `git status` clean.

Commit: `refactor(brief): encode action chips as a structured ringdrill://chip URI`.

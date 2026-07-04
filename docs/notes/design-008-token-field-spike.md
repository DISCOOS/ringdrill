# DESIGN-008 Stage 4 prototype gate: editable `WidgetSpan` chip — no-go

**Date:** 2026-07-04

## Context

DESIGN-008 Stage 4 wants `{{var.name}}` rendered as an inline chip inside an
*editable* `TextField` (`MarkdownSectionField` in token-aware mode), not just
read-only rendered markdown (`brief_markdown.dart` already does that safely).
The open question flagged in the design doc and the Stage 4 prompt: does a
`WidgetSpan` chip emitted from a custom `TextEditingController.buildTextSpan`
keep caret movement, selection and backspace sane? The stage is gated on
answering this before the insertion menu and the wiring are built.

No iOS/Android simulator or emulator is available in this environment (a
sandboxed CLI, no GUI device). The spike below is therefore built as a
`flutter_test` widget test against `RenderEditable`/`EditableText` directly,
which exercises the same Skia/Flutter-framework caret-geometry and
text-editing-value code real iOS and Android builds use — the risk this gate
cares about turns out to live entirely in that framework layer, not in a
platform-specific IME quirk, so this evidence is directly applicable even
without a device. What it cannot rule out is a *platform* IME/autocorrect
interaction on top of a sound chip; that residual risk is moot here because
the framework-level problem below is decisive on its own.

## What we tried

A throwaway `_ChipController extends TextEditingController` overriding
`buildTextSpan` to replace every `{{var.<name>}}` match with a `WidgetSpan`
(a padded, rounded `Container` chip), leaving everything else as plain
`TextSpan`. Pumped into a bare `TextField`, seeded with `'A {{var.x}} B'`
(13 characters; the token spans raw offsets 2–11).

Two things were measured directly against `RenderEditable`:

1. `getLocalRectForCaret(TextPosition(offset: n))` for `n` at the chip's
   start, one character in, the middle, one before its end, and just after
   it.
2. What a real backspace keystroke actually does at the token's right edge
   — simulated as the same one-code-unit-shorter `TextEditingValue` the
   engine would deliver, since `EditableText`/`RenderEditable` have no
   concept of "this offset is inside a chip" to intercept it.

## What we found

**Caret geometry inside the token does not track the character underneath
it.** Measured x positions for offsets 2 (chip start), 3, 6, 10 (chip
end − 1), and 11 (chip end):

```
offset  2 (before)   → x = 33.3
offset  3 (+1)        → x = 57.7
offset  6 (+4)        → x = 90.7
offset 10 (end − 1)   → x = 90.7   (same as offset 6)
offset 11 (end)       → x = 90.7   (same as offset 6 and 10)
```

Three logically distinct caret positions — the middle of the token, the
position just before its last character, and the position just after the
whole token — all render at the identical pixel position, while a fourth
position one character into the token lands somewhere else entirely with no
smooth interpolation between them. A run of 9 ordinary characters gives 9
(or close to it) evenly increasing x positions; this token gives effectively
two. That is precisely "caret moves left/right across and past a chip
without landing inside it visibly wrong" from the gate's checklist, and it
reproduces from the framework's own layout math — a `WidgetSpan` is laid out
as a single object-replacement unit, so many distinct logical text offsets
inside its span collapse onto the same or a handful of visual slots. Confirmed
with `expect()` assertions in the spike, not just observation.

**Backspace at the token's right edge deletes one character, not the whole
token.** Simulating the exact `TextEditingValue` a backspace keystroke
delivers (one UTF-16 code unit removed before the caret) turns
`'A {{var.x}} B'` into `'A {{var.x} B'` — the trailing brace is gone, the
rest of the token remains. Nothing in `TextField`/`EditableText` knows a
given offset sits "inside a chip"; that is purely a `buildTextSpan`-time
rendering fact, invisible to the platform text-editing pipeline. Getting
"backspace deletes the whole token" would require intercepting key events
(or diffing `TextEditingValue` changes) in the controller and rewriting the
edit — real, nontrivial logic, not a side effect of using `WidgetSpan`.

**Control case: the styled-`TextSpan` fallback has neither problem.** The
same experiment against a controller that instead wraps each match in a
plain `TextSpan` with `color`/`backgroundColor` (no `WidgetSpan`, no nested
widget) gives 14 strictly increasing, evenly-spaced caret x positions for
offsets 0–13 — a perfect 1:1 mapping, because no placeholder-collapsing
occurs. Backspace at the boundary removes exactly the one character before
the caret, same as any plain field; there is no "whole token" concept to get
wrong because there is no chip, just colored text.

## Decision: no-go

**Chips render as styled `TextSpan` (colored, boxed via `background`/
`color`), not `WidgetSpan`.** The interior-caret and backspace problems
above are structural to placing a `WidgetSpan` inside an *editable* field's
`buildTextSpan` — they are not implementation bugs we could fix by writing
the chip differently, they follow from how `TextPainter`/`RenderEditable`
lay out placeholders versus how `TextEditingController.selection` addresses
raw text. Making `WidgetSpan` behave would need custom key-event
interception for backspace/delete and custom caret-position snapping logic
for arrow-key movement and tap-to-position — meaningfully more surface area
and risk than the feature is worth for Stage 4, especially with no device to
validate the platform IME behavior on top of it.

This matches the prompt's pre-approved fallback exactly: "style the
`{{…}}` text with color and a boxed background via `TextStyle`/`background`,
no inline widget." `TokenTextEditingController` (Stage 4, Step 2) implements
chip states (known/empty/unknown → blue/amber/red) as styled `TextSpan`
runs, not `WidgetSpan`s. The underlying `TextEditingController.text` stays
the raw markdown either way — that constraint holds regardless of which
representation renders it.

## Implications

* No inline `WidgetSpan` chips anywhere behind `RINGDRILL_PLAN_VARIABLES` in
  this stage. If a later stage wants a true chip look (e.g. a delete "x"
  affordance drawn on the chip itself), revisit this note first — the
  underlying framework limitation does not go away, and the mitigation
  (custom key handling) would need to be designed deliberately, not bolted
  on.
* Save-time red-token validation (Stage 5) does not depend on this choice —
  it reads the same regex match list either way.
* If real-device testing later surfaces IME-specific problems with the
  styled-`TextSpan` approach (unlikely, since it does not alter the
  text-editing value model at all), add a new note rather than editing this
  one.

## Related

* [ADR-0046](../adrs/0046-plan-variables.md) — `var.` namespace and validation states this chip renders.
* [DESIGN-008](../design/008-plan-variables-and-section-navigated-editor.md) — "Open questions" §1, the caret/selection risk this note resolves.
* `lib/views/widgets/brief_markdown.dart` — the existing read-only `WidgetSpan` chip, unaffected by this note since it is not inside an editable field.
* `docs/prompts/design-008-stage-4-implementation.md` — Step 1, the gate this note satisfies.

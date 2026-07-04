# Implement DESIGN-008 Stage 4

You are working in the RingDrill repository. Implement Stage 4 of DESIGN-008 ("Plan variables and the section-navigated editor"). DESIGN-008 at `docs/design/008-plan-variables-and-section-navigated-editor.md` is the authoritative UX spec; [ADR-0046](../adrs/0046-plan-variables.md) is the data-model decision. Read both, plus the Stage 1–3 prompts, before starting. Stages 1–3 have shipped: the model carries variables and overrides, `BriefRenderer` resolves them, and `ProgramFormScreen` renders on the section-navigated shell behind `RINGDRILL_PLAN_VARIABLES`, using `MarkdownSectionField` for each markdown section body.

Stage 4 is the **token-aware field and the insertion menu**. It teaches the markdown section field to render `{{var.<name>}}` tokens as inline chips and to insert them through a `/` command menu (and a `{{` autocomplete), replacing `MarkdownSectionField`'s internals behind its existing constructor API. It does **not** build the Variabler declaration/override UI or wire the inline "create variable" action — that is Stage 5.

## The prototype gate comes first

The whole stage rests on one uncertain capability: rendering `{{var.name}}` as an inline `WidgetSpan` chip **inside an editable field** while keeping caret movement, selection and delete sane on iOS and Android. `brief_markdown.dart` already emits `WidgetSpan` chips, but that is read-only rendered markdown, not an editable `TextField` — the editable caret is the unknown. **Step 1 is a spike that must pass before Steps 2–5 are written.** If it fails on a target platform, fall back to the documented plan (style the `{{…}}` text with color and a boxed background via `TextStyle`/`background`, no inline widget) and build the rest of the stage on that fallback. Either way, record the outcome. Do not build the menu and the wiring on top of an unproven chip.

## Feature flag and blast radius

Token features activate **only when the field is explicitly put in token mode** by the flag-on Program editor. `MarkdownSectionField` gains an opt-in (`tokenAware`, default `false`, plus the token data). The legacy flag-off path (`OptionalFieldSections`) passes none of it and stays a plain `TextFormField`, byte-identical to today. This is the gate: no `AppFlags` check inside the widget is needed, because only the flag-on caller supplies token mode.

Chip validation keys **only on the `var.` namespace**. `{{var.<name>}}` is validated against the registry (blue / amber / red as below). Every other `{{...}}` expression — `{{station.position.utm}}`, `{{exercise.name}}` and any future cross-reference — is left as plain literal text, never chipped and never shown red. This matches ADR-0046 (only `var.*` participates in the registry) and avoids false-flagging legitimate cross-references that the renderer resolves.

Chip states for a `{{var.<name>}}` token:

| State | Condition | Look |
|-------|-----------|------|
| known | `name` declared, effective value non-empty | blue chip, value available to the picker |
| empty | `name` declared, effective value empty | amber chip |
| unknown | `name` not declared | red dashed chip |

Save-blocking on a red token is Stage 5's validation. Stage 4 only renders the state.

## Ground rules

Read `AGENTS.md` and `CLAUDE.md`. Non-negotiable here:

* **Underlying text stays raw.** The field's `TextEditingController.text` is always the raw markdown with literal `{{var.name}}`. Chips are a render-time projection in `buildTextSpan`; they never rewrite the stored text. This is the DESIGN-004 constraint that keeps `BriefRenderer` seeing plain mustache.
* **User-visible strings via ARB**, then `make i18n`. New strings: the menu's group-free per-item "planfelt" hint, the `{{`/`/` menu's empty-state, and any tooltip. Norwegian is the shipped `nb`.
* **No `position: fixed`-style hacks; use the Flutter overlay.** Anchor the menu at the caret with `CompositedTransformTarget`/`CompositedTransformFollower` + `OverlayEntry`, or `MenuAnchor`. It must not push layout or trap focus.
* **Views-only, plus the token model.** Touch `lib/views/…`, `lib/l10n/…`, and a small token-model file. Do not change `lib/models/` entities, `lib/services/`, or the flag-off path.
* **No new lint suppressions.** `flutter analyze` and `flutter test` before claiming green.

## Scope

Five steps, in order. Step 1 gates the rest.

### Step 1. Prototype gate — editable WidgetSpan chip

Build a throwaway spike (a scratch route or a dedicated test) that renders a `TextField` backed by a custom `TextEditingController` whose `buildTextSpan` replaces `{{var.x}}` with a `WidgetSpan` chip and leaves the rest as text. Exercise, on both an iOS and an Android target (simulator/emulator acceptable):

* caret moves left/right across and past a chip without landing "inside" it visibly wrong;
* selection that spans a chip behaves;
* backspace at the right edge of a chip deletes the whole `{{var.x}}` token, not one brace;
* typing before/after a chip inserts text in the right place;
* IME/autocorrect does not corrupt the token.

Decide **go** (chips are usable) or **no-go** (fall back to colored/boxed text spans, no inline widget — still in `buildTextSpan`, just `TextSpan` with `background`/`color` instead of `WidgetSpan`). Write the decision and the evidence into `docs/notes/` (match the existing note convention) and reference it from the commit body. The spike code itself is not committed unless you turn it into a test.

Files expected in this commit:

* `docs/notes/design-008-token-field-spike.md`

Run `git status`. Commit: `docs(notes): record DESIGN-008 token-field prototype gate outcome`.

### Step 2. Token model and the controller

Add a small token model (e.g. `lib/views/widgets/editor_token.dart`): a `VariableToken` (`name`, `effectiveValue`, `declared`) and a `PlanFieldToken` (`name` like `exercise.name`, `label`, `hint`) — enough for chip validation and the picker. Keep it a view concern; do not couple it to `BriefRenderer`.

Add `TokenTextEditingController` (e.g. `lib/views/widgets/token_text_editing_controller.dart`) extending `TextEditingController`. Override `buildTextSpan` to scan the text for `{{var.<name>}}` (the same `RegExp(r'\{\{\s*var\.([a-z][a-z0-9_]*)\s*\}\}')` used server-side in the renderer — keep them in sync, note the duplication) and emit, per match, the chip span from the gate's chosen approach (WidgetSpan or styled TextSpan), with the blue/amber/red state resolved against the supplied variable list. Everything else, including non-`var` `{{...}}`, is emitted as ordinary text with the base style.

The controller takes the current `List<VariableToken>` so it can resolve state; expose a setter so the field can update it when the registry or scope changes without recreating the controller.

Files expected in this commit:

* `lib/views/widgets/editor_token.dart`
* `lib/views/widgets/token_text_editing_controller.dart`

Run `git status`. Commit: `feat(views): add token model and TokenTextEditingController`.

### Step 3. Insertion menu

Add the `/` command menu and `{{` autocomplete as an overlay anchored at the caret. It is a **single flat list** (no group headers — DESIGN-008): variable entries show their effective value; plan-field entries show a muted "planfelt" hint instead of a value. Filter as the user types after the trigger. Selecting an entry inserts the corresponding token (`{{var.name}}` or `{{planField}}`) at the caret and dismisses the menu.

`/` opens the command menu; `{{` opens the same picker directly. Handle the trigger detection on text/selection change (watch for a just-typed `/` at a word boundary, or an unclosed `{{`). Dismiss on Escape, on selection change away, and on tap outside.

The inline **"Opprett variabel «x»"** entry (shown when the filter matches no variable) is wired to an optional `ValueChanged<String>? onCreateVariable` callback. In Stage 4 the Program editor does **not** pass it, so the entry is hidden. Stage 5 supplies the callback and the registry mutation. Build the entry and the hook now; leave it dormant.

Files expected in this commit:

* the menu widget under `lib/views/widgets/`
* `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, regenerated `lib/l10n/app_localizations*.dart`

Run `make i18n`. Run `git status`. Commit: `feat(views): add slash/brace token insertion menu`.

### Step 4. Wire into MarkdownSectionField and the Program editor

Replace `MarkdownSectionField`'s internals behind its existing constructor API, adding opt-in token params (all defaulted so the current call sites are unaffected):

* `bool tokenAware = false`
* `List<VariableToken> variables = const []`
* `List<PlanFieldToken> planFields = const []`
* `ValueChanged<String>? onCreateVariable`

When `tokenAware` is false, render exactly the current plain `TextFormField` (legacy path untouched). When true, use `TokenTextEditingController` and attach the insertion menu.

In `ProgramFormScreen`'s flag-on section bodies (Stage 3), pass `tokenAware: true` and the program-scope token data: `variables` built from `program.variables` and their values (program scope has no overrides), and a `planFields` catalog of the program-scope derived fields worth offering (keep it small and explicit — e.g. program name, exercise count; do not over-reach). Do not pass `onCreateVariable` yet. The controllers are already owned by the form; swap the plain controller for the token controller only on the token-aware path, keeping `_save` reading the same `.text`.

Files expected in this commit:

* `lib/views/widgets/markdown_section_field.dart`
* `lib/views/program_form_screen.dart`

Run `git status`. Commit: `feat(views): make MarkdownSectionField token-aware in the flag-on Program editor`.

### Step 5. Tests

Add tests under `test/views/`.

* **Chip states.** A `TokenTextEditingController` seeded with `frekvens` declared (value `Kanal 6`), `tom` declared (empty), and text containing `{{var.frekvens}}`, `{{var.tom}}` and `{{var.mangler}}` produces the three states. Assert via the spans `buildTextSpan` returns (known vs amber vs red), driving whichever representation the gate chose.
* **Non-var expressions untouched.** Text with `{{station.position.utm}}` yields no chip and no red — plain text.
* **Raw text preserved.** After the controller renders chips, `controller.text` still equals the original raw string with literal `{{…}}`.
* **Menu opens and inserts.** Pump a token-aware `MarkdownSectionField`. Type `/`; assert the menu appears with the seeded variables and plan-fields as a flat list. Select one; assert the token text is inserted at the caret and the menu closes. Repeat for the `{{` trigger.
* **Create entry hidden without callback.** With `onCreateVariable` null and a no-match filter, the "Opprett variabel" entry is absent.
* **Legacy path unchanged.** A `MarkdownSectionField` with `tokenAware: false` renders a plain field with no menu and no chip behavior.
* **Backspace deletes whole token** (only if the gate chose WidgetSpan and it is testable in the widget tester; otherwise assert the fallback styling and note the manual check).

Run `flutter analyze`. `flutter test test/views/`. Then the full suite.

Files expected in this commit:

* new/edited test files under `test/views/`

Run `git status`. Commit: `test(views): cover token chip states and the insertion menu`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` no new failures.
3. `make i18n` idempotent after commit. `make build` not needed.
4. `dart compile exe bin/ringdrill.dart` (or `dart build cli`) succeeds.
5. **Gate recorded.** `docs/notes/design-008-token-field-spike.md` states go/no-go and which chip representation the stage uses.
6. **Flag-off untouched.** No `--dart-define`: `ProgramFormScreen` and `OptionalFieldSections` render plain fields, no chips, no menu. Confirm by test.
7. **Flag-on manual QA** (`--dart-define=RINGDRILL_PLAN_VARIABLES=true`), narrow and wide, recorded in the commit body or `docs/notes/` — since Flutter web is CanvasKit with no DOM (per the Stage 3 note), rely on widget tests for structural assertions and use a simulator/emulator for the caret/menu feel: type `/`, insert a variable, see the chip; type a raw `{{var.x}}` for an undeclared name, see the red chip; confirm `{{station.position.utm}}` stays plain.
8. **Blast-radius check.** `git diff --stat main` (since Stage 3) touches only `lib/views/…`, `lib/l10n/…`, `docs/notes/…`, `test/views/…`. No `lib/models/` or `lib/services/` changes; Exercise/Station/RolePlay forms untouched.
9. **Clean tree gate** and **diff sanity** as in prior stages.

## Deliverables

Conventional Commits (English) on `design-008`, clean tree. The final commit body summarises the gate outcome, the chip representation chosen, that token features are opt-in and confined to the flag-on Program editor, and that Stage 5 (Variabler declaration/override section, the `onCreateVariable` wiring, and save-time red-token validation) remains.

DESIGN-008 and ADR-0046 are authoritative. The one place you are expected to exercise judgment is the prototype gate — if WidgetSpan chips prove unusable, the colored-text fallback is pre-approved; anything beyond those two options, stop and ask. Do not write a new ADR for this stage.

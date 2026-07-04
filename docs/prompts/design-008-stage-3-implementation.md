# Implement DESIGN-008 Stage 3

You are working in the RingDrill repository. Implement Stage 3 of DESIGN-008 ("Plan variables and the section-navigated editor"). DESIGN-008 at `docs/design/008-plan-variables-and-section-navigated-editor.md` is the authoritative UX spec; [ADR-0046](../adrs/0046-plan-variables.md) is the data-model decision. Read both, plus the Stage 1 and Stage 2 prompts, before starting. Stages 1 and 2 have shipped: the model carries variables and overrides, and `BriefRenderer` resolves them.

Stage 3 is the **section-navigated editor shell** and the **first editor migrated onto it**. It builds the shared navigation pattern (a section switcher that is a dropdown on compact and a master/detail rail on expanded) and rebuilds `ProgramFormScreen` on it. **No variables UI in this stage** — no "Variabler" section, no token-aware field, no slash menu. Those are Stages 4 and 5. This stage only changes how a form is navigated, not what it can hold.

## Scope split (read this)

DESIGN-008's Stage 3 note lists all four editors (Program, Exercise, Station, RolePlay). This prompt deliberately narrows Stage 3 to **the shared shell plus the `Program` editor**, for reviewability. The other three editors are follow-ups on the same shell and are out of scope here. Do not migrate `ExerciseFormScreen`, `StationFormScreen` or `RolePlayFormScreen` in this stage. Leave them exactly as they are.

## Feature flag: gate the new editor

The section-navigated `Program` editor is gated behind `RINGDRILL_PLAN_VARIABLES` (added in Stage 1). When the flag is **off** (production default), `ProgramFormScreen` renders exactly as it does today — the current single-scroll form, unchanged. When the flag is **on**, it renders as a section-navigated form. This keeps the feature invisible in production and lets it be developed in parallel. The branch is a single `if (AppFlags.planVariables)` at the top of the form's `build`, selecting between the existing body and the new shell. Extract the shared field editors (Step 2) so the two paths do not duplicate field-building logic.

## Ground rules

Read `AGENTS.md` and `CLAUDE.md` and follow every rule. The non-negotiable ones for this change:

* **User-visible strings via ARB.** Any new label ("Legg til seksjon", the remove-section action, the section-switcher tooltip, and the default "Plan" section label) goes in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`, then `make i18n`. No raw English in widgets. Norwegian UI term for the Program base section is **"Plan"**; the general rule (documented in DESIGN-008) is that the default section carries the entity's name.
* **Reuse the wide-screen primitives, do not invent new ones.** `WindowSizeClass.of(context)` gives `compact` / `medium` / `expanded`. Forms are already opened through `openFormSurface` / `showRingdrillFormDialog` (see `lib/views/widgets/ringdrill_sheet.dart` and `context_sheet.dart`) — a modal dialog on wide, a route/sheet on compact, per [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md). The new shell renders *inside* that host. Read how `main_screen.dart` and `roleplays_view.dart` use these before writing layout code, and reconcile chrome so there is never a double AppBar or double close button.
* **Row-affordance rule ([ADR-0031](../adrs/0031-row-edit-affordances.md)).** Removing an added section is an action in the section's overflow menu (the `⋮` in the AppBar on compact, in the detail-pane header on wide), never a per-row pencil.
* **Preserve existing behavior when the flag is off.** The current `ProgramFormScreen` save path, validation, quick-rename, station-number-format and language pickers, and tags editor must all keep working unchanged in the flag-off path.
* **No model or renderer changes.** This is a views-only stage. Do not touch `lib/models/` or `lib/services/`.
* **No new lint suppressions.** Run `flutter analyze` and `flutter test` before claiming green.

## Concepts (from DESIGN-008)

The **default section** carries the entity's short structural fields and is named after the entity — "Plan" for `Program`. Short fields (name, description, tags, number format, language) live only there and never become their own section. Each optional markdown field, once added, becomes its own section that fills the screen when selected. The switcher lists: the default section, then each added markdown section, then a trailing "Legg til seksjon" that reveals the unused optional fields. (The "Variabler" section that DESIGN-008 shows between them arrives in Stage 5 — omit it here.)

## Scope

Four steps, in order.

### Step 1. The shared shell

Create `lib/views/widgets/section_navigated_form.dart` with two public types.

`FormSection` — describes one navigable section:

```dart
class FormSection {
  const FormSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.removable = false,
  });

  final String id;
  final String label;              // localized
  final IconData icon;
  final WidgetBuilder builder;     // renders the section body
  final bool removable;            // default section is not removable
}
```

`SectionNavigatedForm` — the shell. It owns the chrome (close, save, title/switcher) and the selected-section state, and lays out compact vs wide. Suggested surface:

```dart
class SectionNavigatedForm extends StatefulWidget {
  const SectionNavigatedForm({
    super.key,
    required this.title,          // AppBar title on compact, e.g. "Rediger plan"
    required this.sections,       // ordered, active sections only
    required this.addable,        // unused optional sections, for "Legg til seksjon"
    required this.onAdd,          // ValueChanged<String> section id
    required this.onRemove,       // ValueChanged<String> section id (removable only)
    required this.onSave,
    required this.onClose,
    this.initialSectionId,
  });
  // ...
}
```

Behavior:

* **Compact** (`WindowSizeClass.compact`): a `Scaffold` with an `AppBar`. Leading is the close button. The title is a tappable switcher — the current section's label plus a chevron — that opens a menu (a bottom sheet using the existing `showRingdrillSheet` chrome, or a `MenuAnchor`) listing every active section, a divider, then a "Legg til seksjon" entry that reveals the `addable` list. The actions slot holds an overflow `⋮` (which offers "Fjern seksjon" when the current section is `removable`) and the Save button. The body is the current section's `builder`.
* **Expanded / medium** (`WindowSizeClass.expanded` / `.medium`): a `Row`. A left rail (~210 logical px) lists the sections with their icons, the current one highlighted, and a trailing "Legg til seksjon" entry. The right pane shows a header (current section label + `⋮` overflow for remove) and the current section's `builder` below. Close and Save live in the host dialog chrome — check `openFormSurface`/`showRingdrillFormDialog` and do not duplicate them; if the host does not provide them on wide, render them in the detail-pane header. Do not create your own dialog here; the caller wraps this widget via `openFormSurface`.

Match the mockups at `docs/design/mockups/variables-mobile.html` and `docs/design/mockups/variables-wide.html` for structure (ignore the "Variabler" entry — Stage 5).

Files expected in this commit:

* `lib/views/widgets/section_navigated_form.dart`
* `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, and the regenerated `lib/l10n/app_localizations*.dart` (for "Legg til seksjon", "Fjern seksjon", switcher tooltip)

Run `make i18n`. Run `git status`. Commit: `feat(views): add SectionNavigatedForm shell with compact dropdown and wide rail`.

### Step 2. Extract the markdown section field editor

The flag-on and flag-off paths must share field-building. Extract the labelled multi-line markdown `TextFormField` (the body `OptionalFieldSections` renders per active section today) into a small reusable widget, e.g. `MarkdownSectionField`, that takes a controller, focus node, label and the min/max lines. `OptionalFieldSections` (flag-off path) is refactored to use it, and the new section bodies (flag-on path) use the same widget so a markdown section fills the available height. No behavior change for the flag-off path — this is a pure refactor.

Keep the token-aware behavior out. This is still a plain `TextFormField`. The token-aware field is Stage 4 and will later replace `MarkdownSectionField`'s internals behind the same API.

Files expected in this commit:

* `lib/views/widgets/optional_field_sections.dart`
* the new `MarkdownSectionField` file (or an addition to an existing widgets file — match the repo's layout)

Run `git status`. Commit: `refactor(views): extract MarkdownSectionField shared by both form paths`.

### Step 3. Migrate ProgramFormScreen behind the flag

In `lib/views/program_form_screen.dart`, branch `build` on `AppFlags.planVariables`.

* **Flag off:** the existing body, verbatim. No change.
* **Flag on:** render a `SectionNavigatedForm`. Sections:
  * `Plan` (default, not removable): the base fields — name, description, tags, station-number-format, language picker. Reuse the existing widgets (`_TagsEditor`, `_StationNumberFormatPicker`, `_LanguagePicker`), just hosted in this section's body.
  * One section per **active** optional markdown field (`briefIntroMd`, `commsMd`, `beforeRoundMd`), body = `MarkdownSectionField` over the existing controller. Icon `Icons.description_outlined` or similar. `removable: true`.
  * `addable` = the optional fields not yet active, driving "Legg til seksjon". Adding one activates it (same `_activeSections` set as today) and selects its new section. Removing clears the controller and deactivates, as `_removeSection` does today.

The save path, controllers, focus nodes and `_activeSections` state are unchanged — only their presentation moves into sections. `_save()` reads the same controllers. The AppBar quick-rename requirement from DESIGN-006: on compact the section switcher occupies the title, so plan rename happens through the name field in the "Plan" section (the AppBar title is no longer an editable rename in flag-on mode — note this in a code comment; it is acceptable because the name field is one tap away in the default section).

Files expected in this commit:

* `lib/views/program_form_screen.dart`

Run `git status`. Commit: `feat(views): render ProgramFormScreen as a section-navigated form behind RINGDRILL_PLAN_VARIABLES`.

### Step 4. Tests

Add widget tests under `test/views/`. Because the flag is a compile-time `bool.fromEnvironment`, you cannot flip it at runtime in a normal test. Handle this by making the flag injectable where the test needs both paths: either read `AppFlags.planVariables` through a value that a test can override, or structure `ProgramFormScreen` so the section-navigated body is a testable widget you can pump directly. Prefer pumping `SectionNavigatedForm` and the flag-on `Program` body directly, and cover the flag-off path by asserting the default (unflagged) build still renders the legacy form.

Cover:

* **Switcher lists active sections and switches.** Pump the flag-on Program body with two active md sections at compact width. Open the switcher, select a section, assert its body is shown and the previous one is not.
* **Add reveals an inactive section.** "Legg til seksjon" lists an unused field; selecting it activates and shows its editor.
* **Remove deactivates.** The overflow "Fjern seksjon" removes the current removable section and returns to a sensible section; the default "Plan" section offers no remove.
* **Default section is not removable.** Assert no "Fjern seksjon" action while "Plan" is selected.
* **Wide layout shows the rail.** Pump at expanded width (`MediaQuery` with a wide size); assert the rail lists sections and the detail pane shows the selected one, with no duplicate close/AppBar.
* **Flag-off legacy path.** The default build renders the current single-scroll form (assert a marker unique to the legacy layout).
* **Save round-trips.** Editing the name in the "Plan" section and a markdown section, then Save, pops the expected updated `Program` (same assertions the existing form test makes).

Run `flutter analyze`. Run `flutter test test/views/`. Then the full suite once.

Files expected in this commit:

* the new/edited test files under `test/views/`

Run `git status`. Commit: `test(views): cover section navigation, add/remove and flag-off legacy path`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` no new failures.
3. `make i18n` idempotent after commit. `make build` not needed (no model/enum changes).
4. `dart compile exe bin/ringdrill.dart -o /tmp/ringdrill-cli` (or the repo's `dart build cli`) succeeds.
5. **Flag-off is byte-identical UX.** With no `--dart-define`, `ProgramFormScreen` is the current form. Confirm by test and by a quick `flutter run` if practical.
6. **Flag-on manual QA.** Run with `--dart-define=RINGDRILL_PLAN_VARIABLES=true` on a narrow window and a wide window. Verify: switcher dropdown on narrow, rail on wide; add/remove sections; a markdown section fills the screen; Save persists; no double AppBar or double close on wide. Record the matrix in the final commit body or a `docs/notes/` file per convention.
7. **Scope check.** `git diff --stat main` touches only `lib/views/…`, `lib/l10n/…` and `test/views/…`. No `lib/models/` or `lib/services/` changes. `ExerciseFormScreen`, `StationFormScreen`, `RolePlayFormScreen` untouched.
8. **Clean tree gate.** `git status` clean; `git ls-files --others --exclude-standard` empty.
9. **Diff sanity.** `git log --stat origin/main..HEAD` — every path in the commit you intended, generated localizations included.

## Deliverables

A series of Conventional Commits (English) on `design-008`, clean tree at the end. The final commit body summarises the shared shell, the flag-gated Program migration, and that Exercise/Station/RolePlay migrations and the Variabler section (Stage 5) remain. Note how the flag was made testable.

DESIGN-008 and ADR-0046 are authoritative. If reconciling the shell with `openFormSurface`'s wide-screen chrome forces a structural choice not covered here (for example, the host dialog already renders a title bar you must suppress), make the minimal choice that avoids duplicate chrome and note it in the commit body. If it needs a larger deviation, stop and ask. Do not write a new ADR for this stage.

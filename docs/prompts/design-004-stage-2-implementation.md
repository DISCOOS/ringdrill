# Implement DESIGN-004 Stage 2

You are working in the RingDrill repository. Implement Stage 2 of DESIGN-004 ("Exercise brief template") end-to-end. DESIGN-004 at `docs/design/brief-template.md` is the authoritative spec. Stages 1a and 1b have shipped and are merged. Read their prompts at `docs/prompts/adr-0022-stage-1a-implementation.md` and `docs/prompts/adr-0022-stage-1b-implementation.md` for the conventions they established.

Stage 2 introduces the template engine. It adds the `mustache_template` dependency, registers the first template (`ringdrill-standard-v1`, locale `nb`), ships the template asset, and adds `BriefRenderer` under `lib/services/`. The renderer takes a `Program`, an optional `Exercise` for single-exercise briefs, a `BriefAudience` and a template id, and returns rendered markdown. No UI, no route, no form editor work happens in this stage. Stages 3 through 5 cover those.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* The CLI must stay Flutter-free. `bin/ringdrill.dart` transitively imports `lib/data/`, never `lib/services/`. Confirm before adding new code that nothing under `lib/services/` ends up imported from `bin/`. Use `rg "package:ringdrill/services" bin/ lib/data/` to verify.
* Mobile-safe imports. The renderer is reachable on web. Do not introduce `dart:html` or `package:web`. The `mustache_template` package is pure Dart, but verify it has no platform-specific transitive deps before merging.
* User-visible strings on Norwegian-template output come from the template file, not from `app_nb.arb`. The template ships hardcoded Norwegian section headings ("Tid", "Metode", "Læringsmål" and so on). Localized strings on the eventual UI surface (Stage 3) still go through ARB. Do not add ARB entries in this stage.
* No new lint suppressions. Match existing Dart style.
* Run `flutter analyze` and `flutter test` before claiming the change is green. `test/widget_test.dart` is the known-broken default-template smoke test. Flag it as such rather than asserting all tests pass.
* The renderer is a pure function over the in-memory program. Do not call `DrillFile.fromProgram` or `program()` from inside it. The brief is rendered after the program is already loaded.
* `BriefAudience` IDs are English (`participant`, `instructor`, `director`) per DESIGN-004. Norwegian terms appear only inside the `nb` template.

## Commits

Commit as you progress, not in one giant blob. Each step below is a natural commit boundary. The project uses Conventional Commits with a scope. Allowed types from history: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Suggested subjects:

* `chore(deps): add mustache_template for brief rendering`
* `feat(services): scaffold BriefAudience, Template and TemplateRegistry`
* `feat(assets): add ringdrill-standard-v1 brief template (nb)`
* `feat(services): add BriefRenderer with helpers and audience gating`
* `test(services): cover BriefRenderer for participant/instructor/director audiences`

All five commits land together as one continuous series on the same branch.

### Commit discipline (non-negotiable)

A recurring failure mode in past rounds has been agents leaving regenerated files or test files uncommitted in the working tree. Avoid this:

* After every step below, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Anything beyond the list also belongs in the commit unless explicitly punted. If you see a path you do not recognize in `git status`, do not delete it. Inspect it, then either include it or stop and ask.
* Never close a step with `git stash` or `git restore`. If something is in the working tree, it ships with the commit.
* The final Verification gate requires `git status` to print a clean tree on the working branch with no untracked or unstaged files. The work is not done until this is true.

## Scope

Five steps. Do them in order.

### Step 1. Add mustache_template dependency

Edit `pubspec.yaml`. Add `mustache_template: ^2.0.0` (or the latest 2.x version) under `dependencies:`. Match the alphabetical ordering used in the rest of the section. Run `flutter pub get` to refresh `pubspec.lock`.

Files expected in this commit:

* `pubspec.yaml`
* `pubspec.lock`

Run `git status`. Confirm the tree is clean apart from those two paths. Commit: `chore(deps): add mustache_template for brief rendering`.

### Step 2. Scaffold types

Create `lib/services/brief/brief_audience.dart`:

```dart
/// Audience filter for brief rendering. Drives which mustache sections are
/// active when the template is expanded. See DESIGN-004.
enum BriefAudience {
  participant,
  instructor,
  director;

  bool get includesDirectorNotes => this != BriefAudience.participant;
  bool get includesActorPii => this == BriefAudience.director;
}
```

Create `lib/services/brief/template_registry.dart`:

```dart
/// A registered brief template. Identified by [id]. Loaded from [assetPath]
/// via the Flutter asset bundle.
class BriefTemplate {
  const BriefTemplate({
    required this.id,
    required this.version,
    required this.locale,
    required this.scope,
    required this.assetPath,
  });

  final String id;
  final int version;
  final String locale;       // BCP 47 tag, 'nb' for v1
  final String scope;        // 'system' for v1; 'org' and 'team' come later
  final String assetPath;    // path under assets/, used by rootBundle.loadString
}

/// In-memory registry of brief templates. v1 has exactly one entry. The
/// registry is the only thing the renderer needs to know about template
/// discovery; callers always pass a [BriefTemplate.id], never a path.
class TemplateRegistry {
  TemplateRegistry._(this._templates);

  static final TemplateRegistry instance = TemplateRegistry._({
    'ringdrill-standard-v1': const BriefTemplate(
      id: 'ringdrill-standard-v1',
      version: 1,
      locale: 'nb',
      scope: 'system',
      assetPath: 'assets/templates/ringdrill-standard-v1.nb.md.mustache',
    ),
  });

  final Map<String, BriefTemplate> _templates;

  BriefTemplate? get(String id) => _templates[id];

  BriefTemplate get systemDefault =>
      _templates['ringdrill-standard-v1']!;

  /// Resolves the template for [exercise]. Falls back to [systemDefault]
  /// when [Exercise.templateId] is null or unknown. When team/org defaults
  /// arrive, they are consulted here before the system default.
  BriefTemplate resolve(String? templateId) {
    if (templateId == null) return systemDefault;
    return _templates[templateId] ?? systemDefault;
  }
}
```

Files expected in this commit:

* `lib/services/brief/brief_audience.dart`
* `lib/services/brief/template_registry.dart`

Run `git status`. Commit: `feat(services): scaffold BriefAudience, Template and TemplateRegistry`.

### Step 3. Ship the v1 template

Create `assets/templates/ringdrill-standard-v1.nb.md.mustache`. The content is the template described in DESIGN-004 under "Template anatomy". The illustrative snippet in DESIGN-004 lines 208-292 is a starting point but is not a literal copy-paste. Fill in the gaps:

* Document title and (optional) description at the top.
* Table of contents block iterating exercises and (under each) stations. Each entry links to its anchor with a markdown link to a `#`-anchor that matches what `markdown_widget` produces from the heading text.
* For each exercise, render the metadata table (Tid, Metode, Læringsmål, Øvingsmomenter, Organisering, Ordreformat, Tips til gjennomføring, Samband) using `{{durationLabel}}`, `{{{methodMd}}}`, `{{{learningGoalsMd}}}`, `{{{trainingFocusMd}}}`, `{{setupLabel}}`, `{{{orderFormatMd}}}`, `{{{executionTipsMd}}}` and `{{{effectiveCommsMd}}}`. Omit rows whose source field is null using mustache sections (`{{#methodMd}}...{{/methodMd}}`).
* For each station, render the headline `### {{exerciseNumber}}{{stationLetter}} – {{name}}{{#variantSuffix}} – {{variantSuffix}}{{/variantSuffix}}`, then the UTM line, then each markdown section in the order DESIGN-004 specifies. RolePlay loop comes before "Situasjon" per DESIGN-004's render example.
* Audience gating uses `{{#if_director}}...{{/if_director}}` for actor PII and `{{#if_instructor_or_director}}...{{/if_instructor_or_director}}` for director notes. The renderer (Step 4) supplies these as booleans in the context.

Register the asset in `pubspec.yaml`:

```yaml
  assets:
    - shorebird.yaml
    - assets/templates/ringdrill-standard-v1.nb.md.mustache
```

Files expected in this commit:

* `assets/templates/ringdrill-standard-v1.nb.md.mustache`
* `pubspec.yaml`

Run `git status`. Commit: `feat(assets): add ringdrill-standard-v1 brief template (nb)`.

### Step 4. BriefRenderer

Create `lib/services/brief/brief_renderer.dart`. Public surface:

```dart
class BriefRenderer {
  BriefRenderer({TemplateRegistry? registry, AssetBundle? bundle})
      : _registry = registry ?? TemplateRegistry.instance,
        _bundle = bundle ?? rootBundle;

  final TemplateRegistry _registry;
  final AssetBundle _bundle;

  /// Renders a brief for [program]. When [exercise] is non-null, scopes the
  /// brief to that exercise. When null, renders the whole program. The
  /// template is resolved from [exercise?.templateId] (single-exercise mode)
  /// or from the system default (program mode).
  Future<String> render({
    required Program program,
    Exercise? exercise,
    required BriefAudience audience,
  }) async { ... }
}
```

Implementation outline:

1. Resolve the template via `_registry.resolve(exercise?.templateId)`. Load the template string from `_bundle.loadString(template.assetPath)`.
2. Parse it with `Template.parse(...)` from `mustache_template`. Pass `htmlEscapeValues: false` because the output is markdown, not HTML.
3. Build the rendering context. The context is a `Map<String, dynamic>` with keys: `program`, `exercises` (a list of exercise contexts), `if_director`, `if_instructor_or_director`.
4. Each exercise context contains: `name`, `durationLabel`, `methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `effectiveCommsMd`, `setupLabel`, `stations` (a list of station contexts), `roleplays` (list of roleplay contexts scoped to this exercise).
5. Each station context contains: `name`, `variantSuffix`, `exerciseNumber`, `stationLetter`, `position` (a map with `utm` key), every `*Md` field, plus the filtered roleplay list for that station with `actor` resolved.
6. `roleplay.actor` is included only when `audience == BriefAudience.director`. Otherwise the `actor` key is null and the template's `{{#actor}}...{{/actor}}` section renders nothing.
7. `directorNotesMd` is included only when `audience != BriefAudience.participant`. Easiest path: gate the whole block in the template with `{{#if_instructor_or_director}}`, and pass `directorNotesMd` regardless. The gate handles the visibility.

Helpers required by the template (implement as plain functions or methods on a `_BriefContext` helper class):

* `durationLabel(Exercise)` — total minutes per round formatted as `60 min.`. v1 uses `executionTime`. If `numberOfRounds > 1`, returns `4 x 60 min.` or similar. Decide the exact format and document it in a comment.
* `setupLabel(Exercise)` — ring config string. v1 format: `4 x (60 | 15 | 5)` where the numbers are `numberOfRounds x (executionTime | evaluationTime | rotationTime)`. Below that, the per-round wall-clock schedule from `exercise.schedule`. Render as a single line with `\n` for the schedule, since this lands inside a markdown table cell. If the schedule does not fit cleanly in a cell, fall back to listing the start times comma-separated. Match what reads well in the rendered example in DESIGN-004.
* `exerciseNumber(Program, Exercise)` — 1-based position of the exercise in the program's exercise list.
* `stationLetter(Station)` — lowercase letter derived from `station.index`. `index = 0` -> `'a'`, `index = 1` -> `'b'`, and so on. Use `String.fromCharCode('a'.codeUnitAt(0) + station.index)`.
* `utm(LatLng?)` — formatted UTM string. Call `latLng?.toUtm()?.toRefString()` from `lib/utils/projection.dart`. Returns empty string when null.
* `effectiveCommsMd(Program, Exercise)` — `exercise.commsMd ?? program.commsMd`.

Mustache resolves cross-references inside rich-text fields. The DESIGN-004 example uses `{{station.position.utm}}` inside a station's `situationMd`. To make that work, the inner markdown content must itself be parsed as a mustache template using the station's own context. Implementation: before substituting a `*Md` field into the outer template, run it through `Template.parse(content, htmlEscapeValues: false).renderString(stationContext)`. Apply this to every `*Md` field that can plausibly reference structural data. The renderer must be tolerant of fields that contain literal `{{` not intended as mustache — for v1 it is acceptable to require authors to escape with `{{=<% %>=}}` if they need literal braces, and document the constraint at the top of the renderer file.

Files expected in this commit:

* `lib/services/brief/brief_renderer.dart`

Run `git status`. Commit: `feat(services): add BriefRenderer with helpers and audience gating`.

### Step 5. Tests

Create `test/services/brief/brief_renderer_test.dart`. Tests must drive the renderer through the production code path. For the asset bundle, use Flutter's test bundle (`rootBundle` works under `TestWidgetsFlutterBinding.ensureInitialized()` and resolves `assets/templates/...` against the pubspec asset list).

Tests to add:

* `renders the DESIGN-004 fixture for director audience byte-for-byte`. Construct the program/exercise/station/roleplay/actor fixture from DESIGN-004 lines 310-378. Run `BriefRenderer.render` with `audience: BriefAudience.director`. Assert the output equals the expected markdown in DESIGN-004 lines 383-434. Whitespace matters. Trim trailing whitespace per line but otherwise compare exactly.
* `participant audience drops actor PII and director notes`. Same fixture, `audience: BriefAudience.participant`. Assert the output does *not* contain `Kari Hansen`, `99887766`, `Markør:` or `Notater til instruktør/øvingsledelse`. Assert it still contains `Anne Glemsk` (the roleplay name is publishable).
* `instructor audience shows director notes but not actor PII`. Assert the output contains `Notater til instruktør/øvingsledelse` and does not contain `Kari Hansen` or the phone number.
* `mustache cross-references resolve inside markdown fields`. Build a station with `situationMd: 'IPP er ved {{position.utm}}.'`. Render. Assert the output contains the resolved UTM string and does not contain `{{position.utm}}`.
* `null markdown fields omit their sections`. Build a station with only `situationMd` set. Render. Assert no `#### Utstyrsbehov` heading, no `#### Oppdrag` heading, no `#### Kritiske spørsmål` heading. Assert the `#### Situasjon` heading is present.
* `exercise.commsMd overrides program.commsMd`. Build a program with `commsMd: 'PROG'` and one exercise with `commsMd: 'EX'`. Render. Assert the exercise's Samband cell contains `EX` and not `PROG`. Build a second program where the exercise has no `commsMd`. Assert the Samband cell falls back to `PROG`.
* `unknown templateId falls back to system default`. Build an exercise with `templateId: 'does-not-exist'`. Render. Assert the output is the same as if `templateId` were null.
* `stationLetter maps index 0..25 to a..z`. Pure helper test. No renderer call needed if the helper is exposed. If it is private to the renderer, use `@visibleForTesting`.
* `durationLabel and setupLabel format match DESIGN-004 render example`. Lock down the exact format strings.

Files expected in this commit:

* `test/services/brief/brief_renderer_test.dart`

Run `flutter analyze`. Run `flutter test test/services/brief/`. Run the full test suite once to confirm nothing else regressed.

Run `git status`. Commit: `test(services): cover BriefRenderer for participant/instructor/director audiences`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` produces no new failures. `test/widget_test.dart` remains broken. Do not try to fix it.
3. `flutter build apk --debug` succeeds. This catches asset registration mistakes (a missing entry in `pubspec.yaml` does not show up under `flutter test`). If a full APK build is too slow on the dev machine, `flutter build bundle` is an acceptable substitute.
4. `dart compile exe bin/ringdrill.dart -o /tmp/ringdrill-cli` succeeds. This catches any accidental Flutter import that made it into the CLI's transitive dependency graph.
5. **Clean tree gate.** `git status` on the working branch prints `nothing to commit, working tree clean`, and `git ls-files --others --exclude-standard` prints nothing. No untracked, no unstaged, no stashed work. The stage is not complete until this is true.
6. **Diff sanity.** Run `git log --stat origin/main..HEAD` and walk every changed path. Confirm each file appears in exactly the commit you intended.
7. Manual QA matrix (record the result in the final commit body or a `docs/notes/` file, whichever matches existing convention):
   * **Renderer smoke.** Write a one-off Dart script (or a `flutter test` that prints) that loads the DESIGN-004 fixture, renders it for all three audiences, and dumps the output to `/tmp/brief-{audience}.md`. Eyeball the three files. The director output should match DESIGN-004's example. The participant and instructor outputs should differ in the expected ways.
   * **Cross-reference resolution.** Verify the `{{station.position.utm}}` expression inside `situationMd` in the fixture renders as `32V 0580414E 6552008N` (the value from `LatLng(58.99, 10.43)` via `lib/utils/projection.dart`).
   * **Template asset bundling.** Run the app on web (`flutter run -d chrome`) and confirm the template asset loads. There is no UI surface for the brief yet, so the easiest path is a debug-only button or a `print` statement in `main.dart` that calls the renderer once on app start. Remove the debug call before committing — it must not survive into the final commit.
8. Confirm Stage 3 surfaces (`/brief/...` route, audience toggle UI, print stylesheet) are untouched. Stage 2 is engine-only.

## Deliverables

A series of five Conventional Commits as outlined above, all on the same working branch, with a clean tree at the end. The final commit body should include:

* A short summary of what the renderer does and what surfaces are still missing (Stages 3, 4 and 5 explicitly deferred).
* The manual QA matrix filled out.
* A note on any open question from DESIGN-004 that the implementation answered (e.g. whether `{{station.position.utm}}` inside `situationMd` works as expected, since DESIGN-004 lists it under "Open questions" as a roundtrip-stability concern). If the open question is *not* answered, say so and link the test that would have to land first.

DESIGN-004 is the authoritative spec. If you find yourself contradicting it, stop and ask. Do not write a new ADR for template-engine choices unless something forces a structural deviation from DESIGN-004 (for example, if `mustache_template` cannot be used and a different package or a hand-rolled parser becomes necessary).

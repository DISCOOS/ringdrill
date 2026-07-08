# Implement DESIGN-009 — Prompt 4c: station and roleplay own-facet tokens

You are working in the RingDrill repository, on `design-009`. A small, **views-only** follow-up in the same shape as prompt 4b. 4b exposed `program.*` and `exercise.*` in the picker. This exposes the station's and the roleplay's **own** scalar facets, which the renderer already resolves but the picker does not offer — the gap the author hit when a Post's "Postbeskrivelse" field could not insert `{{station.name}}` or `{{station.position.utm}}`. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` (see "Own-entity facets, facet completion, and leaf fields") are authoritative. Read `AGENTS.md` rule 9.

**No model change, no renderer change.** Wire already-resolvable facets into the picker's `planFields` list. Protected invariant, same as 4b: *the picker never offers a token the renderer can't resolve at that scope.*

## What resolves where (verified against `brief_renderer.dart`)

`_buildStationContext` builds `stationRefContext` with a `station` map (lines ~286–293) that resolves in station fields and — cascaded — in roleplay fields; `roleplayRefContext` adds a `roleplay` map (lines ~330–336) resolving in roleplay fields.

* **Station own facets** — resolvable in the station editor and the roleplay editor: `station.name`, `station.stationCode`, `station.position.utm`, `station.variantSuffix`.
* **RolePlay own facets** — resolvable in the roleplay editor only: `roleplay.name`, `roleplay.age`, `roleplay.signalement`, `roleplay.position.utm`.

**Self-reference rule (do not offer these).** `station.description` resolves too, but it *is* the free-text markdown field the author edits in the base section — offering `{{station.description}}` there recurses through the fixpoint pass. Withhold it. For the roleplay, withhold `roleplay.name` and `roleplay.signalement` **from those same fields** (the name field and the signalement field) for the same reason; they may still be offered in the roleplay's *other* fields (`behavior`, `background`, `propsMd`). If per-field withholding is more than a trivial filter given the current call sites, withhold `roleplay.name`/`roleplay.signalement` from the roleplay editor entirely and note it — offering the short derived facets (`age`, `position.utm`) is the main win.

## Ground rules

* **One source of truth.** Add `PlanFieldTokens.station(l)` and `PlanFieldTokens.roleplay(l)` to the existing `lib/views/widgets/plan_field_tokens.dart`, alongside `program(l)`/`exercise(l)`. Same `PlanFieldToken(name, label)` shape.
* Views-only. No `brief_renderer.dart` or `refContext` change. A facet offered here must already be in a `refContext` map.
* Labels via ARB, then `make i18n`. Reuse existing keys where sensible (`stationName`, `stationDescription` etc.); add nb+en keys for what has none — likely `stationCode` ("Postkode" or the existing term if one exists), `position`/`utm` ("Posisjon (UTM)"), `variantSuffix`, and the roleplay facets (`age` may exist; `signalement` likely exists). Prefer existing keys; add only the missing ones. Use natural en counterparts.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; `make i18n` only when ARB changes; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Three commits.

### Commit 1. Add station/roleplay token builders + labels

Extend `plan_field_tokens.dart` with `station(AppLocalizations)` (the four station facets, minus `description`) and `roleplay(AppLocalizations)` (the four roleplay facets, applying the self-reference decision above). Add any missing ARB labels (nb + en) and `make i18n`.

Files: `plan_field_tokens.dart`, `lib/l10n/app_nb.arb`, `lib/l10n/app_en.arb`, regenerated localizations. `flutter analyze` + `flutter test test/views/`. Commit: `refactor(views): add station and roleplay own-facet token builders`.

### Commit 2. Wire the lists into the two editors

* `station_form_screen.dart`: extend the `planFields` list from `[...program(l), ...exercise(l)]` to also include `...station(l)`.
* `roleplay_form_screen.dart`: extend to `[...program(l), ...exercise(l), ...station(l), ...roleplay(l)]`. If applying the per-field self-reference rule, build the name/signalement fields' list without the withheld facets.

These are additive to the `station.loc/person.*` entries `StationScope` already supplies — both coexist.

Files: `station_form_screen.dart`, `roleplay_form_screen.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): offer station and roleplay own-facet tokens in their editors`.

### Commit 3. Tests

Under `test/views/` plus a renderer round-trip guard (extend the 4b resolution test or add a sibling):

* **Picker offers them.** Station editor lists the `station.*` facets (not `station.description`); roleplay editor lists `station.*` + `roleplay.*` (respecting the self-reference decision); the exercise and program editors do **not** list `station.*`/`roleplay.*`.
* **Resolution guard (the important one).** For every `PlanFieldToken` in `station(l)` and `roleplay(l)`, insert `{{<name>}}` into the appropriate scope's field of a sample station/roleplay, render through `BriefRenderer`, and assert no `briefUnknownReference` placeholder. This enforces "the picker never offers an unresolvable token."
* Coexistence: the plan-field entries appear alongside `station.loc/person.*` in both editors.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover station/roleplay own-facet picker entries and resolution`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke: in the Post editor, the Postbeskrivelse field's `/` and `{{station.` surface `station.name`/`station.position.utm` (but not `station.description`); inserting `{{station.position.utm}}` renders the UTM in the brief; the roleplay editor additionally surfaces `roleplay.*`; the exercise/program editors do not offer either.
4. `git diff --stat` touches only `lib/views/…`, `lib/l10n/…`, `test/views/…`. No model or renderer change.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the picker now offers the station's and roleplay's own already-resolvable facets from the shared `PlanFieldTokens` source, withholding each field's self-referential free-text facet, guarded by a renderer round-trip.

ADR-0047 and DESIGN-009 are authoritative. Facet completion for `station.loc/person.<slug>.` (prompt 4d) and token-aware scenario leaf fields (prompt 4e) are **out of scope** here. If exposing these facets needs anything beyond token builders, ARB labels, and the `planFields` wiring, stop and report.

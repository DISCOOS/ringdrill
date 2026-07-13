# Implement: consistent cards in the Spill viewer + revised position-card collapse

You are working in the RingDrill repository, on `design-010`. Now that the shared collapsible section card exists (`CollapsibleSectionCard` / `CollapseChevron` / `CollapsibleSectionStore`), bring the Spill viewer's bespoke cards into the same family and rework the position card's collapse affordance. References: the mockups `docs/design/mockups/spill-viewer-consistency.html` and `docs/design/mockups/collapsible-position-card.html`. Read `AGENTS.md` (rules 9, 12).

**Views (+ any ARB string) only.** No model/renderer/schema change. Reuse the existing shared widgets; don't fork collapse logic.

## Fix 1 — Post-context card → the shared card family (`roleplay_screen.dart`, `_StationContextCard`)

Today it's a bespoke bare row (flag + name + one-line description + a trailing `›` that navigates). Make it a `CollapsibleSectionCard` like the others: a header (`CardSectionHeader`) with the flag icon + title **"POST"** + the collapse chevron, and a body holding the station name + description excerpt as a **tappable row** (with a trailing `›`) that opens the Post viewer.

* No bespoke "open" affordance in the header. As with every collapsible card, the card is expanded first; the body's station row is what navigates (its `onTap` = today's `ContextSheet.of(context).replace(StationSheetTarget(...))`). Keep that navigation.
* The wide-layout "does nothing / master out of sync" behaviour of that navigation is fixed generally by `design-shell-master-detail-target-sync.md` (target → master segment + selection), **not** here — this prompt just keeps the existing `replace` call. Don't re-implement cross-segment sync in this card.
* Persist collapsed state with a stable `sectionId` (e.g. `stationContext`).

## Fix 2 — Person / identity card → harmonized + expandable (`roleplay_screen.dart`, `_EffectiveIdentityCard`)

Harmonize it into the same card family and make it reveal the full person info on expand:

* Drop the dark "Spilles av …" band (`surfaceContainerHigh` background) — make it a plain, **muted footer** (a top border + `onSurfaceVariant` text, like the other cards' footers), keeping the masks icon + "Spilles av {actor}".
* Make the card **collapsible/expandable** via the shared `CollapseChevron` + `CollapsibleSectionStore` (stable `sectionId`, e.g. `identity`). It is not a `CardSectionHeader` card (it keeps its avatar + name identity layout), so wire the chevron into that layout rather than forcing a generic uppercase header.
* **Collapsed:** avatar + name + "age · gender" + a short/one-line signalement + the "Spilles av" footer (today's summary).
* **Expanded:** reveal the rest of the person — the full signalement, the person's **notes**, and the linked **location** (name + coordinate) — each resolving tokens the same way the summary fields already do. Effective-identity rule stays for the overridable fields (name/age/gender/signalement); notes/location come from the linked `Person`.

## Fix 3 — Revised position-card collapse (`position_card.dart`, `PositionCardShell`)

Rework the collapse affordance landed earlier (leading chevron on the bar) to match `collapsible-position-card.html`:

* The coordinate bar becomes the card's header-equivalent: a **leading position icon** + the title **"POSISJON"** styled exactly like `CardSectionHeader`'s title (uppercase, bold, same `labelMedium`/letter-spacing), then the UTM (`barChild`), then a trailing control.
* **Expanded (map shown):** the collapse control is **just the chevron** (no background box), a top-right overlay on the map — the corner is free (`PositionCardShell` has no map-layer control). The bar's trailing keeps the editor `›` (opens the position editor).
* **Collapsed (map hidden):** only the bar; the editor `›` is **replaced** by an expand chevron at the trailing edge. Never show both the editor `›` and the expand chevron at once.
* Keep the current **`!fillHeight` gating**: no collapse in the Post/Spill expanded right pane (the map is the whole pane there); this revised model applies to the stacked (fixed-thumbnail) position card. The `fillHeight` right pane always shows the map.
* Applies wherever the collapsible `PositionCardShell` renders (Post viewer + Spill viewer stacked). Persisted `sectionId` (`position`) is unchanged.

## Scope — four commits

### Commit 1. Revised position-card collapse

`position_card.dart`: "POSISJON" title + leading icon on the bar; collapse chevron as a plain map overlay (expanded); expand chevron replacing `›` (collapsed); `!fillHeight` gating kept.

Commit: `fix(views): rework position-card collapse — title bar, map-overlay chevron`.

### Commit 2. Post-context card as a shared collapsible card

`roleplay_screen.dart` `_StationContextCard` → `CollapsibleSectionCard` ("POST" header, navigable body row).

Commit: `feat(views): the Spill post-context card uses the shared collapsible card`.

### Commit 3. Person card harmonized + expandable

`roleplay_screen.dart` `_EffectiveIdentityCard`: muted footer, collapsible, expanded reveals notes + location + full signalement.

Commit: `feat(views): fold the Spill person card open to full person info`.

### Commit 4. Tests

* Post-context card renders a "POST" header + chevron; expanded, its body row is tappable and (mocking the sheet) targets the station.
* Person card collapses/expands; expanded shows the person's notes/location; the "Spilles av" footer has no dark band.
* Position card: "POSISJON" title uses the header title style; expanded shows a map-overlay collapse chevron and the bar's editor `›`; collapsed shows the expand chevron and no editor `›`; no collapse chevron at all in `fillHeight`.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): cover Spill card consistency and the revised position collapse`.

## Ground rules

* Views + test only (plus ARB if a new string like a section title is unavoidable — both languages, `make i18n`). Reuse `CollapsibleSectionCard`/`CollapseChevron`/`CollapsibleSectionStore`.
* `PlayerStatusCard` stays non-collapsible. Section order unchanged.
* Behaviour-preserving apart from the card chrome, the person expand, and the position affordance.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke (Spill viewer): POST and person cards read as the same family as MARKØRORDRE / NÅR AKTIV; the person card expands to show notes + location; "Spilles av" is a quiet footer, no dark band; the post card, once expanded, opens the Post viewer from its body row. Position card: "POSISJON" title, collapse chevron alone on the map top-right when expanded, expand chevron on the bar when collapsed (never the editor `›` at the same time); no collapse in the expanded right pane.
4. `git diff --stat` touches `lib/views/…`, `test/…` (and `lib/l10n/…` only if needed).
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The mockups are authoritative. Cross-segment navigation sync is handled by `design-shell-master-detail-target-sync.md`, not here.

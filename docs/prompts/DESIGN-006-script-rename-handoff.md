## DESIGN-006 Script/Spill segment rename — landing summary

**Landed 2026-06-02** in three commits on `main`:

1. `refactor(program)`: `ProgramSegment.roleplays` → `ProgramSegment.script` in
   `lib/views/program_view.dart`, `lib/views/main_screen.dart`, and all affected
   test files. Switcher content mapping (`RolePlaysView`, `RolePlayDetailEmpty`)
   unchanged. Four stale `program_overview_test.dart` tests removed (they tested
   features revised out of Stage 3: summary line, brief in overview,
   NestedScrollView); scroll-collapse test updated to use `ListView.first`.
2. `feat(l10n)`: `scriptSegment` key added (nb "Spill", en "Script") to both ARB
   files; `flutter gen-l10n` run. Switcher label repointed from `rolePlaysTab`
   to `scriptSegment`. Two test label-text finders updated (`program_view_test`
   line ~296, `program_scoped_routing_test` line ~213).
3. `docs(design)`: DESIGN-006 updated — ASCII switcher row, segment table,
   FAB/actions table, prose and Terminology. Script-layer note added.
   Changelog entry added.

### What was deliberately left in place

- `rolePlaysTab` l10n key — still used as "Markører" for the role roster inside
  the Spill segment (empty states, cast surfaces, `RolePlaysView` header).
- All `RolePlay*` code (`RolePlaysController`, `RolePlaysView`, `RolePlayFormScreen`,
  role-form/cast flow, `/roleplays/...` routing back-compat redirects).
- `roleplay` ICU plural key — used in the overview (if/when the summary line is
  ever added back) and potentially elsewhere.

### Reserved seam

`SilentWitness` ("Tause vitner") — a scenario element with description/story/
purpose/info + position, no actor — is parked as a followup item. It would live
as a second content type in the Spill segment alongside `RolePlay`. Consider a
shared `ScenarioElement` base when it lands.

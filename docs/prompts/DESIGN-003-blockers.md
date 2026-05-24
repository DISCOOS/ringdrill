# DESIGN-003 Blockers

## Steps 6, 7, 8, and 18 — Session/position infrastructure does not exist

**Steps blocked:** Step 6 (`feat(session): add rolePlayUuid to SessionParticipant`), Step 7 (`feat(position): broadcast when rolePlayUuid is set`), Step 8 (`feat(realtime): allow position patches from roleplayers`), and Step 18 (`feat(map): render live roleplayer broadcasters distinct from teams`).

**Root cause:** All four steps reference files and classes that have not yet been implemented:
- `lib/data/session_status.dart` — does not exist. `SessionParticipant` is not defined anywhere in the codebase.
- `lib/services/position_broadcast_service.dart` — does not exist.
- `checkedInTeamUuid` — not referenced anywhere in `lib/`.
- `participant_position` patch authorization — not implemented.

The entire realtime session/participant layer specified in ADR-0009 ("Realtime transport and session model") and ADR-0012 ("Position sharing and team aggregation") has not been built yet. These ADRs are Accepted on paper but their code does not exist.

**What the loop would have to invent:** Building these four steps would require implementing the full session participant schema, the realtime transport layer, the position broadcast service, and the patch authorization logic from scratch — work that is substantially outside the scope of DESIGN-003 and that belongs to a separate implementation task covering ADR-0009 and ADR-0012.

**Resolution:** Steps 6–8 and 18 are deferred. They become the first steps of the next implementation loop once the session layer exists. The data model changes from Phase A (RolePlay, Actor, Program.rolePlays/actors, DrillFile schema 1.1) and the authoring UI from Phase C are fully self-contained and can ship without Phase B.

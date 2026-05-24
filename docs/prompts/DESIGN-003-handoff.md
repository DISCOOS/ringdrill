## Step 1: RolePlay and Actor models (c346da5)
- State established: `lib/models/role_play.dart` and `lib/models/actor.dart` exist, codegen ran clean, 5 model tests pass.
- Next step inputs: `Program` in `lib/models/program.dart` needs `rolePlays`/`actors` fields; `ProgramRepository` needs CRUD with key prefixes `pr:` and `pa:`; all `Program(...)` call sites need the two new required fields.
- Deferred: nothing.

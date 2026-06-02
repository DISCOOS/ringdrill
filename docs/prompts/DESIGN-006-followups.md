1. `MainScreen.dispose()` does not dispose its field-held `RolePlaysController`, leaving `filterExerciseUuid` undisposed after the shell is torn down.

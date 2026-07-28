import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/edit_permissions.dart';
import 'package:ringdrill/services/exercise_service.dart';

/// ADR-0057's matrix, stated once so the call sites do not each re-derive it.
///
/// Two exceptions carry the whole design and are asserted from both directions:
/// an actor may edit roleplays *and nothing else*, an instructor may edit teams
/// *and nothing else*. And roleplays survive the live lock, because a marker's
/// behaviour is exactly what gets adjusted mid-scenario, while the exercise's own
/// structure is frozen under a running drill for everyone including the director.
const _exerciseUuid = 'ex-permissions';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Permissions Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [],
  schedule: const [],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

/// Every target except the ones named.
Iterable<EditTarget> except(Set<EditTarget> allowed) =>
    EditTarget.values.where((t) => !allowed.contains(t));

void main() {
  tearDown(ExerciseService().stop);

  group('idle', () {
    test('a director edits everything', () {
      for (final target in EditTarget.values) {
        expect(
          canEdit(StaffRole.director, target, exerciseUuid: _exerciseUuid),
          isTrue,
          reason: '$target',
        );
      }
    });

    test('an instructor edits teams, and only teams', () {
      expect(canEdit(StaffRole.instructor, EditTarget.team), isTrue);
      for (final target in except({EditTarget.team})) {
        expect(
          canEdit(StaffRole.instructor, target),
          isFalse,
          reason: '$target',
        );
      }
    });

    test('an actor edits roleplays, and only roleplays', () {
      expect(canEdit(StaffRole.actor, EditTarget.rolePlay), isTrue);
      for (final target in except({EditTarget.rolePlay})) {
        expect(canEdit(StaffRole.actor, target), isFalse, reason: '$target');
      }
    });
  });

  group('while that exercise is running', () {
    setUp(() => ExerciseService().start(_exercise()));

    test('its structure is frozen, for the director too', () {
      for (final target in except({EditTarget.rolePlay})) {
        expect(
          canEdit(StaffRole.director, target, exerciseUuid: _exerciseUuid),
          isFalse,
          reason: '$target must not be edited under a running drill',
        );
      }
    });

    // The deliberate exception: a marker's behaviour is what gets adjusted
    // mid-scenario, so it is the one thing the live lock lets through.
    test('roleplays stay editable', () {
      for (final role in [StaffRole.director, StaffRole.actor]) {
        expect(
          canEdit(role, EditTarget.rolePlay, exerciseUuid: _exerciseUuid),
          isTrue,
          reason: '$role',
        );
      }
      // Still not for an instructor: the live lock is not a promotion.
      expect(
        canEdit(
          StaffRole.instructor,
          EditTarget.rolePlay,
          exerciseUuid: _exerciseUuid,
        ),
        isFalse,
      );
    });

    test('a different exercise is unaffected', () {
      expect(
        canEdit(
          StaffRole.director,
          EditTarget.station,
          exerciseUuid: 'some-other-exercise',
        ),
        isTrue,
        reason: 'the lock is scoped to the exercise actually running',
      );
    });

    // Null means "not tied to an exercise" — the plan, the roster. Those are
    // already director-only, and editing them changes nothing another device is
    // rendering for the drill in progress.
    test('plan-level targets are not locked by a running exercise', () {
      expect(canEdit(StaffRole.director, EditTarget.plan), isTrue);
      expect(canEdit(StaffRole.director, EditTarget.staff), isTrue);
    });
  });

  // Joining the staff roster is not the same authority as running it: an actor
  // may put themselves on the list, while changing or removing other people's
  // records stays with the director.
  group('canCreate', () {
    test('an actor may add to the roster, and nothing else', () {
      expect(canCreate(StaffRole.actor, EditTarget.staff), isTrue);
      for (final target in except({EditTarget.staff})) {
        expect(
          canCreate(StaffRole.actor, target),
          isFalse,
          reason: 'creating structure is the director\'s: $target',
        );
      }
    });

    // The three questions diverge on the roster, which is what forced canCreate
    // into existence: add yes, change no, remove no.
    test('an actor adding is not an actor editing or deleting', () {
      expect(canCreate(StaffRole.actor, EditTarget.staff), isTrue);
      expect(canEdit(StaffRole.actor, EditTarget.staff), isFalse);
      expect(canDelete(StaffRole.actor, EditTarget.staff), isFalse);
    });

    test('a director creates everything', () {
      for (final target in EditTarget.values) {
        expect(
          canCreate(StaffRole.director, target),
          isTrue,
          reason: '$target',
        );
      }
    });

    // DESIGN-011 adds director and instructor as staff roles; until the roster
    // holds anything but markører, an instructor has nothing to join.
    test('an instructor creates nothing yet', () {
      for (final target in EditTarget.values) {
        expect(
          canCreate(StaffRole.instructor, target),
          isFalse,
          reason: '$target',
        );
      }
    });

    test('a running exercise blocks creating things inside it', () {
      ExerciseService().start(_exercise());
      expect(
        canCreate(
          StaffRole.director,
          EditTarget.station,
          exerciseUuid: _exerciseUuid,
        ),
        isFalse,
      );
      // The roster is not part of the running exercise's structure, so adding a
      // stand-in mid-drill stays possible — the case this exists for.
      expect(
        canCreate(
          StaffRole.actor,
          EditTarget.staff,
          exerciseUuid: _exerciseUuid,
        ),
        isTrue,
      );
    });
  });

  // Removing content is a command act, so canDelete does NOT inherit canEdit's
  // two delegations. An actor authoring a markør's script is not thereby
  // authorised to delete the markør — nor the persons and locations it
  // references, which an actor overrides rather than removes.
  group('canDelete', () {
    test('only a director deletes, for every target', () {
      for (final target in EditTarget.values) {
        expect(
          canDelete(StaffRole.director, target),
          isTrue,
          reason: '$target',
        );
        expect(
          canDelete(StaffRole.actor, target),
          isFalse,
          reason: 'an actor writes scripts, does not delete: $target',
        );
        expect(
          canDelete(StaffRole.instructor, target),
          isFalse,
          reason: 'an instructor adjusts teams, does not remove them: $target',
        );
      }
    });

    // The divergence that makes canDelete a separate function rather than an
    // alias: an actor may *edit* a roleplay, and must still not delete it.
    test('diverges from canEdit exactly where the delegations were', () {
      expect(canEdit(StaffRole.actor, EditTarget.rolePlay), isTrue);
      expect(canDelete(StaffRole.actor, EditTarget.rolePlay), isFalse);

      expect(canEdit(StaffRole.instructor, EditTarget.team), isTrue);
      expect(canDelete(StaffRole.instructor, EditTarget.team), isFalse);
    });

    group('while an exercise runs', () {
      setUp(() => ExerciseService().start(_exercise()));

      test('nobody deletes anything belonging to it', () {
        for (final role in StaffRole.values) {
          for (final target in EditTarget.values) {
            expect(
              canDelete(role, target, exerciseUuid: _exerciseUuid),
              isFalse,
              reason: '$role / $target',
            );
          }
        }
      });

      // The live lock has no roleplay exemption, unlike canEdit's. Adjusting a
      // markør's behaviour mid-scenario is the point; deleting one the running
      // exercise still references is data loss with no undo.
      test('not even a roleplay, which stays editable', () {
        expect(
          canEdit(
            StaffRole.director,
            EditTarget.rolePlay,
            exerciseUuid: _exerciseUuid,
          ),
          isTrue,
        );
        expect(
          canDelete(
            StaffRole.director,
            EditTarget.rolePlay,
            exerciseUuid: _exerciseUuid,
          ),
          isFalse,
        );
      });

      test('a different exercise is unaffected', () {
        expect(
          canDelete(
            StaffRole.director,
            EditTarget.station,
            exerciseUuid: 'some-other-exercise',
          ),
          isTrue,
        );
      });
    });
  });

  // `other` is the escape hatch for a support role the enum does not name, and it
  // is selectable as this device's own role. It is deliberately named nowhere in the
  // permission functions, so it gets nothing by falling through — asserted here so
  // that stays a decision rather than an accident nobody noticed.
  group('the other role', () {
    test('may not edit, create or delete anything', () {
      for (final target in EditTarget.values) {
        expect(canEdit(StaffRole.other, target), isFalse, reason: '$target');
        expect(canCreate(StaffRole.other, target), isFalse, reason: '$target');
        expect(canDelete(StaffRole.other, target), isFalse, reason: '$target');
      }
    });

    // Not even the roster, which an actor may add to: joining the staff list is
    // still an assertion about the exercise, and a role defined by not being any of
    // the others has no claim to make it.
    test('may not add to the roster, unlike an actor', () {
      expect(canCreate(StaffRole.actor, EditTarget.staff), isTrue);
      expect(canCreate(StaffRole.other, EditTarget.staff), isFalse);
    });
  });
}

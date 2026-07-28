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
          canEdit(AppUserRole.director, target, exerciseUuid: _exerciseUuid),
          isTrue,
          reason: '$target',
        );
      }
    });

    test('an instructor edits teams, and only teams', () {
      expect(canEdit(AppUserRole.instructor, EditTarget.team), isTrue);
      for (final target in except({EditTarget.team})) {
        expect(
          canEdit(AppUserRole.instructor, target),
          isFalse,
          reason: '$target',
        );
      }
    });

    test('an actor edits roleplays, and only roleplays', () {
      expect(canEdit(AppUserRole.actor, EditTarget.rolePlay), isTrue);
      for (final target in except({EditTarget.rolePlay})) {
        expect(canEdit(AppUserRole.actor, target), isFalse, reason: '$target');
      }
    });
  });

  group('while that exercise is running', () {
    setUp(() => ExerciseService().start(_exercise()));

    test('its structure is frozen, for the director too', () {
      for (final target in except({EditTarget.rolePlay})) {
        expect(
          canEdit(AppUserRole.director, target, exerciseUuid: _exerciseUuid),
          isFalse,
          reason: '$target must not be edited under a running drill',
        );
      }
    });

    // The deliberate exception: a marker's behaviour is what gets adjusted
    // mid-scenario, so it is the one thing the live lock lets through.
    test('roleplays stay editable', () {
      for (final role in [AppUserRole.director, AppUserRole.actor]) {
        expect(
          canEdit(role, EditTarget.rolePlay, exerciseUuid: _exerciseUuid),
          isTrue,
          reason: '$role',
        );
      }
      // Still not for an instructor: the live lock is not a promotion.
      expect(
        canEdit(
          AppUserRole.instructor,
          EditTarget.rolePlay,
          exerciseUuid: _exerciseUuid,
        ),
        isFalse,
      );
    });

    test('a different exercise is unaffected', () {
      expect(
        canEdit(
          AppUserRole.director,
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
      expect(canEdit(AppUserRole.director, EditTarget.plan), isTrue);
      expect(canEdit(AppUserRole.director, EditTarget.actor), isTrue);
    });
  });
}

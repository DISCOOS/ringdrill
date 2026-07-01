import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/pwa_update_policy.dart';

void main() {
  group('computeCanAutoApply', () {
    test('true only when waiting at startup AND online', () {
      expect(computeCanAutoApply(atStartup: true, isOnline: true), isTrue);
    });

    test('false when offline, even at startup', () {
      // Activating a new SW offline could strand the app without assets.
      expect(computeCanAutoApply(atStartup: true, isOnline: false), isFalse);
    });

    test('false when not at startup (mid-session), even online', () {
      // Mid-session updates must not reload out from under the user.
      expect(computeCanAutoApply(atStartup: false, isOnline: true), isFalse);
    });

    test('false when offline and mid-session', () {
      expect(computeCanAutoApply(atStartup: false, isOnline: false), isFalse);
    });
  });

  group('decidePwaUpdateAction', () {
    test('auto-applies when safe and no drill is running', () {
      expect(
        decidePwaUpdateAction(canAutoApply: true, isExerciseRunning: false),
        PwaUpdateAction.autoApply,
      );
    });

    test('prompts while a drill is running, even when otherwise safe', () {
      // A reload would interrupt the live exercise.
      expect(
        decidePwaUpdateAction(canAutoApply: true, isExerciseRunning: true),
        PwaUpdateAction.prompt,
      );
    });

    test('prompts when auto-apply is not safe (e.g. offline or mid-session)',
        () {
      expect(
        decidePwaUpdateAction(canAutoApply: false, isExerciseRunning: false),
        PwaUpdateAction.prompt,
      );
    });

    test('prompts when neither safe nor idle', () {
      expect(
        decidePwaUpdateAction(canAutoApply: false, isExerciseRunning: true),
        PwaUpdateAction.prompt,
      );
    });
  });
}

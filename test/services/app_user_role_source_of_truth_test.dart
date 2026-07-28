import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The notifier leads; the store only seeds it.
///
/// Reported as "the brief viewer does not pick up the role just selected". The
/// cause was two sources of truth: [setAppUserRole] publishes immediately but
/// persists asynchronously, so a surface that re-read the *store* on open could
/// serve the previous role. Anything needing the role once now reads
/// [currentAppUserRole].
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Prefs.reset();
    Prefs.bind(await SharedPreferences.getInstance());
    appUserRole.value = AppUserRole.director;
    addTearDown(Prefs.reset);
  });

  test('a role read straight after a change is the new one', () {
    // Deliberately not awaited: this is the window the bug lived in — a surface
    // opening on the same frame as the pick.
    final pending = setAppUserRole(AppUserRole.actor);

    expect(
      currentAppUserRole(),
      AppUserRole.actor,
      reason: 'the notifier is published before the write is awaited',
    );
    return pending;
  });

  test('and it survives the write completing', () async {
    await setAppUserRole(AppUserRole.instructor);

    expect(currentAppUserRole(), AppUserRole.instructor);
    expect(
      Prefs.getString(AppConfig.keyAppUserRole),
      AppUserRole.instructor.name,
      reason: 'the store catches up',
    );
  });

  test('the store seeds the notifier, it does not override it', () {
    // A stale stored value must not win over one already published — which is
    // what made a screen opened after a pick reset the role.
    appUserRole.value = AppUserRole.actor;

    expect(readAppUserRoleNow(), isNot(AppUserRole.actor));
    expect(
      currentAppUserRole(),
      AppUserRole.actor,
      reason: 'reading the store must not be how a surface learns the role',
    );
  });

  test('unbound prefs read as no stored role', () {
    Prefs.reset();

    expect(readAppUserRoleNow(), isNull);
  });
}

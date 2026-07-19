import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/views/widgets/roleplay_scope.dart';

/// [RoleplayScope.forRoleplay] is the single source of the `{{roleplay.*}}`
/// field set — it carries the raw values (mirroring StationScope), and
/// resolveScopedField builds the facet map from them. The viewer seeds it from
/// the saved roleplay, the editor from a live working copy.
const _rolePlay = RolePlay(
  uuid: 'rp-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: 'Anna',
  age: 34,
  signalement: 'Gul jakke',
  position: LatLng(59.91, 10.75),
);

void main() {
  testWidgets('forRoleplay exposes the roleplay fields to descendants', (
    tester,
  ) async {
    RoleplayScope? scope;
    await tester.pumpWidget(
      RoleplayScope.forRoleplay(
        _rolePlay,
        child: Builder(
          builder: (context) {
            scope = RoleplayScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(scope, isNotNull);
    expect(scope!.name, 'Anna');
    expect(scope!.age, 34);
    expect(scope!.signalement, 'Gul jakke');
    // Pre-formatted UTM (the copy-chip wrapping is applied in
    // resolveScopedField, like StationScope).
    expect(scope!.positionUtm, formatUtm(const LatLng(59.91, 10.75)));
  });

  testWidgets('a roleplay with no position leaves positionUtm null', (
    tester,
  ) async {
    RoleplayScope? scope;
    await tester.pumpWidget(
      RoleplayScope.forRoleplay(
        const RolePlay(uuid: 'rp-2', index: 0, exerciseUuid: 'ex-1', name: 'B'),
        child: Builder(
          builder: (context) {
            scope = RoleplayScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(scope!.positionUtm, isNull);
    expect(scope!.signalement, isNull);
  });
}

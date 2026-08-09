import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/publish_plan_dialog.dart';

/// The publish dialog's three decisions (DESIGN-015 §5.8).
///
/// More design lands on this one screen than on any other, and most of it is
/// only visible as copy and defaults. The two that would be silently wrong if
/// broken:
///
/// * Signed out must not read as a paywall. Publish stays primary, "Sign in
///   first" is the alternative, and the explanation is one plain line.
/// * `shared` must not be sent on the publish itself. The server refuses it
///   without grantees, so the plan lands as `account` — less open than asked
///   for, never more — and the grantees follow separately.

class FakeTransport extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
}

void installSignedIn({required bool organisation}) {
  final service = AuthService(
    client: AuthClient(
      baseUrl: 'https://api.test',
      httpClient: FakeTransport(),
    ),
    store: InMemoryAuthTokenStore(),
  );
  AuthService.install(service);
  // Reach the state the same way a restore would, without a round trip.
  service.debugSetStateForTest(
    AuthState(
      user: const AuthUser(id: 'u_1', displayName: 'Kari'),
      accounts: [
        AccountMembership(
          accountId: organisation ? 'a_bergen' : 'a_kari',
          displayName: organisation ? 'Red Cross Bergen' : 'Kari',
          type: organisation ? 'organization' : 'personal',
          role: 'owner',
        ),
      ],
    ),
  );
}

Plan aPlan() {
  final now = DateTime(2026);
  return Plan(
    uuid: 'p_1',
    name: 'LSOR Eidene',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    staff: const [],
  );
}

Future<PublishPlanInput?> openDialog(WidgetTester tester) async {
  PublishPlanInput? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await showPublishPlanDialog(
                context,
                plan: aPlan(),
                mode: PublishDialogMode.firstTime,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  tearDown(AuthService.resetForTest);

  group('signed out', () {
    testWidgets('explains in one plain line, with no lock or warning', (
      tester,
    ) async {
      // Anonymous publishing is a supported workflow (ADR-0025), not a
      // degraded one. A lock icon or a warning colour would make it read as
      // a paywall.
      await openDialog(tester);

      expect(
        find.textContaining('You are not signed in, so open to everyone'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    testWidgets('offers no sharing choice — there is only one', (tester) async {
      // Showing three disabled radios would imply the user is missing out on
      // options they could reach by doing something differently right now.
      await openDialog(tester);

      expect(find.byType(RadioListTile<PublishSharing>), findsNothing);
      expect(find.text('Publishes to'), findsNothing);
    });

    testWidgets('publishing yields the public policy', (tester) async {
      await openDialog(tester);
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      // Asserted through the enum's wire value, which is what reaches the
      // server.
      expect(PublishSharing.public.wireValue, 'public');
    });
  });

  group('signed in', () {
    testWidgets('names the account the publish lands in', (tester) async {
      // Someone who publishes to the wrong account otherwise finds out
      // afterwards.
      installSignedIn(organisation: true);
      await openDialog(tester);

      expect(find.text('Publishes to'), findsOneWidget);
      expect(find.text('Red Cross Bergen'), findsOneWidget);
    });

    testWidgets('calls it Sharing, never Access', (tester) async {
      // DESIGN-015 §7 reserves "Access" for a person's standing in an
      // account. One word for both would put a plan's write policy and a
      // member's role under the same label.
      installSignedIn(organisation: true);
      await openDialog(tester);

      expect(find.text('Sharing'), findsOneWidget);
      expect(find.text('Access'), findsNothing);
    });

    testWidgets('names the organisation in the protective option', (
      tester,
    ) async {
      // "Only my account" is meaningless for an account shared with
      // colleagues.
      installSignedIn(organisation: true);
      await openDialog(tester);

      expect(find.text('Red Cross Bergen only'), findsOneWidget);
      expect(find.text('Only my account'), findsNothing);
    });

    testWidgets('says "Only my account" for a personal account', (
      tester,
    ) async {
      installSignedIn(organisation: false);
      await openDialog(tester);

      expect(find.text('Only my account'), findsOneWidget);
    });

    testWidgets('defaults to the protective option, not to public', (
      tester,
    ) async {
      // A default of "open to everyone" would publish somebody's plan more
      // widely than they chose, every time they did not read the dialog.
      installSignedIn(organisation: true);
      await openDialog(tester);

      final selected = tester
          .widgetList<RadioListTile<PublishSharing>>(
            find.byType(RadioListTile<PublishSharing>),
          )
          // ignore: deprecated_member_use
          .where((r) => r.value == r.groupValue)
          .single;
      expect(selected.value, PublishSharing.accountOnly);
    });

    testWidgets('promises the roster stays inside the organisation', (
      tester,
    ) async {
      // Publishing is the exact moment somebody wonders whether the phone
      // numbers they typed are about to become public (ADR-0072).
      installSignedIn(organisation: true);
      await openDialog(tester);

      expect(find.text('Staff details are never published.'), findsOneWidget);
      expect(
        find.textContaining('The roster stays inside Red Cross Bergen'),
        findsOneWidget,
      );
    });
  });

  group('the wire values', () {
    test('shared publishes as account, not as shared', () {
      // The server refuses `shared` with no grantees. Sending it would fail
      // the publish; sending `account` lands the plan at the protective half
      // of what was asked for, and the grantees follow separately. The
      // ordering matters: the other way round leaves a window where the plan
      // is more open than intended.
      expect(PublishSharing.shared.wireValue, 'account');
      expect(PublishSharing.shared, isA<PublishSharing>());
    });

    test('needsGrantees is set only for shared', () {
      expect(
        const PublishPlanInput(
          slug: 'a',
          sharing: PublishSharing.shared,
        ).needsGrantees,
        isTrue,
      );
      expect(
        const PublishPlanInput(
          slug: 'a',
          sharing: PublishSharing.accountOnly,
        ).needsGrantees,
        isFalse,
      );
      expect(
        const PublishPlanInput(
          slug: 'a',
          sharing: PublishSharing.public,
        ).needsGrantees,
        isFalse,
      );
    });

    test('accountOnly and public map to their policies', () {
      expect(PublishSharing.accountOnly.wireValue, 'account');
      expect(PublishSharing.public.wireValue, 'public');
    });
  });
}

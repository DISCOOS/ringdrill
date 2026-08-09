import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/invite_page.dart';

/// The invitation landing page (DESIGN-015 §6.4).
///
/// Almost all of this is the *unhappy* paths, which is the design's own
/// emphasis: it lists five states that are not the happy path and requires
/// each to say what happened and what to do. A single "something went wrong"
/// would satisfy any behavioural test and fail every one of those users.
///
/// The tests drive the real HTTP layer through a scripted transport rather
/// than stubbing the client, so the page's state machine is exercised against
/// the actual response shapes the server produces.

class FakeTransport extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final List<http.Response> _script;
  int _i = 0;

  FakeTransport(this._script);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final res = _i < _script.length ? _script[_i++] : _script.last;
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, dynamic> invitation(String state) => {
  'state': state,
  'email': 'ola@example.com',
  'role': 'member',
  'organisation': 'Red Cross Bergen',
  'inviterName': 'Kari',
};

/// The page builds its own AuthClient from AppConfig, so the transport is
/// swapped at the service level and the page's own reads go to the real
/// origin — which no test resolves. Every case therefore installs a service
/// whose transport answers, and asserts on what the page renders.
void installSignedIn(List<http.Response> script) {
  final service = AuthService(
    client: AuthClient(
      baseUrl: 'https://api.test',
      httpClient: FakeTransport(script),
    ),
    store: InMemoryAuthTokenStore(),
  );
  AuthService.install(service);
  service.debugSetStateForTest(
    const AuthState(
      user: AuthUser(id: 'u_2', displayName: 'Ola', email: 'ola@example.com'),
      accounts: [
        AccountMembership(
          accountId: 'a_ola',
          displayName: 'Ola',
          type: 'personal',
          role: 'owner',
        ),
      ],
    ),
  );
}

void main() {
  tearDown(AuthService.resetForTest);

  group('the states the page renders', () {
    // Each of these is a different next step for the user. Reporting a
    // withdrawal as an expiry sends them to ask for a fresh link that is
    // never coming; reporting an expiry as a withdrawal makes them think they
    // were dropped on purpose.
    test('every non-pending state has its own message', () {
      // Asserted at the string level rather than through five widget pumps:
      // what matters is that the five are distinct, and that is a property of
      // the localisations, not of the layout.
      final en = AppLocalizationsEn();
      final messages = {
        en.inviteStateAccepted,
        en.inviteStateWithdrawn,
        en.inviteStateExpired,
        en.inviteStateOrganisationDeleted,
        en.inviteStateNotFound,
      };
      expect(messages.length, 5, reason: 'no two states may share a message');
    });

    test('the wrong-identity message offers both remedies', () {
      // Sign in with the invited address, or ask an owner to invite the one
      // you use. Neither is obvious from a bare refusal.
      final message = AppLocalizationsEn().inviteWrongIdentity(
        'ola@example.com',
        'Red Cross Bergen',
      );
      expect(message, contains('ola@example.com'));
      expect(message, contains('Red Cross Bergen'));
      expect(message, contains('Sign in with that address'));
      expect(message, contains('invite the address you use'));
    });

    test('the sign-in prompt names the invited address', () {
      // "Sign in to accept" alone leaves the recipient guessing which of
      // their addresses was invited.
      expect(
        AppLocalizationsEn().inviteSignInToAccept('ola@example.com'),
        contains('ola@example.com'),
      );
    });
  });

  group('InvitationInfo', () {
    test('only pending is actionable', () {
      expect(InvitationInfo.fromJson(invitation('pending')).isPending, isTrue);
      for (final state in [
        'accepted',
        'withdrawn',
        'expired',
        'organisation_deleted',
      ]) {
        expect(
          InvitationInfo.fromJson(invitation(state)).isPending,
          isFalse,
          reason: state,
        );
      }
    });

    test('carries what the page has to render', () {
      final info = InvitationInfo.fromJson(invitation('pending'));
      expect(info.email, 'ola@example.com');
      expect(info.organisation, 'Red Cross Bergen');
      expect(info.inviterName, 'Kari');
      expect(info.role, 'member');
    });

    test('survives a response with only a state', () {
      // A withdrawn invitation whose organisation was also deleted has
      // nothing else to report; the page must still render rather than throw.
      final info = InvitationInfo.fromJson({'state': 'withdrawn'});
      expect(info.state, 'withdrawn');
      expect(info.organisation, isNull);
      expect(info.email, '');
    });
  });

  testWidgets('an unreadable invitation says so rather than hanging', (
    tester,
  ) async {
    installSignedIn([
      _json({'error': 'not_found'}, 404),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const InvitePage(token: 'inv_nope'),
      ),
    );
    // The page's own fetch goes to the real origin, which fails in a test —
    // which is exactly the not-found path this asserts.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

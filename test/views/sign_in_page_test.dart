import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/sign_in_page.dart';

/// The sign-in screen (DESIGN-015 §3.3, §5.1).
///
/// Most of these assert *copy*, which is unusual for a widget test and is the
/// point here: the design's two hard rules about this screen are both things
/// it has to say, not things it has to do. Dropping either sentence would be
/// invisible to any behavioural test and would break the design.

class FakeTransport extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final List<http.Response> _script;
  final List<AuthProvider> providers;
  int _i = 0;

  FakeTransport(this._script, {this.providers = const []});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);

    // Discovery is answered by path rather than from the script: the screen
    // asks for it on open, and threading it through every email test's script
    // would make each one carry a response it does not care about.
    if (request.url.path.endsWith('/auth/providers')) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'providers': [
                for (final p in providers)
                  {
                    'id': p.id,
                    'label': p.label,
                    'authorizeUrl': p.authorizeUrl,
                  },
              ],
            }),
          ),
        ),
        200,
      );
    }

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

final _challenge = _json({'challengeId': 'c_1', 'expiresInMs': 600000});

final _session = _json({
  'accessToken': 'at_1',
  'refreshToken': 'rt_1',
  'sessionId': 's_1',
  'expiresIn': 3600,
  'user': {'id': 'u_1', 'displayName': 'Kari', 'email': 'kari@example.com'},
  'accounts': ['a_kari'],
  'roles': {'a_kari': 'owner'},
});

final _me = _json({
  'user': {'id': 'u_1', 'displayName': 'Kari', 'email': 'kari@example.com'},
  'accounts': [
    {
      'id': 'a_kari',
      'displayName': 'Kari',
      'type': 'personal',
      'role': 'owner',
    },
  ],
  'activeAccount': 'a_kari',
  'devices': [],
});

FakeTransport install(
  List<http.Response> script, {
  List<AuthProvider> providers = const [],
  WebAuthLauncher? launcher,
}) {
  final fake = FakeTransport(script, providers: providers);
  AuthService.install(
    AuthService(
      client: AuthClient(baseUrl: 'https://api.test', httpClient: fake),
      store: InMemoryAuthTokenStore(),
      launcher: launcher,
    ),
  );
  return fake;
}

Future<void> pumpSignIn(WidgetTester tester, {VoidCallback? onSignedIn}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: SignInPage(onSignedIn: onSignedIn),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(AuthService.resetForTest);

  group('what the screen has to say', () {
    testWidgets('discloses that an account may be created', (tester) async {
      // Signing in *is* getting an account (ADR-0024 creates it), so this is
      // the only place the user is told. A thing created silently on your
      // behalf is worse than a thing you were told about.
      //
      // Conditional, and that is the assertion worth having: this screen and
      // this magic link are also how a returning user signs back in, so
      // stating flatly that an account is being created is wrong for
      // everybody after their first time. The screen cannot tell which they
      // are — start-email answers identically for a known and an unknown
      // address on purpose, so that it cannot be used to find out who has an
      // account — so the sentence has to be true either way.
      install([_challenge]);
      await pumpSignIn(tester);

      expect(
        find.text(
          'If you do not have an account yet, one is created for you. '
          'It owns the plans you publish.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says an account is optional', (tester) async {
      // §5.1: no account is the normal state. Somebody who opened this by
      // accident must be able to leave believing nothing is wrong.
      install([_challenge]);
      await pumpSignIn(tester);

      expect(find.textContaining('You do not need an account'), findsOneWidget);
    });

    testWidgets('offers sign-in without a separate create-account choice', (
      tester,
    ) async {
      // Presenting them as two decisions is the mistake §5.1 rules out.
      install([_challenge]);
      await pumpSignIn(tester);

      expect(find.textContaining('Create an account'), findsNothing);
      expect(find.textContaining('Sign up'), findsNothing);
    });
  });

  group('the email flow', () {
    testWidgets('rejects a non-address before asking the server', (
      tester,
    ) async {
      final fake = install([_challenge]);
      await pumpSignIn(tester);

      await tester.enterText(find.byType(TextField), 'not-an-address');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Enter an email address'), findsOneWidget);
      // Discovery fires when the screen opens, so the assertion is about the
      // *sign-in* round trip specifically.
      expect(
        fake.requests.where((r) => r.url.path.endsWith('/auth/start-email')),
        isEmpty,
        reason: 'no round trip for a typo',
      );
    });

    testWidgets('moves to the code step and names the address', (tester) async {
      install([_challenge]);
      await pumpSignIn(tester);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Both redemptions are the same challenge, so the copy must not imply
      // that using the code forfeits the link.
      // Asserted as the whole sentence: the address also sits in the email
      // field above, so a textContaining on the address alone matches twice.
      expect(
        find.text(
          'We sent a link and a six-digit code to kari@example.com. '
          'Either one works.',
        ),
        findsOneWidget,
      );
      expect(find.text('Six-digit code'), findsOneWidget);
    });

    testWidgets('mock mode is announced, and never fills the code in', (
      tester,
    ) async {
      // AUTH_MODE=mock returns the code in the response so the flow can be
      // completed with no mail provider (ADR-0073). The screen used to paste
      // it straight into the field, which skipped the one step carrying the
      // whole security property — proving you can read the address's mail —
      // and made a correct system look like one where a typed address is
      // enough.
      install([
        _json({'challengeId': 'c_1', 'expiresInMs': 600000, 'code': '9FAQLX'}),
      ]);
      await pumpSignIn(tester);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Development mode'), findsOneWidget);
      expect(
        find.text(
          'No mail was sent. The sign-in code is in the server console. '
          'In production it only ever arrives by email.',
        ),
        findsOneWidget,
      );

      // The banner says the mode, not the code: handing it over on screen
      // removes the same step the autofill used to remove.
      expect(find.text('9FAQLX'), findsNothing);
      final code = tester.widget<TextField>(find.byType(TextField).last);
      expect(code.controller!.text, isEmpty);
    });

    testWidgets('live mode shows no development banner', (tester) async {
      // The banner can only render when the *server* put a code in the
      // response. Live never does, and ADR-0073's load-time guard stops a
      // production deploy from being able to.
      install([_challenge]);
      await pumpSignIn(tester);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Development mode'), findsNothing);
    });

    testWidgets('signs in and calls back', (tester) async {
      install([_challenge, _session, _me]);
      var resumed = false;
      await pumpSignIn(tester, onSignedIn: () => resumed = true);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(AuthService.instance.isSignedIn, isTrue);
      // The callback is what lets a caller resume an interrupted flow —
      // accepting an invitation, say — instead of dropping the user
      // somewhere with no explanation.
      expect(resumed, isTrue);
    });

    testWidgets('asks for names on a plain sign-in', (tester) async {
      // Neither name can be derived — a provider gives a full name or nothing,
      // the code flow gives only an address — so the app has to ask once.
      install([_challenge, _session, _me]);
      await pumpSignIn(tester);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Your name'), findsOneWidget);
      expect(find.text('Nickname'), findsOneWidget);
    });

    testWidgets('does not ask when a flow is waiting to resume', (
      tester,
    ) async {
      // onSignedIn means this sign-in interrupted something the person was
      // already doing — accepting an invitation, publishing a plan. Asking for
      // names in front of it stacks a second interruption on the first, for a
      // prompt the account page carries anyway.
      install([_challenge, _session, _me]);
      var resumed = false;
      await pumpSignIn(tester, onSignedIn: () => resumed = true);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Your name'), findsNothing);
      expect(resumed, isTrue);
    });

    testWidgets('a wrong code is retryable, not a dead end', (tester) async {
      install([
        _challenge,
        _json({'error': 'bad_code'}, 401),
      ]);
      await pumpSignIn(tester);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '000000');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // Names the actual fault. "That did not work" — what this used to say,
      // in both languages — could equally have meant the network, the server
      // or the address, so it told the reader nothing they could act on.
      expect(
        find.text('That code is not correct. Check the email and try again.'),
        findsOneWidget,
      );
      // And carries an icon, so the message does not depend on colour alone.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // Still on the code step with the field live — a failure that sent the
      // user back to the start would make them request a second code and
      // invalidate the one they already have.
      expect(find.text('Six-digit code'), findsOneWidget);
      expect(AuthService.instance.isSignedIn, isFalse);
    });

    testWidgets('an expired code says so rather than "wrong code"', (
      tester,
    ) async {
      // Different remedy: ask for a new one, not retype this one.
      install([
        _challenge,
        _json({'error': 'expired', 'state': 'expired'}, 400),
      ]);
      await pumpSignIn(tester);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.textContaining('expired'), findsOneWidget);
    });

    testWidgets('can ask for a new code without changing address', (
      tester,
    ) async {
      // A ten-minute expiry with no resend made "use another email" the only
      // way forward, which reads as a different decision entirely.
      final fake = install([
        _challenge,
        _json({'challengeId': 'c_2', 'expiresInMs': 600000}),
      ]);
      await pumpSignIn(tester);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'OLDCOD');

      await tester.tap(find.text('Send a new code'));
      await tester.pumpAndSettle();

      // Same address, asked again.
      final starts = fake.requests
          .where((r) => r.url.path.endsWith('/auth/start-email'))
          .toList();
      assert(starts.length == 2);
      expect(
        find.text(
          'A new code is on its way. The previous one no longer works.',
        ),
        findsOneWidget,
      );

      // The old code is dead once a new challenge exists, so leaving it in the
      // field would invite typing something the server has forgotten.
      final code = tester.widget<TextField>(find.byType(TextField).last);
      expect(code.controller!.text, isEmpty);
    });

    testWidgets('a third request says the mail may have stopped', (
      tester,
    ) async {
      // ADR-0079 caps how much mail one address gets and keeps a refusal
      // silent, so the server answers "sent" either way. Somebody who asked
      // three times and has nothing in their inbox is exactly who that silence
      // strands — and this device already knows it asked three times, which is
      // our own history rather than an answer about the address.
      final fake = install([
        _challenge,
        _json({'challengeId': 'c_2', 'expiresInMs': 600000}),
        _json({'challengeId': 'c_3', 'expiresInMs': 600000}),
      ]);
      await pumpSignIn(tester);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      const hint =
          'Several codes have been sent to this address. Check your spam '
          'folder and use the code from the newest email — asking again may '
          'not send another.';
      expect(find.text(hint), findsNothing, reason: 'not on the first send');

      await tester.tap(find.text('Send a new code'));
      await tester.pumpAndSettle();
      expect(find.text(hint), findsNothing, reason: 'twice is still normal');

      await tester.tap(find.text('Send a new code'));
      await tester.pumpAndSettle();
      expect(find.text(hint), findsOneWidget);

      // It replaces the resend confirmation rather than stacking with it: two
      // notes about the same send is one too many.
      expect(
        find.text(
          'A new code is on its way. The previous one no longer works.',
        ),
        findsNothing,
      );
      assert(
        fake.requests
                .where((r) => r.url.path.endsWith('/auth/start-email'))
                .length ==
            3,
      );
    });

    testWidgets('can go back to a different address', (tester) async {
      // A typo in the address is otherwise unrecoverable without leaving the
      // screen.
      install([_challenge]);
      await pumpSignIn(tester);

      await tester.enterText(find.byType(TextField), 'kari@example.com');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use a different address'));
      await tester.pumpAndSettle();

      expect(find.text('Six-digit code'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('provider sign-in', () {
    const google = AuthProvider(
      id: 'google',
      label: 'Google',
      authorizeUrl: 'https://accounts.google.com/o/oauth2/v2/auth?state=s1',
    );

    testWidgets('a discovered provider gets a button', (tester) async {
      install([_challenge], providers: [google]);
      await pumpSignIn(tester);

      expect(find.text('Continue with Google'), findsOneWidget);
      // Email stays available, and is not labelled as a fallback.
      expect(find.text('or continue with email'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
    });

    testWidgets(
      'no configured provider renders nothing, not an empty section',
      (tester) async {
        install([_challenge]);
        await pumpSignIn(tester);

        expect(find.textContaining('Continue with'), findsNothing);
        expect(find.text('or continue with email'), findsNothing);
      },
    );

    testWidgets('tapping opens the server-built URL and signs in', (
      tester,
    ) async {
      // The app holds no client id — it opens what discovery handed it.
      String? opened;
      install(
        [_session, _me],
        providers: [google],
        launcher: ({required url, required callbackUrlScheme}) async {
          opened = url;
          return 'ringdrill://auth/callback?handoff=h1';
        },
      );
      await pumpSignIn(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(opened, google.authorizeUrl);
      expect(AuthService.instance.isSignedIn, isTrue);
    });

    testWidgets('cancelling is silent, not an error', (tester) async {
      // Closing the browser is an ordinary thing to do. An error message would
      // tell somebody they failed at deciding not to.
      install(
        [_challenge],
        providers: [google],
        launcher: ({required url, required callbackUrlScheme}) async =>
            'ringdrill://auth/callback?error=access_denied',
      );
      await pumpSignIn(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.textContaining('did not complete'), findsNothing);
      expect(AuthService.instance.isSignedIn, isFalse);
    });

    testWidgets('a real failure says so and leaves email usable', (
      tester,
    ) async {
      install(
        [_challenge],
        providers: [google],
        launcher: ({required url, required callbackUrlScheme}) async =>
            'ringdrill://auth/callback?error=code_exchange_failed',
      );
      await pumpSignIn(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.textContaining('did not complete'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
    });

    testWidgets('a discovery failure does not take the email path down', (
      tester,
    ) async {
      // Providers are an addition to sign-in, not a precondition for it.
      AuthService.install(
        AuthService(
          client: AuthClient(
            baseUrl: 'https://api.test',
            httpClient: FakeTransport([http.Response('boom', 500)]),
          ),
          store: InMemoryAuthTokenStore(),
        ),
      );
      await pumpSignIn(tester);

      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });
}

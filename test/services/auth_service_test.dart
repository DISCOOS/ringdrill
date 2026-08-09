import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/services/auth_service.dart';

/// The session (ADR-0024, DESIGN-015 §3).
///
/// The refresh behaviour gets the most attention, because it is the part where
/// a plausible implementation is actively harmful: refresh tokens rotate and
/// replay is treated as a compromise signal, so a client that refreshes twice
/// concurrently, or retries a refused refresh, ends its own session.

/// A fake transport that records requests and replays scripted responses.
class _Fake extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final List<http.Response> _script;
  int _i = 0;

  /// Completes when [gate] is set, so two refreshes can be held in flight at
  /// once and the single-flight can actually be observed.
  Future<void>? gate;

  _Fake(this._script);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (gate != null) await gate;
    final res = _i < _script.length ? _script[_i++] : _script.last;
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }

  int get refreshCount =>
      requests.where((r) => r.url.path.endsWith('/auth/refresh')).length;
}

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, dynamic> _tokens({
  String access = 'at_1',
  String refresh = 'rt_1',
  int expiresIn = 3600,
}) => {
  'accessToken': access,
  'refreshToken': refresh,
  'sessionId': 's_1',
  'expiresIn': expiresIn,
  'user': {'id': 'u_1', 'displayName': 'Kari', 'email': 'kari@example.com'},
  'accounts': ['a_kari'],
  'roles': {'a_kari': 'owner'},
};

Map<String, dynamic> get _me => {
  'user': {'id': 'u_1', 'displayName': 'Kari', 'email': 'kari@example.com'},
  'accounts': [
    {
      'id': 'a_kari',
      'displayName': 'Kari',
      'type': 'personal',
      'role': 'owner',
    },
    {
      'id': 'a_bergen',
      'displayName': 'Red Cross Bergen',
      'type': 'organization',
      'role': 'member',
    },
  ],
  'activeAccount': 'a_kari',
  'devices': const [],
};

({AuthService service, _Fake fake, InMemoryAuthTokenStore store}) harness(
  List<http.Response> script, {
  DateTime Function()? now,
}) {
  final fake = _Fake(script);
  final store = InMemoryAuthTokenStore();
  return (
    service: AuthService(
      // Both sides share one clock. Deriving expiry from the wall clock and
      // checking it against an injected one is the bug this pins.
      client: AuthClient(
        baseUrl: 'https://api.test',
        httpClient: fake,
        now: now,
      ),
      store: store,
      now: now,
    ),
    fake: fake,
    store: store,
  );
}

void main() {
  group('signing in', () {
    test('adopts the session and hydrates the account names', () async {
      // callback returns account *ids*; only /me can name them, so a sign-in
      // that skipped the hydrate would render a list of opaque ids.
      final h = harness([_json(_tokens()), _json(_me)]);

      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

      expect(h.service.isSignedIn, isTrue);
      expect(h.service.state.user!.displayName, 'Kari');
      expect(h.service.state.organisations.map((a) => a.displayName), [
        'Red Cross Bergen',
      ]);
    });

    test('persists the session so a restart does not re-prompt', () async {
      final h = harness([_json(_tokens()), _json(_me)]);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

      final stored =
          jsonDecode((await h.store.read())!) as Map<String, dynamic>;
      expect(stored['refreshToken'], 'rt_1');
      // An absolute instant, not the server's duration: a stored "3600
      // seconds" would look fresh for an hour after every launch.
      expect(DateTime.parse(stored['expiresAt'] as String).isUtc, isTrue);
    });

    test('the personal account is active by default', () async {
      // It is the one the user did not have to think about.
      final h = harness([_json(_tokens()), _json(_me)]);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

      expect(h.service.state.activeAccount!.accountId, 'a_kari');
      expect(h.service.state.activeAccount!.isOrganisation, isFalse);
    });
  });

  group('restore', () {
    test('a stored session comes back signed in', () async {
      final h = harness([_json(_me)]);
      await h.store.write(
        jsonEncode(
          AuthTokens.fromJson(
            _tokens(),
            now: DateTime.utc(2026, 1, 1),
          ).toJson(),
        ),
      );

      await h.service.restore();
      expect(h.service.isSignedIn, isTrue);
      expect(h.service.state.user!.id, 'u_1');
    });

    test('an unreadable session is discarded, not retried forever', () async {
      // A session that cannot be decoded cannot be used; keeping it would be a
      // permanent failure loop with no way out from the UI.
      final h = harness([_json(_me)]);
      await h.store.write('{not json');

      await h.service.restore();
      expect(h.service.isSignedIn, isFalse);
      expect(await h.store.read(), isNull);
    });

    test('restoring with no stored session is a no-op, not an error', () async {
      // No account is the normal state (DESIGN-015 §5.1) — startup must not
      // treat it as a failure.
      final h = harness([]);
      await h.service.restore();
      expect(h.service.isSignedIn, isFalse);
      expect(h.fake.requests, isEmpty);
    });
  });

  group('refresh', () {
    test('a valid token is reused rather than refreshed', () async {
      final h = harness([_json(_tokens()), _json(_me)]);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');
      final before = h.fake.refreshCount;

      expect(await h.service.accessToken(), 'at_1');
      expect(h.fake.refreshCount, before);
    });

    test('an expiring token refreshes before it expires in flight', () async {
      // Refreshing exactly at expiry means a request can leave with a token
      // that dies on the way.
      var now = DateTime.utc(2026, 1, 1);
      final h = harness([
        _json(_tokens(expiresIn: 3600)),
        _json(_me),
        _json(_tokens(access: 'at_2', refresh: 'rt_2')),
      ], now: () => now);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

      // Inside the margin, but not yet expired.
      now = now.add(const Duration(minutes: 56));
      expect(await h.service.accessToken(), 'at_2');
      expect(h.fake.refreshCount, 1);
    });

    test(
      'concurrent callers share one refresh — a second is a replay',
      () async {
        // This is the case that ends sessions. Rotation means the second
        // refresh presents an already-rotated token, and replay detection kills
        // the session — so the single-flight is correctness, not a nicety.
        var now = DateTime.utc(2026, 1, 1);
        final h = harness([
          _json(_tokens(expiresIn: 3600)),
          _json(_me),
          _json(_tokens(access: 'at_2', refresh: 'rt_2')),
        ], now: () => now);
        await h.service.completeSignIn(challengeId: 'c_1', code: '123456');
        now = now.add(const Duration(hours: 2));

        // Hold the transport open so all five calls are genuinely in flight.
        final gate = Completer<void>();
        h.fake.gate = gate.future;
        final all = Future.wait(
          List.generate(5, (_) => h.service.accessToken()),
        );
        gate.complete();

        expect(await all, everyElement('at_2'));
        expect(h.fake.refreshCount, 1, reason: 'five callers, one refresh');
      },
    );

    test('a refused refresh signs out instead of retrying', () async {
      // 401 is expiry or a detected replay. Both mean sign in again, and
      // retrying is how a revoked session becomes a hot loop.
      var now = DateTime.utc(2026, 1, 1);
      final h = harness([
        _json(_tokens(expiresIn: 3600)),
        _json(_me),
        _json({'error': 'replayed'}, 401),
      ], now: () => now);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');
      now = now.add(const Duration(hours: 2));

      expect(await h.service.accessToken(), isNull);
      expect(h.service.isSignedIn, isFalse);
      expect(await h.store.read(), isNull);
    });

    test('a network failure fails the request but keeps the session', () async {
      // Signing somebody out because their train went into a tunnel is a
      // worse answer than failing one request.
      var now = DateTime.utc(2026, 1, 1);
      final h = harness([
        _json(_tokens(expiresIn: 3600)),
        _json(_me),
        _json({'error': 'internal'}, 500),
      ], now: () => now);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');
      now = now.add(const Duration(hours: 2));

      expect(await h.service.accessToken(), isNull);
      expect(h.service.isSignedIn, isTrue, reason: 'a 500 is not a revocation');
    });
  });

  group('signing out', () {
    test(
      'clears the session locally even when the server call fails',
      () async {
        // The user asked to be signed out on this device; the network is not
        // entitled to a vote.
        final h = harness([
          _json(_tokens()),
          _json(_me),
          _json({'error': 'internal'}, 500),
        ]);
        await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

        await h.service.signOut();
        expect(h.service.isSignedIn, isFalse);
        expect(await h.store.read(), isNull);
        expect(await h.service.accessToken(), isNull);
      },
    );

    test('notifies listeners so the UI leaves the signed-in state', () async {
      final h = harness([_json(_tokens()), _json(_me)]);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

      var notified = 0;
      h.service.addListener(() => notified++);
      await h.service.signOut();
      expect(notified, greaterThan(0));
    });
  });

  group('devices and revocation', () {
    test('lists the devices /me reports, tombstones included', () async {
      // A session ended by replay detection arrives as a tombstone rather
      // than being absent — that is the whole point of keeping it.
      final h = harness([
        _json(_tokens()),
        _json(_me),
        _json({
          ..._me,
          'devices': [
            {
              'sessionId': 's_1',
              'deviceLabel': 'iPhone 15',
              'lastUsedAt': '2026-08-01T00:00:00.000Z',
            },
            {
              'sessionId': 's_2',
              'deviceLabel': 'Old laptop',
              'endedAt': '2026-08-02T00:00:00.000Z',
              'endedReason': 'replayed',
            },
          ],
        }),
      ]);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

      final devices = await h.service.devices();
      expect(devices.map((d) => d.sessionId), ['s_1', 's_2']);
      expect(devices.first.isEnded, isFalse);
      expect(devices.last.isEnded, isTrue);
      expect(devices.last.endedReason, 'replayed');
    });

    test('marks the current device by id, not by label', () async {
      // Two identical phones report the same label; only the id distinguishes
      // the one you are holding.
      final h = harness([_json(_tokens()), _json(_me)]);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

      expect(h.service.currentSessionId, 's_1');
      const a = AuthDevice(sessionId: 's_1', label: 'iPhone 15');
      const b = AuthDevice(sessionId: 's_2', label: 'iPhone 15');
      expect(a.isCurrent(h.service.currentSessionId), isTrue);
      expect(b.isCurrent(h.service.currentSessionId), isFalse);
    });

    test('revoking another device does not sign this one out', () async {
      final h = harness([_json(_tokens()), _json(_me), http.Response('', 204)]);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

      await h.service.revokeSession('s_other');

      expect(h.service.isSignedIn, isTrue);
      expect(h.fake.requests.last.url.path, endsWith('/auth/sessions/revoke'));
    });

    test('revoking the current device signs out instead', () async {
      // Otherwise the app keeps running on a session the server has just
      // destroyed, and every later request 401s with no explanation.
      final h = harness([_json(_tokens()), _json(_me), http.Response('', 204)]);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

      await h.service.revokeSession(h.service.currentSessionId!);

      expect(h.service.isSignedIn, isFalse);
      expect(await h.store.read(), isNull);
    });

    test('signing out proves ownership with the refresh token', () async {
      // The server refuses a bare session id now, and the access token may
      // already have expired — without this the session lives 60 more days.
      final h = harness([_json(_tokens()), _json(_me), http.Response('', 204)]);
      await h.service.completeSignIn(challengeId: 'c_1', code: '123456');

      await h.service.signOut();

      final body = jsonDecode((h.fake.requests.last as http.Request).body);
      expect(body['sessionId'], 's_1');
      expect(body['refreshToken'], 'rt_1');
    });
  });

  group('provider order per platform', () {
    const apple = AuthProvider(id: 'apple', label: 'Apple', authorizeUrl: 'a');
    const google = AuthProvider(
      id: 'google',
      label: 'Google',
      authorizeUrl: 'g',
    );
    const microsoft = AuthProvider(
      id: 'microsoft',
      label: 'Microsoft',
      authorizeUrl: 'm',
    );
    const serverOrder = [google, apple, microsoft];

    test('iOS puts Apple first — a requirement, not a preference', () {
      // Apple's guidelines say Sign in with Apple must be at least as
      // prominent as the alternatives. Last position is a rejection.
      expect(
        orderProvidersForPlatform(
          serverOrder,
          platform: TargetPlatform.iOS,
          isWeb: false,
        ).map((p) => p.id),
        ['apple', 'google', 'microsoft'],
      );
    });

    test('macOS follows iOS', () {
      expect(
        orderProvidersForPlatform(
          serverOrder,
          platform: TargetPlatform.macOS,
          isWeb: false,
        ).first.id,
        'apple',
      );
    });

    test('Android follows the design table', () {
      expect(
        orderProvidersForPlatform(
          serverOrder,
          platform: TargetPlatform.android,
          isWeb: false,
        ).map((p) => p.id),
        ['google', 'microsoft', 'apple'],
      );
    });

    test('Windows promotes Microsoft', () {
      expect(
        orderProvidersForPlatform(
          serverOrder,
          platform: TargetPlatform.windows,
          isWeb: false,
        ).map((p) => p.id),
        ['microsoft', 'google', 'apple'],
      );
    });

    test('web uses the web row whatever the host platform is', () {
      // defaultTargetPlatform reports iOS for Safari, so without the web check
      // first a browser on a Mac would be ordered as a native Apple client.
      expect(
        orderProvidersForPlatform(
          serverOrder,
          platform: TargetPlatform.iOS,
          isWeb: true,
        ).map((p) => p.id),
        ['google', 'microsoft', 'apple'],
      );
    });

    test('an unnamed provider lands at the end rather than vanishing', () {
      // ADR-0024 reserves Feide and Vipps. One added later must still appear.
      const feide = AuthProvider(
        id: 'feide',
        label: 'Feide',
        authorizeUrl: 'f',
      );
      expect(
        orderProvidersForPlatform(
          const [feide, google, apple],
          platform: TargetPlatform.iOS,
          isWeb: false,
        ).map((p) => p.id),
        ['apple', 'google', 'feide'],
      );
    });

    test('a missing provider is skipped, not left as a gap', () {
      // A deployment without Apple cannot promote it. (It also cannot offer
      // the others — the server refuses — but this function does not assume
      // that.)
      expect(
        orderProvidersForPlatform(
          const [google, microsoft],
          platform: TargetPlatform.iOS,
          isWeb: false,
        ).map((p) => p.id),
        ['google', 'microsoft'],
      );
    });

    test('the caller\'s list is not mutated', () {
      // It returns a reordered copy. A cascade-based implementation quietly
      // reordered the input, which would corrupt a cached list.
      final input = [google, apple, microsoft];
      orderProvidersForPlatform(
        input,
        platform: TargetPlatform.iOS,
        isWeb: false,
      );
      expect(input.map((p) => p.id), ['google', 'apple', 'microsoft']);
    });
  });
}

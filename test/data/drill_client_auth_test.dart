import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/plan.dart';

/// The bearer plumbing on [DrillClient] (ADR-0025).
///
/// Two things need pinning, and they pull in opposite directions:
///
/// * A signed-in publish **must** carry the token, because since ADR-0025 that
///   is the only thing that decides ownership — `ownerId` is a caller-supplied
///   claim and the server ignores it.
/// * A signed-out publish must still work. Anonymous publishing is a supported
///   path, not a degraded one: signing in buys protection, it is not the price
///   of publishing. A client that refused to publish without a token would
///   quietly remove a documented capability.
void main() {
  late List<http.BaseRequest> seen;

  MockClient recording({int status = 200, Map<String, dynamic>? body}) {
    return MockClient((req) async {
      seen.add(req);
      return http.Response(
        jsonEncode(
          body ??
              {
                'slug': 'lsor',
                'planId': 'p_1',
                'version': '1',
                'etag': '"e1"',
                'latest': 'https://example.test/d/lsor',
                'versioned': 'https://example.test/d/lsor@1',
              },
        ),
        status,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  setUp(() => seen = []);

  /// A real archive: `upload` reads `program.json` out of it (ADR-0043), so
  /// arbitrary bytes never get as far as the request under test.
  DrillFile aPlan() {
    final now = DateTime(2026);
    return DrillFile.fromPlan(
      Plan(
        uuid: 'p_1',
        name: 'LSOR',
        description: '',
        metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
        teams: const [],
        sessions: const [],
        exercises: const [],
        rolePlays: const [],
        staff: const [],
      ),
      'lsor',
    );
  }

  String? authOf(http.BaseRequest r) => r.headers['authorization'];

  group('upload', () {
    test('carries the bearer token when signed in', () async {
      final client = DrillClient(
        baseUrl: 'https://example.test',
        accessToken: () async => 'at_1',
        httpClient: recording(),
      );

      await client.upload(aPlan());

      expect(authOf(seen.single), 'Bearer at_1');
    });

    test('sends no authorization header when signed out', () async {
      // Not an empty header, not "Bearer null" — absent. The server treats a
      // malformed header as a failed authentication, which would turn a
      // supported anonymous publish into a 401.
      final client = DrillClient(
        baseUrl: 'https://example.test',
        accessToken: () async => null,
        httpClient: recording(),
      );

      await client.upload(aPlan());

      expect(seen.single.headers.containsKey('authorization'), isFalse);
    });

    test('works with no token provider at all — the CLI has none', () async {
      final client = DrillClient(
        baseUrl: 'https://example.test',
        httpClient: recording(),
      );

      await client.upload(aPlan());

      expect(seen.single.headers.containsKey('authorization'), isFalse);
    });

    test('passes a requested access policy through', () async {
      final client = DrillClient(
        baseUrl: 'https://example.test',
        accessToken: () async => 'at_1',
        httpClient: recording(),
      );

      await client.upload(aPlan(), accessPolicy: 'public');

      expect(seen.single.url.queryParameters['accessPolicy'], 'public');
    });

    test('omits the policy parameter when none was asked for', () async {
      // Sending a default would make every ordinary update state a policy,
      // and the server applies a requested policy to new plans only — so a
      // stray default is a silent widening waiting for a server change.
      final client = DrillClient(
        baseUrl: 'https://example.test',
        httpClient: recording(),
      );

      await client.upload(aPlan());

      expect(
        seen.single.url.queryParameters.containsKey('accessPolicy'),
        isFalse,
      );
    });
  });

  group('setAccessPolicy', () {
    test('posts the policy and its grantees with the token', () async {
      final client = DrillClient(
        baseUrl: 'https://example.test',
        accessToken: () async => 'at_1',
        httpClient: recording(body: {'accessPolicy': 'shared'}),
      );

      await client.setAccessPolicy(
        'lsor',
        accessPolicy: 'shared',
        sharedAccountIds: const ['a_fjell'],
      );

      final req = seen.single as http.Request;
      expect(authOf(req), 'Bearer at_1');
      expect(req.url.queryParameters['slug'], 'lsor');
      expect(jsonDecode(req.body), {
        'accessPolicy': 'shared',
        'sharedAccountIds': ['a_fjell'],
      });
    });

    test('omits an empty grantee list rather than sending []', () async {
      // The server refuses `shared` with no grantees; for every other policy
      // an empty array is noise that reads as "I mean this".
      final client = DrillClient(
        baseUrl: 'https://example.test',
        accessToken: () async => 'at_1',
        httpClient: recording(body: {'accessPolicy': 'account'}),
      );

      await client.setAccessPolicy('lsor', accessPolicy: 'account');

      expect(jsonDecode((seen.single as http.Request).body), {
        'accessPolicy': 'account',
      });
    });

    test('surfaces the server reason rather than a bare status', () async {
      // The UI branches on `shared_requires_accounts` versus
      // `owner_role_required` — they need different messages.
      final client = DrillClient(
        baseUrl: 'https://example.test',
        accessToken: () async => 'at_1',
        httpClient: recording(
          status: 400,
          body: {'error': 'shared_requires_accounts'},
        ),
      );

      expect(
        () => client.setAccessPolicy('lsor', accessPolicy: 'shared'),
        throwsA(
          isA<DrillApiException>()
              .having((e) => e.message, 'message', 'shared_requires_accounts')
              .having((e) => e.status, 'status', 400),
        ),
      );
    });
  });
}

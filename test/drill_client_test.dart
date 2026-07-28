import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ringdrill/data/drill_client.dart';

void main() {
  test('marketFeed accepts an empty top-level list', () async {
    final client = DrillClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final feed = await client.marketFeed();

    expect(feed.items, isEmpty);
  });

  test('marketFeed accepts an empty paged response', () async {
    final client = DrillClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"items":[]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    final feed = await client.marketFeed();

    expect(feed.items, isEmpty);
  });

  group('x-version header parsing', () {
    test('head() parses x-version from a 200 response', () async {
      final client = DrillClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (_) async => http.Response('', 200, headers: {'x-version': '5'}),
        ),
      );

      final head = await client.head('sprint-1');

      expect(head.version, '5');
    });

    test('head() leaves version null when the header is absent', () async {
      final client = DrillClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      final head = await client.head('sprint-1');

      expect(head.version, isNull);
    });

    test('download() parses x-version from a 200 response', () async {
      final client = DrillClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
          (_) async => http.Response('bytes', 200, headers: {'x-version': '7'}),
        ),
      );

      final download = await client.download('sprint-1');

      expect(download.version, '7');
    });
  });

  group('MarketFeedItem.fromJson (ADR-0040)', () {
    test('parses the widened shape', () {
      final item = MarketFeedItem.fromJson({
        'programId': 'prog-1',
        'slug': 'sprint-1',
        'name': 'Sprint',
        'description': 'A full plan',
        'exerciseCount': 4,
        'author': 'Kari',
        'accessPolicy': 'shared',
        'tags': ['a', 'b'],
        'latestUrl': 'https://example.test/d/sprint-1',
        'updatedAt': '2026-02-01T00:00:00.000Z',
      });

      expect(item.description, 'A full plan');
      expect(item.exerciseCount, 4);
      expect(item.author, 'Kari');
      expect(item.accessPolicy, 'shared');
    });

    test('a legacy payload without the new fields degrades gracefully', () {
      final item = MarketFeedItem.fromJson({
        'programId': 'prog-2',
        'slug': 'legacy',
        'name': 'Legacy',
        'tags': <String>[],
        'latestUrl': 'https://example.test/d/legacy',
        'updatedAt': null,
      });

      expect(item.description, '');
      expect(item.exerciseCount, isNull);
      expect(item.author, isNull);
      expect(item.accessPolicy, isNull);
    });
  });

  group('planId/programId wire fallback (ADR-0055)', () {
    test('MarketFeedItem.fromJson reads planId when present', () {
      final item = MarketFeedItem.fromJson({
        'planId': 'plan-1',
        'slug': 'sprint-1',
        'name': 'Sprint',
        'tags': <String>[],
        'latestUrl': 'https://example.test/d/sprint-1',
        'updatedAt': null,
      });

      expect(item.planId, 'plan-1');
    });

    test(
      'MarketFeedItem.fromJson falls back to the legacy programId field',
      () {
        final item = MarketFeedItem.fromJson({
          'programId': 'prog-1',
          'slug': 'sprint-1',
          'name': 'Sprint',
          'tags': <String>[],
          'latestUrl': 'https://example.test/d/sprint-1',
          'updatedAt': null,
        });

        expect(item.planId, 'prog-1');
      },
    );

    test('MarketFeedItem.fromJson prefers planId when both are present', () {
      final item = MarketFeedItem.fromJson({
        'planId': 'plan-1',
        'programId': 'prog-1',
        'slug': 'sprint-1',
        'name': 'Sprint',
        'tags': <String>[],
        'latestUrl': 'https://example.test/d/sprint-1',
        'updatedAt': null,
      });

      expect(item.planId, 'plan-1');
    });

    test(
      'DrillUploadResponse.fromJson falls back to the legacy programId field',
      () {
        final response = DrillUploadResponse.fromJson({
          'slug': 'sprint-1',
          'programId': 'prog-1',
          'version': '1',
          'etag': '"etag-v1"',
          'latest': 'https://example.test/d/sprint-1',
          'versioned': 'https://example.test/d/sprint-1@1',
        });

        expect(response.planId, 'prog-1');
      },
    );

    test('DrillUploadResponse.fromJson reads planId when present', () {
      final response = DrillUploadResponse.fromJson({
        'slug': 'sprint-1',
        'planId': 'plan-1',
        'version': '1',
        'etag': '"etag-v1"',
        'latest': 'https://example.test/d/sprint-1',
        'versioned': 'https://example.test/d/sprint-1@1',
      });

      expect(response.planId, 'plan-1');
    });
  });
}

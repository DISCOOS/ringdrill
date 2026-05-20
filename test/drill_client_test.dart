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
}

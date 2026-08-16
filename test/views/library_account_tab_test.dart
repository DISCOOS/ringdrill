import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ringdrill/data/auth_client.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/library_view.dart';
import 'package:ringdrill/views/widgets/catalog_browser.dart';

/// The Library's account tab (DESIGN-015 §5.7).
///
/// The tab exists to show an account's *own* plans, which is why two of its
/// behaviours invert the public catalog's: it lists drafts, and it needs to
/// say so. The third thing worth pinning is the signed-out state, because the
/// obvious rendering — an empty list, or worse a prompt — would contradict
/// §5.1's "no account is the normal state" and make the tab read as a setup
/// step somebody skipped.

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

MarketFeedPageResponse _page(List<Map<String, dynamic>> items) =>
    MarketFeedPageResponse.fromJson({'items': items});

Map<String, dynamic> _item(
  String slug,
  String name, {
  bool? published,
  String? namespace,
}) => {
  'planId': 'p_$slug',
  'slug': slug,
  'name': name,
  'description': '',
  'tags': <String>[],
  'latestUrl': 'https://example.test/d/$slug',
  'published': published,
  'namespace': namespace,
};

void main() {
  tearDown(AuthService.resetForTest);

  // The default loader (the public catalog probe) is not exercised here: it
  // reaches the network, and every existing CatalogBrowser caller already
  // passes no loader, so the whole existing suite covers that path.
  group('CatalogBrowser as the account tab', () {
    testWidgets('lists the account plans its loader returns', (tester) async {
      await tester.pumpWidget(
        _app(
          CatalogBrowser(
            subtitle: 'Plans owned by Red Cross Bergen',
            loader: () async => _page([
              _item('vinter', 'Vinter', published: true, namespace: 'a_bergen'),
              _item('host', 'Høst', published: false, namespace: 'a_bergen'),
            ]),
            onItemTap: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vinter'), findsOneWidget);
      // The draft is listed, not filtered. A tab that hid drafts would hide
      // exactly what it exists for.
      expect(find.text('Høst'), findsOneWidget);
    });

    testWidgets('uses the caller-supplied empty text', (tester) async {
      // The public catalog's "Nothing published yet" is wrong for an account
      // that simply has no plans.
      await tester.pumpWidget(
        _app(
          CatalogBrowser(
            subtitle: 'Plans owned by Red Cross Bergen',
            emptyText: 'This account has no plans yet',
            loader: () async => _page(const []),
            onItemTap: (_, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This account has no plans yet'), findsOneWidget);
    });
  });

  group('the published flag', () {
    test('is null from the public feed, which only ever returns published', () {
      // A `true` there would be noise on every row.
      final item = MarketFeedItem.fromJson({
        'planId': 'p_1',
        'slug': 'lsor',
        'name': 'LSOR',
        'tags': <String>[],
        'latestUrl': 'https://example.test/d/lsor',
      });
      expect(item.published, isNull);
    });

    test('distinguishes a draft from a published plan', () {
      expect(
        MarketFeedItem.fromJson(_item('a', 'A', published: false)).published,
        isFalse,
      );
      expect(
        MarketFeedItem.fromJson(_item('b', 'B', published: true)).published,
        isTrue,
      );
    });

    test('carries the namespace, and null means anonymous', () {
      // An anon plan's URL has no namespace segment and never will
      // (ADR-0074 §2), so null is the right absence rather than "anon".
      expect(
        MarketFeedItem.fromJson(
          _item('a', 'A', namespace: 'a_bergen'),
        ).namespace,
        'a_bergen',
      );
      expect(MarketFeedItem.fromJson(_item('b', 'B')).namespace, isNull);
    });
  });

  group('accountPlans', () {
    test('requests the account path with the bearer token', () async {
      late http.BaseRequest seen;
      final client = DrillClient(
        baseUrl: 'https://example.test',
        accessToken: () async => 'at_1',
        httpClient: _Recording((req) {
          seen = req;
          return http.Response(
            jsonEncode({
              'items': [_item('vinter', 'Vinter', published: true)],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final page = await client.accountPlans('a_bergen');

      expect(seen.url.path, '/api/accounts/a_bergen/plans');
      expect(seen.headers['authorization'], 'Bearer at_1');
      expect(page.items.single.slug, 'vinter');
    });

    test('a 403 surfaces rather than looking like an empty account', () async {
      // "Not a member" and "no plans" must not render the same, or somebody
      // removed from an organisation sees an empty library and assumes the
      // plans were deleted.
      final client = DrillClient(
        baseUrl: 'https://example.test',
        accessToken: () async => 'at_1',
        httpClient: _Recording(
          (_) => http.Response('{"error":"not_a_member"}', 403),
        ),
      );

      expect(
        () => client.accountPlans('a_bergen'),
        throwsA(
          isA<DrillApiException>().having((e) => e.status, 'status', 403),
        ),
      );
    });
  });

  group('AuthState.activeAccount', () {
    test(
      'is null when signed out, so the tab explains rather than empties',
      () {
        expect(AuthState.signedOut.activeAccount, isNull);
      },
    );

    test('prefers the personal account when nothing was chosen', () {
      // It is the one the user did not have to think about.
      const state = AuthState(
        user: AuthUser(id: 'u_1', displayName: 'Kari'),
        accounts: [
          AccountMembership(
            accountId: 'a_bergen',
            displayName: 'Red Cross Bergen',
            type: 'organization',
            role: 'member',
          ),
          AccountMembership(
            accountId: 'a_kari',
            displayName: 'Kari',
            type: 'personal',
            role: 'owner',
          ),
        ],
      );
      expect(state.activeAccount!.accountId, 'a_kari');
    });

    test('honours an explicit choice over the personal default', () {
      const state = AuthState(
        user: AuthUser(id: 'u_1', displayName: 'Kari'),
        activeAccountId: 'a_bergen',
        accounts: [
          AccountMembership(
            accountId: 'a_kari',
            displayName: 'Kari',
            type: 'personal',
            role: 'owner',
          ),
          AccountMembership(
            accountId: 'a_bergen',
            displayName: 'Red Cross Bergen',
            type: 'organization',
            role: 'member',
          ),
        ],
      );
      expect(state.activeAccount!.accountId, 'a_bergen');
    });
  });

  /// The tab order, and the coupling that makes it fragile.
  ///
  /// `LibraryTab.index` is handed to the `TabController` as its initial index,
  /// so the enum's order *is* the tab order. Reordering the `TabBar` without
  /// the enum — or the other way round — neither fails to compile nor throws:
  /// it silently opens the wrong tab for everyone passing `initialTab`.
  group('library tab order', () {
    test('nearest first: mine, my account, everybody, then the action', () {
      // myPlans and account are both *yours* — one on this device, one owned
      // by an account you belong to — so they sit together. online is
      // everybody's. fromFile is not a source at all but an action, so it
      // stays last.
      expect(LibraryTab.values, [
        LibraryTab.myPlans,
        LibraryTab.account,
        LibraryTab.online,
        LibraryTab.fromFile,
      ]);
    });

    test('fromFile stays last, which its own listener relies on', () {
      // _LibraryBodyState watches for a move away from that tab and compares
      // by index, so moving it would quietly change what the listener means.
      expect(LibraryTab.fromFile.index, LibraryTab.values.length - 1);
    });
  });

}

class _Recording extends http.BaseClient {
  final http.Response Function(http.BaseRequest) _respond;

  _Recording(this._respond);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = _respond(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(res.body)),
      res.statusCode,
      headers: res.headers,
    );
  }
}

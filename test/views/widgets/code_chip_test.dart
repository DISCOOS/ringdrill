import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/code_chip.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

Widget _harness(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('CodeChip', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('renders the text and a copy icon', (tester) async {
      await tester.pumpWidget(
        _harness(
          const CodeChip(
            text: '32V 0580414E 6552008N',
            textStyle: TextStyle(),
            backgroundColor: Color(0xFFEFF1F3),
          ),
        ),
      );

      expect(find.text('32V 0580414E 6552008N'), findsOneWidget);
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets(
      'a value wrapped in parentheses draws the parens outside the pill '
      'and copies only the inner text',
      (tester) async {
        String? copied;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });

        await tester.pumpWidget(
          _harness(
            const CodeChip(
              text: '(32V 0580414E 6552008N)',
              textStyle: TextStyle(),
              backgroundColor: Color(0xFFEFF1F3),
            ),
          ),
        );

        expect(find.text('32V 0580414E 6552008N'), findsOneWidget);
        expect(find.text('('), findsOneWidget);
        expect(find.text(')'), findsOneWidget);

        await tester.tap(find.text('32V 0580414E 6552008N'));
        await tester.pumpAndSettle();

        expect(copied, '32V 0580414E 6552008N');
      },
    );

    testWidgets('tapping the chip copies the text and shows a snackbar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const CodeChip(
            text: 'Meiselen 14',
            textStyle: TextStyle(),
            backgroundColor: Color(0xFFEFF1F3),
          ),
        ),
      );

      await tester.tap(find.text('Meiselen 14'));
      await tester.pumpAndSettle();

      expect(find.text('Copied'), findsOneWidget);
    });
  });

  group('CodeActionChip', () {
    late _FakeUrlLauncher fakeLauncher;

    setUp(() {
      fakeLauncher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fakeLauncher;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('tapping the text runs the action; tapping the icon copies', (
      tester,
    ) async {
      var ran = false;
      await tester.pumpWidget(
        _harness(
          CodeActionChip(
            text: '32V 0580414E 6552008N',
            textStyle: const TextStyle(),
            backgroundColor: const Color(0xFFEFF1F3),
            actions: [ChipAction(() async => ran = true)],
          ),
        ),
      );

      await tester.tap(find.text('32V 0580414E 6552008N'));
      await tester.pump();
      expect(ran, isTrue);

      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pumpAndSettle();
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('parens-adornment: parens drawn outside, excluded from copy', (
      tester,
    ) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });

      await tester.pumpWidget(
        _harness(
          CodeActionChip(
            text: '(32V 0580414E 6552008N)',
            textStyle: const TextStyle(),
            backgroundColor: const Color(0xFFEFF1F3),
            actions: const [],
          ),
        ),
      );

      expect(find.text('('), findsOneWidget);
      expect(find.text(')'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pumpAndSettle();
      expect(copied, '32V 0580414E 6552008N');
    });
  });

  group('chipActions', () {
    test('action=map with lat/lng launches a Google Maps search URL', () async {
      final actions = chipActions(
        Uri.parse('ringdrill://chip?action=map&lat=58.99&lng=10.43'),
      );
      expect(actions, hasLength(1));

      final fakeLauncher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fakeLauncher;
      await actions.first.run();

      expect(
        fakeLauncher.launchedUrls,
        contains('https://www.google.com/maps/search/?api=1&query=58.99,10.43'),
      );
    });

    test('action=map missing lat or lng returns no actions', () {
      expect(
        chipActions(Uri.parse('ringdrill://chip?action=map&lat=58.99')),
        isEmpty,
      );
      expect(chipActions(Uri.parse('ringdrill://chip?action=map')), isEmpty);
    });

    test('action=call with tel launches a tel: URL', () async {
      final actions = chipActions(
        Uri.parse('ringdrill://chip?action=call&tel=%2B4712345678'),
      );
      expect(actions, hasLength(1));

      final fakeLauncher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fakeLauncher;
      await actions.first.run();

      expect(fakeLauncher.launchedUrls, contains('tel:+4712345678'));
    });

    test('action=call missing tel returns no actions', () {
      expect(chipActions(Uri.parse('ringdrill://chip?action=call')), isEmpty);
    });

    test('an unrecognized action degrades to no actions', () {
      expect(
        chipActions(Uri.parse('ringdrill://chip?action=unknown')),
        isEmpty,
      );
      expect(chipActions(Uri.parse('ringdrill://chip')), isEmpty);
    });
  });
}

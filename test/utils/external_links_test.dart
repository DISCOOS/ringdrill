import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/external_links.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform {
  _FakeUrlLauncher({this.canLaunchResult = true, this.launchResult = true});

  final bool canLaunchResult;
  final bool launchResult;
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => canLaunchResult;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return launchResult;
  }
}

void main() {
  group('launchExternalApp', () {
    test('an unparseable URL returns false without launching', () async {
      final fake = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fake;

      final result = await launchExternalApp('http://[::1');

      expect(result, isFalse);
      expect(fake.launchedUrls, isEmpty);
    });

    test('a URL the platform cannot launch returns false', () async {
      final fake = _FakeUrlLauncher(canLaunchResult: false);
      UrlLauncherPlatform.instance = fake;

      final result = await launchExternalApp('tel:+4712345678');

      expect(result, isFalse);
      expect(fake.launchedUrls, isEmpty);
    });

    test('a launchable URL is launched and its result returned', () async {
      final fake = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fake;

      final result = await launchExternalApp('tel:+4712345678');

      expect(result, isTrue);
      expect(fake.launchedUrls, contains('tel:+4712345678'));
    });

    test(
      'the platform launch outcome is passed through as the result',
      () async {
        final fake = _FakeUrlLauncher(launchResult: false);
        UrlLauncherPlatform.instance = fake;

        final result = await launchExternalApp('tel:+4712345678');

        expect(result, isFalse);
        expect(fake.launchedUrls, contains('tel:+4712345678'));
      },
    );
  });
}

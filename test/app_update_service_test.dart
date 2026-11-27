import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_book/services/app_update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const installed = InstalledAppVersion(
    versionName: '1.1.0',
    buildNumber: 2,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  AppUpdateService service(
    http.Client client, {
    InstalledAppVersion version = installed,
  }) {
    return AppUpdateService(
      httpClient: client,
      installedVersionLoader: () async => version,
      preferencesLoader: SharedPreferences.getInstance,
      requestTimeout: const Duration(seconds: 2),
    );
  }

  String releaseJson({
    String version = '1.1.1',
    int build = 3,
    bool withChecksum = true,
  }) {
    return jsonEncode(<String, Object>{
      'tag_name': 'v$version+$build',
      'body': 'Bug fixes aur update card.',
      'html_url':
          'https://github.com/djha6638-bossDK/Hisaab_book/releases/tag/'
          'v$version+$build',
      'assets': <Map<String, Object>>[
        <String, Object>{
          'name': 'hisaab-book-$version+$build.apk',
          'browser_download_url':
              'https://example.com/hisaab-book-$version+$build.apk',
          'size': 1200,
        },
        if (withChecksum)
          <String, Object>{
            'name': 'hisaab-book-$version+$build.apk.sha256',
            'browser_download_url':
                'https://example.com/hisaab-book-$version+$build.apk.sha256',
            'size': 80,
          },
      ],
    });
  }

  test('parses a release tag and its APK assets', () {
    final update = AppUpdateService.parseRelease(
      jsonDecode(releaseJson()) as Map<String, dynamic>,
    );

    expect(update, isNotNull);
    expect(update!.versionName, '1.1.1');
    expect(update.buildNumber, 3);
    expect(update.releaseNotes, 'Bug fixes aur update card.');
    expect(update.apkUri.toString(), contains('hisaab-book-1.1.1+3.apk'));
    expect(update.checksumUri, isNotNull);
    expect(update.apkSizeBytes, 1200);
  });

  test('ignores malformed tags and releases without an APK', () {
    final noBuild = Map<String, dynamic>.from(
      jsonDecode(releaseJson()) as Map<String, dynamic>,
    )..['tag_name'] = 'v1.1.1';
    expect(AppUpdateService.parseRelease(noBuild), isNull);

    final noApk = Map<String, dynamic>.from(
      jsonDecode(releaseJson()) as Map<String, dynamic>,
    )..['assets'] = <Object>[];
    expect(AppUpdateService.parseRelease(noApk), isNull);
  });

  test('returns a newer build and caches the GitHub response', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(releaseJson(), 200);
    });
    final updateService = service(client);

    final first = await updateService.checkForUpdate();
    final second = await updateService.checkForUpdate();

    expect(first, isNotNull);
    expect(first!.buildNumber, 3);
    expect(second, isNotNull);
    expect(second!.buildNumber, 3);
    expect(requests, 1);
  });

  test('does not offer the release when the build is not newer', () async {
    final client = MockClient((request) async {
      return http.Response(releaseJson(build: 2), 200);
    });

    final update = await service(client).checkForUpdate();

    expect(update, isNull);
  });

  test('uses the cached update when GitHub is unavailable', () async {
    var offline = false;
    final client = MockClient((request) async {
      if (offline) throw Exception('offline');
      return http.Response(releaseJson(), 200);
    });
    final updateService = service(client);

    expect((await updateService.checkForUpdate())?.buildNumber, 3);
    offline = true;

    final cached = await updateService.checkForUpdate(force: true);
    expect(cached, isNotNull);
    expect(cached!.buildNumber, 3);
  });

  test('skipVersion hides that build from later checks', () async {
    final client = MockClient((request) async {
      return http.Response(releaseJson(), 200);
    });
    final updateService = service(client);

    final update = await updateService.checkForUpdate();
    await updateService.skipVersion(update!);

    expect(await updateService.checkForUpdate(force: true), isNull);
  });

  test('parses a SHA-256 checksum file', () {
    final hash = 'a' * 64;
    expect(AppUpdateService.parseChecksum('$hash  file.apk'), hash);
    expect(AppUpdateService.parseChecksum('$hash\n'), hash);
    expect(AppUpdateService.parseChecksum('not-a-hash'), '');
  });

  test('round-trips cached update JSON', () {
    final update = AppUpdateService.parseRelease(
      jsonDecode(releaseJson()) as Map<String, dynamic>,
    )!;
    final restored = AppUpdateInfo.fromJson(
      jsonDecode(jsonEncode(update.toJson())) as Map<String, dynamic>,
    );

    expect(restored.versionName, update.versionName);
    expect(restored.buildNumber, update.buildNumber);
    expect(restored.releaseNotes, update.releaseNotes);
    expect(restored.apkUri, update.apkUri);
    expect(restored.checksumUri, update.checksumUri);
  });
}

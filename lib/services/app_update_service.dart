import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String appUpdateRepository = 'djha6638-bossDK/Hisaab_book';
const String _updateTagPattern = r'^v?(\d+\.\d+\.\d+)\+(\d+)$';

class InstalledAppVersion {
  const InstalledAppVersion({
    required this.versionName,
    required this.buildNumber,
  });

  final String versionName;
  final int buildNumber;

  String get label => '$versionName+$buildNumber';
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionName,
    required this.buildNumber,
    required this.releaseNotes,
    required this.apkUri,
    required this.releasePageUri,
    this.apkSizeBytes = 0,
    this.checksumUri,
  });

  final String versionName;
  final int buildNumber;
  final String releaseNotes;
  final Uri apkUri;
  final Uri releasePageUri;
  final int apkSizeBytes;
  final Uri? checksumUri;

  String get label => '$versionName+$buildNumber';

  String get displayVersion => '$versionName (build $buildNumber)';

  Map<String, Object?> toJson() => <String, Object?>{
    'versionName': versionName,
    'buildNumber': buildNumber,
    'releaseNotes': releaseNotes,
    'apkUri': apkUri.toString(),
    'releasePageUri': releasePageUri.toString(),
    'apkSizeBytes': apkSizeBytes,
    'checksumUri': checksumUri?.toString(),
  };

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      versionName: json['versionName']?.toString() ?? '',
      buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 0,
      releaseNotes: json['releaseNotes']?.toString() ?? '',
      apkUri: Uri.parse(json['apkUri']?.toString() ?? ''),
      releasePageUri: Uri.parse(json['releasePageUri']?.toString() ?? ''),
      apkSizeBytes: (json['apkSizeBytes'] as num?)?.toInt() ?? 0,
      checksumUri: json['checksumUri'] == null
          ? null
          : Uri.tryParse(json['checksumUri'].toString()),
    );
  }
}

enum AppUpdateInstallResult { opened, permissionDenied, failed }

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef InstalledVersionLoader = Future<InstalledAppVersion> Function();
typedef UpdatePreferencesLoader = Future<SharedPreferences> Function();

class AppUpdateService {
  AppUpdateService({
    http.Client? httpClient,
    InstalledVersionLoader? installedVersionLoader,
    UpdatePreferencesLoader? preferencesLoader,
    this.repository = appUpdateRepository,
    this.checkInterval = const Duration(hours: 6),
    this.requestTimeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient ?? http.Client(),
       _installedVersionLoader =
           installedVersionLoader ?? _loadInstalledVersionFromPlatform,
       _preferencesLoader =
           preferencesLoader ?? SharedPreferences.getInstance;

  const AppUpdateService.disabled()
    : _httpClient = null,
      _installedVersionLoader = null,
      _preferencesLoader = null,
      repository = appUpdateRepository,
      checkInterval = const Duration(hours: 6),
      requestTimeout = const Duration(seconds: 10);

  static const String _lastCheckKey = 'app-update:last-check';
  static const String _cachedReleaseKey = 'app-update:cached-release';
  static const String _skippedBuildKey = 'app-update:skipped-build';

  final http.Client? _httpClient;
  final InstalledVersionLoader? _installedVersionLoader;
  final UpdatePreferencesLoader? _preferencesLoader;
  final String repository;
  final Duration checkInterval;
  final Duration requestTimeout;

  bool get enabled => _httpClient != null;

  static Future<InstalledAppVersion> _loadInstalledVersionFromPlatform() async {
    final info = await PackageInfo.fromPlatform();
    return InstalledAppVersion(
      versionName: info.version,
      buildNumber: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  Future<InstalledAppVersion> installedVersion() async {
    final loader = _installedVersionLoader;
    if (loader == null) {
      return const InstalledAppVersion(versionName: '', buildNumber: 0);
    }
    return loader();
  }

  Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    final client = _httpClient;
    final installedLoader = _installedVersionLoader;
    final preferencesLoader = _preferencesLoader;
    if (client == null || installedLoader == null || preferencesLoader == null) {
      return null;
    }

    final prefs = await preferencesLoader();
    final installed = await installedLoader();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastCheck = prefs.getInt(_lastCheckKey);

    if (!force &&
        lastCheck != null &&
        now - lastCheck < checkInterval.inMilliseconds) {
      return _cachedUpdate(prefs, installed);
    }

    try {
      final response = await client
          .get(
            Uri.parse(
              'https://api.github.com/repos/$repository/releases/latest',
            ),
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'HisaabBook',
            },
          )
          .timeout(requestTimeout);

      if (response.statusCode == 404) {
        await _saveNoUpdate(prefs, now);
        return null;
      }
      if (response.statusCode != 200) {
        return _cachedUpdate(prefs, installed);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _cachedUpdate(prefs, installed);
      }
      final update = parseRelease(decoded);
      if (update == null) {
        await _saveNoUpdate(prefs, now);
        return null;
      }

      await prefs.setInt(_lastCheckKey, now);
      await prefs.setString(_cachedReleaseKey, jsonEncode(update.toJson()));
      return _eligibleUpdate(update, installed, prefs);
    } catch (_) {
      return _cachedUpdate(prefs, installed);
    }
  }

  Future<void> skipVersion(AppUpdateInfo update) async {
    final preferencesLoader = _preferencesLoader;
    if (preferencesLoader == null) return;
    final prefs = await preferencesLoader();
    await prefs.setInt(_skippedBuildKey, update.buildNumber);
  }

  Future<String> downloadApk(
    AppUpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    final client = _httpClient;
    if (client == null) {
      throw const AppUpdateException(
        'Update service abhi available nahi hai.',
      );
    }

    final directory = await getTemporaryDirectory();
    final safeLabel = update.label.replaceAll(
      RegExp(r'[^0-9A-Za-z._-]'),
      '-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'hisaab-book-$safeLabel.apk',
    );
    if (await file.exists()) {
      await file.delete();
    }

    try {
      final request = http.Request('GET', update.apkUri);
      final response = await client.send(request).timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw const AppUpdateException(
          'Update download nahi ho paya. Internet check karke phir try karo.',
        );
      }

      final totalBytes = response.contentLength ?? update.apkSizeBytes;
      var receivedBytes = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 30),
        )) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            onProgress?.call(
              (receivedBytes / totalBytes).clamp(0.0, 1.0).toDouble(),
            );
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      final checksumUri = update.checksumUri;
      if (checksumUri != null) {
        final expected = await _fetchChecksum(client, checksumUri);
        if (expected.isNotEmpty) {
          final actual = await _sha256OfFile(file);
          if (actual != expected) {
            await file.delete();
            throw const AppUpdateException(
              'Download ki file sahi nahi mili. Phir try karo.',
            );
          }
        }
      }

      onProgress?.call(1);
      return file.path;
    } catch (error) {
      if (await file.exists()) {
        await file.delete();
      }
      if (error is AppUpdateException) rethrow;
      throw const AppUpdateException(
        'Update download nahi ho paya. Internet check karke phir try karo.',
      );
    }
  }

  Future<AppUpdateInstallResult> installApk(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const AppUpdateException(
        'Download ki hui APK nahi mili. Phir se download karo.',
      );
    }
    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    switch (result.type) {
      case ResultType.done:
        return AppUpdateInstallResult.opened;
      case ResultType.permissionDenied:
        return AppUpdateInstallResult.permissionDenied;
      case ResultType.fileNotFound:
      case ResultType.noAppToOpen:
      case ResultType.error:
        return AppUpdateInstallResult.failed;
    }
  }

  static AppUpdateInfo? parseRelease(Map<String, dynamic> json) {
    final tag = json['tag_name']?.toString() ?? '';
    final match = RegExp(_updateTagPattern).firstMatch(tag);
    if (match == null) return null;

    final versionName = match.group(1)!;
    final buildNumber = int.tryParse(match.group(2) ?? '');
    if (buildNumber == null) return null;

    final assets = json['assets'];
    if (assets is! List) return null;

    Map<String, dynamic>? apkAsset;
    Map<String, dynamic>? checksumAsset;
    for (final rawAsset in assets) {
      if (rawAsset is! Map) continue;
      final asset = Map<String, dynamic>.from(rawAsset);
      final name = asset['name']?.toString() ?? '';
      if (name.endsWith('.apk')) {
        apkAsset ??= asset;
      } else if (name.endsWith('.apk.sha256')) {
        checksumAsset ??= asset;
      }
    }
    if (apkAsset == null) return null;

    final apkUrl = apkAsset['browser_download_url']?.toString() ?? '';
    final releasePageUrl = json['html_url']?.toString() ?? '';
    if (apkUrl.isEmpty || releasePageUrl.isEmpty) return null;

    final checksumUrl = checksumAsset?['browser_download_url']?.toString();
    return AppUpdateInfo(
      versionName: versionName,
      buildNumber: buildNumber,
      releaseNotes: (json['body']?.toString() ?? '').trim(),
      apkUri: Uri.parse(apkUrl),
      releasePageUri: Uri.parse(releasePageUrl),
      apkSizeBytes: (apkAsset['size'] as num?)?.toInt() ?? 0,
      checksumUri: checksumUrl == null || checksumUrl.isEmpty
          ? null
          : Uri.parse(checksumUrl),
    );
  }

  static String parseChecksum(String contents) {
    final firstToken = contents.trim().split(RegExp(r'\s+')).first;
    final normalized = firstToken.toLowerCase();
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)
        ? normalized
        : '';
  }

  Future<AppUpdateInfo?> _cachedUpdate(
    SharedPreferences prefs,
    InstalledAppVersion installed,
  ) async {
    final cached = prefs.getString(_cachedReleaseKey);
    if (cached == null || cached.isEmpty) return null;
    try {
      final decoded = jsonDecode(cached);
      if (decoded is! Map<String, dynamic>) return null;
      return _eligibleUpdate(
        AppUpdateInfo.fromJson(decoded),
        installed,
        prefs,
      );
    } catch (_) {
      return null;
    }
  }

  AppUpdateInfo? _eligibleUpdate(
    AppUpdateInfo update,
    InstalledAppVersion installed,
    SharedPreferences prefs,
  ) {
    if (update.buildNumber <= installed.buildNumber) return null;
    final skippedBuild = prefs.getInt(_skippedBuildKey) ?? 0;
    if (update.buildNumber <= skippedBuild) return null;
    return update;
  }

  Future<void> _saveNoUpdate(SharedPreferences prefs, int now) async {
    await prefs.setInt(_lastCheckKey, now);
    await prefs.setString(_cachedReleaseKey, '');
  }

  Future<String> _fetchChecksum(http.Client client, Uri uri) async {
    final response = await client.get(uri).timeout(requestTimeout);
    if (response.statusCode != 200) return '';
    return parseChecksum(response.body);
  }

  Future<String> _sha256OfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

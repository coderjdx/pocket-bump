import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'pvp_transport.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String downloadUrl;
  final String releaseName;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.releaseName,
  });
}

class AppUpdateService {
  static const String _latestReleaseApi =
      'https://api.github.com/repos/coderjdx/pocket-bump/releases/latest';
  static const String _skippedVersionKey = 'pocket_bump_skipped_update_tag';
  static const String currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.57',
  );

  static bool _checkedThisSession = false;

  static List<int> _parseSemver(String raw) {
    final clean = raw.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final parts = clean.split('.');
    return List<int>.generate(3, (i) {
      if (i >= parts.length) return 0;
      return int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    });
  }

  static bool isVersionNewer(String candidate, String current) {
    final a = _parseSemver(candidate);
    final b = _parseSemver(current);
    for (int i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  static Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    if (_checkedThisSession && !force) return null;
    _checkedThisSession = true;

    try {
      final raw = await httpGetString(_latestReleaseApi);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final tagName = (decoded['tag_name'] as String?)?.trim() ?? '';
      if (tagName.isEmpty || !isVersionNewer(tagName, currentVersion)) {
        return null;
      }

      if (!force) {
        final prefs = await SharedPreferences.getInstance();
        final skipped = prefs.getString(_skippedVersionKey);
        if (skipped == tagName) {
          return null;
        }
      }

      final releaseUrl = (decoded['html_url'] as String?)?.trim() ??
          'https://github.com/coderjdx/pocket-bump/releases/latest';
      String downloadUrl = releaseUrl;
      final assets = decoded['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is Map) {
            final name = (asset['name'] as String?) ?? '';
            final url = (asset['browser_download_url'] as String?) ?? '';
            if (name.toLowerCase().endsWith('.apk') && url.isNotEmpty) {
              downloadUrl = url;
              break;
            }
          }
        }
      }

      final releaseName = (decoded['name'] as String?)?.trim();
      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: tagName,
        releaseUrl: releaseUrl,
        downloadUrl: downloadUrl,
        releaseName: (releaseName != null && releaseName.isNotEmpty)
            ? releaseName
            : 'Pocket Bump $tagName',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> skipVersion(String tagName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skippedVersionKey, tagName);
    } catch (_) {}
  }
}

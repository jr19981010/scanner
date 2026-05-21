import 'dart:convert';
import 'dart:io';

/// Result of checking GitHub for a newer release.
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String? downloadUrl;
  final String? releaseNotes;
  final String? releaseUrl;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    this.downloadUrl,
    this.releaseNotes,
    this.releaseUrl,
  });
}

/// Checks a public GitHub repo's "latest release" endpoint and returns
/// whether the running app version is older than the released one.
///
/// Asset matching: each platform looks for its own file by suffix —
///   .apk for Android, .dmg (then .zip) for macOS.
class GithubUpdater {
  GithubUpdater({
    required this.owner,
    required this.repo,
    required this.currentVersion,
    this.timeout = const Duration(seconds: 8),
  });

  /// e.g. "jhay-arpilar"
  final String owner;

  /// e.g. "omr-scanner"
  final String repo;

  /// Pulled from pubspec.yaml at build time, e.g. "1.0.1".
  final String currentVersion;

  final Duration timeout;

  Future<UpdateInfo> check() async {
    final uri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/latest');
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(uri);
      req.headers.add('Accept', 'application/vnd.github+json');
      req.headers.add('User-Agent', 'omr-updater');
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode != 200) {
        throw HttpException('GitHub returned ${resp.statusCode}');
      }
      final body = await resp.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      final tag = (j['tag_name'] as String?) ?? '';
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      final notes = j['body'] as String?;
      final pageUrl = j['html_url'] as String?;
      final assets =
          (j['assets'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

      final suffix = _platformSuffix();
      final fallback = _fallbackSuffix();
      String? url;
      for (final a in assets) {
        final name = (a['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith(suffix)) {
          url = a['browser_download_url'] as String?;
          break;
        }
      }
      if (url == null && fallback != null) {
        for (final a in assets) {
          final name = (a['name'] as String?) ?? '';
          if (name.toLowerCase().endsWith(fallback)) {
            url = a['browser_download_url'] as String?;
            break;
          }
        }
      }

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latest,
        hasUpdate: _isNewer(latest, currentVersion),
        downloadUrl: url,
        releaseNotes: notes,
        releaseUrl: pageUrl,
      );
    } finally {
      client.close(force: true);
    }
  }

  String _platformSuffix() {
    if (Platform.isAndroid) return '.apk';
    if (Platform.isMacOS) return '.dmg';
    if (Platform.isWindows) return '.exe';
    if (Platform.isLinux) return '.appimage';
    return '.zip';
  }

  String? _fallbackSuffix() {
    if (Platform.isMacOS) return '.zip';
    return null;
  }

  /// Simple semver comparison. Returns true if `a` (e.g. "1.2.3") > `b`.
  /// Anything that doesn't parse as semver compares as a plain string.
  static bool _isNewer(String a, String b) {
    final pa = _parse(a);
    final pb = _parse(b);
    if (pa == null || pb == null) return a.compareTo(b) > 0;
    for (var i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i] > pb[i];
    }
    return false;
  }

  static List<int>? _parse(String v) {
    final parts = v.split('.').take(3).toList();
    if (parts.length != 3) return null;
    final nums = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p.split('-').first);
      if (n == null) return null;
      nums.add(n);
    }
    return nums;
  }
}

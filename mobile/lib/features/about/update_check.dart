import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:install_plugin/install_plugin.dart';
import 'package:omr_shared/omr_shared.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Repo coordinates — change these to match the public repo that hosts
/// the .apk under GitHub Releases.
const _repoOwner = 'jr19981010';
const _repoName = 'scanner';

Future<void> showUpdateCheckDialog(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ProgressDialog('Checking for updates…'),
  );

  UpdateInfo? info;
  String? error;
  try {
    final pkg = await PackageInfo.fromPlatform();
    final updater = GithubUpdater(
      owner: _repoOwner,
      repo: _repoName,
      currentVersion: pkg.version,
    );
    info = await updater.check();
  } catch (e) {
    error = e.toString();
  }
  if (!context.mounted) return;
  Navigator.of(context).pop();

  if (error != null) {
    await _alert(context, 'Update check failed', error);
    return;
  }
  final i = info!;
  if (!i.hasUpdate) {
    await _alert(context, 'You\'re up to date',
        'Current version: ${i.currentVersion}\nLatest on GitHub: ${i.latestVersion}');
    return;
  }
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Update available · v${i.latestVersion}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You\'re on v${i.currentVersion}.'),
            const SizedBox(height: 12),
            if (i.releaseNotes != null) ...[
              const Text('Release notes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(i.releaseNotes!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later')),
        if (i.downloadUrl == null && i.releaseUrl != null)
          FilledButton(
            onPressed: () => launchUrl(Uri.parse(i.releaseUrl!),
                mode: LaunchMode.externalApplication),
            child: const Text('Open release page'),
          ),
        if (i.downloadUrl != null)
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Download & install'),
            onPressed: () async {
              Navigator.pop(context);
              await _downloadAndInstall(context, i.downloadUrl!);
            },
          ),
      ],
    ),
  );
}

Future<void> _downloadAndInstall(BuildContext context, String url) async {
  final progress = ValueNotifier<double>(0);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Downloading update…'),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, v, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: v == 0 ? null : v),
            const SizedBox(height: 8),
            Text(v == 0
                ? 'Starting…'
                : '${(v * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    ),
  );

  try {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'omr_update.apk'));
    final req = http.Request('GET', Uri.parse(url));
    final resp = await http.Client().send(req);
    final total = resp.contentLength ?? 0;
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in resp.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) progress.value = received / total;
    }
    await sink.flush();
    await sink.close();

    if (!context.mounted) return;
    Navigator.of(context).pop();
    final pkg = await PackageInfo.fromPlatform();
    final result =
        await InstallPlugin.installApk(file.path, appId: pkg.packageName);
    if (!context.mounted) return;
    if (result.toString().toLowerCase().contains('success')) {
      // The system installer has taken over.
    } else {
      await _alert(context, 'Install prompt failed', result.toString());
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    await _alert(context, 'Download failed', e.toString());
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ]),
      );
}

Future<void> _alert(BuildContext context, String title, String body) =>
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SelectableText(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );

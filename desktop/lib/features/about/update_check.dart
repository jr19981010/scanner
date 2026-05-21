import 'package:flutter/material.dart';
import 'package:omr_shared/omr_shared.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Repo coordinates — change these to match the public repo that hosts
/// your built .dmg / .apk under GitHub Releases.
const _repoOwner = 'jr19981010';
const _repoName = 'scanner';

Future<void> showUpdateCheckDialog(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ProgressDialog('Checking GitHub for updates…'),
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
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Update available · v${i.latestVersion}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You\'re on v${i.currentVersion}.'),
            const SizedBox(height: 12),
            if (i.releaseNotes != null) ...[
              const Text('Release notes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: SelectableText(i.releaseNotes!),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later')),
        if (i.releaseUrl != null)
          OutlinedButton(
            onPressed: () => launchUrl(Uri.parse(i.releaseUrl!),
                mode: LaunchMode.externalApplication),
            child: const Text('Open release page'),
          ),
        if (i.downloadUrl != null)
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Download .dmg'),
            onPressed: () => launchUrl(Uri.parse(i.downloadUrl!),
                mode: LaunchMode.externalApplication),
          ),
      ],
    ),
  );
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

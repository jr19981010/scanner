import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history =
        ((Hive.box('settings').get('history') as List?) ?? const [])
            .cast<Map>();
    return Scaffold(
      appBar: AppBar(title: const Text('Recent scans')),
      body: history.isEmpty
          ? const Center(child: Text('No scans yet.'))
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final h = history[i];
                final at = (h['at'] as String).substring(11, 19);
                return ListTile(
                  leading: CircleAvatar(child: Text('${h['score']}')),
                  title: Text(h['student_no'] as String),
                  subtitle: Text(
                      '${h['exam_title']} · ${h['score']}/${h['total']}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(at, style: const TextStyle(fontFamily: 'monospace')),
                      if (h['queued'] == true)
                        const Icon(Icons.cloud_off,
                            size: 14, color: Colors.orange),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

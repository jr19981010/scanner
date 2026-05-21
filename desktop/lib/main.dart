import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'db/database.dart';
import 'server/server.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show a startup splash immediately so the window is never blank, even if
  // DB/server bring-up is slow or fails.
  runApp(const _BootSplash());

  AppDatabase? db;
  LocalServer? server;
  Object? bootError;
  try {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await AppDatabase.open();
    server = LocalServer(db: db);
    // Don't await — start in background so a sandbox/port error doesn't
    // black-hole the UI. The Live-scans tab will show the bound IP once ready.
    unawaited(server.start());
  } catch (e, st) {
    bootError = e;
    // ignore: avoid_print
    print('Boot error: $e\n$st');
  }

  if (db == null || server == null) {
    runApp(_BootErrorApp(error: bootError ?? 'Unknown startup failure'));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        localServerProvider.overrideWithValue(server),
      ],
      child: const OmrDesktopApp(),
    ),
  );
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Starting OMR Desktop…'),
              ],
            ),
          ),
        ),
      );
}

class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Startup failed',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText('$error'),
                const SizedBox(height: 16),
                const Text(
                  'Common causes:\n'
                  '• Sandbox blocked the database directory (rebuild with entitlements).\n'
                  '• Port 4040 already in use (close other instances of this app).\n'
                  '• Disk full or permissions denied on ~/Library/Application Support.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
}

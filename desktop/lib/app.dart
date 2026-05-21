import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'theme.dart';
import 'features/class_record/class_record_screen.dart';
import 'features/exams/exams_screen.dart';
import 'features/live_scan_feed/live_feed_screen.dart';
import 'features/sections/sections_screen.dart';
import 'features/sheet_generator/sheet_generator_screen.dart';
import 'features/students/students_screen.dart';
import 'server/server.dart';

final appDatabaseProvider = Provider<AppDatabase>((_) =>
    throw UnimplementedError('AppDatabase override missing'));

final localServerProvider = Provider<LocalServer>((_) =>
    throw UnimplementedError('LocalServer override missing'));

class OmrDesktopApp extends StatelessWidget {
  const OmrDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMR Class Record',
      theme: YaruLike.light(),
      darkTheme: YaruLike.dark(),
      home: const DashboardShell(),
    );
  }
}

class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _index = 0;

  static const _tabs = [
    ('Live scans', Icons.wifi_tethering),
    ('Class record', Icons.table_chart),
    ('Sections', Icons.school),
    ('Students', Icons.group),
    ('Exams', Icons.fact_check),
    ('Generate sheets', Icons.picture_as_pdf),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final t in _tabs)
                NavigationRailDestination(
                    icon: Icon(t.$2), label: Text(t.$1)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: switch (_index) {
              0 => const LiveFeedScreen(),
              1 => const ClassRecordScreen(),
              2 => const SectionsScreen(),
              3 => const StudentsScreen(),
              4 => const ExamsScreen(),
              5 => const SheetGeneratorScreen(),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

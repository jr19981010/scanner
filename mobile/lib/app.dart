import 'package:flutter/material.dart';

import 'features/connect/connect_screen.dart';
import 'theme.dart';

class OmrMobileApp extends StatelessWidget {
  const OmrMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMR Scanner',
      theme: YaruLike.light(),
      darkTheme: YaruLike.dark(),
      home: const ConnectScreen(),
    );
  }
}

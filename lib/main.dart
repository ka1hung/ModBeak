import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/main_window/main_window.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MbtApp()));
}

class MbtApp extends StatelessWidget {
  const MbtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ModBeak',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: const MainWindow(),
    );
  }
}

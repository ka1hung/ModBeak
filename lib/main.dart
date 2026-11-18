import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'ui/main_window/main_window.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.load();
  await loadSavedThemeMode();
  runApp(const ProviderScope(child: MbtApp()));
}

class MbtApp extends StatelessWidget {
  const MbtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, _) {
        // `home: MainWindow()` is intentionally NOT const. Flutter's element
        // diff skips updates when the new child widget is `identical()` to
        // the old one, and `const MainWindow()` always resolves to the same
        // canonical instance — so without this, MaterialApp would rebuild
        // with the new theme but MainWindow's subtree (which reads
        // `AppColors.*` getters) would never re-run its build, leaving the
        // bulk of the UI stuck on the old palette.
        return MaterialApp(
          title: 'ModBeak',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(mode),
          home: MainWindow(),
        );
      },
    );
  }
}

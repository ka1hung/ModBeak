import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modbeak/core/app_info.dart';
import 'package:modbeak/ui/main_window/dialogs/about_dialog.dart';

void main() {
  group('AppInfo labels', () {
    tearDown(() {
      AppInfo.version = '';
      AppInfo.build = '';
    });

    test('are empty placeholders before load()', () {
      expect(AppInfo.shortLabel, '');
      expect(AppInfo.fullLabel, 'unknown');
    });

    test('render version and build once loaded', () {
      AppInfo.version = '1.0.0';
      AppInfo.build = '1';
      expect(AppInfo.shortLabel, 'v1.0.0');
      expect(AppInfo.fullLabel, '1.0.0 (build 1)');
    });

    test('omit the build suffix when the platform reports none', () {
      AppInfo.version = '1.0.0';
      AppInfo.build = '';
      expect(AppInfo.fullLabel, '1.0.0');
    });
  });

  testWidgets('About dialog shows the running version', (tester) async {
    AppInfo.version = '1.0.0';
    AppInfo.build = '1';
    addTearDown(() {
      AppInfo.version = '';
      AppInfo.build = '';
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AboutModBeakDialog())),
    );

    expect(find.text('Version 1.0.0 (build 1)'), findsOneWidget);
    expect(find.text(AboutModBeakDialog.repoUrl), findsOneWidget);
  });
}

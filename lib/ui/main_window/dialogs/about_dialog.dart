import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_info.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';

/// About box — the canonical place to read (and copy) the exact build a
/// user is running when they file a bug report.
class AboutModBeakDialog extends StatelessWidget {
  const AboutModBeakDialog({super.key});

  static const String repoUrl = 'https://github.com/ka1hung/ModBeak';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CockatielHead(size: 40),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: AppType.h1.copyWith(color: AppColors.text),
                          children: const [
                            TextSpan(
                              text: 'Mod',
                              style: TextStyle(fontWeight: FontWeight.w400),
                            ),
                            TextSpan(
                              text: 'Beak',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version ${AppInfo.fullLabel}',
                        style: AppType.mono.copyWith(color: AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'A cross-platform Modbus master tool for polling TCP and '
                'RTU devices.',
                style: AppType.bodySm.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              SelectableText(
                repoUrl,
                style: AppType.monoSm.copyWith(color: AppColors.textDim),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: 'ModBeak ${AppInfo.fullLabel}'),
                      );
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text('Version copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text('Copy version'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

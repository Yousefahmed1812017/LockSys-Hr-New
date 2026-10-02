import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_language_toggle.dart';
import 'app_logo_full.dart';
import 'app_screen.dart';
import 'l_pattern.dart';

/// White hero used by the pre-login screens (company code, login): faded L
/// pattern, language toggle, the full LockSys logo and a short line.
class AppBrandHero extends StatelessWidget {
  const AppBrandHero({super.key, required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.blue50, Colors.white],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: LPattern(fade: true, gap: 44)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AppLanguageToggle(),
                  ),
                  const SizedBox(height: 12),
                  const AppReveal(index: 0, child: AppLogoFull(width: 240)),
                  const SizedBox(height: 14),
                  AppReveal(
                    index: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: AppText.small,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

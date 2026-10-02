import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// Small pill-less button that switches Arabic <-> English.
/// Shows the name of the language you will switch TO ("English" / "العربية").
/// Put it top-end on welcome / login screens; account screen has a full row.
class AppLanguageToggle extends StatelessWidget {
  const AppLanguageToggle({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    // A single-language company has nothing to switch to.
    if (!LocaleScope.of(context).canSwitch) return const SizedBox.shrink();
    final l = context.l10n;
    final fg = onDark ? Colors.white : AppColors.navy;
    return Pressable(
      scale: .96,
      semanticLabel: l.chooseLanguage,
      onTap: () => LocaleScope.of(context).toggle(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: .08) : Colors.white,
          borderRadius: AppRadius.btnAll,
          border: Border.all(
            color: onDark
                ? Colors.white.withValues(alpha: .2)
                : AppColors.lineStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.globe, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              l.switchLanguageLabel,
              style: AppText.small.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

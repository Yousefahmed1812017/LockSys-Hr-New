import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'app_icon.dart';
import 'pressable.dart';

enum AppButtonVariant { primary, navy, ghost, danger }

enum AppButtonSize { sm, md, lg }

/// The only button. Square, radius 8, full width by default.
/// One primary button per screen, placed last.
///
///   AppButton(label: 'حفظ', icon: AppIcons.forward, onPressed: save)
///   AppButton(label: 'إلغاء', variant: AppButtonVariant.ghost, ...)
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.leadingIcon,
    this.loading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;

  /// Shown after the label (points "forward" for the current direction).
  final AppIconData? icon;
  final AppIconData? leadingIcon;
  final bool loading;

  /// false = wrap content (use in rows with [AppButtonSize.sm]).
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final height = switch (size) {
      AppButtonSize.sm => AppSizes.buttonSm,
      AppButtonSize.md => AppSizes.buttonMd,
      AppButtonSize.lg => AppSizes.buttonLg,
    };
    final fontSize = switch (size) {
      AppButtonSize.sm => 13.6,
      AppButtonSize.md => 15.2,
      AppButtonSize.lg => 16.0,
    };
    final hPad = size == AppButtonSize.sm ? 18.0 : 22.0;

    final (bg, pressedBg, fg) = switch (variant) {
      AppButtonVariant.primary =>
        (AppColors.blue, AppColors.bluePressed, Colors.white),
      AppButtonVariant.navy =>
        (AppColors.navy, AppColors.navy3, Colors.white),
      AppButtonVariant.ghost =>
        (Colors.transparent, AppColors.blue50, AppColors.navy),
      AppButtonVariant.danger =>
        (AppColors.danger, AppColors.dangerPressed, Colors.white),
    };
    final ghost = variant == AppButtonVariant.ghost;
    final accent = ghost ? AppColors.blue : Colors.white;
    final accentOpacity = ghost ? .16 : .3;

    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ghost ? AppColors.blue : Colors.white,
              backgroundColor: (ghost ? AppColors.lineStrong : Colors.white)
                  .withValues(alpha: .4),
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (!loading && leadingIcon != null) ...[
          AppIcon(leadingIcon!,
              size: 18,
              color: fg,
              accentColor: accent,
              accentOpacity: accentOpacity),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.button.copyWith(color: fg, fontSize: fontSize),
          ),
        ),
        if (!loading && icon != null) ...[
          const SizedBox(width: 10),
          AppIcon(icon!,
              size: 18,
              color: fg,
              accentColor: accent,
              accentOpacity: accentOpacity),
        ],
      ],
    );

    return Opacity(
      opacity: onPressed == null ? .4 : 1,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        semanticLabel: label,
        builder: (context, pressed) => AnimatedContainer(
          duration: AppMotion.fast,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: hPad),
          decoration: BoxDecoration(
            color: pressed ? pressedBg : bg,
            borderRadius: AppRadius.btnAll,
            border:
                ghost ? Border.all(color: AppColors.lineStrong, width: 1.5) : null,
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

/// 44px icon-only button (toolbar actions, filters, bell...).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.color,
  });

  final AppIconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      scale: .94,
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: AppSizes.iconButton,
        height: AppSizes.iconButton,
        child: Center(child: AppIcon(icon, color: color ?? AppColors.navy)),
      ),
    );
  }
}

/// Text link (blue, semibold, small).
class AppTextLink extends StatelessWidget {
  const AppTextLink(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .96,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: AppText.small
              .copyWith(color: AppColors.blue, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

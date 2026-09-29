import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_icon.dart';

/// Bottom sheet: for filters and pickers. Handle bar + optional title.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lineStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (title != null) ...[
            Text(title, style: AppText.h3),
            const SizedBox(height: 12),
          ],
          builder(ctx),
        ],
      ),
    ),
  );
}

/// Confirmation dialog. Use only for destructive / irreversible actions.
/// Returns true when confirmed.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.navy.withValues(alpha: .5),
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: AppColors.blue),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.h3),
                const SizedBox(height: 6),
                Text(message, style: AppText.small),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: cancelLabel ?? AppLocalizations.of(ctx).cancel,
                        variant: AppButtonVariant.ghost,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: confirmLabel ?? AppLocalizations.of(ctx).confirm,
                        variant: destructive
                            ? AppButtonVariant.danger
                            : AppButtonVariant.primary,
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Transient message. Navy, floating, with a tone icon and optional action.
abstract final class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    AppTone tone = AppTone.success,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final icon = switch (tone) {
      AppTone.success => AppIcons.check,
      AppTone.danger || AppTone.warning => AppIcons.warning,
      _ => AppIcons.info,
    };
    final tint = switch (tone) {
      AppTone.success => const Color(0xFF5FD6A0),
      AppTone.danger => const Color(0xFFFF8A8A),
      AppTone.warning => const Color(0xFFFFC46B),
      _ => AppColors.blueBright,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2600),
          content: Row(
            children: [
              AppIcon(icon,
                  size: 20,
                  color: tint,
                  accentColor: Colors.white,
                  accentOpacity: .25),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: AppColors.blueBright,
                  onPressed: onAction ?? () {},
                ),
        ),
      );
  }
}

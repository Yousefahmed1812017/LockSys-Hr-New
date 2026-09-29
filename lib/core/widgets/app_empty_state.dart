import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'app_icon.dart';
import 'l_pattern.dart';

/// Empty / error / offline state: icon art, title, short message, action.
/// Every list screen needs one for "no data" and one for "load failed".
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tone = AppTone.info,
  }) : _offline = false;

  /// Preset: nothing here yet.
  const AppEmptyState.empty({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  })  : icon = AppIcons.inbox,
        tone = AppTone.info,
        _offline = false;

  /// Preset: no connection / request failed. Text is localized.
  /// Pass [onAction] to show the "Try again" button.
  const AppEmptyState.offline({super.key, this.onAction})
      : icon = AppIcons.wifi,
        title = '',
        message = null,
        actionLabel = null,
        tone = AppTone.danger,
        _offline = true;

  final AppIconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppTone tone;
  final bool _offline;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = _offline ? l.offlineTitle : this.title;
    final message = _offline ? l.offlineMessage : this.message;
    final actionLabel =
        _offline ? (onAction == null ? null : l.retry) : this.actionLabel;
    final danger = tone == AppTone.danger;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: danger ? AppColors.dangerBg : AppColors.blue50,
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: danger ? AppColors.dangerBg : AppColors.line,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!danger) const Positioned.fill(child: LPattern()),
                  AppIcon(
                    icon,
                    size: 36,
                    color: danger ? AppColors.danger : AppColors.blue,
                    accentColor: danger ? AppColors.danger : AppColors.blue,
                    accentOpacity: .2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppText.h3, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  message,
                  style: AppText.small,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: actionLabel,
                size: AppButtonSize.sm,
                expanded: false,
                variant:
                    danger ? AppButtonVariant.ghost : AppButtonVariant.primary,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

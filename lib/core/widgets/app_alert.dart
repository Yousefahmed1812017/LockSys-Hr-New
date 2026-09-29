import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';

/// In-page notice. White card + solid tone icon tile + thin tone line at the
/// bottom. For transient messages use AppSnackbar instead.
class AppAlert extends StatelessWidget {
  const AppAlert({
    super.key,
    required this.title,
    this.message,
    this.tone = AppTone.info,
    this.onClose,
  });

  final String title;
  final String? message;
  final AppTone tone;
  final VoidCallback? onClose;

  AppIconData get _icon => switch (tone) {
        AppTone.success => AppIcons.check,
        AppTone.warning || AppTone.danger => AppIcons.warning,
        _ => AppIcons.info,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.sh2,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconTile(_icon, tone: tone, solid: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                      if (message != null)
                        Text(message!, style: AppText.small),
                    ],
                  ),
                ),
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: Container(height: 2, color: tone.color),
          ),
        ],
      ),
    );
  }
}

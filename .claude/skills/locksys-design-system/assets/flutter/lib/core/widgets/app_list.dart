import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'app_icon.dart';

/// Bordered container that stacks tiles with 1px dividers.
class AppListGroup extends StatelessWidget {
  const AppListGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// List row, min 64px. leading = [AppIconTile] or [AppAvatar].
/// trailing = [AppBadge], value text, Switch, or the default chevron.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Defaults to true when [onTap] is set and there is no [trailing].
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final chevron = showChevron ?? (onTap != null && trailing == null);
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.blueLight,
        highlightColor: AppColors.blue50,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppText.body
                            .copyWith(fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: AppText.xs.copyWith(height: 1.4)),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
                if (chevron) ...[
                  const SizedBox(width: 8),
                  const AppIcon(AppIcons.chevron,
                      size: 18, color: AppColors.lineStrong),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small grey section label above a list group ("الحساب", "الدعم"...).
class AppGroupTitle extends StatelessWidget {
  const AppGroupTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppText.xs.copyWith(fontWeight: FontWeight.w600, letterSpacing: .3),
      );
}

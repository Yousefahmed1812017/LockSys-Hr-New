import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'pressable.dart';

/// A request as a classic white card: a colored edge on the start side (the
/// state of the request), who or what it is with a tinted status pill, a light
/// band with the three facts that matter (duration, from, to), an optional note
/// and, when there is something to decide, the actions.
///
///   AppRequestCard(
///     leading: AppAvatar('SA'),
///     title: 'Sara Ahmed',
///     subtitle: 'Annual leave',
///     status: 'Approved', statusTone: AppTone.success,
///     facts: [('Duration', '3 days'), ('From', 'Nov 2'), ('To', 'Nov 4')],
///     actions: Row(...),
///   )
class AppRequestCard extends StatelessWidget {
  const AppRequestCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.status,
    this.statusTone = AppTone.info,
    this.accent = AppColors.blue,
    required this.facts,
    this.note,
    this.noteColor = AppColors.warning,
    this.actions,
    this.replacement,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// The status pill (null: none).
  final String? status;
  final AppTone statusTone;

  /// The colored edge.
  final Color accent;

  /// (label, value) pairs of the band, shown side by side.
  final List<(String, String)> facts;

  /// A line under the band (who has to decide first...).
  final String? note;
  final Color noteColor;

  /// Buttons under the band.
  final Widget? actions;

  /// Shown instead of the band and the actions (the result of a decision).
  final Widget? replacement;
  final VoidCallback? onTap;

  static (Color, Color) _pill(AppTone tone) => switch (tone) {
    AppTone.success => (AppColors.successBg, AppColors.success),
    AppTone.danger => (AppColors.dangerBg, AppColors.danger),
    AppTone.warning => (AppColors.warningBg, AppColors.warning),
    AppTone.muted => (AppColors.blue50, AppColors.muted),
    _ => (AppColors.blue50, AppColors.blue),
  };

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(color: AppColors.muted),
                ),
            ],
          ),
        ),
        if (status != null) ...[
          const SizedBox(width: 8),
          Builder(
            builder: (_) {
              final (bg, fg) = _pill(statusTone);
              // At most 110 px so a long status never squeezes the title away.
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(AppRadius.xs + 2),
                  ),
                  child: Text(
                    status!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.xs.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );

    final band = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(AppRadius.xs + 2),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.line,
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      facts[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.xs.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      facts[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppText.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? AppColors.blue : AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          child: replacement != null
              ? KeyedSubtree(
                  key: const ValueKey('replacement'),
                  child: replacement!,
                )
              : Column(
                  key: const ValueKey('facts'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    band,
                    if (note != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        note!,
                        style: AppText.small.copyWith(
                          color: noteColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (actions != null) ...[
                      const SizedBox(height: 12),
                      actions!,
                    ],
                  ],
                ),
        ),
      ],
    );

    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.sh1,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(padding: const EdgeInsets.all(14), child: body),
            ),
          ],
        ),
      ),
    );
    return onTap == null
        ? card
        : Pressable(onTap: onTap, scale: .985, child: card);
  }
}

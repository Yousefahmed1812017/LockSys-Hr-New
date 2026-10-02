import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'app_icon.dart';
import 'l_pattern.dart';
import 'pressable.dart';

/// Square back button (40px, thin border). Always the first item of the
/// top bar on pushed screens. Arrow mirrors automatically in LTR.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: .95,
      semanticLabel: AppLocalizations.of(context).back,
      onTap: onPressed ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: AppSizes.backButton,
        height: AppSizes.backButton,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.btnAll,
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.sh1,
        ),
        child: const Center(child: AppIcon(AppIcons.back)),
      ),
    );
  }
}

/// 56px top bar with a 1px bottom border. On a pushed screen (back button + title)
/// the title sits in the middle of the bar, right beside the back button, so the
/// screen needs no big heading and the content starts higher. Without a back
/// button the title starts at the leading edge (home).
///   [back]   title (centered)   [actions or an empty square]
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.showBack = false,
    this.actions = const [],
    this.leading,
    this.forceLtr = false,
    this.flat = false,
  });

  final String? title;
  final bool showBack;
  final List<Widget> actions;

  /// Replaces the title (e.g. the brand logo on the home tab).
  final Widget? leading;

  /// Lay the bar out left to right in every language (the home bar: logo on the
  /// left, notifications and account on the right, also in Arabic).
  final bool forceLtr;

  /// No fill and no line under the bar: the screen's background shows through
  /// (the home screen).
  final bool flat;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.appBar);

  @override
  Widget build(BuildContext context) {
    final centered = showBack && leading == null && title != null;
    final bar = Material(
      color: flat ? Colors.transparent : Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: AppSizes.appBar,
          padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
          decoration: flat
              ? null
              : const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
          child: centered
              ? Row(
                  children: [
                    const AppBackButton(),
                    Expanded(
                      child: Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppText.h3,
                      ),
                    ),
                    // Keeps the title centered: as wide as the back button.
                    if (actions.isEmpty)
                      const SizedBox(width: AppSizes.backButton)
                    else
                      ...actions,
                  ],
                )
              : Row(
                  children: [
                    if (showBack) ...[
                      const AppBackButton(),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child:
                          leading ??
                          Text(
                            title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.h3,
                          ),
                    ),
                    ...actions,
                  ],
                ),
        ),
      ),
    );
    return forceLtr
        ? Directionality(textDirection: TextDirection.ltr, child: bar)
        : bar;
  }
}

/// One short line under the top bar (the date, a hint, where a code was sent).
/// Replaces the big heading: the screen's name is already in the top bar.
class AppScreenIntro extends StatelessWidget {
  const AppScreenIntro(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      12,
      AppSpacing.gutter,
      0,
    ),
    child: Text(text, style: AppText.small),
  );
}

/// Screen heading: L kicker, H1, description, short animated blue underline.
/// No longer used by the screens (see [AppTopBar] and [AppScreenIntro]).
/// Order is fixed: Kicker -> H1 -> description -> underline.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.kicker,
    this.subtitle,
  });

  final String title;
  final String? kicker;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        20,
        AppSpacing.gutter,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kicker != null)
            Row(
              children: [
                const LTick(opacity: 1, height: 15),
                const SizedBox(width: 8),
                Text(
                  kicker!,
                  style: AppText.small.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          Text(title, style: AppText.h1),
          if (subtitle != null) Text(subtitle!, style: AppText.small),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.progress,
            curve: AppMotion.easeOut,
            builder: (context, v, _) => Transform.scale(
              scaleX: v,
              alignment: AlignmentDirectional.centerStart,
              child: Container(width: 56, height: 2, color: AppColors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + rise 16px, delayed by [index] * 60ms. Wrap list items for the
/// staggered reveal when a screen opens.
class AppReveal extends StatelessWidget {
  const AppReveal({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = AppMotion.stagger.inMilliseconds * index.clamp(0, 6);
    final total = AppMotion.reveal.inMilliseconds + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: AppMotion.easeOut),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Standard screen: top bar -> header -> staggered content.
///
///   AppScreen(
///     title: 'طلب إجازة', showBack: true,
///     kicker: 'الإجازات', heading: 'طلب إجازة جديد', subtitle: '...',
///     children: [ ... ],
///   )
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    this.title,
    this.showBack = false,
    this.topBarLeading,
    this.actions = const [],
    this.kicker,
    this.heading,
    this.subtitle,
    this.children = const [],
    this.body,
    this.bottomBar,
    this.floatingActionButton,
    this.onRefresh,
    this.stagger = true,
  });

  final String? title;
  final bool showBack;
  final Widget? topBarLeading;
  final List<Widget> actions;
  final String? kicker;
  final String? heading;
  final String? subtitle;

  /// Content blocks, spaced 16px apart with the screen gutter.
  final List<Widget> children;

  /// Use instead of [children] for fully custom bodies (lists, tabs).
  final Widget? body;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;
  final bool stagger;

  @override
  Widget build(BuildContext context) {
    Widget content =
        body ??
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            if (subtitle != null) AppScreenIntro(subtitle!),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.s4),
                    stagger
                        ? AppReveal(index: i, child: children[i])
                        : children[i],
                  ],
                ],
              ),
            ),
          ],
        );
    if (onRefresh != null && body == null) {
      content = RefreshIndicator(
        color: AppColors.blue,
        onRefresh: onRefresh!,
        child: content,
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        title: title ?? heading,
        showBack: showBack,
        actions: actions,
        leading: topBarLeading,
      ),
      body: content,
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

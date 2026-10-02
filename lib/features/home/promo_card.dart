import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/pressable.dart';

/// The announcement card in the middle of home: a NEW tag, a headline, one line
/// of text, a button and a small drawing of the app on a phone. Soft blue, the
/// colors of the brand.
class HomePromoCard extends StatelessWidget {
  const HomePromoCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFFEAF3FF), Color(0xFFD3E6FF)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(AppRadius.xs + 2),
                  ),
                  child: Text(
                    l.promoNew,
                    style: AppText.xs.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l.promoTitle,
                  style: AppText.h2.copyWith(fontSize: 20, height: 1.25),
                ),
                const SizedBox(height: 6),
                Text(
                  l.promoBody,
                  style: AppText.small.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                Pressable(
                  onTap: onTap,
                  scale: .97,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l.promoButton,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const AppIcon(
                          AppIcons.forward,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _PhoneArt(),
        ],
      ),
    );
  }
}

/// A phone showing a profile, a small blue chart card in front and a few
/// sparkle strokes, drawn with plain boxes (no image file).
class _PhoneArt extends StatelessWidget {
  const _PhoneArt();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h) => Container(
      width: 7,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    Widget line(double w) => Container(
      width: w,
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    Widget spark(double angle) => Transform.rotate(
      angle: angle,
      child: Container(
        width: 12,
        height: 3,
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: 112,
        height: 136,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              top: 2,
              end: 4,
              child: Transform.rotate(
                angle: .14,
                child: Container(
                  width: 74,
                  height: 124,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.navy, width: 3),
                    boxShadow: AppShadows.sh1,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.blue,
                        ),
                        child: const Center(
                          child: AppIcon(
                            AppIcons.user,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      line(40),
                      const SizedBox(height: 5),
                      line(30),
                      const SizedBox(height: 5),
                      line(36),
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: 6,
              start: 0,
              child: Container(
                width: 58,
                height: 44,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppShadows.sh1,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [bar(12), bar(20), bar(28)],
                ),
              ),
            ),
            PositionedDirectional(top: 14, start: 6, child: spark(-.7)),
            PositionedDirectional(top: 4, start: 26, child: spark(-1.5)),
            PositionedDirectional(top: 28, start: 0, child: spark(.1)),
          ],
        ),
      ),
    );
  }
}

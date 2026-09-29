import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'app_icon.dart';
import 'pressable.dart';

class AppNavItem {
  const AppNavItem({required this.icon, required this.label, this.badge});
  final AppIconData icon;
  final String label;

  /// Unread count shown as a red dot (0 / null = hidden).
  final int? badge;
}

/// Bottom tab bar: 3-5 items, 64px, translucent white with a top border.
/// Active item turns blue, lifts 2px and shows a slanted 28x2 indicator.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        border: const Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.tabBar,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    active: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final AppNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.blue : AppColors.muted;
    return Pressable(
      onTap: onTap,
      scale: .94,
      semanticLabel: item.label,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSlide(
                duration: AppMotion.ui,
                curve: AppMotion.easeOut,
                offset: Offset(0, active ? -.06 : 0),
                child: AppIcon(
                  item.icon,
                  size: 23,
                  color: color,
                  accentOpacity: active ? .3 : .16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: AppText.xs.copyWith(
                  fontSize: 11,
                  color: color,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            child: AnimatedContainer(
              duration: AppMotion.ui,
              curve: AppMotion.easeOut,
              width: active ? 28 : 0,
              height: 2,
              transform: Matrix4.skewX(-0.2705),
              color: AppColors.blue,
            ),
          ),
          if ((item.badge ?? 0) > 0)
            PositionedDirectional(
              top: 8,
              end: 22,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.badge}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

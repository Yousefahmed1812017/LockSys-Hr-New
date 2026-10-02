import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'app_icon.dart';
import 'pressable.dart';

/// One tab of [AppIconTabs]: an icon over a short label.
class AppTabSpec {
  const AppTabSpec(this.label, this.icon, {this.rotated = false});
  final String label;
  final AppIconData icon;

  /// Turns the icon 45 degrees (a plus becomes a cross).
  final bool rotated;
}

/// Tabs as one rectangle across the screen: equal tabs, each an icon over its
/// label, the selected one raised on white. Used where a screen has a few
/// states to switch between (my leave, approvals).
class AppIconTabs extends StatelessWidget {
  const AppIconTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<AppTabSpec> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                label: tabs[i].label,
                excludeSemantics: true,
                child: Pressable(
                  onTap: () => onChanged(i),
                  scale: .97,
                  child: AnimatedContainer(
                    duration: AppMotion.ui,
                    curve: AppMotion.easeOut,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 2,
                    ),
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: i == selectedIndex ? AppShadows.sh1 : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _icon(tabs[i], i == selectedIndex),
                        const SizedBox(height: 3),
                        Text(
                          tabs[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppText.xs.copyWith(
                            fontWeight: i == selectedIndex
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == selectedIndex
                                ? AppColors.navy
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _icon(AppTabSpec t, bool selected) {
    final icon = AppIcon(
      t.icon,
      size: 20,
      color: selected ? AppColors.blue : AppColors.muted,
    );
    return t.rotated ? Transform.rotate(angle: .785398, child: icon) : icon;
  }
}

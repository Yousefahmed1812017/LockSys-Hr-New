import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'pressable.dart';

/// Horizontal scrollable filter chips. Selected = navy fill, white text.
class AppChipRow extends StatelessWidget {
  const AppChipRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = i == selectedIndex;
          return Pressable(
            onTap: () => onSelected(i),
            scale: .96,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: on ? AppColors.navy : Colors.white,
                borderRadius: AppRadius.btnAll,
                border: Border.all(
                  color: on ? AppColors.navy : AppColors.lineStrong,
                ),
              ),
              child: Text(
                labels[i],
                style: AppText.small.copyWith(
                  color: on ? Colors.white : AppColors.navy,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Segmented control (e.g. monthly / weekly / daily).
class AppSegmented extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(i),
                scale: .97,
                child: AnimatedContainer(
                  duration: AppMotion.ui,
                  curve: AppMotion.easeOut,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: i == selectedIndex ? AppShadows.sh1 : null,
                  ),
                  child: Text(
                    labels[i],
                    style: AppText.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: i == selectedIndex
                          ? AppColors.blue
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

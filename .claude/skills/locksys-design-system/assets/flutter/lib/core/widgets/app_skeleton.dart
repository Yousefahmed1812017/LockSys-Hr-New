import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

const _base = Color(0xFFEEF3F9);
const _highlight = Color(0xFFF7FAFD);

/// Wraps skeleton boxes and sweeps one shimmer across all of them (1.4s loop).
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.skeleton)
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          colors: const [_base, _highlight, _base],
          stops: const [.25, .5, .75],
          transform: _Slide(_c.value * 2 - 1),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.percent);
  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}

/// A grey block. Must sit inside [AppShimmer].
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _base,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// One list row: square icon + two text lines.
class AppSkeletonTile extends StatelessWidget {
  const AppSkeletonTile({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AppSkeletonBox(width: 40, height: 40, radius: 8),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: .6,
                    child: AppSkeletonBox(height: 12),
                  ),
                  SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: .35,
                    child: AppSkeletonBox(height: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Bordered group of skeleton rows, same shape as [AppListGroup].
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.count = 3});
  final int count;

  @override
  Widget build(BuildContext context) => AppShimmer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const Divider(),
                const AppSkeletonTile(),
              ],
            ],
          ),
        ),
      );
}

/// Full-width card placeholder.
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key, this.height = 86});
  final double height;

  @override
  Widget build(BuildContext context) => AppShimmer(
        child: AppSkeletonBox(
          width: double.infinity,
          height: height,
          radius: 8,
        ),
      );
}

/// Shows [skeleton] while [loading], then fades to [child] (300ms).
/// Every screen that loads data MUST use this (or an equivalent skeleton).
class AppLoadable extends StatelessWidget {
  const AppLoadable({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: AppMotion.ui,
        switchInCurve: AppMotion.easeOut,
        child: KeyedSubtree(
          key: ValueKey(loading),
          child: loading ? skeleton : child,
        ),
      );
}

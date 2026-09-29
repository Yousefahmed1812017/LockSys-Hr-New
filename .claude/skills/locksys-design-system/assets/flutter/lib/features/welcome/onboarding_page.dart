import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_language_toggle.dart';
import '../../core/widgets/app_logo_mark.dart';
import '../../core/widgets/l_pattern.dart';
import '../../l10n/app_localizations.dart';

/// 3 welcome screens shown on first launch only. One idea per screen.
/// Top row: brand mark (start) + language toggle and Skip (end).
/// "Skip" is hidden on the last screen. [onDone] fires from Skip and from
/// "Get started".
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pc = PageController();
  int _i = 0;
  static const _count = 3;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_i == _count - 1) {
      widget.onDone();
    } else {
      _pc.nextPage(duration: AppMotion.page, curve: AppMotion.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final last = _i == _count - 1;
    final copy = [
      (l.onb1Title, l.onb1Desc),
      (l.onb2Title, l.onb2Desc),
      (l.onb3Title, l.onb3Desc),
    ];
    final arts = <Widget>[
      _ArtFrame(builder: (w, h) => _attendanceArt(w, h, l)),
      _ArtFrame(builder: (w, h) => _leaveArt(w, h, l)),
      _ArtFrame(builder: (w, h) => _payrollArt(w, h, l)),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const AppLogoMark(height: 32),
                    const Spacer(),
                    const AppLanguageToggle(),
                    const SizedBox(width: 12),
                    Opacity(
                      opacity: last ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: last,
                        child: AppTextLink(l.skip, onTap: widget.onDone),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _count,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: arts[i]),
                      const SizedBox(height: 22),
                      Text(copy[i].$1, style: AppText.h1.copyWith(fontSize: 26)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: Text(copy[i].$2, style: AppText.bodyMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var k = 0; k < _count; k++)
                        AnimatedContainer(
                          duration: AppMotion.ui,
                          curve: AppMotion.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: k == _i ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: k == _i
                                ? AppColors.blue
                                : AppColors.lineStrong,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: last ? l.start : l.next,
                    size: AppButtonSize.lg,
                    icon: AppIcons.forward,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- art ----

/// Framed illustration area: soft gradient, faded L pattern, big L outline.
class _ArtFrame extends StatelessWidget {
  const _ArtFrame({required this.builder});
  final List<Widget> Function(double w, double h) builder;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.line),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.blue50, Colors.white],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          return Stack(
            children: [
              const Positioned.fill(child: LPattern(fade: true)),
              PositionedDirectional(
                end: -w * .12,
                bottom: -h * .08,
                child: Opacity(
                  opacity: .18,
                  child: AppLogo(
                    height: w * .78 * 40 / 30,
                    strokeUnits: .9,
                  ),
                ),
              ),
              ...builder(w, h),
            ],
          );
        },
      ),
    );
  }
}

List<Widget> _attendanceArt(double w, double h, AppLocalizations l) => [
      const Center(child: _Hub()),
      PositionedDirectional(
        top: h * .12,
        start: w * .07,
        child: _Floaty(
          child: _FloatCard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIconTile(AppIcons.location, size: 34),
                const SizedBox(width: 10),
                _Two(l.artBranch, l.artInRange),
              ],
            ),
          ),
        ),
      ),
      PositionedDirectional(
        bottom: h * .12,
        end: w * .07,
        child: _Floaty(
          delay: .5,
          child: _FloatCard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Two('08:02', l.artCheckinTime, mono: true),
                const SizedBox(width: 10),
                AppBadge(l.artPresent, tone: AppTone.success),
              ],
            ),
          ),
        ),
      ),
    ];

List<Widget> _leaveArt(double w, double h, AppLocalizations l) => [
      Center(
        child: SizedBox(
          width: math.min(236, w * .72),
          child: AppCard(
            showMark: false,
            elevated: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppIconTile(AppIcons.calendar, size: 36),
                    const SizedBox(width: 10),
                    Expanded(child: _Two(l.artAnnualLeave, l.artThreeDays)),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: [
                    for (var i = 0; i < 14; i++)
                      Container(
                        decoration: BoxDecoration(
                          color: (i >= 4 && i <= 6)
                              ? AppColors.blue
                              : AppColors.blueLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      PositionedDirectional(
        top: h * .12,
        start: w * .07,
        child: _Floaty(
          child: _FloatCard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIconTile(AppIcons.check,
                    size: 34, tone: AppTone.success),
                const SizedBox(width: 10),
                _Two(l.artApproved, l.artDirectManager),
              ],
            ),
          ),
        ),
      ),
      PositionedDirectional(
        bottom: h * .12,
        end: w * .07,
        child: _Floaty(
          delay: .5,
          child: _FloatCard(child: _Two(l.artBalanceDays, l.artBalanceLeft)),
        ),
      ),
    ];

List<Widget> _payrollArt(double w, double h, AppLocalizations l) {
  final cardW = math.min(236.0, w * .72);
  return [
    Positioned(
      top: h * .15,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: cardW,
          child: AppCard(
            navy: true,
            elevated: true,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.artNetSalary,
                    style: AppText.xs.copyWith(color: AppColors.onNavyMuted)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text('12,450',
                            style: AppText.stat
                                .copyWith(color: Colors.white, fontSize: 32)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(l.artCurrency,
                        style: AppText.xs.copyWith(color: AppColors.onNavyMuted)),
                  ],
                ),
                const SizedBox(height: 8),
                AppBadge(l.artTransferred, tone: AppTone.success, solid: true),
              ],
            ),
          ),
        ),
      ),
    ),
    Positioned(
      bottom: h * .13,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: math.min(206.0, w * .64),
          child: AppCard(
            showMark: false,
            elevated: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _Line(l.artBasic, '10,000'),
                const Divider(),
                _Line(l.artAllowances, '3,000'),
                const Divider(),
                _Line(l.artDeductions, '-550'),
              ],
            ),
          ),
        ),
      ),
    ),
    PositionedDirectional(
      top: h * .5,
      end: w * .05,
      child: _Floaty(
        delay: .5,
        child: _FloatCard(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIconTile(AppIcons.shield, size: 34),
              const SizedBox(width: 10),
              _Two(l.artProtected, l.artPdpl),
            ],
          ),
        ),
      ),
    ),
  ];
}

class _Two extends StatelessWidget {
  const _Two(this.title, this.sub, {this.mono = false});
  final String title;
  final String sub;
  final bool mono;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (mono ? AppText.mono : AppText.label)
                .copyWith(fontSize: 13, fontWeight: FontWeight.w700, height: 1.3),
          ),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.xs.copyWith(fontSize: 11, height: 1.3)),
        ],
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.xs.copyWith(fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(value,
                textDirection: TextDirection.ltr,
                style: AppText.mono.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _FloatCard extends StatelessWidget {
  const _FloatCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.sh2,
        ),
        child: child,
      );
}

/// Gentle vertical float (6px, 5s loop). [delay] 0..1 shifts the phase.
class _Floaty extends StatefulWidget {
  const _Floaty({required this.child, this.delay = 0});
  final Widget child;
  final double delay;

  @override
  State<_Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<_Floaty> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
    value: widget.delay,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -6 * AppMotion.easeInOut.transform(_c.value)),
          child: child,
        ),
      );
}

/// Navy fingerprint tile with two expanding ripple rings.
class _Hub extends StatefulWidget {
  const _Hub();

  @override
  State<_Hub> createState() => _HubState();
}

class _HubState extends State<_Hub> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _ring(double t) => Opacity(
        opacity: .5 * (1 - t),
        child: Transform.scale(
          scale: .9 + .7 * t,
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.blue, width: 2),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Stack(
              alignment: Alignment.center,
              children: [
                _ring(AppMotion.easeOut.transform(_c.value)),
                _ring(AppMotion.easeOut.transform((_c.value + .5) % 1)),
              ],
            ),
          ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.sh2,
            ),
            child: const Center(
              child: AppIcon(
                AppIcons.fingerprint,
                size: 56,
                color: Colors.white,
                accentColor: AppColors.blueBright,
                accentOpacity: .45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

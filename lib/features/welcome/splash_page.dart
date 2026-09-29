import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_logo_mark.dart';
import '../../core/widgets/l_pattern.dart';

/// Splash: white screen with the faded L pattern. The real LockSys mark
/// rises in, the name fades up, a thin progress bar fills. 2.6s total, then
/// [onFinished] fires once.
class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.onFinished,
    this.version = '1.0.0',
  });

  final VoidCallback onFinished;
  final String version;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.splash);
  late final Animation<double> _logo = CurvedAnimation(
    parent: _c,
    curve: const Interval(.05, .42, curve: AppMotion.easeOut),
  );
  late final Animation<double> _name = CurvedAnimation(
    parent: _c,
    curve: const Interval(.3, .58, curve: AppMotion.easeOut),
  );
  late final Animation<double> _bar = CurvedAnimation(
    parent: _c,
    curve: const Interval(.11, .96, curve: AppMotion.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final arabic = context.isArabic;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const RadialGradient(
                  center: Alignment(0, -.15),
                  radius: .8,
                  colors: [Colors.black, Colors.transparent],
                ).createShader(r),
                child: const LPattern(gap: 44),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logo,
                    child: ScaleTransition(
                      scale: Tween(begin: .88, end: 1.0).animate(_logo),
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, .08),
                          end: Offset.zero,
                        ).animate(_logo),
                        child: const AppLogoMark(height: 120),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _name,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, .3),
                        end: Offset.zero,
                      ).animate(_name),
                      child: Column(
                        children: [
                          Text(
                            'LockSys HR',
                            textDirection: TextDirection.ltr,
                            style: AppText.h1.copyWith(
                              fontSize: 30,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l.splashTagline,
                            style: AppText.xs.copyWith(
                              fontSize: 11,
                              // letter-spacing breaks Arabic letter joining
                              letterSpacing: arabic ? 0 : 3.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Stack(
                          children: [
                            Container(color: AppColors.blueLight),
                            AnimatedBuilder(
                              animation: _bar,
                              builder: (_, _) => FractionallySizedBox(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: _bar.value,
                                child: Container(color: AppColors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      l.versionLabel(widget.version),
                      style: AppText.xs.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

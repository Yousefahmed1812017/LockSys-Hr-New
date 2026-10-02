import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_icon.dart';
import '../../l10n/app_localizations.dart';

/// What the employee is asked to do in front of the camera.
enum FaceChallenge { right, left, up, down }

extension FaceChallengeX on FaceChallenge {
  /// Screen direction of the movement (the preview is mirrored like a selfie).
  Offset get direction => switch (this) {
    FaceChallenge.right => const Offset(1, 0),
    FaceChallenge.left => const Offset(-1, 0),
    FaceChallenge.up => const Offset(0, -1),
    FaceChallenge.down => const Offset(0, 1),
  };

  String text(AppLocalizations l) => switch (this) {
    FaceChallenge.right => l.faceRight,
    FaceChallenge.left => l.faceLeft,
    FaceChallenge.up => l.faceUp,
    FaceChallenge.down => l.faceDown,
  };
}

enum _Phase { ready, challenge, success, done }

/// Live face check: a camera with an oval, then three moves picked at random
/// ("turn right", "look up"...) so a photo or a screen cannot pass. Each move
/// shows an arrow and a ghost face doing it; the ring fills while the move is
/// held and turns green when it is done.
///
/// Simulated: the camera is drawn and every move is accepted after a moment.
/// The real version feeds the camera frames to a face detector at these points.
class FaceCheckView extends StatefulWidget {
  const FaceCheckView({
    super.key,
    required this.onVerified,
    this.confirmingLocation = false,
    this.random,
  });

  /// Called once all moves are done; the view waits for it to finish (the
  /// location is confirmed meanwhile).
  final Future<void> Function() onVerified;

  /// Show "Confirming your location..." after the moves.
  final bool confirmingLocation;
  final math.Random? random;

  @override
  State<FaceCheckView> createState() => _FaceCheckViewState();
}

class _FaceCheckViewState extends State<FaceCheckView>
    with TickerProviderStateMixin {
  static const _moves = 3;

  late final List<FaceChallenge> _challenges = ([
    ...FaceChallenge.values,
  ]..shuffle(widget.random ?? math.Random())).take(_moves).toList();
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final AnimationController _demo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  _Phase _phase = _Phase.ready;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _pauseClock?.dispose();
    _hold.dispose();
    _demo.dispose();
    super.dispose();
  }

  AnimationController? _pauseClock;

  Future<void> _pause(int ms) async {
    final c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );
    _pauseClock?.dispose();
    _pauseClock = c;
    try {
      await c.forward().orCancel;
    } on TickerCanceled {
      // The page closed.
    }
  }

  Future<void> _run() async {
    await _pause(1400);
    for (var i = 0; i < _moves; i++) {
      if (!mounted) return;
      setState(() {
        _index = i;
        _phase = _Phase.challenge;
      });
      try {
        await _hold.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
      if (!mounted) return;
      setState(() => _phase = _Phase.success);
      await _pause(700);
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.done);
    await widget.onVerified();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final challenge = _challenges[_index];
    final title = switch (_phase) {
      _Phase.ready => l.faceGetReady,
      _Phase.challenge => challenge.text(l),
      _Phase.success => l.faceHold,
      _Phase.done => l.faceVerified,
    };
    final ok = _phase == _Phase.success || _phase == _Phase.done;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        12,
        AppSpacing.gutter,
        16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _phase == _Phase.ready || _phase == _Phase.done
                    ? ''
                    : l.faceStepOf(_index + 1, _moves),
                textAlign: TextAlign.center,
                style: AppText.small,
              ),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: Listenable.merge([_hold, _demo]),
                builder: (context, _) => AspectRatio(
                  aspectRatio: .86,
                  child: ClipRRect(
                    borderRadius: AppRadius.mdAll,
                    child: CustomPaint(
                      painter: FaceFramePainter(
                        challenge: _phase == _Phase.challenge
                            ? challenge
                            : null,
                        progress: _phase == _Phase.challenge
                            ? _hold.value
                            : (ok ? 1 : 0),
                        demo: Curves.easeInOut.transform(_demo.value),
                        ok: ok,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: AppMotion.ui,
                child: Text(
                  title,
                  key: ValueKey('$_phase-$_index'),
                  textAlign: TextAlign.center,
                  style: AppText.h2.copyWith(
                    color: ok ? AppColors.success : AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _moves; i++)
                    AnimatedContainer(
                      duration: AppMotion.ui,
                      width: 28,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color:
                            i < _index ||
                                _phase == _Phase.done ||
                                (i == _index && _phase == _Phase.success)
                            ? AppColors.success
                            : (i == _index && _phase == _Phase.challenge
                                  ? AppColors.blue
                                  : AppColors.line),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (_phase == _Phase.done && widget.confirmingLocation)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        l.faceConfirmingLocation,
                        style: AppText.small,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppIcon(
                      AppIcons.shield,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(l.faceLiveNote, style: AppText.xs)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The frame over the camera: a dark preview, a ghost face that shows the move, an oval with
/// the progress ring, and an arrow on the side to move toward.
class FaceFramePainter extends CustomPainter {
  const FaceFramePainter({
    required this.challenge,
    required this.progress,
    required this.demo,
    required this.ok,
    this.live = false,
  });

  /// Over a real camera preview: no drawn background and no ghost face.
  final bool live;

  final FaceChallenge? challenge;
  final double progress;
  final double demo;
  final bool ok;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    if (!live) {
      canvas.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF123B6E), Color(0xFF071F3D)],
          ).createShader(full),
      );
    }

    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .46),
      width: size.width * .66,
      height: size.height * .66,
    );

    if (!live) {
      // The ghost face (head and shoulders) slides toward the move.
      final dir = challenge?.direction ?? Offset.zero;
      final shift = Offset(
        dir.dx * oval.width * .16 * demo,
        dir.dy * oval.height * .1 * demo,
      );
      final ghost = Paint()..color = Colors.white.withValues(alpha: .16);
      final head = oval.center + shift;
      canvas.drawOval(
        Rect.fromCenter(
          center: head.translate(0, -oval.height * .04),
          width: oval.width * .56,
          height: oval.height * .62,
        ),
        ghost,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2 + shift.dx * .5, size.height * .98),
          width: size.width * .86,
          height: size.height * .42,
        ),
        ghost,
      );
    }

    // Dark scrim with the oval cut out.
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(full)
      ..addOval(oval);
    canvas.drawPath(
      scrim,
      Paint()..color = const Color(0xFF020B18).withValues(alpha: .55),
    );

    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ok ? AppColors.success : Colors.white.withValues(alpha: .85),
    );

    if (progress > 0) {
      final path = Path()..addOval(oval);
      for (final m in path.computeMetrics()) {
        canvas.drawPath(
          m.extractPath(0, m.length * progress),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..color = ok ? AppColors.success : AppColors.blueBright,
        );
      }
    }

    final c = challenge;
    if (c != null) _arrow(canvas, oval, c.direction, demo);
  }

  void _arrow(Canvas canvas, Rect oval, Offset d, double t) {
    final c =
        oval.center +
        Offset(
          d.dx * (oval.width / 2 + 26 + 6 * t),
          d.dy * (oval.height / 2 + 26 + 6 * t),
        );
    final perp = Offset(-d.dy, d.dx);
    final tip = c + d * 12;
    final a = c - d * 8 + perp * 14;
    final b = c - d * 8 - perp * 14;
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(b.dx, b.dy),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(FaceFramePainter old) =>
      old.challenge != challenge ||
      old.progress != progress ||
      old.demo != demo ||
      old.ok != ok ||
      old.live != live;
}

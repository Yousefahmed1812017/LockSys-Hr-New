import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_icon.dart';
import 'face_check_view.dart';
import 'face_liveness.dart';

/// Live face check with the real front camera. The preview shows inside an oval;
/// every frame goes to the on-device face detector (ML Kit) and [LivenessSession]
/// decides: one real face in front of the camera, facing it, then three random
/// moves (turn right / left, look up / down), each held for a moment. A photo, a
/// video or a screen cannot follow moves it has never seen.
///
/// Nothing leaves the phone: the frames are analysed here and dropped.
///
/// NOTE for the first run on a real phone: [LivenessSession.yawRightSign] says
/// whether the detector's positive yaw is the person's right or left. If "turn
/// right" is accepted when turning left, flip that one constant.
class LiveFaceCheckView extends StatefulWidget {
  const LiveFaceCheckView({
    super.key,
    required this.onVerified,
    required this.onRetry,
    this.confirmingLocation = false,
    this.random,
  });

  final Future<void> Function() onVerified;

  /// The employee asked to try again after a failed check.
  final VoidCallback onRetry;
  final bool confirmingLocation;
  final math.Random? random;

  @override
  State<LiveFaceCheckView> createState() => _LiveFaceCheckViewState();
}

class _LiveFaceCheckViewState extends State<LiveFaceCheckView>
    with SingleTickerProviderStateMixin {
  static const _moves = 3;

  late final List<FaceChallenge> _challenges = ([
    ...FaceChallenge.values,
  ]..shuffle(widget.random ?? math.Random())).take(_moves).toList();
  late final LivenessSession _session = LivenessSession(_challenges);
  late final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: .2,
    ),
  );
  late final AnimationController _demo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  CameraController? _camera;
  LivenessStatus _status = const LivenessStatus(
    phase: LivenessPhase.ready,
    index: 0,
    progress: 0,
    guide: FaceGuide.none,
  );
  bool _busy = false;
  bool _starting = true;
  bool _cameraDenied = false;
  bool _failedToStart = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _demo.dispose();
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      unawaited(() async {
        try {
          if (camera.value.isStreamingImages) await camera.stopImageStream();
        } catch (_) {}
        await camera.dispose();
      }());
    }
    unawaited(_detector.close());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _cameraDenied = false;
      _failedToStart = false;
    });
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      await controller.startImageStream(_onFrame);
      if (mounted) setState(() => _starting = false);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _cameraDenied = e.code.toLowerCase().contains('denied');
        _failedToStart = !_cameraDenied;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _starting = false;
          _failedToStart = true;
        });
      }
    }
  }

  InputImage? _toInput(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    final camera = _camera;
    if (_busy || camera == null || _reported) return;
    _busy = true;
    try {
      final input = _toInput(image, camera.description);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted) return;
      // The frame is rotated by the sensor: the upright width is the short side.
      final width = math.min(image.width, image.height).toDouble();
      final face = faces.length == 1 ? faces.first : null;
      final sample = FaceSample(
        faces: faces.length,
        yaw: face?.headEulerAngleY ?? 0,
        pitch: face?.headEulerAngleX ?? 0,
        sizeRatio: face == null ? 0 : face.boundingBox.width / width,
      );
      final status = _session.update(sample, DateTime.now());
      setState(() => _status = status);
      if (status.phase == LivenessPhase.done) await _finish();
    } catch (_) {
      // One bad frame: the next one will do.
    } finally {
      _busy = false;
    }
  }

  Future<void> _finish() async {
    if (_reported) return;
    _reported = true;
    final camera = _camera;
    if (camera != null && camera.value.isStreamingImages) {
      try {
        await camera.stopImageStream();
      } catch (_) {}
    }
    await widget.onVerified();
  }

  String _guideText(BuildContext context, FaceGuide g) {
    final l = context.l10n;
    return switch (g) {
      FaceGuide.noFace => l.faceNoFace,
      FaceGuide.multiple => l.faceMultiple,
      FaceGuide.tooFar => l.faceTooFar,
      FaceGuide.tooClose => l.faceTooClose,
      FaceGuide.lookStraight => l.faceLookStraight,
      FaceGuide.none => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_cameraDenied || _failedToStart) {
      return AppEmptyState(
        icon: AppIcons.camera,
        tone: AppTone.danger,
        title: _cameraDenied
            ? l.faceCameraDeniedTitle
            : l.faceCameraFailedTitle,
        message: _cameraDenied ? l.faceCameraDeniedMsg : l.faceCameraFailedMsg,
        actionLabel: l.blkRetry,
        onAction: _start,
      );
    }
    if (_status.phase == LivenessPhase.failed) {
      return AppEmptyState(
        icon: AppIcons.user,
        tone: AppTone.danger,
        title: l.faceFailedTitle,
        message: l.faceFailedMsg,
        actionLabel: l.blkRetry,
        onAction: widget.onRetry,
      );
    }

    final s = _status;
    final challenge = s.index < _moves ? _challenges[s.index] : null;
    final moving = s.phase == LivenessPhase.challenge && challenge != null;
    final ok =
        s.phase == LivenessPhase.success || s.phase == LivenessPhase.done;
    final guide = _guideText(context, s.guide);
    final title = guide.isNotEmpty
        ? guide
        : switch (s.phase) {
            LivenessPhase.ready => l.faceGetReady,
            LivenessPhase.challenge => challenge!.text(l),
            LivenessPhase.success => l.faceHold,
            _ => l.faceVerified,
          };
    final camera = _camera;
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
                moving || s.phase == LivenessPhase.success
                    ? l.faceStepOf(math.min(s.index + 1, _moves), _moves)
                    : '',
                textAlign: TextAlign.center,
                style: AppText.small,
              ),
              const SizedBox(height: 6),
              AspectRatio(
                aspectRatio: .86,
                child: ClipRRect(
                  borderRadius: AppRadius.mdAll,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFF071F3D)),
                      if (camera != null && camera.value.isInitialized)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: camera.value.previewSize!.height,
                            height: camera.value.previewSize!.width,
                            child: CameraPreview(camera),
                          ),
                        ),
                      if (_starting)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      AnimatedBuilder(
                        animation: _demo,
                        builder: (context, _) => CustomPaint(
                          painter: FaceFramePainter(
                            challenge: moving ? challenge : null,
                            progress: ok ? 1 : s.progress,
                            demo: Curves.easeInOut.transform(_demo.value),
                            ok: ok,
                            live: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: AppMotion.ui,
                child: Text(
                  title,
                  key: ValueKey('${s.phase}-${s.index}-$guide'),
                  textAlign: TextAlign.center,
                  style: AppText.h2.copyWith(
                    color: ok
                        ? AppColors.success
                        : (guide.isNotEmpty
                              ? AppColors.warning
                              : AppColors.navy),
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
                        color: i < s.index || s.phase == LivenessPhase.done
                            ? AppColors.success
                            : (i == s.index && moving
                                  ? AppColors.blue
                                  : AppColors.line),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (s.phase == LivenessPhase.done && widget.confirmingLocation)
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

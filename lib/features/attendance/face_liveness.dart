import 'face_check_view.dart' show FaceChallenge;

/// What the face detector saw in one camera frame.
class FaceSample {
  const FaceSample({
    required this.faces,
    this.yaw = 0,
    this.pitch = 0,
    this.sizeRatio = .5,
  });

  /// How many faces are in the frame.
  final int faces;

  /// Head turn left / right in degrees (see [LivenessSession.yawRightSign]).
  final double yaw;

  /// Head tilt up / down in degrees (positive = looking up).
  final double pitch;

  /// Width of the face as a share of the frame width.
  final double sizeRatio;
}

/// What the person must fix before the check can go on.
enum FaceGuide { none, noFace, multiple, tooFar, tooClose, lookStraight }

enum LivenessPhase { ready, challenge, success, done, failed }

/// A snapshot for the screen to draw.
class LivenessStatus {
  const LivenessStatus({
    required this.phase,
    required this.index,
    required this.progress,
    required this.guide,
  });
  final LivenessPhase phase;

  /// Which move of the challenges (0-based).
  final int index;

  /// 0..1: how long the current move has been held.
  final double progress;
  final FaceGuide guide;
}

/// The rules of the live check, apart from the camera so they can be tested:
/// one real face must be in front of the camera, steady and facing it; then it
/// must do each requested move (turn right / left, look up / down) and hold it
/// for a moment. Moves are picked at random by the caller, so a photo or a video
/// cannot be prepared in advance. Time is passed in, never read.
class LivenessSession {
  LivenessSession(this.challenges);

  final List<FaceChallenge> challenges;

  /// Degrees of head turn that count as a move.
  static const turnDegrees = 20.0;
  static const nodDegrees = 14.0;

  /// Degrees within which the head counts as facing the camera.
  static const straightDegrees = 12.0;

  static const readyHold = Duration(milliseconds: 700);
  static const moveHold = Duration(milliseconds: 450);
  static const successPause = Duration(milliseconds: 600);
  static const moveTimeout = Duration(seconds: 14);

  /// +1 when ML Kit's positive yaw is the person's right, -1 when it is their
  /// left. Check on a real phone (see the note in the camera view).
  static const yawRightSign = -1.0;

  LivenessPhase _phase = LivenessPhase.ready;
  int _index = 0;
  DateTime? _since; // when the current condition started to hold
  DateTime? _phaseStart; // when the current phase started
  bool _sawStraight = true; // must face the camera again between moves
  double _progress = 0;
  FaceGuide _guide = FaceGuide.none;

  LivenessPhase get phase => _phase;

  LivenessStatus get status => LivenessStatus(
    phase: _phase,
    index: _index,
    progress: _progress,
    guide: _guide,
  );

  bool _straight(FaceSample s) =>
      s.yaw.abs() <= straightDegrees && s.pitch.abs() <= straightDegrees;

  bool _doing(FaceChallenge c, FaceSample s) {
    switch (c) {
      case FaceChallenge.right:
        return s.yaw * yawRightSign >= turnDegrees;
      case FaceChallenge.left:
        return s.yaw * yawRightSign <= -turnDegrees;
      case FaceChallenge.up:
        return s.pitch >= nodDegrees;
      case FaceChallenge.down:
        return s.pitch <= -nodDegrees;
    }
  }

  /// Feeds one frame. Returns the new status.
  LivenessStatus update(FaceSample s, DateTime now) {
    if (_phase == LivenessPhase.done || _phase == LivenessPhase.failed) {
      return status;
    }
    _phaseStart ??= now;

    // After a passed move: a short pause, then the next move.
    if (_phase == LivenessPhase.success) {
      if (now.difference(_phaseStart!) >= successPause) {
        _index++;
        _phase = _index >= challenges.length
            ? LivenessPhase.done
            : LivenessPhase.challenge;
        _phaseStart = now;
        _since = null;
        _progress = 0;
        _sawStraight = false;
      }
      return status;
    }

    // Is there one real face of the right size?
    if (s.faces == 0) {
      _guide = FaceGuide.noFace;
    } else if (s.faces > 1) {
      _guide = FaceGuide.multiple;
    } else if (s.sizeRatio < .25) {
      _guide = FaceGuide.tooFar;
    } else if (s.sizeRatio > .8) {
      _guide = FaceGuide.tooClose;
    } else {
      _guide = FaceGuide.none;
    }
    if (_guide != FaceGuide.none) {
      // Lost or wrong: the hold starts over.
      _since = null;
      _progress = 0;
      return status;
    }

    if (_phase == LivenessPhase.ready) {
      if (!_straight(s)) {
        _guide = FaceGuide.lookStraight;
        _since = null;
        _progress = 0;
        return status;
      }
      _since ??= now;
      _progress =
          (now.difference(_since!).inMilliseconds / readyHold.inMilliseconds)
              .clamp(0, 1)
              .toDouble();
      if (now.difference(_since!) >= readyHold) {
        _phase = LivenessPhase.challenge;
        _phaseStart = now;
        _since = null;
        _progress = 0;
        _sawStraight = true;
      }
      return status;
    }

    // challenge
    if (now.difference(_phaseStart!) > moveTimeout) {
      _phase = LivenessPhase.failed;
      return status;
    }
    if (_straight(s)) _sawStraight = true;
    final target = challenges[_index];
    if (_sawStraight && _doing(target, s)) {
      _since ??= now;
      _progress =
          (now.difference(_since!).inMilliseconds / moveHold.inMilliseconds)
              .clamp(0, 1)
              .toDouble();
      if (now.difference(_since!) >= moveHold) {
        _phase = LivenessPhase.success;
        _phaseStart = now;
        _progress = 1;
      }
    } else {
      _since = null;
      _progress = 0;
    }
    return status;
  }
}

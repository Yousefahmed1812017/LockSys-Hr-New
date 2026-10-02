import 'package:flutter_test/flutter_test.dart';
import 'package:lock_sys_hr/features/attendance/face_check_view.dart';
import 'package:lock_sys_hr/features/attendance/face_liveness.dart';

/// Drives a [LivenessSession] with frames 100 ms apart.
class _Clock {
  _Clock(this.session);
  final LivenessSession session;
  DateTime now = DateTime(2026, 10, 2, 9);

  LivenessStatus feed(FaceSample s, {int ms = 100}) {
    now = now.add(Duration(milliseconds: ms));
    return session.update(s, now);
  }

  /// Frames of [s] for [ms] milliseconds; returns the last status.
  LivenessStatus hold(FaceSample s, int ms) {
    LivenessStatus? last;
    for (var t = 0; t < ms; t += 100) {
      last = feed(s);
    }
    return last!;
  }
}

const _straight = FaceSample(faces: 1);

/// A head turn that counts as `right` for [LivenessSession.yawRightSign].
FaceSample _right() =>
    FaceSample(faces: 1, yaw: 30 * LivenessSession.yawRightSign);
FaceSample _left() =>
    FaceSample(faces: 1, yaw: -30 * LivenessSession.yawRightSign);

void main() {
  test('nobody in front of the camera: it asks for a face and waits', () {
    final c = _Clock(LivenessSession([FaceChallenge.up]));
    final s = c.hold(const FaceSample(faces: 0), 3000);
    expect(s.guide, FaceGuide.noFace);
    expect(s.phase, LivenessPhase.ready);
  });

  test('two people, a face too far or too close are not accepted', () {
    final c = _Clock(LivenessSession([FaceChallenge.up]));
    expect(c.feed(const FaceSample(faces: 2)).guide, FaceGuide.multiple);
    expect(
      c.feed(const FaceSample(faces: 1, sizeRatio: .1)).guide,
      FaceGuide.tooFar,
    );
    expect(
      c.feed(const FaceSample(faces: 1, sizeRatio: .9)).guide,
      FaceGuide.tooClose,
    );
    expect(c.session.phase, LivenessPhase.ready);
  });

  test('a face that is not facing the camera does not start the moves', () {
    final c = _Clock(LivenessSession([FaceChallenge.up]));
    final s = c.hold(FaceSample(faces: 1, yaw: 40), 2000);
    expect(s.phase, LivenessPhase.ready);
    expect(s.guide, FaceGuide.lookStraight);
  });

  test('a steady face starts the moves, then each move is held and passed', () {
    final c = _Clock(
      LivenessSession([
        FaceChallenge.right,
        FaceChallenge.up,
        FaceChallenge.left,
      ]),
    );
    expect(c.hold(_straight, 1000).phase, LivenessPhase.challenge);

    // Move 1: turn right. Held long enough -> success, then the next move.
    expect(c.hold(_right(), 300).phase, LivenessPhase.challenge); // not yet
    expect(c.hold(_right(), 300).phase, LivenessPhase.success);
    c.hold(_straight, 800);
    expect(c.session.status.index, 1);

    // Move 2: look up.
    c.hold(const FaceSample(faces: 1, pitch: 25), 700);
    c.hold(_straight, 800);
    expect(c.session.status.index, 2);

    // Move 3: turn left -> done.
    c.hold(_left(), 700);
    expect(c.hold(_straight, 800).phase, LivenessPhase.done);
  });

  test('the wrong move does not pass', () {
    final c = _Clock(LivenessSession([FaceChallenge.right]));
    c.hold(_straight, 1000);
    final s = c.hold(_left(), 2000); // asked right, turned left
    expect(s.phase, LivenessPhase.challenge);
    expect(s.progress, 0);
  });

  test('a move does not count again until the face is straight in between', () {
    final c = _Clock(
      LivenessSession([FaceChallenge.right, FaceChallenge.right]),
    );
    c.hold(_straight, 1000);
    c.hold(_right(), 700);
    c.hold(_right(), 800); // success pause passes, still turned right
    expect(c.session.status.index, 1);
    // Still turned: the second move cannot pass without facing the camera first.
    expect(c.hold(_right(), 2000).phase, LivenessPhase.challenge);
    c.hold(_straight, 300);
    c.hold(_right(), 700);
    expect(c.session.phase, anyOf(LivenessPhase.success, LivenessPhase.done));
  });

  test('losing the face during a move starts the hold over', () {
    final c = _Clock(LivenessSession([FaceChallenge.up]));
    c.hold(_straight, 1000);
    c.hold(const FaceSample(faces: 1, pitch: 25), 300);
    final lost = c.feed(const FaceSample(faces: 0));
    expect(lost.progress, 0);
    expect(lost.guide, FaceGuide.noFace);
  });

  test('a move that is never done fails after the time limit', () {
    final c = _Clock(LivenessSession([FaceChallenge.down]));
    c.hold(_straight, 1000);
    expect(c.hold(_straight, 15000).phase, LivenessPhase.failed);
  });
}

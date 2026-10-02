import 'package:flutter/material.dart';

import '../auth/auth_api.dart' show AuthException;
import 'attendance_api.dart';
import 'location_service.dart';

/// How an employee checks in, set per employee on the server
/// (APP_CHECKIN_BY_FACE / APP_CHECKIN_BY_LOCATION).
///   faceAndLocation  the employee sees a live face check; the location is
///                    confirmed silently from the phone in the background.
///   face             a live face check only.
///   location         a map showing the work area and where the employee is.
enum AttendanceMode { faceAndLocation, face, location }

/// Whether the face check is part of the mode.
extension AttendanceModeX on AttendanceMode {
  bool get usesFace => this != AttendanceMode.location;
  bool get usesLocation => this != AttendanceMode.face;
}

/// What the phone's own safety checks find. Used by the design preview to
/// show every blocking screen; the real checks read the phone.
enum DeviceProblem {
  none,
  locationOff,
  permissionDenied,
  mockLocation,
  vpn,
  developerOptions,
}

/// Today's attendance of the signed-in employee, shared by the attendance
/// screens and the check-in flow. It holds what the server says ([today]): the
/// employee's sites and work areas, how they check in, and where the day stands.
/// With a [MockAttendanceApi] (tests, no server) the design preview controls
/// change what the "server" answers.
class AttendanceController extends ChangeNotifier {
  AttendanceController({AttendanceApi? api, LocationService? location})
    : api = api ?? MockAttendanceApi() {
    this.location = location ?? SimulatedLocationService(this);
  }

  final AttendanceApi api;
  late final LocationService location;

  AttendanceToday? _today;
  bool _loading = false;
  AuthException? _error;
  bool _permissionsGranted = false;
  DeviceProblem _device = DeviceProblem.none;
  bool _outside = false;

  AttendanceToday? get today => _today;
  bool get loading => _loading;
  AuthException? get error => _error;

  /// True while the server is the design stand-in (the preview controls work).
  bool get simulated => api is MockAttendanceApi;

  /// Asks the server for today. Keeps the last answer when it fails.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _today = await api.today();
    } on AuthException catch (e) {
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }

  /// The server accepted a check-in / check-out: show it at once, then refresh.
  void applyResult(CheckResult r) {
    final t = _today;
    if (t != null) {
      _today = AttendanceToday(
        date: t.date,
        allowed: t.allowed,
        byLocation: t.byLocation,
        byFace: t.byFace,
        state: r.type == 'IN' ? 'IN' : 'DONE',
        checkInAt: r.type == 'IN' ? r.time : t.checkInAt,
        checkOutAt: r.type == 'OUT' ? r.time : null,
        mockPolicy: t.mockPolicy,
        sites: t.sites,
      );
      notifyListeners();
    }
    load();
  }

  DateTime? _at(String? hhmm) {
    final d = _today?.date ?? DateTime.now();
    final m = RegExp(r'^(\d\d):(\d\d)$').firstMatch(hhmm ?? '');
    if (m == null) return null;
    return DateTime(d.year, d.month, d.day, int.parse(m[1]!), int.parse(m[2]!));
  }

  DateTime? get checkInAt => _at(_today?.checkInAt);
  DateTime? get checkOutAt => _at(_today?.checkOutAt);

  bool get isCheckedIn => _today?.state == 'IN';
  bool get isDone => _today?.state == 'DONE';

  /// How this employee checks in (from the server; face + location until known).
  AttendanceMode get mode {
    final t = _today;
    if (t == null) return AttendanceMode.faceAndLocation;
    if (t.byFace && t.byLocation) return AttendanceMode.faceAndLocation;
    if (t.byFace) return AttendanceMode.face;
    if (t.byLocation) return AttendanceMode.location;
    return AttendanceMode.faceAndLocation;
  }

  /// The server lets this employee check in from the app.
  bool get allowed => _today?.allowed ?? true;

  /// Time at work so far (until check-out, or now).
  Duration? get worked {
    final start = checkInAt;
    if (start == null) return null;
    return (checkOutAt ?? DateTime.now()).difference(start);
  }

  /// The camera / location permissions were explained and allowed on this phone.
  bool get permissionsGranted => _permissionsGranted;

  void grantPermissions() {
    _permissionsGranted = true;
    notifyListeners();
  }

  // ---- design preview (only with the stand-in server) ----

  /// Design preview: the problem the phone reports (none = all good).
  DeviceProblem get device => _device;

  /// Design preview: the employee is outside the work area.
  bool get outside => _outside;

  void selectMode(AttendanceMode mode) {
    final mock = api;
    if (mock is! MockAttendanceApi) return;
    mock.byFace = mode.usesFace;
    mock.byLocation = mode.usesLocation;
    load();
  }

  /// What the company does with a fake location (BLOCK or RECORD).
  String get mockPolicy => _today?.mockPolicy ?? 'BLOCK';

  /// Design preview: change that policy.
  void selectMockPolicy(String policy) {
    final mock = api;
    if (mock is! MockAttendanceApi) return;
    mock.mockPolicy = policy;
    load();
  }

  void selectDevice(DeviceProblem problem) {
    _device = problem;
    notifyListeners();
  }

  void setOutside(bool value) {
    _outside = value;
    notifyListeners();
  }
}

/// Gives the screens under the home shell the same [AttendanceController].
class AttendanceScope extends InheritedNotifier<AttendanceController> {
  const AttendanceScope({
    super.key,
    required AttendanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AttendanceController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AttendanceScope>();
    assert(scope != null, 'AttendanceScope not found above this context');
    return scope!.notifier!;
  }
}

/// `08:02` in Western digits, in both languages.
String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// `4:12` for a duration of 4 h 12 min.
String formatDuration(Duration d) =>
    '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';

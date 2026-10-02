import 'attendance_state.dart';
import 'location_service.dart';

/// The phone's own safety checks before a check-in. Each finds one problem, or
/// none:
///   locationOff        location services are turned off
///   permissionDenied   the app may not use the location
///   mockLocation       a fake-location app or mock provider is active (found
///                      when the position is read, see [LocationService])
///   vpn                a VPN / proxy is on                  (to come)
///   developerOptions   developer options are on             (to come)
abstract interface class DeviceChecks {
  /// The first problem found, or [DeviceProblem.none].
  Future<DeviceProblem> run();
}

/// On the phone: the location checks that exist today.
class PhoneDeviceChecks implements DeviceChecks {
  const PhoneDeviceChecks(this.location);
  final LocationService location;

  @override
  Future<DeviceProblem> run() async {
    try {
      await location.requestPermission();
    } on DeviceProblemException catch (e) {
      return e.problem;
    }
    return DeviceProblem.none;
  }
}

/// Design preview: answers with the problem chosen on the attendance screen.
class SimulatedDeviceChecks implements DeviceChecks {
  const SimulatedDeviceChecks(this.controller);
  final AttendanceController controller;

  @override
  Future<DeviceProblem> run() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final p = controller.device;
    // A fake location is only found when the position is read.
    return p == DeviceProblem.mockLocation ? DeviceProblem.none : p;
  }
}

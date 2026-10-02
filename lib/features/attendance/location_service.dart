import 'package:geolocator/geolocator.dart';

import 'attendance_api.dart';
import 'attendance_state.dart';

/// Reads where the phone is. Throws [DeviceProblemException] when it cannot,
/// with what the employee must fix (location off, no permission).
abstract interface class LocationService {
  /// Asks for the permission (the system dialog) when it is not given yet.
  Future<void> requestPermission();

  Future<LocationFix> current();
}

class DeviceProblemException implements Exception {
  const DeviceProblemException(this.problem);
  final DeviceProblem problem;
}

/// The phone's GPS (geolocator). Also reports a fake / mock location provider.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<void> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceProblemException(DeviceProblem.locationOff);
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      throw const DeviceProblemException(DeviceProblem.permissionDenied);
    }
  }

  @override
  Future<LocationFix> current() async {
    await requestPermission();
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationFix(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyMeters: p.accuracy,
        isMock: p.isMocked,
      );
    } on LocationServiceDisabledException {
      throw const DeviceProblemException(DeviceProblem.locationOff);
    } on PermissionDeniedException {
      throw const DeviceProblemException(DeviceProblem.permissionDenied);
    }
  }
}

/// Design preview (tests, no phone): a fixed position inside or outside the
/// sample work area, or the problem chosen on the attendance screen.
class SimulatedLocationService implements LocationService {
  const SimulatedLocationService(this.controller);
  final AttendanceController controller;

  @override
  Future<void> requestPermission() async {
    final p = controller.device;
    if (p == DeviceProblem.locationOff || p == DeviceProblem.permissionDenied) {
      throw DeviceProblemException(p);
    }
  }

  @override
  Future<LocationFix> current() async {
    await requestPermission();
    const c = MockAttendanceApi.center;
    return LocationFix(
      latitude: controller.outside ? c.lat + .0022 : c.lat,
      longitude: c.lng,
      accuracyMeters: 8,
      isMock: controller.device == DeviceProblem.mockLocation,
    );
  }
}

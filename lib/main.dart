import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/local_secrets.dart';
import 'features/approvals/approvals_api.dart';
import 'features/attendance/attendance_api.dart';
import 'features/attendance/location_service.dart';
import 'features/auth/auth_api.dart';
import 'features/auth/session_store.dart';
import 'features/leave/leave_api.dart';
import 'features/company/api_company_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    LockSysApp(
      prefs: prefs,
      sessionStore: const SecureSessionStore(),
      attendanceApiFor: (company, session) =>
          HttpAttendanceApi(baseUrl: company.apiBaseUrl, token: session.token),
      locationService: const GeolocatorLocationService(),
      approvalsApiFor: (company, session) =>
          HttpApprovalsApi(baseUrl: company.apiBaseUrl, token: session.token),
      leaveApiFor: (company, session) =>
          HttpLeaveApi(baseUrl: company.apiBaseUrl, token: session.token),
      authApiFor: (company) => HttpAuthApi(
        baseUrl: company.apiBaseUrl,
        deviceId: () => deviceIdFrom(prefs),
      ),
      registry: ApiCompanyRegistry(
        username: const String.fromEnvironment(
          'API_USER',
          defaultValue: localApiUser,
        ),
        password: const String.fromEnvironment(
          'API_PASSWORD',
          defaultValue: localApiPassword,
        ),
      ),
    ),
  );
}

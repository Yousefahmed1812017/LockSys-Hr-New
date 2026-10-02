import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lock_sys_hr/app.dart';
import 'package:lock_sys_hr/features/auth/auth_api.dart';
import 'package:lock_sys_hr/features/auth/session_store.dart';
import 'package:lock_sys_hr/features/company/company.dart';
import 'package:lock_sys_hr/features/company/company_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _company = Company(
  code: '1000',
  name: 'Delta',
  arabicName: 'الدلتا',
  apiBaseUrl: 'https://x.example/',
  features: {AppFeature.auth, AppFeature.authPassword},
);

class _Registry implements CompanyRegistry {
  @override
  Future<Company> resolve(String code) async => _company;
}

/// Answers `me` the way the server does for a good or a dead token.
class _Api extends MockAuthApi {
  const _Api({this.error});
  final AuthException? error;

  @override
  Future<Map<String, dynamic>> me(String token) async {
    if (error != null) throw error!;
    return {'nameEn': 'Fresh Name', 'nameAr': 'اسم جديد'};
  }
}

const _dead = AuthException(
  code: 'TOKEN_INVALID',
  messageAr: 'انتهت الجلسة',
  messageEn: 'expired',
);

Future<MemorySessionStore> _open(
  WidgetTester t, {
  AuthSession? saved,
  AuthApi api = const _Api(),
}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({
    'onboarding_done': true,
    'app_locale': 'en',
    'company': jsonEncode(_company.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  final store = MemorySessionStore();
  if (saved != null) await store.save(saved);
  await t.pumpWidget(
    LockSysApp(
      prefs: prefs,
      registry: _Registry(),
      sessionStore: store,
      authApiFor: (_) => api,
    ),
  );
  await t.pump(const Duration(milliseconds: 2700));
  await t.pump(const Duration(milliseconds: 1500));
  await t.pump(const Duration(milliseconds: 1500));
  return store;
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a saved session opens the home without signing in', (t) async {
    await _open(
      t,
      saved: const AuthSession(
        token: 'abc',
        user: {'nameEn': 'Old Name', 'nameAr': 'اسم قديم'},
      ),
    );
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    // The data was refreshed from the server in the background.
    expect(find.text('Fresh Name'), findsOneWidget);
  });

  testWidgets('no saved session: the sign-in screen', (t) async {
    await _open(t);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Services'), findsNothing);
  });

  testWidgets('an expired session is dropped', (t) async {
    final store = await _open(
      t,
      saved: const AuthSession(token: 'abc', expiresAt: '2020-01-01T00:00:00Z'),
    );
    expect(find.text('Services'), findsNothing);
    expect(await store.load(), isNull);
  });

  testWidgets('a token the server rejects sends back to sign-in', (t) async {
    final store = await _open(
      t,
      saved: const AuthSession(token: 'abc'),
      api: const _Api(error: _dead),
    );
    expect(find.text('Services'), findsNothing);
    expect(find.text('Sign in'), findsWidgets);
    expect(await store.load(), isNull);
  });

  testWidgets('no connection keeps the saved session', (t) async {
    final store = await _open(
      t,
      saved: const AuthSession(token: 'abc'),
      api: const _Api(error: AuthException.network()),
    );
    expect(find.text('Services'), findsOneWidget);
    expect(await store.load(), isNotNull);
  });
}

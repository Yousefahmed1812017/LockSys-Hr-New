import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lock_sys_hr/app.dart';
import 'package:lock_sys_hr/features/company/company.dart';
import 'package:lock_sys_hr/features/company/company_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fast = MockCompanyRegistry(delay: Duration(milliseconds: 50));

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(Duration(milliseconds: ms));
}

TextDirection dirOf(WidgetTester t, Finder f) =>
    Directionality.of(t.element(f.first));

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'splash -> onboarding -> language -> company code -> login -> home',
      (t) async {
    phone(t);
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(LockSysApp(prefs: prefs, registry: _fast));

    // Splash (Arabic, RTL by default)
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('LockSys HR'), findsOneWidget);
    expect(find.text('الموارد البشرية'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2700));
    await settle(t);

    // Onboarding in Arabic, then switch to English (LTR, persisted)
    expect(find.text('سجّل حضورك بلمسة واحدة'), findsOneWidget);
    expect(dirOf(t, find.text('التالي')), TextDirection.rtl);
    await t.tap(find.text('English'));
    await settle(t);
    expect(find.text('Check in with one touch'), findsOneWidget);
    expect(dirOf(t, find.text('Next')), TextDirection.ltr);
    expect(prefs.getString('app_locale'), 'en');
    for (var i = 0; i < 2; i++) {
      await t.tap(find.text('Next'));
      await settle(t);
    }
    await t.tap(find.text('Get started'));
    await settle(t, 800);
    expect(prefs.getBool('onboarding_done'), true);

    // Company code screen (first time only)
    expect(find.text('First step'), findsOneWidget);
    expect(find.text('Company code'), findsWidgets);
    final field = find.byType(TextFormField);

    // empty -> required error
    await t.ensureVisible(find.text('Verify code'));
    await t.tap(find.text('Verify code'));
    await settle(t);
    expect(find.text('Enter the company code'), findsOneWidget);

    // unknown code -> invalid error, nothing saved
    await t.enterText(field, 'nope1');
    await t.tap(find.text('Verify code'));
    await settle(t);
    expect(find.text('Invalid company code. Check it and try again.'),
        findsOneWidget);
    expect(prefs.getString('company'), isNull);

    // valid code (typed lower-case -> forced upper-case) -> found card
    await t.enterText(field, 'locksys');
    await t.tap(find.text('Verify code'));
    await settle(t);
    expect(find.text('LockSys Solutions'), findsOneWidget);
    expect(find.text('Available services'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Payslip'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // editing the code goes back to verifying
    await t.enterText(field, 'LOCKSYS1');
    await settle(t);
    expect(find.text('Verify code'), findsOneWidget);
    await t.enterText(field, 'LOCKSYS');
    await t.ensureVisible(find.text('Verify code'));
    await t.tap(find.text('Verify code'));
    await settle(t);

    // continue -> saved once, login shown
    await t.tap(find.text('Continue'));
    await settle(t, 800);
    final saved = jsonDecode(prefs.getString('company')!) as Map;
    expect(saved['code'], 'LOCKSYS');
    expect(saved['apiBaseUrl'], 'https://api.locksys.co');
    expect(saved['features'], containsAll(['attendance', 'leave', 'payslip']));

    // Login: validation, then sign in
    expect(find.text('Welcome back'), findsOneWidget);
    await t.ensureVisible(find.text('Sign in').last);
    await t.tap(find.text('Sign in').last);
    await settle(t);
    expect(find.text('Enter your username or employee number'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).first, 'EMP-0012');
    await t.enterText(find.byType(TextFormField).last, 'secret123');
    await t.tap(find.text('Sign in').last);
    await t.pump(const Duration(milliseconds: 1400));
    await settle(t, 1500);

    // Home, then language back to Arabic from the account tab
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Check in'), findsOneWidget);
    await t.tap(find.text('Account'));
    await settle(t);
    await t.tap(find.text('Language'));
    await settle(t);
    await t.tap(find.text('Arabic'));
    await settle(t);
    expect(find.text('حسابي'), findsWidgets);
    expect(prefs.getString('app_locale'), 'ar');
  });

  testWidgets('company code: offline error keeps the user on the screen',
      (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(LockSysApp(prefs: prefs, registry: _Offline()));
    await t.pump(const Duration(milliseconds: 2700));
    await settle(t, 800);
    expect(find.text('كود الشركة'), findsWidgets);
    await t.enterText(find.byType(TextFormField), 'LOCKSYS');
    await t.ensureVisible(find.text('تحقق من الكود'));
    await t.tap(find.text('تحقق من الكود'));
    await settle(t);
    expect(find.text('لا يوجد اتصال'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(prefs.getString('company'), isNull);
  });

  testWidgets('returning user with a saved company goes straight to login',
      (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'company': jsonEncode({
        'code': 'LOCKSYS',
        'name': 'LockSys Solutions',
        'apiBaseUrl': 'https://api.locksys.co',
        'features': ['attendance', 'leave', 'payslip'],
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(LockSysApp(prefs: prefs, registry: _fast));
    await t.pump(const Duration(milliseconds: 2700));
    await settle(t, 800);
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.text('كود الشركة'), findsNothing);
    expect(find.text('سجّل حضورك بلمسة واحدة'), findsNothing);
  });

  testWidgets('onboarded but no company yet asks for the code', (t) async {
    phone(t);
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(LockSysApp(prefs: prefs, registry: _fast));
    await t.pump(const Duration(milliseconds: 2700));
    await settle(t, 800);
    expect(find.text('كود الشركة'), findsWidgets);
  });
}

class _Offline implements CompanyRegistry {
  @override
  Future<Company> resolve(String code) async =>
      throw const CompanyRegistryUnavailableException();
}

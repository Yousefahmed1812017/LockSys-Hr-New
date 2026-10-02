import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lock_sys_hr/app.dart';
import 'package:lock_sys_hr/core/widgets/app_screen.dart';
import 'package:lock_sys_hr/features/auth/otp_flow.dart';
import 'package:lock_sys_hr/features/company/company.dart';
import 'package:lock_sys_hr/features/company/company_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A company with every sign-in feature on (what company 1000 has).
final _company = Company(
  code: '1000',
  name: 'Delta',
  arabicName: 'الدلتا',
  apiBaseUrl: 'https://x.example/',
  features: {
    for (final f in AppFeature.values)
      if (f.key.startsWith('auth')) f,
  },
);

class _Fixed implements CompanyRegistry {
  @override
  Future<Company> resolve(String code) async => _company;
}

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(Duration(milliseconds: ms));
}

/// Opens the app on the sign-in screen (company already saved).
Future<void> openLogin(
  WidgetTester t, {
  String locale = 'en',
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.platformDispatcher.clearAllTestValues);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({
    'onboarding_done': true,
    'app_locale': locale,
    'company': jsonEncode(_company.toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  await t.pumpWidget(LockSysApp(prefs: prefs, registry: _Fixed()));
  await t.pump(const Duration(milliseconds: 2700));
  await settle(t, 800);
}

Finder inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

Future<void> tapScrolled(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await settle(t);
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('masking keeps only what is safe to show', () {
    expect(maskPhone('+20 10 1234 5678'), '•••• 5678');
    expect(maskPhone('12'), '•••• 12');
    expect(maskEmail('mohamed@company.com'), 'm•••••@company.com');
    expect(maskEmail('not-an-email'), 'not-an-email');
  });

  testWidgets('sign in by mobile number: channel, code, home', (t) async {
    await openLogin(t);
    expect(find.text('Username'), findsOneWidget); // the three methods
    expect(find.text('Mobile'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);

    await t.tap(find.text('Mobile'));
    await settle(t);
    await tapScrolled(t, find.text('Send verification code'));
    expect(find.text('Enter your mobile number'), findsOneWidget);

    await t.enterText(find.byType(TextFormField), '12 ab');
    await tapScrolled(t, find.text('Send verification code'));
    expect(find.text('The mobile number is not valid'), findsOneWidget);

    await t.enterText(find.byType(TextFormField), '+20 10 1234 5678');
    await tapScrolled(t, find.text('Send verification code'));

    // Channel sheet: the three channels; phone is masked, e-mail is "on account".
    expect(find.text('How do you want to receive the code?'), findsOneWidget);
    expect(inSheet('Text message (SMS)'), findsOneWidget);
    expect(inSheet('WhatsApp'), findsOneWidget);
    expect(inSheet('Email'), findsOneWidget);
    expect(find.text('•••• 5678'), findsNWidgets(2)); // SMS + WhatsApp
    expect(find.text('The email on your account'), findsOneWidget);

    await t.tap(inSheet('WhatsApp'));
    await settle(t, 800);
    expect(find.text('Enter the verification code'), findsOneWidget);
    expect(find.textContaining('by WhatsApp'), findsOneWidget);
    expect(find.textContaining('5678'), findsOneWidget);

    // Verify with an incomplete code, then a complete one.
    await t.tap(find.text('Verify'));
    await settle(t);
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    await t.enterText(find.byType(TextField), '123456');
    await t.pump(const Duration(milliseconds: 1000));
    await settle(t, 1500);
    expect(find.text('Good morning'), findsOneWidget);
  });

  testWidgets('sign in by e-mail uses the typed address', (t) async {
    await openLogin(t);
    await t.tap(find.text('Email'));
    await settle(t);
    await t.enterText(find.byType(TextFormField), 'nope');
    await tapScrolled(t, find.text('Send verification code'));
    expect(find.text('The email address is not valid'), findsOneWidget);

    await t.enterText(find.byType(TextFormField), 'mohamed@company.com');
    await tapScrolled(t, find.text('Send verification code'));
    expect(find.text('m•••••@company.com'), findsOneWidget);
    expect(find.text('The mobile number on your account'), findsNWidgets(2));

    await t.tap(inSheet('Text message (SMS)'));
    await settle(t, 800);
    expect(find.textContaining('by text message'), findsOneWidget);
  });

  testWidgets('the code can be sent again after the countdown, or elsewhere', (
    t,
  ) async {
    await openLogin(t);
    await t.tap(find.text('Mobile'));
    await settle(t);
    await t.enterText(find.byType(TextFormField), '+201012345678');
    await tapScrolled(t, find.text('Send verification code'));
    await t.tap(inSheet('Text message (SMS)'));
    await settle(t, 800);

    expect(find.textContaining('You can resend in 0:'), findsOneWidget);
    expect(find.text('Resend code'), findsNothing);
    await t.pump(const Duration(seconds: 31));
    expect(find.text('Resend code'), findsOneWidget);
    await t.tap(find.text('Resend code'));
    await settle(t);
    expect(find.text('A new code was sent'), findsOneWidget);
    expect(find.textContaining('You can resend in 0:'), findsOneWidget);

    await t.tap(find.text('Change how you receive the code'));
    await settle(t);
    await t.tap(inSheet('Email'));
    await settle(t, 800);
    expect(find.textContaining('by email'), findsOneWidget);
  });

  testWidgets('forgot password by mobile number ends on the sign-in screen', (
    t,
  ) async {
    await openLogin(t);
    await tapScrolled(t, find.text('Forgot password?'));
    expect(
      find.descendant(
        of: find.byType(AppTopBar),
        matching: find.text('Forgot your password?'),
      ),
      findsOneWidget,
    );
    expect(find.text('Email address'), findsWidgets);
    expect(find.text('Mobile number'), findsOneWidget); // the second option

    await t.tap(find.text('Mobile number'));
    await settle(t);
    await t.enterText(find.byType(TextFormField), '+20 10 1234 5678');
    await tapScrolled(t, find.text('Send verification code'));
    await t.tap(inSheet('Text message (SMS)'));
    await settle(t, 800);
    expect(
      find.descendant(
        of: find.byType(AppTopBar),
        matching: find.text('Enter the verification code'),
      ),
      findsOneWidget,
    );

    await t.enterText(find.byType(TextField), '654321');
    await t.pump(const Duration(milliseconds: 1000));
    await settle(t, 1500);

    expect(find.text('Set a new password'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await t.enterText(fields.first, 'secret123');
    await t.enterText(fields.last, 'different');
    await tapScrolled(t, find.text('Save password'));
    expect(find.text('The passwords do not match'), findsOneWidget);

    await t.enterText(fields.last, 'secret123');
    await tapScrolled(t, find.text('Save password'));
    await t.pump(const Duration(milliseconds: 1000));
    await settle(t, 1000);
    expect(find.text('Welcome back'), findsOneWidget); // back on sign in
    expect(
      find.text('Your password was changed. Sign in with it.'),
      findsOneWidget,
    );
  });

  testWidgets('forgot password by e-mail', (t) async {
    await openLogin(t);
    await tapScrolled(t, find.text('Forgot password?'));
    await t.enterText(find.byType(TextFormField), 'mohamed@company.com');
    await tapScrolled(t, find.text('Send verification code'));
    expect(find.text('m•••••@company.com'), findsOneWidget);
    await t.tap(inSheet('Email'));
    await settle(t, 800);
    expect(find.textContaining('by email'), findsOneWidget);
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('no overflow at 320 px and large text ($locale)', (t) async {
      await openLogin(
        t,
        locale: locale,
        size: const Size(320, 640),
        textScale: 1.3,
      );
      expect(t.takeException(), isNull);

      Future<void> pass(String label) async {
        await t.tap(find.text(label));
        await settle(t);
        expect(t.takeException(), isNull, reason: 'login: $label');
      }

      final names = locale == 'ar'
          ? ['الموبايل', 'البريد', 'اسم المستخدم']
          : ['Mobile', 'Email', 'Username'];
      for (final n in names) {
        await pass(n);
      }

      // Code screen and recovery screens render without overflow too.
      await t.tap(find.text(names[0]));
      await settle(t);
      await t.enterText(find.byType(TextFormField), '+201012345678');
      await t.ensureVisible(
        find.text(
          locale == 'ar' ? 'إرسال رمز التحقق' : 'Send verification code',
        ),
      );
      await t.tap(
        find.text(
          locale == 'ar' ? 'إرسال رمز التحقق' : 'Send verification code',
        ),
      );
      await settle(t);
      await t.tap(inSheet(locale == 'ar' ? 'واتساب' : 'WhatsApp'));
      await settle(t, 800);
      expect(t.takeException(), isNull, reason: 'otp page');
    });
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lock_sys_hr/app.dart';
import 'package:lock_sys_hr/core/widgets/app_screen.dart';
import 'package:lock_sys_hr/features/company/company.dart';
import 'package:lock_sys_hr/features/company/company_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

Company company(Set<AppFeature> features) => Company(
  code: '1000',
  name: 'Delta',
  arabicName: 'الدلتا',
  apiBaseUrl: 'https://x.example/',
  features: features,
);

class _Registry implements CompanyRegistry {
  _Registry(this.company);
  final Company company;
  @override
  Future<Company> resolve(String code) async => company;
}

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(Duration(milliseconds: ms));
}

/// Opens sign in for a company that is saved on the device with [saved]
/// features, while the server answers with [server] (default: the same).
Future<void> openLogin(
  WidgetTester t,
  Set<AppFeature> saved, {
  Set<AppFeature>? server,
}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({
    'onboarding_done': true,
    'app_locale': 'en',
    'company': jsonEncode(company(saved).toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  await t.pumpWidget(
    LockSysApp(prefs: prefs, registry: _Registry(company(server ?? saved))),
  );
  await t.pump(const Duration(milliseconds: 2700));
  await settle(t, 800);
}

Finder inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

Future<void> tapScrolled(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await settle(t, 800);
}

const _auth = AppFeature.auth;
const _password = AppFeature.authPassword;

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('which sign-in methods appear', () {
    testWidgets('only username + password: no switch, no recovery link', (
      t,
    ) async {
      await openLogin(t, {_auth, _password});
      expect(find.text('Username or employee number'), findsOneWidget);
      expect(find.text('Mobile'), findsNothing);
      expect(find.text('Email'), findsNothing);
      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets('mobile and e-mail appear only when their feature is on', (
      t,
    ) async {
      await openLogin(t, {
        _auth,
        AppFeature.authEmail,
        AppFeature.authEmailViaEmail,
        AppFeature.authPhone,
        AppFeature.authPhoneViaSms,
      });
      // No password feature: the two code methods are the only choices.
      expect(find.text('Username'), findsNothing);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('a method with no delivery channel is not offered', (t) async {
      await openLogin(t, {_auth, _password, AppFeature.authPhone});
      expect(find.text('Mobile'), findsNothing);
      expect(find.text('Username or employee number'), findsOneWidget);
    });

    testWidgets('nothing on: explains instead of showing a blank form', (
      t,
    ) async {
      await openLogin(t, {});
      expect(find.text('Sign in is not available'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('a sub feature is off when its parent is off', (t) async {
      // auth itself missing: password and mobile are ignored.
      await openLogin(t, {
        _password,
        AppFeature.authPhone,
        AppFeature.authPhoneViaSms,
      });
      expect(find.text('Sign in is not available'), findsOneWidget);
    });
  });

  group('which code channels appear', () {
    testWidgets('one channel: the code screen opens straight away', (t) async {
      await openLogin(t, {
        _auth,
        _password,
        AppFeature.authPhone,
        AppFeature.authPhoneViaSms,
      });
      await t.tap(find.text('Mobile'));
      await settle(t);
      await t.enterText(find.byType(TextFormField), '+201012345678');
      await tapScrolled(t, find.text('Send verification code'));

      expect(find.text('How do you want to receive the code?'), findsNothing);
      expect(find.text('Enter the verification code'), findsOneWidget);
      expect(find.textContaining('by text message'), findsOneWidget);
      // Nothing to switch to, so no link to change the channel.
      expect(find.text('Change how you receive the code'), findsNothing);
    });

    testWidgets('two channels: the sheet lists only those two', (t) async {
      await openLogin(t, {
        _auth,
        AppFeature.authPhone,
        AppFeature.authPhoneViaSms,
        AppFeature.authPhoneViaWhatsapp,
      });
      // Mobile is the only method, so there is no switch and the field is shown.
      expect(find.text('Mobile'), findsNothing);
      await t.enterText(find.byType(TextFormField), '+201012345678');
      await tapScrolled(t, find.text('Send verification code'));

      expect(inSheet('Text message (SMS)'), findsOneWidget);
      expect(inSheet('WhatsApp'), findsOneWidget);
      expect(inSheet('Email'), findsNothing);
    });

    testWidgets('the channels of e-mail sign in do not leak from mobile', (
      t,
    ) async {
      await openLogin(t, {
        _auth,
        AppFeature.authPhone,
        AppFeature.authPhoneViaSms,
        AppFeature.authEmail,
        AppFeature.authEmailViaEmail,
      });
      await t.tap(find.text('Email'));
      await settle(t);
      await t.enterText(find.byType(TextFormField), 'mohamed@company.com');
      await tapScrolled(t, find.text('Send verification code'));
      // E-mail has one channel (e-mail): straight to the code screen.
      expect(find.textContaining('by email'), findsOneWidget);
    });
  });

  group('password recovery', () {
    final forgotByEmail = {
      _auth,
      _password,
      AppFeature.authForgot,
      AppFeature.authForgotEmail,
      AppFeature.authForgotEmailViaEmail,
    };

    testWidgets('no link when recovery has no method switched on', (t) async {
      await openLogin(t, {_auth, _password, AppFeature.authForgot});
      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets('link appears with a usable recovery method', (t) async {
      await openLogin(t, forgotByEmail);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('one method: no switch, only that field', (t) async {
      await openLogin(t, forgotByEmail);
      await tapScrolled(t, find.text('Forgot password?'));
      expect(
        find.descendant(
          of: find.byType(AppTopBar),
          matching: find.text('Forgot your password?'),
        ),
        findsOneWidget,
      );
      expect(find.text('Email address'), findsOneWidget); // the field label
      expect(find.text('Mobile number'), findsNothing); // no second option
      await t.enterText(find.byType(TextFormField), 'mohamed@company.com');
      await tapScrolled(t, find.text('Send verification code'));
      // One channel: straight to the code screen.
      expect(
        find.descendant(
          of: find.byType(AppTopBar),
          matching: find.text('Enter the verification code'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('by email'), findsOneWidget);
    });

    testWidgets('both methods: the switch offers e-mail and mobile', (t) async {
      await openLogin(t, {
        ...forgotByEmail,
        AppFeature.authForgotPhone,
        AppFeature.authForgotPhoneViaSms,
        AppFeature.authForgotPhoneViaWhatsapp,
      });
      await tapScrolled(t, find.text('Forgot password?'));
      expect(find.text('Email address'), findsWidgets);
      await t.tap(find.text('Mobile number'));
      await settle(t);
      await t.enterText(find.byType(TextFormField), '+201012345678');
      await tapScrolled(t, find.text('Send verification code'));
      // Mobile recovery has SMS + WhatsApp: the sheet shows only those.
      expect(inSheet('Text message (SMS)'), findsOneWidget);
      expect(inSheet('WhatsApp'), findsOneWidget);
      expect(inSheet('Email'), findsNothing);
    });
  });

  testWidgets('features changed on the server show up after launch', (t) async {
    await openLogin(
      t,
      {_auth, _password},
      server: {
        _auth,
        _password,
        AppFeature.authPhone,
        AppFeature.authPhoneViaSms,
      },
    );
    // The saved copy only had a password; the refresh brought the mobile method.
    expect(find.text('Mobile'), findsOneWidget);
  });
}

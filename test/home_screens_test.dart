import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lock_sys_hr/app.dart';
import 'package:lock_sys_hr/core/widgets/app_bottom_nav.dart';
import 'package:lock_sys_hr/core/widgets/app_button.dart';
import 'package:lock_sys_hr/core/widgets/app_card.dart';
import 'package:lock_sys_hr/core/widgets/app_icon_tabs.dart';
import 'package:lock_sys_hr/core/widgets/app_logo_mark.dart';
import 'package:lock_sys_hr/core/widgets/app_screen.dart';
import 'package:lock_sys_hr/core/widgets/app_square_tile.dart';
import 'package:lock_sys_hr/features/company/company.dart';
import 'package:lock_sys_hr/features/company/company_registry.dart';
import 'package:lock_sys_hr/features/home/promo_card.dart';
import 'package:lock_sys_hr/features/leave/leave_state.dart';
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

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(Duration(milliseconds: ms));
}

/// Signs in and waits for the home screen to finish loading.
Future<void> openHome(
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
  await t.pumpWidget(LockSysApp(prefs: prefs, registry: _Registry()));
  await t.pump(const Duration(milliseconds: 2700));
  await settle(t, 800);
  await t.enterText(find.byType(TextFormField).first, 'EMP-0012');
  await t.enterText(find.byType(TextFormField).last, 'secret123');
  final signIn = locale == 'ar' ? 'دخول' : 'Sign in';
  await scrollTo(t, find.text(signIn).last);
  await t.tap(find.text(signIn).last);
  await t.pump(const Duration(milliseconds: 1400));
  await settle(t, 1500);
  await settle(t, 1000); // the home's own 900 ms load
}

/// Scrolls [f] to the middle of its list.
Future<void> scrollTo(WidgetTester t, Finder f) async {
  await Scrollable.ensureVisible(t.element(f.first), alignment: .5);
  await t.pump(const Duration(milliseconds: 100));
}

/// A square on the home grid.
Finder tile(String label) => find.widgetWithText(AppSquareTile, label);

/// Opens a service from the home grid and waits for its own load.
Future<void> openPage(WidgetTester t, String label) async {
  await scrollTo(t, tile(label));
  await t.tap(tile(label));
  await settle(t, 800);
  await settle(t, 600); // the page's 900 ms load
}

/// Back to the home screen from the page on top.
Future<void> goHome(WidgetTester t) async {
  await t.tap(find.byType(AppBackButton).last);
  await settle(t, 800);
}

Finder button(String label) => find.widgetWithText(AppButton, label);

/// A filter chip (the same words are also status badges in the list).
Finder chip(String label) =>
    find.descendant(of: find.byType(AppIconTabs), matching: find.text(label));

/// Lets time pass in small steps, so animations and what waits on them run.
Future<void> pumpFor(WidgetTester t, int ms) async {
  for (var i = 0; i < ms / 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// A chip of the debug-only design preview on the check-in screen.
Future<void> previewChip(WidgetTester t, String label) async {
  await scrollTo(t, find.widgetWithText(ChoiceChip, label));
  await t.tap(find.widgetWithText(ChoiceChip, label));
  await settle(t);
}

Future<void> tapButton(WidgetTester t, String label) async {
  await scrollTo(t, button(label));
  await t.tap(button(label));
  await settle(t);
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('home', () {
    testWidgets(
      'has no tab bar and no attendance card: a small greeting, then the squares',
      (t) async {
        await openHome(t);
        // the bottom bar: home, approvals, my account
        expect(find.byType(AppBottomNav), findsOneWidget);
        expect(find.text('Good morning'), findsOneWidget);
        expect(find.text('Youssef El-Zorkeny'), findsOneWidget);
        // The check-in card is gone: attendance is one of the squares.
        expect(button('Check in'), findsNothing);
        expect(find.text('You have not checked in yet'), findsNothing);
        expect(find.text('Services'), findsOneWidget);
        // The greeting is two lines, so the services start high on the screen
        // (the old header and card pushed them below the middle).
        expect(t.getTopLeft(find.text('Services')).dy, lessThan(200));
        // The logo in the top bar is the official mark.
        expect(find.byType(AppLogoMark), findsOneWidget);
        // No counters on the squares.
        expect(
          find.descendant(of: tile('Leave'), matching: find.text('2')),
          findsNothing,
        );
      },
    );

    testWidgets('the squares sit side by side in one row', (t) async {
      await openHome(t);
      const labels = ['Attendance', 'Leave', 'Approvals', 'Payslip'];
      expect(find.byType(AppSquareTile), findsNWidgets(4));
      final tops = [for (final l in labels) t.getTopLeft(tile(l)).dy];
      final lefts = [for (final l in labels) t.getTopLeft(tile(l)).dx];
      // Same row = same top, each one to the side of the previous.
      expect(tops.toSet().length, 1);
      expect(lefts.toSet().length, 4);
      // They are squares.
      final size = t.getSize(
        find.descendant(
          of: tile('Attendance'),
          matching: find.byKey(const ValueKey('tile-square')),
        ),
      );
      expect(size.width, size.height);
    });

    testWidgets('services without a screen yet say so', (t) async {
      await openHome(t);
      await t.tap(tile('Payslip'));
      await settle(t);
      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('a square opens its screen, back returns home', (t) async {
      await openHome(t);
      await openPage(t, 'Leave');
      expect(find.text('Choose what you need'), findsOneWidget);
      await goHome(t);
      expect(find.text('Services'), findsOneWidget);

      await openPage(t, 'Attendance');
      await openPage(t, 'Check-in');
      expect(find.text('Delta Fertilizers'), findsOneWidget);
    });

    testWidgets('the language is chosen on the account screen', (t) async {
      await openHome(t);
      expect(tile('Language'), findsNothing); // no language square on home
      await t.tap(find.byKey(const Key('home-account')));
      await settle(t, 800);
      await t.tap(find.text('Language'));
      await settle(t, 800);
      expect(find.text('Choose language'), findsOneWidget);
    });

    testWidgets('the approvals waiting for me are on home, decided in place', (
      t,
    ) async {
      await openHome(t);
      expect(find.text('Waiting for your decision'), findsOneWidget);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      // a red dot (not a count) sits on the approvals square
      expect(
        find.descendant(
          of: tile('Approvals'),
          matching: find.byKey(const ValueKey('tile-dot')),
        ),
        findsOneWidget,
      );
      // a rejection asks for the reason first
      await scrollTo(t, find.text('Reject'));
      await t.tap(find.text('Reject'));
      await settle(t, 800);
      await t.tap(button('Confirm'));
      await settle(t, 800);
      expect(find.text('A reason is required to reject'), findsOneWidget);
      await t.enterText(find.byType(TextFormField).last, 'not now');
      await t.tap(button('Confirm'));
      await settle(t, 800);
      await settle(t, 800);
      // the card folded away and the count went
      expect(find.text('Sara Ahmed'), findsNothing);
      expect(find.text('Waiting for your decision'), findsNothing);
      expect(
        find.descendant(
          of: tile('Approvals'),
          matching: find.byKey(const ValueKey('tile-dot')),
        ),
        findsNothing,
      );
    });

    testWidgets('the bottom bar switches home, approvals and account', (
      t,
    ) async {
      await openHome(t);
      await t.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text('Approvals'),
        ),
      );
      await settle(t, 800);
      await settle(t, 600);
      expect(find.text('Waiting for me (1)'), findsOneWidget);
      expect(
        find.byType(AppBackButton),
        findsNothing,
      ); // a tab, not a pushed page
      await t.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text('Account'),
        ),
      );
      await settle(t, 800);
      expect(find.text('Preferences'), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text('Home'),
        ),
      );
      await settle(t, 800);
      expect(find.text('Services'), findsOneWidget);
    });

    testWidgets('pulling the page down reloads it', (t) async {
      await openHome(t);
      await t.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await settle(t, 1500);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(
        find.text('Sara Ahmed'),
        findsOneWidget,
      ); // still there after reload
    });

    testWidgets('the reject sheet fits a small phone with the keyboard up', (
      t,
    ) async {
      await openHome(t, size: const Size(320, 568), textScale: 1.3);
      t.view.viewInsets = const FakeViewPadding(bottom: 280); // the keyboard
      addTearDown(t.view.resetViewInsets);
      await settle(t, 400);
      await scrollTo(t, find.text('Reject'));
      await settle(t, 400);
      await t.tap(find.text('Reject'));
      await settle(t, 800);
      // short screen + keyboard: the sheet scrolls, the button can be reached
      await scrollTo(t, button('Confirm'));
      await t.tap(button('Confirm'));
      await settle(t, 800);
      expect(find.text('A reason is required to reject'), findsOneWidget);
      expect(t.takeException(), isNull); // no overflow stripes
    });

    testWidgets('the account opens from the small square on top', (t) async {
      await openHome(t);
      await t.tap(find.byKey(const Key('home-account')));
      await settle(t, 800);
      expect(find.text('EMP-0012'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);

      await tapButton(t, 'Sign out');
      await t.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Sign out'),
        ),
      );
      await settle(t, 800);
      // Back on the sign-in screen, no account screen left on the stack.
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Preferences'), findsNothing);
    });
  });

  group('attendance', () {
    Future<void> openCheckIn(WidgetTester t) async {
      await openHome(t);
      await openPage(t, 'Attendance');
      await openPage(t, 'Check-in');
      await pumpFor(t, 600);
    }

    Finder site() => find.text('Delta Fertilizers');

    /// Opens the site card, then starts the check-in / check-out on its screen.
    Future<void> openSite(WidgetTester t, [String? start]) async {
      await scrollTo(t, site());
      await t.tap(site());
      await settle(t, 800);
      if (start != null) await tapButton(t, start);
    }

    testWidgets('the sites are big cards; a site opens its own screen', (
      t,
    ) async {
      await openCheckIn(t);
      // No how-to card and no log on the list: just the sites.
      expect(find.text('How you check in'), findsNothing);
      expect(find.text('Today log'), findsNothing);
      expect(site(), findsOneWidget);
      expect(find.text('Factory'), findsOneWidget); // its work area
      expect(find.text('You have not checked in yet'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.text('Check in'),
        ),
        findsOneWidget,
      );

      // The site: the navy card first, then the areas and the button.
      await openSite(t);
      expect(find.text('Check-in time'), findsOneWidget);
      expect(find.text('Check-out time'), findsOneWidget);
      expect(find.text('Work areas'), findsOneWidget);
      expect(button('Check in'), findsOneWidget);
    });

    testWidgets('face + location: permissions, three moves, then done', (
      t,
    ) async {
      await openCheckIn(t);
      await openSite(t, 'Check in');

      // The permissions are asked for in plain words first.
      expect(find.text('Before we start'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      await tapButton(t, 'Allow and continue');

      // Step one: the map. Inside the work area it goes on to the face.
      await pumpFor(t, 800);
      expect(find.text('You are inside Factory'), findsOneWidget);
      expect(
        find.text('Place your face inside the oval and look straight ahead'),
        findsNothing,
      );
      await tapButton(t, 'Continue');
      await pumpFor(t, 800);

      // Step two: a live face check, the oval, then moves one by one.
      expect(
        find.text('Place your face inside the oval and look straight ahead'),
        findsOneWidget,
      );
      await pumpFor(t, 1700);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      await pumpFor(t, 9500);
      expect(find.text('You are checked in'), findsOneWidget);
      await tapButton(t, 'Done');

      // Back on the site: the navy card knows, and the button is now check-out.
      await pumpFor(t, 600);
      expect(find.textContaining('Checked in at'), findsOneWidget);
      expect(button('Check out'), findsOneWidget);

      // Check out: the permissions are remembered, so it goes straight in.
      await tapButton(t, 'Check out');
      expect(find.text('Before we start'), findsNothing);
      await pumpFor(t, 800);
      await tapButton(t, 'Continue');
      await pumpFor(t, 12000);
      expect(find.text('You are checked out'), findsOneWidget);
      await tapButton(t, 'Done');
      await pumpFor(t, 600);

      // The day is over: the site says so instead of offering a button.
      expect(find.textContaining('Checked out at'), findsOneWidget);
      expect(find.text('You already checked out today'), findsOneWidget);
      expect(button('Check out'), findsNothing);
      expect(button('Check in'), findsNothing);

      // And the list shows the site as checked out.
      await goHome(t);
      await pumpFor(t, 600);
      expect(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.text('Checked out'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('location only: a map, inside the area it checks in', (
      t,
    ) async {
      await openCheckIn(t);
      await previewChip(t, 'Location');
      await pumpFor(t, 600);
      await openSite(t, 'Check in');
      await tapButton(t, 'Allow and continue');
      expect(find.text('Camera'), findsNothing);
      await pumpFor(t, 600);
      expect(find.text('You are inside Factory'), findsOneWidget);
      await t.tap(button('Check in'));
      await pumpFor(t, 800);
      expect(find.text('You are checked in'), findsOneWidget);
    });

    testWidgets('location only: outside the area it cannot check in', (
      t,
    ) async {
      await openCheckIn(t);
      await previewChip(t, 'Location');
      await previewChip(t, 'Outside the area');
      await pumpFor(t, 600);
      await openSite(t, 'Check in');
      await tapButton(t, 'Allow and continue');
      await pumpFor(t, 600);
      expect(find.text('You are outside your work area'), findsWidgets);
      expect(find.textContaining('m away'), findsOneWidget);
      expect(button('Update my location'), findsOneWidget);
    });

    testWidgets('face + location outside: it stops at the map, no face check', (
      t,
    ) async {
      await openCheckIn(t);
      await previewChip(t, 'Outside the area');
      await openSite(t, 'Check in');
      await tapButton(t, 'Allow and continue');
      await pumpFor(t, 1000);
      expect(find.text('You are outside your work area'), findsWidgets);
      expect(find.textContaining('m away'), findsOneWidget);
      expect(button('Update my location'), findsOneWidget);
      expect(button('Continue'), findsNothing);
      expect(
        find.text('Place your face inside the oval and look straight ahead'),
        findsNothing,
      );
    });

    testWidgets(
      'fake location: the company can record it instead of blocking it',
      (t) async {
        await openCheckIn(t);
        await previewChip(t, 'Location');
        await previewChip(t, 'Record it'); // the company policy
        await previewChip(t, 'Fake location');
        await pumpFor(t, 600);
        await openSite(t, 'Check in');
        await tapButton(t, 'Allow and continue');
        await pumpFor(t, 800);
        // Not stopped: the map goes on, and the server accepts the check-in.
        expect(find.text('A fake location was detected'), findsNothing);
        expect(find.text('You are inside Factory'), findsOneWidget);
        await t.tap(button('Check in'));
        await pumpFor(t, 800);
        expect(find.text('You are checked in'), findsOneWidget);
      },
    );

    for (final (chip, title, action) in [
      ('Location off', 'Location is turned off', 'Open location settings'),
      ('No permission', 'Location permission is needed', 'Open app settings'),
      ('VPN', 'Turn off the VPN', 'Open network settings'),
      (
        'Developer options',
        'Developer options are on',
        'Open developer settings',
      ),
      ('Fake location', 'A fake location was detected', 'Try again'),
    ]) {
      testWidgets('a phone problem opens its own screen: $chip', (t) async {
        await openCheckIn(t);
        // Location only, so a fake location is found as soon as the map reads it.
        await previewChip(t, 'Location');
        await previewChip(t, chip);
        await pumpFor(t, 600);
        await openSite(t, 'Check in');
        await tapButton(t, 'Allow and continue');
        await pumpFor(t, 1500);
        expect(find.text(title), findsOneWidget);
        // Fixed in the settings: it goes back to the check.
        await tapButton(t, action);
        await pumpFor(t, 1500);
        expect(find.text(title), findsNothing);
      });
    }
  });

  group('approvals', () {
    testWidgets('waiting, later, details and a decision', (t) async {
      await openHome(t);
      await openPage(t, 'Approvals');
      // my turn: the request of someone else, with the counts on the chips
      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(find.text('Waiting for me (1)'), findsOneWidget);

      // later: who has to decide first is shown
      await t.tap(find.text('Later (1)'));
      await settle(t, 800);
      expect(
        find.text('Waiting for Mina · Direct Manager first'),
        findsOneWidget,
      );

      // done (the chip row scrolls sideways on a narrow phone)
      await t.tap(find.text('Done (1)'));
      await settle(t, 800);
      expect(find.text('Approved'), findsWidgets);

      // open the one that waits for me
      await t.tap(find.text('Waiting for me (1)'));
      await settle(t, 800);
      await t.tap(find.text('Sara Ahmed'));
      await settle(t, 800);
      await settle(t, 600);
      expect(find.text('Requested by'), findsOneWidget);
      expect(find.text('Approval steps'), findsOneWidget);

      // a rejection needs a reason
      await t.tap(find.text('Reject'));
      await settle(t, 800);
      await t.tap(button('Confirm'));
      await settle(t, 800);
      expect(find.text('A reason is required to reject'), findsOneWidget);
      Navigator.of(
        t.element(find.byType(Scaffold).first),
      ).pop(); // close the sheet
      await settle(t, 800);

      // approve with no notes
      await t.tap(find.text('Approve'));
      await settle(t, 800);
      expect(find.text('Approve the request of Sara Ahmed?'), findsOneWidget);
      await t.tap(button('Confirm')); // asked first, then sent
      await settle(t, 600); // the card turns into the result
      expect(find.text('The request was approved'), findsOneWidget);
      await settle(t, 1500); // then the page closes
    });
  });

  group('leave', () {
    testWidgets('the hub has three squares', (t) async {
      await openHome(t);
      await openPage(t, 'Leave');
      expect(find.text('Choose what you need'), findsOneWidget);
      expect(tile('My leave'), findsOneWidget);
      expect(tile('My balances'), findsOneWidget);
      expect(tile('Request leave'), findsOneWidget);
      final tops = [
        for (final l in ['My leave', 'My balances', 'Request leave'])
          t.getTopLeft(tile(l)).dy,
      ];
      expect(tops[0], tops[1]);
      expect(tops[1], tops[2]);
    });

    testWidgets('my leave lists the requests, filters and opens details', (
      t,
    ) async {
      await openHome(t);
      await openPage(t, 'Leave');
      await openPage(t, 'My leave');
      expect(find.text('2 requests'), findsOneWidget);
      expect(find.text('Annual'), findsOneWidget);
      expect(find.text('Casual'), findsOneWidget);

      await t.tap(chip('Approved'));
      await settle(t, 800);
      expect(find.text('1 requests'), findsOneWidget);
      expect(find.text('Casual'), findsOneWidget);
      expect(find.text('Annual'), findsNothing);

      await t.tap(chip('Rejected'));
      await settle(t, 800);
      expect(find.text('No requests'), findsOneWidget);

      await t.tap(chip('All'));
      await settle(t, 800);
      await t.tap(find.text('Annual'));
      await settle(t, 800);
      expect(find.text('No reason given'), findsOneWidget);
      expect(find.text('3 days'), findsWidgets);
    });

    testWidgets('my balances shows each leave type', (t) async {
      await openHome(t);
      await openPage(t, 'Leave');
      await openPage(t, 'My balances');
      expect(find.text('Annual leave'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('days left'), findsNWidgets(2));
      expect(find.text('Carried forward'), findsOneWidget);
      expect(find.text('Casual leave'), findsOneWidget);
      expect(find.text('4'), findsWidgets);
    });

    testWidgets('new request: validation, then it is sent', (t) async {
      await openHome(t);
      await openPage(t, 'Leave');
      await t.tap(tile('Request leave'));
      await settle(t, 800);
      expect(
        find.text('Your request goes to your direct manager.'),
        findsOneWidget,
      );

      await tapButton(t, 'Submit request');
      expect(find.text('Choose a leave type'), findsWidgets);
      expect(find.text('Choose the start date'), findsOneWidget);
      expect(find.text('Choose the end date'), findsOneWidget);

      await t.tap(find.text('Choose a leave type').first); // the field
      await settle(t, 800);
      expect(
        find.text('Compensatory'),
        findsOneWidget,
      ); // types come from the server
      await t.tap(find.text('Casual').last);
      await settle(t, 800);

      await t.tap(find.text('Choose a date').first); // the From field
      await settle(t, 800);
      await t.tap(find.text('OK'));
      await settle(t, 800);
      // the server's count: today .. today, 4 days left, 1 used
      expect(find.text('1 day'), findsWidgets);
      expect(find.text('Left after this request'), findsOneWidget);

      await t.tap(find.text('First half').last); // casual allows a half day
      await settle(t, 800);
      expect(find.text('0.5 days'), findsWidgets);

      await tapButton(t, 'Submit request');
      await settle(t, 800);
      expect(
        find.text('Your request was sent to your manager'),
        findsOneWidget,
      );
    });

    test('balances and counting', () {
      final c = LeaveController(today: DateTime(2026, 10, 1));
      expect(c.left(LeaveType.annual), 18);
      expect(c.left(LeaveType.unpaid), isNull); // no limit
      expect(c.pending, 2);
      expect(daysBetween(DateTime(2026, 10, 12), DateTime(2026, 10, 14)), 3);
      expect(daysBetween(DateTime(2026, 10, 12), DateTime(2026, 10, 12)), 1);
    });
  });

  for (final locale in ['en', 'ar']) {
    testWidgets('no overflow at 320 px and large text ($locale)', (t) async {
      final ar = locale == 'ar';
      String s(String en, String arabic) => ar ? arabic : en;
      await openHome(
        t,
        locale: locale,
        size: const Size(320, 640),
        textScale: 1.3,
      );

      // Overflows are collected with the step and the widget that caused them,
      // so a failure says where, not just that something overflowed.
      final problems = <String>[];
      var step = 'home';
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        final where = RegExp(r'file:///[^\s]*lib[^\s]*')
            .allMatches(d.toString())
            .map((m) => m.group(0)!.split('LockSys-Hr-New/').last)
            .toSet()
            .join(' ');
        final detail = d
            .toString()
            .split('\n')
            .where((l) => l.contains('constraints:') || l.contains('size:'))
            .take(3)
            .join(' | ');
        problems.add(
          '[$step] ${d.exceptionAsString().split('\n').first} @ $where $detail',
        );
      };
      addTearDown(() => FlutterError.onError = old);

      Future<void> visit(String name, Future<void> Function() action) async {
        step = name;
        try {
          await action();
        } catch (e) {
          problems.add(
            '[$name] ${e.toString().split(String.fromCharCode(10)).first}',
          );
        }
      }

      // Scroll the whole home: hero, the three rows, the notice.
      await visit('home scrolled', () async {
        await scrollTo(t, tile(s('Payslip', 'كشف الراتب')));
        await settle(t);
        await scrollTo(t, find.byType(HomePromoCard)); // the announcement
        await settle(t);
      });

      await visit('attendance page', () async {
        await openPage(t, s('Attendance', 'الحضور والانصراف'));
        await openPage(t, s('Check-in', 'التحضير'));
        await pumpFor(t, 600);
      });
      await visit('site page', () async {
        final site = find.text(s('Delta Fertilizers', 'شركة الدلتا للأسمدة'));
        await scrollTo(t, site);
        await t.tap(site);
        await settle(t, 800);
      });
      await visit('check-in: permissions', () async {
        await tapButton(t, s('Check in', 'تسجيل حضور'));
      });
      await visit('check-in: map', () async {
        await tapButton(t, s('Allow and continue', 'سماح ومتابعة'));
        await pumpFor(t, 1000);
      });
      await visit('check-in: face moves', () async {
        await tapButton(t, s('Continue', 'متابعة'));
        await pumpFor(t, 11500);
      });
      await visit(
        'check-in: back to the site',
        () => tapButton(t, s('Done', 'تم')),
      );
      await visit('site: back to the list', () => goHome(t));
      await visit('map: inside', () async {
        await previewChip(t, 'Location');
        await pumpFor(t, 600);
        final site = find.text(s('Delta Fertilizers', 'شركة الدلتا للأسمدة'));
        await scrollTo(t, site);
        await t.tap(site);
        await settle(t, 800);
        await tapButton(t, s('Check out', 'تسجيل انصراف'));
        await pumpFor(t, 1200);
      });
      await visit('map: back', () => goHome(t));
      await visit('map: back to the list', () => goHome(t));
      await visit('map: outside', () async {
        await previewChip(t, 'Outside the area');
        final site = find.text(s('Delta Fertilizers', 'شركة الدلتا للأسمدة'));
        await scrollTo(t, site);
        await t.tap(site);
        await settle(t, 800);
        await tapButton(t, s('Check out', 'تسجيل انصراف'));
        await pumpFor(t, 1200);
      });
      await visit('map: back again', () => goHome(t));
      await visit('map: back to the list again', () => goHome(t));
      await visit('phone problem', () async {
        await previewChip(t, 'VPN');
        final site = find.text(s('Delta Fertilizers', 'شركة الدلتا للأسمدة'));
        await scrollTo(t, site);
        await t.tap(site);
        await settle(t, 800);
        await tapButton(t, s('Check out', 'تسجيل انصراف'));
        await pumpFor(t, 1500);
      });
      await visit('problem: back', () => goHome(t));
      await visit('problem: back to the list', () => goHome(t));
      await visit('back to the hub', () => goHome(t));
      await visit('back home', () => goHome(t));

      await visit('leave page', () => openPage(t, s('Leave', 'الإجازات')));
      await visit('my leave', () => openPage(t, s('My leave', 'إجازاتي')));
      await visit('leave details', () async {
        await t.tap(find.text(s('Annual', 'سنوية')));
        await settle(t, 800);
      });
      await visit('dismiss details', () async {
        // Large Arabic text makes the sheet cover the whole screen: close it
        // through the navigator instead of tapping the scrim.
        Navigator.of(t.element(find.byType(Scaffold).first)).pop();
        await settle(t, 800);
      });
      await visit('back to the hub', () => goHome(t));
      await visit('my balances', () => openPage(t, s('My balances', 'أرصدتي')));
      await visit('back to the hub again', () => goHome(t));
      await visit('request form', () async {
        await t.tap(tile(s('Request leave', 'طلب إجازة')));
        await settle(t, 800);
      });
      await visit(
        'request form with errors',
        () => tapButton(t, s('Submit request', 'إرسال الطلب')),
      );
      await visit('back to the hub once more', () => goHome(t));
      await visit('back to the page', () => goHome(t));

      await visit('account page', () async {
        await t.tap(find.byKey(const Key('home-account')));
        await settle(t, 800);
      });

      FlutterError.onError = old; // the framework requires this before expect
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}

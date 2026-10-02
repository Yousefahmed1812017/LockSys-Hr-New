import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lock_sys_hr/core/theme/app_theme.dart';
import 'package:lock_sys_hr/features/attendance/attendance_api.dart';
import 'package:lock_sys_hr/features/attendance/month_summary_page.dart';
import 'package:lock_sys_hr/l10n/app_localizations.dart';

Future<void> _open(
  WidgetTester t, {
  String locale = 'en',
  Size size = const Size(390, 844),
  double textScale = 1,
  AttendanceApi? api,
}) async {
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.platformDispatcher.clearAllTestValues);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MonthSummaryPage(api: api ?? MockAttendanceApi()),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 600));
}

/// A server that only knows the answer it was given.
class _Api extends MockAttendanceApi {
  _Api(this.answer);
  final MonthSummary answer;
  final asked = <String?>[];

  @override
  Future<MonthSummary> month(String? month) async {
    asked.add(month);
    return answer;
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the month, its figures and every day as a calendar', (t) async {
    await _open(t);
    final now = DateTime.now();
    final days = DateUtils.getDaysInMonth(now.year, now.month);
    expect(find.text('Month summary'), findsOneWidget);
    expect(find.text('Present'), findsWidgets);
    expect(find.text('Absent'), findsWidgets);
    expect(find.text('Leave'), findsWidgets);
    // The summary is only these three; the legend names the other colors.
    expect(find.text('Official holiday'), findsOneWidget);
    expect(find.text('Rest day'), findsOneWidget);
    // Every day of the month has its number on the calendar.
    expect(find.text('$days'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    // The legend says what the colors mean.
    expect(find.text('Worked on a rest day'), findsWidgets);
  });

  testWidgets('previous goes back a month; next is off in the current month', (
    t,
  ) async {
    final api = MockAttendanceApi();
    await _open(t, api: api);
    final now = DateTime.now();
    // Next is disabled while on the current month.
    final next = find.bySemanticsLabel('Next month');
    expect(next, findsOneWidget);

    await t.tap(find.bySemanticsLabel('Previous month'));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 600));
    // Now the next month button is on and goes back to where we were.
    await t.tap(find.bySemanticsLabel('Next month'));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 600));
    expect(
      find.text('${DateUtils.getDaysInMonth(now.year, now.month)}'),
      findsOneWidget,
    );
  });

  testWidgets('a tapped day tells what it was', (t) async {
    String d(int n) => '2026-09-${n.toString().padLeft(2, '0')}';
    final days = <Map<String, dynamic>>[
      for (var n = 1; n <= 30; n++) {'date': d(n), 'status': 'FUTURE'},
    ];
    days[16] = {
      'date': d(17),
      'status': 'PRESENT',
      'workedOnOff': true,
      'checkIn': '08:00',
      'checkOut': '16:30',
      'hours': 8.5,
    };
    days[17] = {'date': d(18), 'status': 'ABSENT'};
    days[18] = {'date': d(19), 'status': 'OFF', 'reason': 'WEEKLY_OFF'};
    days[19] = {
      'date': d(20),
      'status': 'LEAVE',
      'reason': 'LEAVE',
      'nameAr': 'سنوية',
      'nameEn': 'Annual',
    };
    days[20] = {
      'date': d(21),
      'status': 'MISSION',
      'reason': 'MISSION',
      'nameEn': 'Site visit',
    };
    await _open(
      t,
      api: _Api(
        MonthSummary.fromJson({
          'month': '2026-09',
          'supported': true,
          'prev': '2026-08',
          'next': '2026-10',
          'summary': {
            'present': 1,
            'absent': 1,
            'off': 1,
            'leave': 1,
            'mission': 1,
            'workedOnOff': 1,
            'hours': 8.5,
          },
          'days': days,
        }),
      ),
    );
    Future<void> tapDay(int n) async {
      await t.ensureVisible(find.text('$n').last);
      await t.tap(find.text('$n').last);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 600));
    }

    Future<void> close() async {
      Navigator.of(t.element(find.byType(Scaffold).first)).pop();
      await t.pump(const Duration(milliseconds: 600));
    }

    await tapDay(17);
    expect(find.text('Present'), findsWidgets);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);
    expect(find.text('You worked on a rest day'), findsOneWidget);
    await close();

    await tapDay(18);
    expect(find.text('Absent'), findsWidgets);
    await close();

    await tapDay(19);
    expect(find.text('Weekly rest day'), findsOneWidget);
    await close();

    await tapDay(20);
    expect(find.text('On leave'), findsOneWidget);
    expect(find.text('Annual'), findsOneWidget);
    await close();

    await tapDay(21);
    expect(find.text('On mission'), findsOneWidget);
    expect(find.text('Site visit'), findsOneWidget);
  });

  testWidgets('rotating shifts: the server says it is not available yet', (
    t,
  ) async {
    await _open(
      t,
      api: _Api(
        MonthSummary.fromJson({
          'month': '2026-10',
          'supported': false,
          'message': {
            'ar': 'غير متاح للمناوبات',
            'en': 'Not available for rotating shifts',
          },
          'days': [],
        }),
      ),
    );
    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.text('Not available for rotating shifts'), findsOneWidget);
  });

  testWidgets('no overflow at 320 px and large text, in both languages', (
    t,
  ) async {
    for (final locale in ['en', 'ar']) {
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      await _open(
        t,
        locale: locale,
        size: const Size(320, 640),
        textScale: 1.3,
      );
      FlutterError.onError = old;
      expect(errors, isEmpty, reason: '$locale: ${errors.join('\n')}');
    }
  });
}

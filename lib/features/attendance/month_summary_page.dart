import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_list.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_api.dart';
import 'attendance_api.dart';

/// Month summary: the month the employee is in, with a button for the previous
/// and the next month, and the days as a calendar:
///   green              a day at work (a star on it: worked on a rest day or holiday)
///   red                absent
///   yellow             leave, official holiday, weekly or compensatory rest
///   blue               on a mission
///   white              today (framed) and days to come
/// Tapping a day says what it was. The server decides what each day is.
class MonthSummaryPage extends StatefulWidget {
  const MonthSummaryPage({super.key, required this.api});
  final AttendanceApi api;

  @override
  State<MonthSummaryPage> createState() => _MonthSummaryPageState();
}

class _MonthSummaryPageState extends State<MonthSummaryPage> {
  MonthSummary? _data;
  bool _loading = true;
  AuthException? _error;
  String? _month; // null = this month

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? month]) async {
    setState(() {
      _loading = true;
      _error = null;
      _month = month;
    });
    try {
      final data = await widget.api.month(month);
      if (!mounted || _month != month) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final data = _data;
    final Widget body;
    if (_loading && data == null) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          children: [
            AppSkeletonCard(height: 70),
            SizedBox(height: AppSpacing.s3),
            AppSkeletonCard(height: 340),
          ],
        ),
      );
    } else if (data == null) {
      body = SizedBox(
        height: 360,
        child: AppEmptyState.offline(onAction: () => _load(_month)),
      );
    } else if (!data.supported) {
      body = SizedBox(
        height: 320,
        child: AppEmptyState(
          icon: AppIcons.calendar,
          tone: AppTone.warning,
          title: l.monthUnavailableTitle,
          message: data.message(lang),
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: _MonthBody(
          data: data,
          loading: _loading,
          error: _error,
          onMonth: _load,
          lang: lang,
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(showBack: true, title: l.attTileMonth),
      body: ListView(children: [body]),
    );
  }
}

class _MonthBody extends StatelessWidget {
  const _MonthBody({
    required this.data,
    required this.loading,
    required this.error,
    required this.onMonth,
    required this.lang,
  });

  final MonthSummary data;
  final bool loading;
  final AuthException? error;
  final void Function(String? month) onMonth;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final title = toWesternDigits(
      DateFormat.yMMMM(locale).format(data.firstDay),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Previous month | the month | next month.
        Row(
          children: [
            _MonthButton(
              icon: AppIcons.back,
              label: l.monthPrev,
              onTap: data.prev == null || loading
                  ? null
                  : () => onMonth(data.prev),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.h2,
              ),
            ),
            _MonthButton(
              icon: AppIcons.forward,
              label: l.monthNext,
              onTap: data.next == null || loading
                  ? null
                  : () => onMonth(data.next),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        _SummaryCard(data: data),
        const SizedBox(height: AppSpacing.s3),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.line),
          ),
          child: AnimatedOpacity(
            opacity: loading ? .45 : 1,
            duration: AppMotion.ui,
            child: _Calendar(data: data, lang: lang),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.s3),
          Text(
            error!.network ? l.offlineMessage : error!.message(lang),
            textAlign: TextAlign.center,
            style: AppText.small.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.s4),
        const _Legend(),
      ],
    );
  }
}

/// A square button: the previous or the next month.
class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final AppIconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .35 : 1,
      child: AppIconButton(icon: icon, semanticLabel: label, onPressed: onTap),
    );
  }
}

/// The month in three numbers, centered: days at work, absences and leave. No box:
/// the number and its name are written in the color of that kind of day.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});
  final MonthSummary data;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final byKind = <DayKind, int>{};
    for (final d in data.days) {
      byKind[kindOf(d)] = (byKind[kindOf(d)] ?? 0) + 1;
    }
    Widget fig(DayKind kind, String label, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            '${byKind[kind] ?? 0}',
            textDirection: TextDirection.ltr,
            style: AppText.stat.copyWith(color: color, fontSize: 30),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fig(DayKind.present, l.monthPresent, AppColors.calPresent),
          fig(DayKind.absent, l.monthAbsent, AppColors.calAbsent),
          fig(DayKind.leave, l.monthLeave, AppColors.calLeaveText),
        ],
      ),
    );
  }
}

/// The weekday row and the days. The week starts on Saturday.
class _Calendar extends StatelessWidget {
  const _Calendar({required this.data, required this.lang});
  final MonthSummary data;
  final String lang;

  /// Saturday first.
  static const _weekdays = [
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final symbols = DateFormat(null, locale).dateSymbols;
    // intl lists weekdays from Sunday (index 0).
    String weekday(int w) => symbols.SHORTWEEKDAYS[w % 7];
    final first = data.firstDay;
    final lead = _weekdays.indexOf(first.weekday);
    final byDay = {for (final d in data.days) d.date.day: d};
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (
        var d = 1;
        d <= DateUtils.getDaysInMonth(first.year, first.month);
        d++
      )
        _DayCell(day: byDay[d], number: d, lang: lang),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }
    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Text(
                  weekday(w),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.xs.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < cells.length ~/ 7; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++) ...[
                  if (c > 0) const SizedBox(width: 6),
                  Expanded(child: cells[r * 7 + c]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// What a day was, one color each.
enum DayKind { present, absent, leave, holiday, rest, mission, today, future }

DayKind kindOf(MonthDay d) {
  switch (d.status) {
    case 'PRESENT':
      return DayKind.present;
    case 'ABSENT':
      return DayKind.absent;
    case 'LEAVE':
      return DayKind.leave;
    case 'MISSION':
      return DayKind.mission;
    case 'TODAY':
      return DayKind.today;
    case 'OFF':
      return d.reason == 'HOLIDAY' ? DayKind.holiday : DayKind.rest;
    default:
      return DayKind.future;
  }
}

class _Look {
  const _Look(this.fill, this.border, this.text);
  final Color fill;
  final Color border;
  final Color text;
}

_Look _lookOf(DayKind k) => switch (k) {
  DayKind.present => const _Look(
    AppColors.calPresent,
    AppColors.calPresent,
    Colors.white,
  ),
  DayKind.absent => const _Look(
    AppColors.calAbsent,
    AppColors.calAbsent,
    Colors.white,
  ),
  DayKind.leave => const _Look(
    AppColors.calLeave,
    AppColors.calLeave,
    Colors.white,
  ),
  DayKind.holiday => const _Look(
    AppColors.calHoliday,
    AppColors.calHoliday,
    Colors.white,
  ),
  DayKind.rest => const _Look(
    AppColors.calRest,
    AppColors.calRest,
    Colors.white,
  ),
  DayKind.mission => const _Look(
    AppColors.calMission,
    AppColors.calMission,
    Colors.white,
  ),
  // Today is framed; days to come have no fill, just a faded number.
  DayKind.today => const _Look(Colors.white, AppColors.blue, AppColors.navy),
  DayKind.future => const _Look(
    Colors.transparent,
    Colors.transparent,
    AppColors.hint,
  ),
};

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.number, required this.lang});
  final MonthDay? day;
  final int number;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final kind = day == null ? DayKind.future : kindOf(day!);
    final look = _lookOf(kind);
    final isToday = kind == DayKind.today;
    final tappable = day != null && kind != DayKind.future;
    final star = day?.workedOnOff ?? false;
    return Semantics(
      button: tappable,
      label: '$number',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: tappable ? () => _showDay(context, day!, lang) : null,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: look.fill,
              borderRadius: AppRadius.smAll,
              border: Border.all(
                color: isToday ? AppColors.blue : look.border,
                width: isToday ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$number',
                    textDirection: TextDirection.ltr,
                    style: AppText.small.copyWith(
                      color: look.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (star)
                  const PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: AppIcon(
                      AppIcons.star,
                      size: 13,
                      color: Colors.white,
                      accentColor: Colors.white,
                      accentOpacity: .9,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _statusName(AppLocalizations l, MonthDay d) {
  switch (kindOf(d)) {
    case DayKind.present:
      return l.dayPresent;
    case DayKind.leave:
      return l.dayLeave;
    case DayKind.mission:
      return l.dayMission;
    case DayKind.today:
      return l.dayToday;
    case DayKind.future:
      return l.dayFuture;
    case DayKind.absent:
      return d.reason == 'ABSENCE' ? l.dayAbsenceLogged : l.dayAbsent;
    case DayKind.holiday:
      return l.dayHoliday;
    case DayKind.rest:
      return switch (d.reason) {
        'COMP' => l.dayComp,
        'PART_TIME_OFF' => l.dayPartTimeOff,
        _ => l.dayWeeklyOff,
      };
  }
}

/// The day's state as a small colored label (the color of the day on the calendar).
class _StateChip extends StatelessWidget {
  const _StateChip({required this.kind, required this.text});
  final DayKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final look = _lookOf(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: look.fill,
        borderRadius: BorderRadius.circular(AppRadius.xs + 2),
        border: Border.all(color: look.border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.small.copyWith(
          color: look.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

void _showDay(BuildContext context, MonthDay d, String lang) {
  final l = context.l10n;
  final locale = Localizations.localeOf(context).toString();
  final date = toWesternDigits(DateFormat.yMMMEd(locale).format(d.date));
  final name = d.name(lang);
  showAppBottomSheet<void>(
    context,
    title: date,
    builder: (ctx) {
      Widget row(String label, Widget value) => AppListTile(
        title: label,
        trailing: Flexible(child: value),
      );
      Text text(String v) => Text(
        v,
        textAlign: TextAlign.end,
        textDirection: TextDirection.ltr,
        style: AppText.mono,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: _StateChip(kind: kindOf(d), text: _statusName(l, d)),
              ),
              if (name != null && d.status != 'PRESENT') ...[
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: AppText.small)),
              ],
            ],
          ),
          if (d.workedOnOff) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const AppIcon(
                  AppIcons.star,
                  size: 16,
                  color: AppColors.success,
                  accentColor: AppColors.success,
                  accentOpacity: .9,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name == null
                        ? l.dayWorkedOnOff
                        : '${l.dayWorkedOnOff} · $name',
                    style: AppText.small,
                  ),
                ),
              ],
            ),
          ],
          if (d.status == 'PRESENT') ...[
            const SizedBox(height: AppSpacing.s3),
            AppListGroup(
              children: [
                row(l.attInTime, text(d.checkIn ?? '--:--')),
                row(
                  l.attOutTime,
                  d.checkOut == null
                      ? Text(
                          l.dayNoCheckout,
                          textAlign: TextAlign.end,
                          style: AppText.small.copyWith(
                            color: AppColors.warning,
                          ),
                        )
                      : text(d.checkOut!),
                ),
                if (d.hours != null)
                  row(l.workedLabel, text(d.hours!.toStringAsFixed(2))),
              ],
            ),
          ],
        ],
      );
    },
  );
}

/// What the colors mean.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget item(Widget mark, String label) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        mark,
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppText.xs)),
      ],
    );
    Widget dot(DayKind k) {
      final look = _lookOf(k);
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: look.fill,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: look.border),
        ),
      );
    }

    final star = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.calPresent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: AppIcon(
          AppIcons.star,
          size: 11,
          color: Colors.white,
          accentColor: Colors.white,
          accentOpacity: .9,
        ),
      ),
    );
    // Two columns side by side; in each one the items are under each other.
    Widget column(List<Widget> items) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            items[i],
          ],
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        column([
          item(dot(DayKind.present), l.legPresent),
          item(dot(DayKind.absent), l.legAbsent),
          item(dot(DayKind.leave), l.legLeave),
        ]),
        const SizedBox(width: 16),
        column([
          item(dot(DayKind.rest), l.legRest),
          item(dot(DayKind.holiday), l.legHoliday),
          item(dot(DayKind.mission), l.legMission),
          item(star, l.legStar),
        ]),
      ],
    );
  }
}

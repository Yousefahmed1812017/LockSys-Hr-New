import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_alert.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chips.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_list.dart';
import '../../core/widgets/app_overlays.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_text_field.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_api.dart';
import 'leave_api.dart';

/// `Oct 12, 2026` / `12 أكتوبر 2026`, Western digits in both languages.
String formatLeaveDate(BuildContext context, DateTime date) => toWesternDigits(
  DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date),
);

/// Whole or half days as text: `3`, `0.5`.
String _n(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// `1 day`, `0.5 days`, `3 days`.
String _days(AppLocalizations l, num v) =>
    v == 1 ? l.daysCount(1) : l.leaveDaysValue(_n(v));

/// New leave request, all from the server: the types allowed in the app
/// (`GET types`), a live count of the days with every rule checked
/// (`POST requests/preview`) and the request itself (`POST requests`).
/// Pops with the created [LeaveItem], or null when the employee goes back.
class LeaveRequestPage extends StatefulWidget {
  const LeaveRequestPage({super.key, required this.api});
  final LeaveApi api;

  @override
  State<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage> {
  final _typeText = TextEditingController();
  final _fromText = TextEditingController();
  final _toText = TextEditingController();
  final _reason = TextEditingController();

  List<LeaveTypeInfo>? _types;
  bool _loadingTypes = true;
  LeaveTypeInfo? _type;
  DateTime? _from;
  DateTime? _to;
  int _half = 0; // 0 full day, 1 first half, 2 second half
  bool _tried = false; // errors show after the first submit, then live
  bool _sending = false;

  // The live count: only the answer to the latest draft is kept.
  int _seq = 0;
  bool _counting = false;
  LeavePreview? _preview;
  String? _ruleError;
  String? _sendError;
  String _lang = 'ar';

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lang = Localizations.localeOf(context).languageCode;
  }

  @override
  void dispose() {
    _seq++;
    _typeText.dispose();
    _fromText.dispose();
    _toText.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    setState(() => _loadingTypes = true);
    try {
      final t = await widget.api.types();
      if (!mounted) return;
      setState(() {
        _types = t;
        _loadingTypes = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _types = null;
        _loadingTypes = false;
      });
    }
  }

  bool get _isHalf => _half != 0;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// The first day the chosen type can start on (its advance notice).
  DateTime get _firstDay =>
      _today.add(Duration(days: _type?.advanceNoticeDays ?? 0));

  Future<void> _pickType() async {
    final l = context.l10n;
    final types = _types ?? const <LeaveTypeInfo>[];
    final picked = await showAppBottomSheet<LeaveTypeInfo>(
      context,
      title: l.leaveType,
      builder: (ctx) => AppListGroup(
        children: [
          for (final t in types)
            AppListTile(
              leading: const AppIconTile(AppIcons.calendar),
              title: t.name(_lang),
              subtitle: t.remaining == null
                  ? l.leaveNoLimit
                  : l.leaveBalanceLeft(t.remaining!.floor()),
              trailing: _type?.id == t.id
                  ? const AppIcon(AppIcons.check, color: AppColors.blue)
                  : null,
              showChevron: false,
              onTap: () => Navigator.of(ctx).pop(t),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _type = picked;
      _typeText.text = picked.name(_lang);
      if (!picked.allowHalfDay) _half = 0;
      // A date before the type's notice is no longer valid.
      if (_from != null && _from!.isBefore(_firstDay)) {
        _from = null;
        _fromText.clear();
        _to = null;
        _toText.clear();
      }
    });
    _recount();
  }

  Future<void> _pickDate({required bool from}) async {
    final first = _firstDay;
    final current = from ? _from : _to;
    final base = from ? first : (_from ?? first);
    final picked = await showDatePicker(
      context: context,
      firstDate: from ? first : (_from ?? first),
      lastDate: first.add(const Duration(days: 365)),
      initialDate: current != null && !current.isBefore(base) ? current : base,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = picked;
        _fromText.text = formatLeaveDate(context, picked);
        // Keep the end valid: a one-day request by default, always one day for a half.
        if (_to == null || _to!.isBefore(picked) || _isHalf) {
          _to = picked;
          _toText.text = formatLeaveDate(context, picked);
        }
      } else {
        _to = picked;
        _toText.text = formatLeaveDate(context, picked);
      }
    });
    _recount();
  }

  void _setHalf(int v) {
    setState(() {
      _half = v;
      if (v != 0 && _from != null) {
        _to = _from;
        _toText.text = formatLeaveDate(context, _from!);
      }
    });
    _recount();
  }

  LeaveDraft? _draft() {
    final type = _type;
    final from = _from;
    final to = _to;
    if (type == null || from == null || to == null || to.isBefore(from)) {
      return null;
    }
    return LeaveDraft(
      typeId: type.id,
      start: from,
      end: to,
      halfDayType: _isHalf ? _half : null,
      reason: _reason.text,
    );
  }

  /// Asks the server to count the draft; a rule that fails is shown at once.
  Future<void> _recount() async {
    final draft = _draft();
    final seq = ++_seq;
    if (draft == null) {
      setState(() {
        _preview = null;
        _ruleError = null;
        _counting = false;
      });
      return;
    }
    // The old numbers go at once: they belong to the previous choice.
    setState(() {
      _counting = true;
      _preview = null;
      _ruleError = null;
      _sendError = null;
    });
    try {
      final p = await widget.api.preview(draft);
      if (!mounted || seq != _seq) return;
      setState(() {
        _preview = p;
        _counting = false;
      });
    } on AuthException catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _preview = null;
        _ruleError = e.network ? context.l10n.offlineMessage : e.message(_lang);
        _counting = false;
      });
    } catch (_) {
      // Anything unexpected must not leave the form stuck on "counting".
      if (!mounted || seq != _seq) return;
      setState(() {
        _preview = null;
        _ruleError = context.l10n.offlineMessage;
        _counting = false;
      });
    }
  }

  String? _errType(AppLocalizations l) =>
      _tried && _type == null ? l.errLeaveType : null;
  String? _errFrom(AppLocalizations l) =>
      _tried && _from == null ? l.errDateFrom : null;
  String? _errTo(AppLocalizations l) {
    if (!_tried) return null;
    if (_to == null) return l.errDateTo;
    if (_from != null && _to!.isBefore(_from!)) return l.errDateOrder;
    return null;
  }

  String? _errReason(AppLocalizations l) =>
      _tried && (_type?.requiresReason ?? false) && _reason.text.trim().isEmpty
      ? l.errReasonRequired
      : null;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final l = context.l10n;
    setState(() => _tried = true);
    final draft = _draft();
    if (_errType(l) != null ||
        _errFrom(l) != null ||
        _errTo(l) != null ||
        _errReason(l) != null ||
        draft == null ||
        _ruleError != null) {
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final created = await widget.api.create(draft);
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError = e.network ? l.offlineMessage : e.message(_lang);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final Widget body;
    if (_loadingTypes) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          children: [
            AppSkeletonCard(height: 64),
            SizedBox(height: AppSpacing.s3),
            AppSkeletonCard(height: 64),
            SizedBox(height: AppSpacing.s3),
            AppSkeletonCard(height: 120),
          ],
        ),
      );
    } else if (_types == null || _types!.isEmpty) {
      body = SizedBox(
        height: 360,
        child: AppEmptyState.offline(onAction: _loadTypes),
      );
    } else {
      body = _form(l);
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(showBack: true, title: l.leaveRequestNew),
      body: ListView(children: [AppScreenIntro(l.leaveFormSubtitle), body]),
    );
  }

  Widget _form(AppLocalizations l) {
    final type = _type;
    final dateFields = [
      AppTextField(
        label: l.dateFrom,
        controller: _fromText,
        hint: l.dateHint,
        readOnly: true,
        prefixIcon: AppIcons.calendar,
        errorText: _errFrom(l),
        onTap: () => _pickDate(from: true),
      ),
      AppTextField(
        label: l.dateTo,
        controller: _toText,
        hint: l.dateHint,
        readOnly: true,
        enabled: !_isHalf,
        prefixIcon: AppIcons.calendar,
        errorText: _errTo(l),
        onTap: () => _pickDate(from: false),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: l.leaveType,
            controller: _typeText,
            hint: l.leaveTypeHint,
            required: true,
            readOnly: true,
            prefixIcon: AppIcons.file,
            errorText: _errType(l),
            onTap: _pickType,
          ),
          if (type != null && type.remaining != null) ...[
            const SizedBox(height: 8),
            Text(
              l.leaveBalanceLeft(type.remaining!.floor()),
              style: AppText.small.copyWith(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          // Side by side when there is room, stacked on a narrow phone.
          LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 340
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: dateFields[0]),
                      const SizedBox(width: 12),
                      Expanded(child: dateFields[1]),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dateFields[0],
                      const SizedBox(height: 16),
                      dateFields[1],
                    ],
                  ),
          ),
          if (type != null && type.allowHalfDay) ...[
            const SizedBox(height: 16),
            AppSegmented(
              labels: [l.leaveFullDay, l.leaveHalfFirst, l.leaveHalfSecond],
              selectedIndex: _half,
              onChanged: _setHalf,
            ),
          ],
          const SizedBox(height: 16),
          _summary(l),
          const SizedBox(height: 16),
          AppTextField(
            label: l.leaveReason,
            controller: _reason,
            hint: (type?.requiresReason ?? false)
                ? l.leaveReasonRequiredHint
                : l.leaveReasonHint,
            required: type?.requiresReason ?? false,
            maxLines: 4,
            errorText: _errReason(l),
            onChanged: (_) {
              if (_tried) setState(() {});
            },
          ),
          if (_sendError != null) ...[
            const SizedBox(height: 16),
            AppAlert(
              title: l.leaveSubmit,
              message: _sendError,
              tone: AppTone.danger,
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: l.leaveSubmit,
            size: AppButtonSize.lg,
            icon: AppIcons.forward,
            loading: _sending,
            onPressed: (_counting || _ruleError != null) ? null : _submit,
          ),
        ],
      ),
    );
  }

  /// The server's count (days, rest days, holidays, balance) or the rule that fails.
  Widget _summary(AppLocalizations l) {
    if (_ruleError != null) {
      return AppAlert(
        title: l.leaveDurationLabel,
        message: _ruleError,
        tone: AppTone.danger,
      );
    }
    final p = _preview;
    if (_counting && p == null) {
      return const AppSkeletonCard(height: 96);
    }
    if (p == null) return const SizedBox.shrink();
    final rows = <(String, String)>[
      (l.leaveSumDays, _days(l, p.workingDays)),
      if (p.weekendDays > 0) (l.leaveSumWeekend, _days(l, p.weekendDays)),
      if (p.holidayDays > 0) (l.leaveSumHolidays, _days(l, p.holidayDays)),
      if (p.deductedDays > 0) (l.leaveSumDeducted, _days(l, p.deductedDays)),
      if (p.balanceAfter != null)
        (l.leaveSumBalanceAfter, _days(l, p.balanceAfter!)),
      if (p.returnDate != null)
        (l.leaveSumReturn, formatLeaveDate(context, p.returnDate!)),
    ];
    return AppCard(
      showMark: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(rows[i].$1, style: AppText.body)),
                Text(rows[i].$2, style: i == 0 ? AppText.h3 : AppText.body),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

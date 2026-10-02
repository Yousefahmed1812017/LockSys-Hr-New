import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_request_card.dart';
import '../../core/widgets/app_icon_tabs.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_api.dart';
import 'leave_api.dart';
import 'leave_detail_page.dart';

/// Days as text: whole numbers use the plural form, halves show as 0.5.
String leaveDaysText(AppLocalizations l, num? days) {
  if (days == null) return '-';
  if (days == days.roundToDouble()) return l.daysCount(days.toInt());
  return l.leaveDaysValue(days.toString());
}

AppTone leaveTone(LeaveItem r) {
  if (r.isApproved) return AppTone.success;
  if (r.isRejected) return AppTone.danger;
  if (r.isCancelled) return AppTone.muted;
  return AppTone.warning;
}

/// The message of a failed call in the current language.
String leaveErrorText(BuildContext context, AuthException e) => e.network
    ? context.l10n.offlineMessage
    : e.message(Localizations.localeOf(context).languageCode);

/// Every leave request of the employee, newest first, with a status filter.
/// The server filters and pages (20 at a time, "Show more" adds the next page).
class MyLeavesPage extends StatefulWidget {
  const MyLeavesPage({super.key, required this.api});
  final LeaveApi api;

  @override
  State<MyLeavesPage> createState() => _MyLeavesPageState();
}

class _MyLeavesPageState extends State<MyLeavesPage> {
  static const _states = [
    LeaveState.all,
    LeaveState.open,
    LeaveState.approved,
    LeaveState.rejected,
    LeaveState.cancelled,
  ];

  int _filter = 0;
  final List<LeaveItem> _items = [];
  int _total = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _more = false;
  AuthException? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final state = _states[_filter];
    setState(() {
      _error = null;
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _items.clear();
      }
    });
    try {
      final page = await widget.api.requests(
        state: state,
        offset: more ? _items.length : 0,
      );
      if (!mounted || state != _states[_filter]) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.total;
        _hasMore = page.hasMore;
        _loading = false;
        _more = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _more = false;
      });
    }
  }

  void _details(LeaveItem r) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LeaveDetailPage(api: widget.api, item: r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: AppSkeletonList(count: 6),
      );
    } else if (_error != null && _items.isEmpty) {
      body = SizedBox(
        height: 360,
        child: AppEmptyState.offline(onAction: _load),
      );
    } else if (_items.isEmpty) {
      body = SizedBox(
        height: 320,
        child: AppEmptyState.empty(
          title: l.leaveEmptyTitle,
          message: l.leaveEmptyMessage,
          actionLabel: _filter == 0 ? null : l.showAll,
          onAction: _filter == 0
              ? null
              : () {
                  setState(() => _filter = 0);
                  _load();
                },
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.leaveCountTotal(_total), style: AppText.small),
            const SizedBox(height: AppSpacing.s2),
            for (final r in _items) ...[
              _LeaveCard(item: r, onTap: () => _details(r)),
              const SizedBox(height: AppSpacing.s3),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.s3),
              Text(
                leaveErrorText(context, _error!),
                textAlign: TextAlign.center,
                style: AppText.small.copyWith(color: AppColors.danger),
              ),
            ],
            if (_hasMore) ...[
              const SizedBox(height: AppSpacing.s3),
              AppButton(
                label: l.leaveShowMore,
                variant: AppButtonVariant.ghost,
                loading: _more,
                onPressed: () => _load(more: true),
              ),
            ],
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(showBack: true, title: l.leaveMyLeaves),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: AppIconTabs(
              tabs: [
                AppTabSpec(l.filterAll, AppIcons.file),
                AppTabSpec(l.statusOpen, AppIcons.clock),
                AppTabSpec(l.statusApproved, AppIcons.check),
                AppTabSpec(l.statusRejected, AppIcons.plus, rotated: true),
                AppTabSpec(l.statusCancelled, AppIcons.lock),
              ],
              selectedIndex: _filter,
              onChanged: (i) {
                if (i == _filter) return;
                setState(() => _filter = i);
                _load();
              },
            ),
          ),
          body,
        ],
      ),
    );
  }
}

/// One request as the shared request card: the type with a tinted status
/// pill, the duration / from / to band, and for an open request the stage it
/// waits at.
class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.item, required this.onTap});
  final LeaveItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final tone = leaveTone(item);
    final accent = switch (tone) {
      AppTone.success => AppColors.success,
      AppTone.danger => AppColors.danger,
      AppTone.muted => AppColors.muted,
      _ => AppColors.warning,
    };
    final stage = item.isOpen ? item.stage(lang) : null;
    return AppRequestCard(
      leading: const AppIconTile(AppIcons.calendar),
      title: item.typeName(lang),
      subtitle: item.requestNo,
      status: item.statusName(lang),
      statusTone: tone,
      accent: accent,
      facts: [
        (l.leaveDurationLabel, leaveDaysText(l, item.totalDays)),
        (l.detailFrom, shortDate(context, item.start)),
        (l.detailTo, shortDate(context, item.end)),
      ],
      note: stage == null ? null : '${l.detailWaitingAt}: $stage',
      onTap: onTap,
    );
  }
}

/// "Dec 6" / "6 ديسمبر": a date without the year, Western digits.
String shortDate(BuildContext context, DateTime? d) => d == null
    ? '-'
    : toWesternDigits(
        DateFormat.MMMd(Localizations.localeOf(context).toString()).format(d),
      );

/// A status pill on a dark surface (the leave detail's navy summary).
class LeaveStatusPill extends StatelessWidget {
  const LeaveStatusPill({super.key, required this.item});
  final LeaveItem item;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final color = switch (leaveTone(item)) {
      AppTone.success => const Color(0xFF3DDC97),
      AppTone.danger => const Color(0xFFFF6B6B),
      AppTone.muted => AppColors.onNavyMuted,
      _ => const Color(0xFFFFC857),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(AppRadius.xs + 2),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Text(
        item.statusName(lang),
        style: AppText.small.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

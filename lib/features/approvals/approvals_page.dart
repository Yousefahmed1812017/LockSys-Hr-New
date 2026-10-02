import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_alert.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_icon_tabs.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_text_field.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_api.dart';
import '../leave/leave_api.dart';
import '../leave/leave_request_page.dart' show formatLeaveDate;
import '../leave/my_leaves_page.dart' show leaveDaysText;
import 'approvals_api.dart';
import 'approvals_feed.dart';

/// Leave requests that need my decision as an approver (module `MobileApprovals`):
///   Waiting for me - my stage is pending and it is my turn
///   Later          - my stage is pending, an earlier stage has to decide first
///   Done           - what I approved or rejected
/// Tapping a request opens [ApprovalDetailPage] where I approve or reject it.
class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key, required this.api, this.embedded = false});
  final ApprovalsApi api;

  /// A tab of the home screen: no back button.
  final bool embedded;

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  static const _tabs = ApprovalTab.values;

  int _tab = 0;
  final List<ApprovalItem> _items = [];
  Map<String, int> _summary = const {};
  bool _hasMore = false;
  bool _loading = true;
  bool _more = false;
  AuthException? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _seq++;
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final seq = ++_seq;
    final tab = _tabs[_tab];
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
      final page = await widget.api.items(
        tab: tab,
        offset: more ? _items.length : 0,
      );
      if (!mounted || seq != _seq) return;
      setState(() {
        _items.addAll(page.items);
        _summary = page.summary;
        _hasMore = page.hasMore;
        _loading = false;
        _more = false;
      });
    } on AuthException catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e;
        _loading = false;
        _more = false;
      });
    }
  }

  Future<void> _open(ApprovalItem item) async {
    final decided = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ApprovalDetailPage(api: widget.api, requestId: item.requestId),
      ),
    );
    if (decided == true && mounted) _load();
  }

  String _label(AppLocalizations l, int i) {
    final n = _summary[_tabs[i].name];
    final base = [l.apprTabWaiting, l.apprTabLater, l.apprTabDone][i];
    return n == null || n == 0 ? base : '$base ($n)';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tab = _tabs[_tab];
    final Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: AppSkeletonList(count: 4),
      );
    } else if (_error != null && _items.isEmpty) {
      body = SizedBox(
        height: 360,
        child: AppEmptyState.offline(onAction: _load),
      );
    } else if (_items.isEmpty) {
      final (t, m) = switch (tab) {
        ApprovalTab.waiting => (l.apprEmptyWaitingTitle, l.apprEmptyWaitingMsg),
        ApprovalTab.later => (l.apprEmptyLaterTitle, l.apprEmptyLaterMsg),
        ApprovalTab.done => (l.apprEmptyDoneTitle, l.apprEmptyDoneMsg),
      };
      body = SizedBox(
        height: 320,
        child: AppEmptyState.empty(title: t, message: m),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final it in _items)
              if (it.canDecide)
                ApprovalActionCard(
                  key: ValueKey('appr-${it.requestId}'),
                  api: widget.api,
                  item: it,
                  onOpen: () => _open(it),
                  onDecided: () {
                    if (!mounted) return;
                    setState(() {
                      _items.remove(it);
                      final n = _summary['waiting'] ?? 0;
                      _summary = {..._summary, 'waiting': n > 0 ? n - 1 : 0};
                    });
                  },
                )
              else ...[
                ApprovalInfoCard(item: it, onTap: () => _open(it)),
                const SizedBox(height: AppSpacing.s2),
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
      appBar: AppTopBar(showBack: !widget.embedded, title: l.approvalsTitle),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          // One rectangle across the screen, the three tabs equal and centered.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: AppIconTabs(
              tabs: [
                AppTabSpec(_label(l, 0), AppIcons.clock),
                AppTabSpec(_label(l, 1), AppIcons.calendar),
                AppTabSpec(_label(l, 2), AppIcons.check),
              ],
              selectedIndex: _tab,
              onChanged: (i) {
                if (i == _tab) return;
                setState(() => _tab = i);
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

/// One request in full: a navy summary card like the balances (who, the type,
/// the days, from / to / back), the request's data, and the approval chain as a
/// timeline. When it is my turn a navy action card sits at the bottom with
/// Approve / Reject; after the decision it shows the result and the page closes
/// (popping true so the list reloads).
class ApprovalDetailPage extends StatefulWidget {
  const ApprovalDetailPage({
    super.key,
    required this.api,
    required this.requestId,
  });
  final ApprovalsApi api;
  final int requestId;

  @override
  State<ApprovalDetailPage> createState() => _ApprovalDetailPageState();
}

class _ApprovalDetailPageState extends State<ApprovalDetailPage> {
  ApprovalDetail? _data;
  bool _loading = true;
  bool _sending = false;
  bool? _approved; // set when the server took my decision
  AuthException? _error;
  String _lang = 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lang = Localizations.localeOf(context).languageCode;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.api.detail(widget.requestId);
      if (!mounted) return;
      setState(() {
        _data = d;
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

  Future<void> _decide({required bool approve}) async {
    final item = _data?.item;
    if (item == null) return;
    setState(() => _sending = true);
    final ok = await decideInline(context, widget.api, item, approve: approve);
    if (!mounted) return;
    if (!ok) {
      setState(() => _sending = false);
      return;
    }
    setState(() => _approved = approve);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = _data;
    final Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          children: [
            AppSkeletonCard(height: 170),
            SizedBox(height: AppSpacing.s3),
            AppSkeletonCard(height: 160),
            SizedBox(height: AppSpacing.s3),
            AppSkeletonCard(height: 140),
          ],
        ),
      );
    } else if (_error != null || d == null) {
      body = SizedBox(
        height: 360,
        child: AppEmptyState.offline(onAction: _load),
      );
    } else {
      body = _content(l, d);
    }
    final canDecide = d?.item.canDecide ?? false;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(showBack: true, title: l.apprDetailTitle),
      body: ListView(children: [body]),
      bottomNavigationBar: canDecide
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  8,
                  AppSpacing.gutter,
                  AppSpacing.gutter,
                ),
                child: AppCard(
                  elevated: true,
                  showMark: false,
                  padding: const EdgeInsets.all(14),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _approved == null
                          ? ApprovalButtons(
                              key: const ValueKey('buttons'),
                              busy: _sending,
                              onApprove: () => _decide(approve: true),
                              onReject: () => _decide(approve: false),
                            )
                          : ApprovalResultPanel(
                              key: const ValueKey('result'),
                              approved: _approved!,
                            ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _content(AppLocalizations l, ApprovalDetail d) {
    final item = d.item;
    final r = item.request;
    final waiting = item.waitingFor(_lang);
    String date(DateTime? v) => v == null ? '-' : formatLeaveDate(context, v);
    final line = AppText.small.copyWith(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    final muted = AppText.xs.copyWith(color: AppColors.onNavyMuted);
    Widget figure(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppText.small.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: muted),
        ],
      ),
    );
    final facts = <(String, String)>[
      if (r.workingDays != null)
        (l.detailWorkingDays, leaveDaysText(l, r.workingDays)),
      if (r.weekendDays != null && r.weekendDays! > 0)
        (l.detailWeekend, leaveDaysText(l, r.weekendDays)),
      if (r.holidayDays != null && r.holidayDays! > 0)
        (l.detailHolidays, leaveDaysText(l, r.holidayDays)),
      (l.detailSubmitted, date(r.requestDate)),
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppReveal(
            index: 0,
            child: AppCard(
              navy: true,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.apprRequester, style: muted),
                  const SizedBox(height: 2),
                  Text(
                    item.requesterName(_lang),
                    style: AppText.h3.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(AppRadius.xs + 2),
                        ),
                        child: Text(leaveDaysText(l, r.totalDays), style: line),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.typeName(_lang), style: line)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      figure(l.detailFrom, date(r.start)),
                      figure(l.detailTo, date(r.end)),
                      figure(l.leaveSumReturn, date(r.returnDate)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (waiting != null) ...[
            const SizedBox(height: AppSpacing.s3),
            AppReveal(
              index: 1,
              child: AppAlert(
                title: l.apprWaitingFirst(waiting),
                message: l.apprNotYet,
                tone: AppTone.warning,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          AppReveal(
            index: 2,
            child: AppCard(
              showMark: false,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.apprInfo, style: AppText.h3.copyWith(fontSize: 15)),
                  const SizedBox(height: 10),
                  for (final (label, value) in facts) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: AppText.small.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        Text(
                          value,
                          style: AppText.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Divider(height: 16, color: AppColors.line),
                  Text(
                    l.detailReason,
                    style: AppText.small.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(r.reason ?? l.noReason, style: AppText.body),
                ],
              ),
            ),
          ),
          if (d.stages.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            AppReveal(
              index: 3,
              child: AppCard(
                showMark: false,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.leaveApprovalSteps,
                      style: AppText.h3.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < d.stages.length; i++)
                      ApprovalTimelineStep(
                        step: d.stages[i],
                        last: i == d.stages.length - 1,
                        lang: _lang,
                        l: l,
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
        ],
      ),
    );
  }
}

/// One step of the approval chain: a dot (check, cross or clock) on a line that
/// joins the steps, the stage and who decides, the date and the notes. My own
/// step is marked.
class ApprovalTimelineStep extends StatelessWidget {
  const ApprovalTimelineStep({
    super.key,
    required this.step,
    required this.last,
    required this.lang,
    required this.l,
  });
  final ApprovalStep step;
  final bool last;
  final String lang;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (step.status) {
      'APPROVED' => (AppColors.success, AppColors.successBg),
      'REJECTED' => (AppColors.danger, AppColors.dangerBg),
      _ => (AppColors.warning, AppColors.warningBg),
    };
    final isMe = step.json['isMe'] == true;
    final notes = (step.json['notes'] as String?)?.trim();
    final who = step.approver(lang);
    final sub = [
      ?who,
      if (step.date != null) formatLeaveDate(context, step.date!),
    ].join(' · ');
    final dot = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: switch (step.status) {
          'APPROVED' => AppIcon(AppIcons.check, size: 15, color: color),
          'REJECTED' => Transform.rotate(
            angle: .785398,
            child: AppIcon(AppIcons.plus, size: 15, color: color),
          ),
          _ => AppIcon(AppIcons.clock, size: 15, color: color),
        },
      ),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                dot,
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: step.status == 'PENDING'
                          ? AppColors.line
                          : color.withValues(alpha: .35),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          step.name(lang),
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        AppBadge(l.apprYouLabel, tone: AppTone.info),
                      ],
                    ],
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: AppText.small.copyWith(color: AppColors.muted),
                    ),
                  if (notes != null && notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        notes,
                        style: AppText.small.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The notes field of the decision. Pops with the notes ('' when empty); a
/// rejection cannot be sent without a reason.
class ApprovalNotesSheet extends StatefulWidget {
  const ApprovalNotesSheet({super.key, required this.approve});
  final bool approve;

  @override
  State<ApprovalNotesSheet> createState() => _ApprovalNotesSheetState();
}

class _ApprovalNotesSheetState extends State<ApprovalNotesSheet> {
  final _notes = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!widget.approve && _notes.text.trim().isEmpty) {
      setState(() => _tried = true);
      return;
    }
    Navigator.of(context).pop(_notes.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // The sheet already lifts itself above the keyboard; this only has to fit
    // the space left, so it scrolls instead of overflowing.
    return Flexible(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: l.apprNotes,
              controller: _notes,
              hint: widget.approve ? l.apprNotesHint : l.apprRejectHint,
              required: !widget.approve,
              maxLines: 3,
              errorText: _tried && _notes.text.trim().isEmpty
                  ? l.apprRejectRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.s3),
            AppButton(
              label: l.apprConfirm,
              icon: widget.approve ? AppIcons.check : null,
              onPressed: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

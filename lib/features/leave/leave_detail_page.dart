import 'package:flutter/material.dart';

import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/widgets/app_skeleton.dart';
import '../approvals/approvals_page.dart' show ApprovalTimelineStep;
import 'leave_api.dart';
import 'leave_request_page.dart' show formatLeaveDate;
import 'my_leaves_page.dart' show LeaveStatusPill, leaveDaysText;

/// One of my leave requests in full, in the same look as an approval: a navy
/// summary (type, status, days, from / to / back), the request's data and the
/// approval chain as a timeline (loaded after the page opens).
class LeaveDetailPage extends StatefulWidget {
  const LeaveDetailPage({super.key, required this.api, required this.item});
  final LeaveApi api;
  final LeaveItem item;

  @override
  State<LeaveDetailPage> createState() => _LeaveDetailPageState();
}

class _LeaveDetailPageState extends State<LeaveDetailPage> {
  late final Future<LeaveDetail> _detail = widget.api.request(widget.item.id);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = widget.item;
    final lang = Localizations.localeOf(context).languageCode;
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
    final stage = r.isOpen ? r.stage(lang) : null;
    final statusReason = r.statusReason(lang);
    final substitute = r.substitute(lang);
    final facts = <(String, String)>[
      if (r.workingDays != null)
        (l.detailWorkingDays, leaveDaysText(l, r.workingDays)),
      if (r.weekendDays != null && r.weekendDays! > 0)
        (l.detailWeekend, leaveDaysText(l, r.weekendDays)),
      if (r.holidayDays != null && r.holidayDays! > 0)
        (l.detailHolidays, leaveDaysText(l, r.holidayDays)),
      if (substitute != null) (l.detailSubstitute, substitute),
      (l.detailSubmitted, date(r.requestDate)),
      if (r.requestNo != null) ('#', r.requestNo!),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(showBack: true, title: l.apprDetailTitle),
      body: ListView(
        children: [
          Padding(
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.typeName(lang),
                                style: AppText.h3.copyWith(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            LeaveStatusPill(item: r),
                          ],
                        ),
                        if (stage != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${l.detailWaitingAt}: $stage',
                            style: AppText.small.copyWith(
                              color: const Color(0xFFFFC857),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            borderRadius: BorderRadius.circular(
                              AppRadius.xs + 2,
                            ),
                          ),
                          child: Text(
                            leaveDaysText(l, r.totalDays),
                            style: line,
                          ),
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
                const SizedBox(height: AppSpacing.s4),
                AppReveal(
                  index: 1,
                  child: AppCard(
                    showMark: false,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.apprInfo,
                          style: AppText.h3.copyWith(fontSize: 15),
                        ),
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
                                textDirection: label == '#'
                                    ? TextDirection.ltr
                                    : null,
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
                        if (statusReason != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            l.detailStatusReason,
                            style: AppText.small.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(statusReason, style: AppText.body),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                FutureBuilder<LeaveDetail>(
                  future: _detail,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const AppSkeletonCard(height: 140);
                    }
                    final stages = snap.data?.stages ?? const <ApprovalStep>[];
                    if (stages.isEmpty) return const SizedBox.shrink();
                    return AppReveal(
                      index: 2,
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
                            for (var i = 0; i < stages.length; i++)
                              ApprovalTimelineStep(
                                step: stages[i],
                                last: i == stages.length - 1,
                                lang: lang,
                                l: l,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
